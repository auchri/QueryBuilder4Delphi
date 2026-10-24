# API reference and limitations

## Execution and optional FireDAC provider

The query describes the operation; the compiler generates parameterized SQL;
`IQueryExecutor` executes it and `IQueryResult` exposes its rows. `IQuery.Execute`
returns a `TQueryResult` record wrapping that interface. It delegates the reader
API, supports `AsRaw` and a one-way implicit conversion to `IQueryResult`.
With `QueryBuilder4Delphi.Mapping` in scope, its record helper supplies
`ToList<T>()` and `FirstOrDefault<T>()` by calling `TQueryMapper`.
Rebuild dependent units after the return-type change; see
[compatibility](OBJECT_MAPPING.md#result-facade-and-compatibility).
The contracts
live beside `IQuery` in `QueryBuilder4Delphi.Query.Core`, avoiding circular unit
references. They use only RTL types. `QueryBuilder4Delphi.Execution` supplies
`TQueryExecutor`, a reusable compiler/dialect implementation for providers.
FireDAC is confined to `QueryBuilder4Delphi.Providers.FireDAC` and its
`.Parameters` and `.Values` helper units. Core and compiler projects need neither FireDAC nor Data.DB.
The provider uses a caller-owned TFDConnection, never an existing TFDQuery.
See the [examples](EXAMPLES.md#query-execution) for a complete walkthrough.

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
cannot describe the type. The object mapper uses GetValue's actual
TValue.TypeInfo, which remains authoritative for non-NULL values. SQLite's
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
already have been rounded by the driver. Existing application/driver mapping rules
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

A complete provider bridge with :ParameterN names is shown in
[Custom providers](EXAMPLES.md#custom-providers) and compiled in
[test/Execution.ProviderExample.pas](../test/Execution.ProviderExample.pas).

The bridge returns its own IQueryResult cursor, interprets TQueryNull hints and
binds ordered values using the convention chosen by its compiler. All providers
must preserve the same result cursor, NULL, metadata and ownership contract.
FireDAC's own constructor retains its fixed :pN convention.

The optional provider-independent `TQueryMapper` maps result rows to ordinary
classes. Its static API supplies `ToList`, `First`, `FirstOrDefault`, `Single`,
`SingleOrDefault`, `MapCurrent` and callback-based `ForEach`, all with the same
`class, constructor` constraint and optional `TQueryMappingOptions`. Returned
objects/lists are caller-owned; streaming objects are borrowed for one callback.
See [cursor semantics and examples](EXAMPLES.md#object-mapping),
[benchmarks](MAPPING_PERFORMANCE.md), and [Object Mapping](OBJECT_MAPPING.md) for RTTI requirements,
native values, automatic built-in `TNullable<T>` mapping, scoped options and custom
converters. `RegisterNullable<T>` is an advanced extension point for application
types; standard nullable properties need no options or registration.
The existing Query.DataMapper helper
only reads object properties when constructing write queries.

Run the separate FireDAC SQLite in-memory suite after rebuilding:

```powershell
./tools/build.ps1 -Suite FireDAC -TestsOnly -Platform Both
```

## Public fluent API

Import `QueryBuilder4Delphi.Query.Core` for interfaces, enums and value helpers,
and `QueryBuilder4Delphi.Query` for the `TQuery` record factory. The factory
returns `IQuery`; fluent methods modify that instance and return it. Use Clone
for an independent variant. Delphi keywords use an `&` prefix, for example
`&From`, `&With`, `&As` and `&Not`.

`IQuery.Compile(Dialect: TSqlDialect = TSqlDialect.MSSql): string` produces a
preview with substituted values. `ICompiler.Compile(Query): ISqlResult`
returns parameterized SQL and ordered/named bindings.
`TQueryCompilerFactory.CreateCompiler(Dialect)`
in `QueryBuilder4Delphi.Compilers.Factory` supports MSSql, MySql, PostgreSql,
Sqlite, Oracle and Firebird. Its static method defaults to MSSql and replaces
the former unit-level `CreateCompiler` function. No factory instance is needed.
Individual compiler classes also return ICompiler from their Create methods.
`ParameterPrefix` configures named markers; `TSqlDialect.EngineCode` supplies
scope codes such as sqlsrv and mysql. Custom scopes can still use strings.

`TValue` carries parameter values. Use TSqlValues.&Of<T> for typed IN arrays,
TRows/TValues for multiple insert rows, or explicit column/value arrays when
order matters. Dates should be wrapped with TValue.From<TDateTime>. Object
write data is read from RTTI-accessible properties; Column, Key and Ignore
attributes control column names, key predicates and omitted properties.
This write helper is separate from result object mapping through `TQueryMapper`.

`TUnsafeLiteral` and `TVariable` are value records and need no Free. Ordinary
values use bindings; TUnsafeLiteral deliberately inserts SQL and must never
contain untrusted input. TQueryWrites and TQueryDataMapper are implementation
helpers used by the public write methods.

Callbacks accept and return IQuery. Return the query passed into the callback.
Custom query implementations can derive from TQueryObject and override
NewQuery/Clone. Low-level clauses and components belong to the query and must
not be freed by callers. Prefer fluent methods for application code.

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

## Additional behavior and limitations

- Having callbacks can build a grouped predicate with Where or Having; Where
  conditions take priority when both are present.
- Oracle aggregate aliases appear outside the aggregate expression.
- Raw binding counts must match unescaped placeholders outside quoted text and
  comments. Mismatches raise EQueryException before execution.
- Operators are checked against a whitelist. Aggregate names and date parts
  must be simple function/part names; raw fragments allow explicit SQL syntax.
- Joined write queries are supported only by the SQL Server and MySQL compilers.
- UseLegacyPagination selects TOP/ROW_NUMBER for SQL Server or ROWNUM for Oracle;
  the default SQL Server and Oracle compilers use OFFSET/FETCH.
- For restores the previous engine scope even if a callback raises. Clone
  preserves comment metadata. Comment/GetComment do not emit SQL comments.
- Batch compilation of an empty query array returns an empty result. Batch
  compilation is distinct from the one-result execution contract.
- Explicit arrays provide stable column/value order; RTTI property and
  dictionary enumeration order should not be assumed.

[Examples](EXAMPLES.md) show usage. [Contributor notes](PORTING.md) retain
technical history and reference-test provenance; [validation](VALIDATION.md)
records what was compiled and executed.
