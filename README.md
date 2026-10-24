# QueryBuilder4Delphi

QueryBuilder4Delphi is a fluent SQL query builder for Delphi 12 and later. It supports multiple SQL dialects, parameterized queries, and database-independent query execution through extensible providers.

Supported targets: **Windows, Win32 and Win64**. Build SQL without a database,
or execute it through the optional FireDAC provider or your own provider.

Current release: **[v1.0.0](https://github.com/auchri/QueryBuilder4Delphi/releases/tag/v1.0.0)**.
See the [changelog](CHANGELOG.md) for release details.

## Installation

Add `src` to the Delphi search path. The core needs only the Delphi RTL.
Import `QueryBuilder4Delphi.Query.Core` and `QueryBuilder4Delphi.Query` to build
queries; add a compiler unit when you need parameterized SQL and bindings.
FireDAC is required only by the optional provider.

## Quick start: build SQL

```delphi
uses
  System.SysUtils,
  QueryBuilder4Delphi.Query.Core,
  QueryBuilder4Delphi.Query,
  QueryBuilder4Delphi.Compilers.Compiler,
  QueryBuilder4Delphi.Compilers.Factory;

procedure ShowBookQuery;
var
  Query: IQuery;
  Compiler: ICompiler;
  Statement: ISqlResult;
begin
  Query := TQuery.Create('Books')
    .Select(['Id', 'Title'])
    .Where('Id', 42);
  Compiler := TQueryCompilerFactory.CreateCompiler(TSqlDialect.MSSql);
  Statement := Compiler.Compile(Query);
  Writeln(Statement.Sql);
  Writeln(Statement.Bindings[0].AsInteger); // 42
end;
```

**Generated parameterized MSSQL SQL (compiler default `@p` prefix):**

```sql
SELECT [Id], [Title] FROM [Books] WHERE [Id] = @p0
```

Bindings:

```text
@p0 = 42
```

Execute `Statement.Sql` together with its bindings. `Query.Compile` and
`Statement.ToString` produce a **SQL preview with values substituted**, intended
for diagnostics. They are not the parameterized execution path.

## Quick start: execute a query

```delphi
uses
  System.SysUtils,
  FireDAC.Comp.Client,
  QueryBuilder4Delphi.Query.Core,
  QueryBuilder4Delphi.Query,
  QueryBuilder4Delphi.Providers.FireDAC;

procedure PrintBooks(Connection: TFDConnection);
var
  Executor: IQueryExecutor;
  Rows: IQueryResult;
begin
  // The application supplies an already configured, connected connection.
  Executor := TFireDACQueryExecutor.Create(Connection, TSqlDialect.MSSql);
  Rows := TQuery.Create('Books')
    .Select(['Id', 'Title'])
    .Where('IsPublished', True)
    .OrderBy('Title')
    .Execute(Executor);
  while Rows.Next do
    if not Rows.IsNull('Title') then
      Writeln(Rows.GetValue('Title').AsString);
end;
```

The executor owns a separate query for each result. Interfaces release queries,
compilers and results automatically. **The caller owns the connection and
transactions; the connection must outlive the executor and all results.**
The SQL dialect selects grammar; the provider selects the driver and binding
mechanism. Supply the dialect explicitly; there is no automatic detection.

**[More examples](docs/EXAMPLES.md)** — filters, joins, CTEs, writes, pagination,
compiler settings, transactions, error handling and custom providers.

## Object Mapping

Fluent mapping is the recommended API. Use `System.Generics.Collections`,
`QueryBuilder4Delphi.Query.Core`, `QueryBuilder4Delphi.Query` and
`QueryBuilder4Delphi.Mapping`. The last unit brings the record helper into scope.
With the `TBook` class from [the compiled example](test/MappingExamples.pas):

```delphi
Books := TQuery.Create('Books')
  .Select(['Id', 'Title AS BookTitle'])
  .Where('IsPublished', True)
  .Execute(Executor)
  .ToList<TBook>();
try
  // Books owns its objects.
finally
  Books.Free;
end;
```

`Execute(Executor).FirstOrDefault<TBook>()` returns one caller-owned object or
`nil`; free it when finished. The returned `TObjectList<TBook>` owns its objects.
The static API remains available: `TQueryMapper.ToList<TBook>(Rows)` and
`TQueryMapper.FirstOrDefault<TBook>(Rows)`.
Fluent mapping consumes its facade and releases that reference before returning,
including on exceptions and after reading only the first row. Copies and retained
`IQueryResult` references keep their shared cursor alive. Materialized objects
remain valid after result destruction; connection ownership stays with the application.
Mapping calls `Next`, starting with the next remaining row. Public/published
writable properties need RTTI; names match without case sensitivity, with
`[Column]` and `[Ignore]` supported. Partial projections retain constructor
defaults. Supported values include signed/unsigned integers, floating point,
Currency, TBcd, Boolean, Unicode string, TDateTime, native SQL timestamp records,
TGUID and TBytes. `TNullable<T>` represents SQL NULL through explicit typed
registrations on operation-scoped `TQueryMappingOptions`. NULL to non-nullable
properties and unsupported or lossy conversions raise exceptions. Options also
provide opt-in `SkipNullAssignment` and exact-pair application converters.
See [working examples and limits](docs/OBJECT_MAPPING.md).

`IQuery.Execute` now returns a `TQueryResult` record holding the same
reference-counted cursor. Direct assignment to `IQueryResult` still works through
a one-way implicit conversion; `Execute(Executor).AsRaw` is the explicit form.
The facade also delegates all reader operations. Copies share cursor position.
Use `Default(TQueryResult)` to clear a facade, and rebuild dependent units after
the return-type change. Custom `IQuery` implementations must update their
`Execute` signature; executor/provider contracts are unchanged. See
[migration and helper scope](docs/OBJECT_MAPPING.md#result-facade-and-compatibility).

## SQL dialects

| Dialect | Compiler class | Default compiler parameters |
| --- | --- | --- |
| `TSqlDialect.MSSql` | `TSqlServerCompiler` | `@p0`, `@p1`, … |
| `TSqlDialect.MySql` | `TMySqlCompiler` | `@p0`, `@p1`, … |
| `TSqlDialect.PostgreSql` | `TPostgresCompiler` | `@p0`, `@p1`, … |
| `TSqlDialect.Sqlite` | `TSqliteCompiler` | `@p0`, `@p1`, … |
| `TSqlDialect.Oracle` | `TOracleCompiler` | `:p0`, `:p1`, … |
| `TSqlDialect.Firebird` | `TFirebirdCompiler` | `@p0`, `@p1`, … |

`TQueryCompilerFactory.CreateCompiler(Dialect)` creates an `ICompiler`
(default: MSSql). No factory instance is needed. Individual compiler classes
live in `QueryBuilder4Delphi.Compilers.<ClassName>` units, omitting the `T`
prefix. Executors use `:pN` by default; FireDAC requires that convention.
Pagination and other dialect differences are handled by the compiler.

## Results and limits

Call `Next` before reading a row. Indices are zero-based; names are resolved
without case sensitivity. `GetValue(Index/Name)` returns a `TValue`;
`IsNull(Index/Name)` distinguishes SQL NULL from empty values. Check NULL before
converting to a Delphi type. Unknown or ambiguous names raise `EQueryException`.
`RowsAffected` reports the provider count, or `-1` when unknown.

The execution API exposes at most one resultset. There is no connection
management or automatic transaction management. `emAuto`
uses query metadata; explicit `emRows`/`emCommand` are available. Identity
batches requested with `ReturnId` are rejected. Raw SQL and custom compilers
must respect the one-result contract; execution does not validate SQL syntax
or detect batches.

See the [API reference](docs/API.md) for types, NULL handling, resource ownership,
provider extensions and limitations.

## Build and test

Open `test/QueryBuilder.Tests.dproj` in Delphi 12+ and use **Project > Build**
for Windows 32-bit and Windows 64-bit. Run the separate optional
`test/QueryBuilder.FireDAC.Tests.dproj` for SQLite in-memory integration tests.
DUnitX sources bundled with Delphi are used only by tests.

After IDE builds, run:

```powershell
./tools/build.ps1 -Suite Core -Platform Both -TestsOnly
./tools/build.ps1 -Suite FireDAC -Platform Both -TestsOnly
```

Command-line builds through `tools/build.ps1` require an edition that supports
command-line compilation. [Validation notes](docs/VALIDATION.md) distinguish
compiled examples, compiler regression checks and actual database execution.
[Contributor and reference notes](docs/PORTING.md) cover generated code and test
provenance.

## License

MIT. See [LICENSE](LICENSE) for the license and retained third-party copyright
notice.
