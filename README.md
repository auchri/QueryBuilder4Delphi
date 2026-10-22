# QueryBuilder4Delphi

A Delphi port of the SqlKata query builder, based on local C# commit
`df4a2377750d34fc057c81886b481e7309ef975e`.
Targets **Delphi 12 or later on Windows, Win32 and Win64**.

The core library builds SQL and parameter lists. An optional FireDAC executor
applies queries and bindings to an existing `TFDQuery`. `SqlKata.Execution`,
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

Only single-statement execution is supported. Raw snippets must not contain
batches or additional SQL statements. If a server procedure yields multiple
resultsets, only its first result is exposed; further results/output parameters
are not accessible. No `NextResult` API is offered. `AsInsert(..., True)`
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
`GetValue` returns `TValue.Empty` for SQL NULL; use `IsNull`/`IsEmpty` before
conversion. NULL never becomes zero, false, or an empty string. Commands have
`HasResultSet=False`; all row/column access, including `Next`, raises.
`RowsAffected` is the provider count captured on execution, or **-1** when
unknown, including SELECTs for which the driver supplies no count.

Result values use string, Integer/Cardinal/Int64, Boolean, Double, Currency,
TDateTime, TGUID, TBcd, TBytes or the Variant's corresponding TValue type.
BCD is preserved as TBcd; binary/BLOB reads copy bytes without text conversion.
Unsupported field types raise a descriptive exception on access. FireDAC's
field definitions determine the exact Delphi type (SQLite has dynamic typing).
Timestamp offsets and nested datasets are not converted implicitly.

The parameter binder retains Unicode, signed/unsigned integers (large UInt64
as exact BCD), Boolean, floating point, Currency, TDateTime, GUID, TBcd, TBytes,
scalar Variant and NULL support. Unsupported bindings fail before allocating a
query. Import `QueryBuilder4Delphi.Providers.FireDAC.Parameters` plus `Data.DB`
for `TFireDACNull.Create(ftCurrency)` or another explicit NULL field type.
Untyped NULL defaults to ftWideString; ftUnknown is not a valid typed NULL.
All dialects use named `:p0`, `:p1`, ... parameters. Provider-created queries
have parameter expansion enabled, macro/escape expansion disabled, and no
caller-owned TFDQuery options to overwrite.

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

A custom provider (for example an external TDanaQueryExecutor) can implement
`IQueryExecutor` directly, or derive from `TQueryExecutor`, call inherited
`Create(Dialect)`, and override `ExecuteCompiled(const Statement: ISqlResult;
Mode: TQueryExecutionMode): IQueryResult`. Consume `Statement.Sql` and ordered
`Statement.Bindings` (named `p0`, `p1`, ...), then return an implementation of
`IQueryResult` with the cursor, NULL, type and ownership semantics above.
No FireDAC or private adapter dependency needs to enter the core repository.

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

These methods generate statements; they do not return affected rows or IDs.
For SQL Server, MySQL, PostgreSQL, and SQLite, `AsInsert` with `ReturnId=True`
appends the identity retrieval statement used by the C# implementation.

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
