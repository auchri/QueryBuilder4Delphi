# API mapping and limitations

## Execution and optional FireDAC provider

The query describes the operation; the compiler generates parameterized SQL;
`IQueryExecutor` executes it and `IQueryResult` exposes its rows. The contracts
live beside `IQuery` in `QueryBuilder4Delphi.Query.Core`, avoiding circular unit
references. They use only RTL types. `QueryBuilder4Delphi.Execution` supplies
`TQueryExecutor`, a reusable compiler/dialect implementation for providers.
FireDAC is confined to `QueryBuilder4Delphi.Providers.FireDAC` and its
`.Parameters` unit. Core and compiler projects need neither FireDAC nor Data.DB.
The former adapter unit and its static API have been removed (breaking change).

```delphi
uses
  System.SysUtils, FireDAC.Comp.Client,
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Query,
  QueryBuilder4Delphi.Providers.FireDAC;

procedure PrintBooks(Connection: TFDConnection);
var
  Executor: IQueryExecutor;
  Rows: IQueryResult;
begin
  // Connection is already configured and connected by the application.
  Executor := TFireDACQueryExecutor.Create(Connection, TSqlDialect.MSSql);
  Rows := TQuery.Create('Books').Select(['Id', 'Title'])
    .Where('IsPublished', True).OrderBy('Title').Execute(Executor);
  while Rows.Next do
    if not Rows.IsNull('Title') then
      Writeln(Rows.GetValue('Title').AsString);
end;

procedure ChangeBook(Connection: TFDConnection);
var
  Executor: IQueryExecutor;
  Command: IQueryResult;
begin
  Executor := TFireDACQueryExecutor.Create(Connection, TSqlDialect.MSSql);
  Connection.StartTransaction;
  try
    Command := TQuery.Create('Books')
      .AsInsert(['Id', 'Title'], [42, 'New book']).Execute(Executor);
    Writeln(Command.RowsAffected);
    Command := TQuery.Create('Books').Where('Id', 42)
      .AsUpdate(['Title'], ['Changed book']).Execute(Executor);
    Command := TQuery.Create('Books').Where('Id', 42).AsDelete.Execute(Executor);
    Command := nil;
    Connection.Commit;
  except
    Connection.Rollback;
    raise;
  end;
end;
```

`Execute(Executor, emAuto)` uses query metadata: select/aggregate opens rows;
insert/update/delete executes a command. WITH clauses do not change this rule.
For a single statement containing RETURNING/OUTPUT supplied through raw
extensions use `emRows` explicitly; `emCommand` explicitly expects no rows.
The compiler must itself support the requested SQL syntax/dialect. Execution
adds no RETURNING/OUTPUT rewriting. SQL prefixes are never parsed to choose a
mode. Unknown methods require an explicit mode. A mismatched explicit mode is
reported by FireDAC; database exception types/messages propagate unchanged.

Execution exposes at most one resultset. There is no NextResult API and
output parameters are unsupported. The executor passes the compiler's SQL and
bindings to the provider without scanning SQL keywords, counting statements,
or validating SQL syntax. emAuto uses query metadata only; explicit modes
handle provider-specific commands and RETURNING/OUTPUT when supported by the
compiler and driver. The database validates SQL syntax.

Raw fragments and custom compilers are caller-controlled SQL escape hatches.
They must satisfy this one-result contract; submitting a batch or procedure
that produces additional resultsets does not make those results accessible.
The library does not detect such commands or guarantee rejection before side
effects. Use the application's adapter directly when multiple resultsets or
output parameters are needed. `AsInsert(..., True)` (identity/ReturnId) is
still rejected from query metadata before execution because existing compilers
can append an identity statement. Retrieve identities separately in the same
caller-managed transaction, or use supported single-statement SQL.
`TUnsafeLiteral` and raw expressions remain explicit caller SQL escape hatches;
ordinary values always use bound parameters and never `RawSql` interpolation.

Results begin **before the first row**. `Next` advances once and returns false
for an empty/exhausted result; subsequent calls remain false. Reading values
before the first or after the last row raises `EQueryException`. Metadata is
available before iteration. Indices are zero based and remain reliable for
duplicate column names. Name lookup is case insensitive; missing or ambiguous
names raise `EQueryException` (FireDAC may disambiguate names itself).
`GetValue` returns `TValue.Empty` (no TypeInfo) for SQL NULL. Check
`IsNull(Index: Integer)` or `IsNull(const Name: string)` before conversion.
Both overloads use the same NULL/cursor rules. Name access reuses GetColumnIndex,
with the same case-insensitive lookup and missing/ambiguous-name exceptions as
GetValue(Name). Delphi also reports `TValue.IsEmpty=True` for a typed empty
dynamic array: an empty TBytes still has TypeInfo(TBytes) and IsNull=False.
Do not use TValue.IsEmpty alone as a SQL NULL test. NULL never becomes zero,
false, an empty string, or empty binary data. Commands have
`HasResultSet=False`; all row/column access, including `Next`, raises.
`RowsAffected` is the provider count captured on execution, or **-1** when
unknown, including SELECTs for which the driver supplies no count.

`GetColumnType(Index): TQueryValueType` is available before iteration, including
empty resultsets and wholly NULL columns. It reports broad provider-neutral
categories, not precision/scale or Delphi RTTI. qtUnknown means the provider
cannot describe the type. It is a useful hint for a future mapper; GetValue's
actual TValue.TypeInfo remains authoritative for non-NULL values. SQLite's
dynamic typing can give a different category from a declared SQL type.

Values preserve string, Integer/Cardinal/Int64, Boolean, Double, Single,
Extended (platform-native precision), Currency, TDateTime, TGUID, TBcd and
TBytes. Standard timestamps use Delphi RTL TSQLTimeStamp and
TSQLTimeStampOffset (Data.SqlTimSt), preserving fractions and timezone offset;
they are not coerced to TDateTime. These record types belong to the optional
provider's values, not the core contracts. Oracle CLOBs are strings. Opaque
ftOraTimeStamp, Oracle intervals, nested datasets and unsupported fields still
raise descriptive exceptions on non-NULL access; they are not guessed or
flattened. A driver may expose an Oracle timestamp as a supported standard
timestamp field instead. No live Oracle or SQL Server validation is claimed.

Both ftBCD and ftFMTBcd use the field's AsBCD accessor. Provider-created queries
prefer FMTBcd via MaxBcdPrecision/MaxBcdScale=0 so driver decimals use TBcd
storage, rather than Delphi's Currency-backed TBCDField. A Currency-backed BCD
field declaring scale >4 or precision >18 is rejected because values may
already have been rounded upstream. Existing application/driver mapping rules
that reduce precision cannot be undone by this library. Controlled field and
TFDMemTable regressions verify 8 decimal places, large/negative values and
zero handling; SQLite NUMERIC storage is not evidence of server decimal
precision. See Embarcadero's [data type mapping documentation](https://docwiki.embarcadero.com/RADStudio/Athens/en/Data_Type_Mapping_%28FireDAC%29).

Use provider-neutral `TQueryNull.Create(qtDecimal)` (or qtString, qtInteger,
qtInt64, qtBoolean, qtFloat, qtCurrency, qtDateTime, qtTimestamp,
qtTimestampOffset, qtGuid, qtBinary). It is a TValue-compatible record in
Query.Core and has no Data.DB dependency. Providers interpret the hint;
qtUnknown/default-initialized hints are rejected by FireDAC. The same query can
be passed to ADO-backed or FireDAC-backed external adapters without changing
its NULL values. For example:

```delphi
TQuery.Create('Books').Where('Id', 42)
  .AsUpdate(['Price'], [TQueryNull.Create(qtDecimal)]).Execute(Executor);
```

TValue.Empty remains an untyped NULL (FireDAC defaults it to ftWideString).
Empty strings and typed empty TBytes are values, with binding/result regressions
covering their distinction from NULL. Other databases may have their own empty
value semantics (notably Oracle empty strings); the provider cannot override
the server's data model. Optional TFireDACNull.Create(TFieldType) remains for
precise FireDAC-specific types beyond these broad hints; import its .Parameters
unit and Data.DB only in provider-specific application code.

Binding retains Unicode, signed/unsigned integers (large UInt64 as exact BCD),
Boolean, floats, Currency, TDateTime, GUID, TBcd, TBytes and scalar Variant.
Unsupported values fail before allocating a query. FireDAC validates that
ISqlResult.NamedBindings contains exactly :p0 ... :pN for the ordered Bindings,
then binds Values[I] to p<I> using pbByName. A compiler with another convention
is rejected by FireDAC. Raw '?' placeholders are expanded only outside quoted
text/identifiers and comments; repeated variables get distinct ordered bindings.
Placeholder-like text inside a string literal is left intact. The small
SqlCodeMask scanner exists only for parameter processing; it skips quoted
identifiers, doubled quotes, comments, PostgreSQL dollar/E strings and Oracle
q strings, with the existing MySQL backslash mode. It does not validate SQL:
unfinished quoted text/comments are masked to the end, while binding-count
checks still reject unmatched values. Outside quoted text, use the existing
`\?` raw escape to mark a non-parameter question mark, including dialect
operators; no operator/keyword heuristic is applied. As before, executable
Sql preserves this escape and ToString preview removes it. Ensure the chosen
compiler/driver supports the resulting raw syntax. Execution never
uses SQL previews or interpolates values into SQL. Provider-owned queries have
parameter expansion enabled, macro/escape expansion disabled, and empty-string
to NULL conversion disabled. There is no existing TFDQuery to overwrite.

Queries, executors and results are reference counted. Execution compiles a
clone, leaving the original query intact. Each result exclusively owns its
own TFDQuery, so another execution cannot invalidate it. Releasing the final
result interface closes the cursor and frees that query, including early loop
exit. Execution exceptions free temporary parameters/queries. Results retain
neither the source query nor the executor; there are no reference cycles.
The **caller-owned connection must outlive the executor and all its results**.
Never free/disconnect it while results are in use. Executors do not connect,
configure, own or free connections, or explicitly begin/commit/rollback
transactions. FireDAC's configured automatic transaction behavior still
applies; start an explicit transaction when the application needs control.
Executors and cursors are not thread safe; follow your driver's thread rules.

SQL dialect and database driver are independent choices: the dialect chooses
SQL grammar (such as SQL Server or Oracle); the provider chooses how to bind,
execute and read it (such as FireDAC or an external ADO bridge). No driver or
connection auto-detection is performed.

A provider may implement IQueryExecutor directly, or derive from TQueryExecutor.
The base constructor accepts `(Dialect, ParameterPrefix)` with default ':p'.
Protected virtual CreateCompiler can return a configured built-in compiler or
an application-defined ICompiler, including custom quoting, pagination and
other compiler settings. It is called once per execution; the returned compiler
produces SQL and bindings together. No finished-SQL placeholder replacement is
performed. Custom compilers must maintain the ISqlResult contract:

- Bindings[I] is the value of the compiler's Prefix + IntToStr(I) placeholder.
- NamedBindings maps those full tokens (including ':') to the same values.
- RawSql is the compiler's internal question-mark form; Sql is executable SQL.
- Repeated named variables are expanded to separate slots; a value is never
  interpolated into Sql by execution. A provider consumes the ordered list,
  not dictionary iteration order.

For an external adapter with :ParameterN names, this complete example compiles
in the core test project as test/Execution.ProviderExample.pas. The application
implements ICommandAdapter using its existing database abstraction; there is
no Dana-specific dependency or implementation in this repository:

```delphi
unit Execution.ProviderExample;

interface

uses
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Execution,
  QueryBuilder4Delphi.Compilers.Compiler;

type
  // Implement this bridge in the application using its existing adapter.
  ICommandAdapter = interface
    ['{6C14C9C2-BAAB-42CE-B5A2-441789327568}']
    function ExecuteParameterized(const Sql: string; const Values: TValues;
      Mode: TQueryExecutionMode): IQueryResult;
  end;

  TAdapterQueryExecutor = class(TQueryExecutor)
  private
    FAdapter: ICommandAdapter;
  protected
    function ExecuteCompiled(const Statement: ISqlResult;
      Mode: TQueryExecutionMode): IQueryResult; override;
  public
    constructor Create(const Adapter: ICommandAdapter; Dialect: TSqlDialect);
  end;

implementation

uses System.SysUtils;

constructor TAdapterQueryExecutor.Create(const Adapter: ICommandAdapter;
  Dialect: TSqlDialect);
begin
  // This adapter's named convention is :Parameter0, :Parameter1, ...
  inherited Create(Dialect, ':Parameter');
  if Adapter = nil then raise EArgumentNilException.Create('Adapter');
  FAdapter := Adapter;
end;

function TAdapterQueryExecutor.ExecuteCompiled(const Statement: ISqlResult;
  Mode: TQueryExecutionMode): IQueryResult;
begin
  // The bridge binds Values[I] to :Parameter<I>, interpreting TQueryNull hints.
  // It returns its own cursor implementation and defines connection ownership.
  Result := FAdapter.ExecuteParameterized(Statement.Sql, Statement.Bindings.ToArray, Mode);
end;

end.
```

The bridge returns its own IQueryResult cursor, interprets TQueryNull hints and
binds ordered values using the convention chosen by its compiler. Both adapters
must preserve the same result cursor, NULL, metadata and ownership contract.
FireDAC's own constructor retains its fixed :pN convention.

Future object mapping can consume only `IQueryResult`: names, TValue type
information, NULL and sequential iteration are already available for single
objects, lists and streaming. Delphi interfaces cannot declare generic
methods; a future record facade holding IQueryResult can offer `ToList<T>`,
`First<T>` or `Single<T>` without changing providers. No result object mapper
is implemented here. The existing Query.DataMapper remains solely for write
query construction from object properties.

Run the separate FireDAC SQLite in-memory suite after rebuilding:

```powershell
./tools/build.ps1 -Suite FireDAC -TestsOnly -Platform Both
```

## Public fluent API

The upstream public `Query` method names are available on `IQuery`, except for
`Include` and `IncludeMany`, which belong to the explicitly excluded execution
and relation-loading layer.

`Query` maps to `IQuery`, `Compiler` to `ICompiler`, and `SqlResult` to
`ISqlResult`. `TQuery.Create` is a record factory. `TCompiler` and the six
dialect compilers are classes; their inherited `Create` class function returns
`ICompiler` immediately. Temporary fluent chains do not require manual cleanup.
Each compiler has its own `QueryBuilder4Delphi.Compilers.<ClassName>` unit,
with the Delphi `T` prefix omitted from the unit name.
`IQuery.Compile(Dialect: TSqlDialect = TSqlDialect.MSSql): string` is a
Delphi convenience method for SQL previews. `TSqlDialect` is a scoped enum in
`QueryBuilder4Delphi.Query.Core` with `MSSql`, `MySql`, `PostgreSql`, `Sqlite`,
`Oracle`, and `Firebird`. The method creates the selected compiler with its
default settings and returns `Compiler.Compile(Query).ToString`, including
substituted values. It preserves the query, propagates compiler errors, and
requires no compiler unit imports in calling code. Use `ICompiler.Compile`
when you need SQL and bindings separately or custom compiler settings.

`CreateCompiler(Dialect)` in `QueryBuilder4Delphi.Compilers.Factory` creates
the corresponding reference-counted compiler. `ICompiler.ParameterPrefix`
configures generated named markers (for example, `':p'` produces `:p0`).
The default compiler prefixes remain unchanged.

`TQueryObject` and the `TQuery` factory live in `QueryBuilder4Delphi.Query`.
`IQuery`, `TClause`, callbacks, attributes, and value types live in
`QueryBuilder4Delphi.Query.Core`. Import both units to use the model directly.
The `SqlKata` and `QueryBuilder4Delphi.Compilers` facade units are no longer
provided. Import the defining units directly; rebuild dependent units and
packages after updating the library. The fluent method signatures remain the
same, but old imports and compatibility type names are intentionally removed.
All include files have been removed. Generated fluent declarations and methods
are regular Pascal source in marked sections of the two query units.
`tools/generate_query.py` updates those sections without replacing handwritten
code; `--check` verifies generated tokens while allowing formatter whitespace
outside strings, comments, and directives. Generation preserves matching
formatted files. Use `tools/format.ps1` after generating changed code.
The upstream `EngineCodes` constants are represented by
`TSqlDialect.EngineCode`: for example, `TSqlDialect.MSSql.EngineCode` returns
`'sqlsrv'`. Dialect compilers and the `ForSqlServer`/`ForMySql`/etc. methods use
this central mapping. The former `TEngineCodes` record has been removed;
replace `TEngineCodes.SqlServer` with `TSqlDialect.MSSql.EngineCode` and use
the corresponding enum member for each other dialect. `IQuery.For` and
`SetEngineScope` continue to accept strings for custom compiler engine names.
The base `TCompiler` uses the string code `'generic'`.

Write operations delegate to the stateless `TQueryWrites` class in
`QueryBuilder4Delphi.Query.Writes`. RTTI property mapping delegates to
`TQueryDataMapper` in `QueryBuilder4Delphi.Query.DataMapper`. These are
implementation helpers; applications continue to call `IQuery.AsInsert`,
`AsUpdate`, `AsDelete`, `AsIncrement`, `AsDecrement`, and `AsAggregate`.
The former `SqlKata.Writes.inc` is no longer used or provided.

`object` parameters become `TValue`; `params` and `IEnumerable` parameters
become open arrays or `TArray`. For IN values from typed arrays,
`TSqlValues.&Of<T>` converts to `TValues`. Multiple rows use `TRows`, with
`TValues` for each row. Dictionaries use `TDictionary<string,TValue>` or arrays
of `TPair<string,TValue>`. Delphi has no C# anonymous data types; object data
uses RTTI-accessible Delphi properties.

`TUnsafeLiteral` and `TVariable` are value records with implicit conversion to
`TValue`; they do not need `Free`. `TUnsafeLiteral.Create(SQL, False)` leaves
the SQL text unchanged. These record constructors replace the `Expressions`
helper class.

Condition and join callbacks use `IQuery` directly. The former
`IConditionGroup`, `TConditionGroup`, `IJoin`, and `TJoin` aliases have been
removed. The C# internal clause subclasses,
interfaces, separate `Wheres`/`Havings`/clause properties, and visitor and
CompileContext extension interfaces are not reproduced with binary or type
compatibility. Instead, the port exposes `TClause`, `Clauses`, `GetComponents`,
`GetOne`, and `ClearComponent`. Components are `where`, `having`, `select`,
`from`, `group`, `order`, `join`, `cte`, `combine`, `limit`, `offset`,
`aggregate`, `insert`, and `update`. These internal lists belong to the query.
Custom query implementations can derive from `TQueryObject` and override
`NewQuery`/`Clone`. Always hold implementation instances through interfaces.

## Compiler classes and extensions

`TCompiler` in `QueryBuilder4Delphi.Compilers.Compiler` contains shared SQL generation.
`TSqlServerCompiler`, `TPostgresCompiler`, `TMySqlCompiler`, `TSqliteCompiler`,
`TOracleCompiler`, and `TFirebirdCompiler` derive from it in individual Pascal
units. Dialect-specific behavior is implemented through virtual overrides,
including pagination, date expressions, random and Boolean expressions,
identifier wrapping, ad hoc tables, multirow inserts, and joined updates.
The compiler sources contain no include directives or engine-name dispatch.

Derive custom compilers from `TCompiler` or a dialect class and override the
relevant virtual methods. Override the protected `CreateInstance` constructor
for initialization, calling `inherited` first. The inherited `Create` class
function uses the receiving class and its virtual constructor, so
`TCustomCompiler.Create` returns an `ICompiler` for the custom descendant.
Do not replace it with an object-returning constructor or call `CreateInstance`
from application code. Derive from `TCompiler` or the named dialect class;
the former `TCompilerObject` and `T...CompilerObject` aliases have been removed.

[CompilerClasses.Tests.pas](../test/CompilerClasses.Tests.pas) demonstrates
custom MySQL and SQL Server descendants. It checks that inherited dialect
behavior survives a custom `EngineCode`, and that custom overrides are called
through `ICompiler`.

## Memory and lifetime

- `IQuery`, `ICompiler`, `ISqlResult`, `IQueryExecutor` and `IQueryResult` use reference counting through
  `TInterfacedObject`. Assignments share the same instance; `Clone` creates an
  independent query. Leaving scope or assigning `Q := nil` releases a reference.
  Never call `Free`/`FreeAndNil` on the implementation objects.
- For single-query `Compile` calls, `ISqlResult.Query` keeps the original query
  alive. For batch results, `Query` remains `nil`, as before.
- `Clauses`, `Variables`, `Bindings`, and `NamedBindings` are borrowed RTL
  collections. They belong to their query or result and must not be freed
  separately. Keep the owning interface alive while using them.
- Supplied query objects are copied. The caller may modify or release the
  original after the method returns.
- Callback helper queries are created and copied internally; their lifetimes
  are also reference-counted. A retained callback query interface remains valid
  after the callback returns. Callbacks are not stored in the query. Callbacks
  must return the query they receive; returning another query or `nil` raises
  an exception. `When` and `For` operate directly on the original query and
  likewise require that query to be returned.
- `TValue` holds scalar values, records, and reference-counted data according
  to RTL rules. Arbitrary `TObject` instances wrapped as parameters are not owned.
- Query clones own independent clauses and subqueries. Reference objects
  embedded in custom `TValue` data are not deeply cloned.
- As with all reference-counted interfaces, custom extensions must avoid strong
  reference cycles. Built-in query trees have no back references; subqueries
  are cloned.
- Query instances and configurable compilers do not synchronize shared mutable
  state. Use separate instances per thread.

## Intentionally corrected upstream bugs

The following corrections were explicitly approved:

1. `Having(function(Q: IQuery): IQuery begin Result := Q.Where(...); end)`
   produces a HAVING group. The C# overload checks only `query.Havings` and
   discards conditions from `query.Wheres`. A callback using `Q.Having(...)`
   also works. For both components, Delphi prefers the Where group and falls
   back to the Having group when no Where group exists.
2. `TOracleCompiler.Create.Compile(TQuery.Create.SelectCount('Id as Total'))`
   produces `COUNT("Id") "Total"`. The C# implementation loses the AS keyword
   while splitting the alias and places the alias inside the aggregate:
   `COUNT("Id" "Total")`. The Delphi correction also applies to filtered
   aggregates and Oracle legacy mode.

The unmodified C# reference outputs for these cases remain in `test/golden.json`.
The twelve affected engine/scenario combinations have explicit correction tests;
the reference data is not silently changed to match the corrected output.

## Other differences due to Delphi and lifetime management

- `For` restores the previous EngineScope even when an exception occurs.
- `Clone` preserves the comment. The current C# implementation does not copy it.
- Batch compilation of an empty array returns an empty result.
- Raw binding counts must match unescaped `?` placeholders; mismatches raise
  `EQueryException` early.
- Operators are checked against a whitelist. Aggregate names and date parts
  must be simple SQL function or part names. Dialect-specific names such as
  `quarter` are allowed; raw expressions support arbitrary SQL fragments.
- The compact model does not guarantee RTTI property or dictionary entry order.
  Use explicit column/value arrays when order matters.
- Whitespace formatting in compiled SQL may differ. Parity comparisons
  normalize only these whitespace differences. No database servers are contacted.

As in the local C# compiler implementation, `Comment`/`GetComment` manage model
metadata; comments are not inserted into SQL.
