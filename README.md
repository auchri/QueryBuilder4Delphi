# QueryBuilder4Delphi

A Delphi port of the SqlKata query builder, based on local C# commit
`df4a2377750d34fc057c81886b481e7309ef975e`.
Targets **Delphi 12 or later on Windows, Win32 and Win64**.

The core library builds SQL and parameter lists. An optional FireDAC executor
uses a caller-owned `TFDConnection` and creates a separate owned query per result. The upstream `SqlKata.Execution` compatibility API,
connection management, object result mapping, `Get`, `First`, and `Paginate`
are outside the scope of this pilot. `ForPage` generates LIMIT/OFFSET or
the equivalent SQL for the selected dialect.

## Installation

Add `src` to the Delphi search path. The core requires only the Delphi RTL.
No package or additional runtime libraries are required.
Import `QueryBuilder4Delphi.Providers.FireDAC` only when using the optional provider;
that unit additionally requires FireDAC and `Data.DB`.

```pascal
uses
  System.SysUtils, System.Rtti,
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Query,
  QueryBuilder4Delphi.Compilers.Compiler,
  QueryBuilder4Delphi.Compilers.SqlServerCompiler;
```

Queries, compilers, and results use **reference-counted interfaces**:
`IQuery`, `ICompiler`, and `ISqlResult`. They are released automatically when
they leave scope, including during exceptions. No `Free` or `try..finally`
is needed for these objects. `TQuery.Create` and the compiler factories return
interfaces directly, preserving the familiar fluent calls.
Supplied subqueries, joins, filters, and condition groups are still copied.
Callbacks accept and return `IQuery` and must return the query they receive.

## Complete example

```pascal
program BooksSql;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Query,
  QueryBuilder4Delphi.Compilers.Compiler,
  QueryBuilder4Delphi.Compilers.SqlServerCompiler;

var
  Q: IQuery;
  Compiler: ICompiler;
  Compiled: ISqlResult;
begin
  Q := TQuery.Create('Books')
    .Select(['Id', 'Title'])
    .WhereTrue('IsPublished')
    .Where('Lang', 'de')
    .OrderByDesc('PublishedAt')
    .Limit(10);

  Compiler := TSqlServerCompiler.Create;
  Compiled := Compiler.Compile(Q);
  Writeln(Compiled.Sql);
  Writeln(Compiled.Bindings[0].AsString); // de
end.
```

SQL:

```sql
SELECT [Id], [Title] FROM [Books]
WHERE [IsPublished] = cast(1 as bit) AND [Lang] = @p0
ORDER BY [PublishedAt] DESC
OFFSET @p1 ROWS FETCH NEXT @p2 ROWS ONLY
```

Bindings, in order: `de`, `0` (offset), `10` (limit).

`Sql` contains named parameters; `RawSql` contains `?` placeholders.
`Bindings` contains `TValue` values in SQL order, and `NamedBindings` contains
the same values under `@p0`, `@p1`, etc., or `:p0`, `:p1`, etc. for Oracle.
`ToString` substitutes parameters for diagnostic output; use SQL and bindings
separately when executing a statement. `ISqlResult.Query` keeps the original
query alive. Compilation does not modify the query.

## Compile directly from a query

For a SQL preview with values substituted, call `Compile` on the query.
SQL Server is the default; no compiler unit imports or manual cleanup are
needed for this shortcut.

```pascal
uses QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Query;

// SELECT [Title] FROM [Books] WHERE [Id] = 42
Sql := TQuery.Create('Books').Select('Title').Where('Id', 42).Compile;

// SELECT `Title` FROM `Books` WHERE `Id` = 42
Sql := TQuery.Create('Books').Select('Title').Where('Id', 42)
  .Compile(TSqlDialect.MySql);
```

`Compile(Dialect: TSqlDialect = TSqlDialect.MSSql): string` supports `MSSql`,
`MySql`, `PostgreSql`, `Sqlite`, `Oracle`, and `Firebird`. It uses the selected
compiler's default settings and returns the same text as
`Compiler.Compile(Query).ToString`, without changing the query. This is a
preview and logging convenience. For execution with parameters, or custom
compiler settings, use the compiler API shown above to keep SQL and bindings
separate.

`TSqlDialect` also provides the central engine-code mapping:
`TSqlDialect.MSSql.EngineCode` returns `'sqlsrv'`, and
`TSqlDialect.MySql.EngineCode` returns `'mysql'`. Use this helper wherever
an engine-code string is needed. Custom compilers can still define their own
string codes for `For` and `SetEngineScope`. The former `TEngineCodes` record
has been removed.

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
    if not Rows.IsNull(1) then
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

Only single-statement execution is supported. A lexical check rejects a
semicolon followed by another statement before any database call, respecting
quoted text/identifiers, -- and /* */ comments, PostgreSQL dollar quotes and
Oracle q-quotes. One trailing semicolon (and comments) is allowed. Raw snippets
must not contain batches, client batch commands, or calls known to return
multiple resultsets. A conservative top-level DML-root check also rejects
adjacent SELECT/INSERT/UPDATE/DELETE statements without semicolons; UNION,
INSERT SELECT, CTEs, ON CONFLICT DO UPDATE and SELECT FOR UPDATE are allowed.
Procedural SQL, EXEC/CALL, DDL, transaction-control statements and MERGE
are rejected by this query execution path. Use the application's database
adapter directly for those operations. The check
is not a full SQL parser and cannot inspect server-side functions or triggers.
Only the first cursor is accessible; additional results and output parameters
are unsupported. No `NextResult` API is offered. `AsInsert(..., True)`
(identity/ReturnId) is rejected before execution in every mode because existing
compilers can append another statement. Retrieve identities separately in the
same caller-managed transaction, or use supported single-statement SQL.
`TUnsafeLiteral` and raw expressions remain explicit caller SQL escape hatches;
ordinary values always use bound parameters and never `RawSql` interpolation.

Results begin **before the first row**. `Next` advances once and returns false
for an empty/exhausted result; subsequent calls remain false. Reading values
before the first or after the last row raises `EQueryException`. Metadata is
available before iteration. Indices are zero based and remain reliable for
duplicate column names. Name lookup is case insensitive; missing or ambiguous
names raise `EQueryException` (FireDAC may disambiguate names itself).
`GetValue` returns `TValue.Empty` (no TypeInfo) for SQL NULL. Use `IsNull`
before conversion. Delphi also reports `TValue.IsEmpty=True` for a typed empty
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
Placeholder-like text inside a string literal is left intact. Execution never
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

## More tested examples

The following functions are also available in `test/ReadmeExamples.pas`.
DUnitX compiles them and checks the generated SQL and parameter counts.
The returned interfaces manage their lifetimes automatically.

### Join with an alias

```pascal
function BooksWithAuthors: IQuery;
begin
  Result := TQuery.Create('Books');
  Result.Join('Authors', 'Authors.Id', 'Books.AuthorId')
    .Select(['Books.*', 'Authors.Name as AuthorName']);
end;
```

```sql
SELECT [Books].*, [Authors].[Name] AS [AuthorName]
FROM [Books]
INNER JOIN [Authors] ON [Authors].[Id] = [Books].[AuthorId]
```

### Nested conditions

```pascal
function NestedConditions: IQuery;
begin
  Result := TQuery.Create('Books');
  Result.Where(
    function(Q: IQuery): IQuery
    begin
      Result := Q.Where('Lang', 'de').OrWhere('Lang', 'en');
    end).WhereNotNull('PublishedAt');
end;
```

```sql
SELECT * FROM [Books]
WHERE ([Lang] = @p0 OR [Lang] = @p1) AND [PublishedAt] IS NOT NULL
```

### CTE

```pascal
function PublishedCte: IQuery;
begin
  Result := TQuery.Create('published');
  Result.&With('published',
    function(Q: IQuery): IQuery
    begin
      Result := Q.&From('Books').WhereTrue('IsPublished');
    end).Select('Title');
end;
```

```sql
WITH [published] AS (
  SELECT * FROM [Books] WHERE [IsPublished] = cast(1 as bit)
)
SELECT [Title] FROM [published]
```

### INSERT, UPDATE, and DELETE

```pascal
function InsertUser: IQuery;
begin
  Result := TQuery.Create('Users');
  Result.AsInsert(['Name', 'CountryId'], ['Jane', 1]);
end;

function UpdateUser: IQuery;
begin
  Result := TQuery.Create('Users');
  Result.Where('Id', 1).AsUpdate(['Name', 'CountryId'], ['Jane', 2]);
end;

function DeleteUser: IQuery;
begin
  Result := TQuery.Create('Users');
  Result.Where('Id', 1).AsDelete;
end;
```

```sql
INSERT INTO [Users] ([Name], [CountryId]) VALUES (@p0, @p1)
UPDATE [Users] SET [Name] = @p0, [CountryId] = @p1 WHERE [Id] = @p2
DELETE FROM [Users] WHERE [Id] = @p0
```

AsInsert/AsUpdate/AsDelete construct statements; Execute returns the result
with RowsAffected. In compilation-only usage, ReturnId=True appends the C#
identity retrieval statement for SQL Server, MySQL, PostgreSQL and SQLite.
Execution rejects these multi-statement identity batches before database access;
use a supported single-statement RETURNING/OUTPUT form or a separate query.

## API and data types

Method names follow the C# API. Delphi keywords receive an `&` prefix:
`&From`, `&As`, `&With`, `&For`, `&Or`, `&And`, `&Not`, `&Except`.
Pass multiple columns or values as an array, for example
`Select(['Id', 'Title'])` or `WhereIn('Id', [1, 2, 3])`.
Use `TSqlValues.&Of<Integer>(Ids)` for typed arrays.

Parameters use `TValue`. Numbers, strings, and Boolean values are converted
implicitly. Use `TValue.Empty` or `WhereNull` for SQL NULL. Pass dates explicitly
with `TValue.From<TDateTime>(DateValue)`. `TBytes` remains a single binary
parameter. Raw array parameters are expanded by one level.
Use `\?` to escape a question mark in a raw expression.

Supported features include WHERE/HAVING with OR/NOT, NULL, Boolean, IN, BETWEEN,
LIKE/Starts/Ends/Contains, date parts, nested groups, subqueries, and EXISTS;
SELECT aggregates with filters, GROUP BY, ORDER BY, joins, CTEs including value
tables, UNION/EXCEPT/INTERSECT, write queries, cloning, variables, `When`, and
engine-specific `For...` callbacks.

Object data is read through RTTI-accessible properties. `[Column('Name')]`,
`[Key('Id')]`, and `[Ignore]` correspond to the C# attributes; with `AsUpdate`,
a key also adds a WHERE condition. Dictionaries use
`TDictionary<string,TValue>`; explicit column arrays determine the order.

See [docs/API.md](docs/API.md) for ownership rules, API limitations, and the
explicitly corrected C# bugs.

## SQL dialects

| Compiler class (`Create` returns `ICompiler`) | EngineCode | Parameter |
| --- | --- | --- |
| `TSqlServerCompiler` | `sqlsrv` | `@p0` |
| `TPostgresCompiler` | `postgres` | `@p0` |
| `TMySqlCompiler` | `mysql` | `@p0` |
| `TSqliteCompiler` | `sqlite` | `@p0` |
| `TOracleCompiler` | `oracle` | `:p0` |
| `TFirebirdCompiler` | `firebird` | `@p0` |

SQL Server and Oracle use OFFSET/FETCH by default.
`UseLegacyPagination := True` enables TOP/ROW_NUMBER for SQL Server and ROWNUM
for Oracle. Firebird supports FIRST/SKIP/ROWS.
As in the C# implementation, write queries with joins are supported only for
SQL Server and MySQL; the other compilers reject them.

Each dialect has its own class and Pascal unit under `src`:

- [TCompiler](src/QueryBuilder4Delphi.Compilers.Compiler.pas): shared compilation logic.
- [TSqlServerCompiler](src/QueryBuilder4Delphi.Compilers.SqlServerCompiler.pas).
- [TPostgresCompiler](src/QueryBuilder4Delphi.Compilers.PostgresCompiler.pas).
- [TMySqlCompiler](src/QueryBuilder4Delphi.Compilers.MySqlCompiler.pas).
- [TSqliteCompiler](src/QueryBuilder4Delphi.Compilers.SqliteCompiler.pas).
- [TOracleCompiler](src/QueryBuilder4Delphi.Compilers.OracleCompiler.pas).
- [TFirebirdCompiler](src/QueryBuilder4Delphi.Compilers.FirebirdCompiler.pas).

The dialect classes inherit from `TCompiler` and override pagination, date
expressions, and other dialect-specific behavior. Compiler implementations
do not use include files. Import `QueryBuilder4Delphi.Compilers.Compiler`
and the required dialect unit directly.
Use the `QueryBuilder4Delphi.Compilers` prefix in compiler `uses` clauses.
Calls such as `TSqlServerCompiler.Create` remain the same.
`Create` returns `ICompiler` and preserves automatic lifetime
management. See [docs/API.md](docs/API.md) for subclassing details.

## Running DUnitX

DUnitX is required only for tests. The test project uses the sources bundled
with Delphi under `$(BDS)\source\DUnitX`.

**IDE, including Community Edition:**

1. Open `test/QueryBuilder.Tests.dproj`.
2. Select Windows 32-bit and run **Project > Build** (`Shift+F9`).
3. Select Windows 64-bit and run **Build** again.
4. Run `./tools/build.ps1 -TestsOnly` from the repository.

**Delphi editions with a command-line compiler:**

```powershell
./tools/build.ps1 -BdsRoot 'C:\Program Files (x86)\Embarcadero\Studio\23.0'
```

For a single platform, add `-Platform Win32` or `-Platform Win64`.
Outputs are written to `build/Win32` and `build/Win64`:
the test executable, `tests.log`, and the NUnit XML report `results.xml`.
The test process returns a nonzero exit code on failure.

The checked-in `test/golden.json` contains output from the actual C# source.
SQL comparisons normalize whitespace; bindings are compared in order.
Known, intentionally corrected upstream bugs are tested separately against
the corrected output. Running the tests requires neither .NET nor a database.
See [docs/VALIDATION.md](docs/VALIDATION.md) for validation details.

Python and a .NET SDK with .NET 8 support are needed only to **regenerate**
the reference data:

```powershell
python tools/generate_oracle.py ../querybuilder
dotnet run --project tools/oracle/Oracle.csproj -- test/golden.json
```

Write operations are implemented by `TQueryWrites` in
`src/QueryBuilder4Delphi.Query.Writes.pas`. Object property mapping is handled
by `TQueryDataMapper` in `src/QueryBuilder4Delphi.Query.DataMapper.pas`.
The public `IQuery` methods delegate to these classes; callers continue to
use the same fluent API.

The query class `TQueryObject` and the `TQuery` factory are implemented in
[QueryBuilder4Delphi.Query](src/QueryBuilder4Delphi.Query.pas). Shared interfaces,
clauses, attributes, and value helpers live in
[QueryBuilder4Delphi.Query.Core](src/QueryBuilder4Delphi.Query.Core.pas).
Import both `QueryBuilder4Delphi.Query.Core` and `QueryBuilder4Delphi.Query`.
The old `SqlKata` and compiler facade units have been removed; existing
applications must update their imports to the defining units. Legacy
`T...CompilerObject`, `IConditionGroup`, `TConditionGroup`, `IJoin`, and `TJoin`
aliases have also been removed. Use the compiler classes and `IQuery` directly.

Regenerate the fluent forwarding methods with `python tools/generate_query.py`.
Make semantic changes in the Pascal units and their corresponding tests.
The generator updates marked sections in the query units; no include files
are required. Reference scenario queries live in `test/Oracle.Scenarios.pas`,
and generated DUnitX case attributes live in `test/QueryBuilder.Tests.pas`.

Verify generated Pascal sources and the generator's replacement safeguards:

```powershell
python tools/generate_query.py --check
python tools/generate_oracle.py --check
python tools/test_generated_sections.py
```

These checks require Python only. Both `--check` commands leave files unchanged
and return a nonzero exit code when generated content is out of date. They
ignore layout outside Pascal strings, comments, and directives; generation
preserves existing formatting when the generated tokens already match.

Format Delphi source and test files with the installed Embarcadero formatter:

```powershell
./tools/format.ps1
```

Run this from a RAD Studio command prompt with `Formatter.exe` on `PATH`, or
pass `-Formatter` with its full path. The script uses the installation's
`config/Formatter_Default.config`; use `-Config` to select another profile.
It formats immediate `.pas` and `.dpr` files in `src` and `test`, leaving IDE
history and build output alone. Run it again after generators change code.

## License

MIT, including the upstream C# copyright notice; see [LICENSE](LICENSE).
