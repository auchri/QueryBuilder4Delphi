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

<!-- mssql:QuickStartBooks -->
**Generated parameterized MSSQL SQL (compiler default `@p` prefix):**

```sql
SELECT [Id], [Title] FROM [Books] WHERE [Id] = @p0
```

Bindings:

```text
@p0 = 42
```
<!-- /mssql:QuickStartBooks -->

Execute `Statement.Sql` together with its bindings. `Query.Compile` and
`Statement.ToString` produce a **SQL preview with values substituted**, intended
for diagnostics. They are not the parameterized execution path.

## Fluent search with optional filters

A book catalogue can combine author details, optional filters and paging in one
chain. Using the imports above, build a fresh query for each search:

```delphi
function SearchBooks(const Title, Author: string; PublishedOnly: Boolean;
  Page, PageSize: Integer): IQuery;
begin
  Result := TQuery.Create('Books as b')
    .Join('Authors as a', 'a.Id', 'b.AuthorId')
    .Select(['b.Id', 'b.Title', 'a.Name as AuthorName'])
    .When(Title <> '',
      function(Q: IQuery): IQuery
      begin
        Result := Q.WhereContains('b.Title', Title);
      end)
    .When(Author <> '',
      function(Q: IQuery): IQuery
      begin
        Result := Q.WhereContains('a.Name', Author);
      end)
    .When(PublishedOnly,
      function(Q: IQuery): IQuery
      begin
        Result := Q.WhereTrue('b.IsPublished');
      end)
    .OrderBy('b.Title').OrderBy('b.Id')
    .ForPage(Page, PageSize);
end;
```

Compile with the same `Compiler` as above:

```delphi
Statement := Compiler.Compile(SearchBooks('Delphi', 'Cantu', True, 2, 10));
```

All three filters are enabled here: title contains `Delphi`, author contains
`Cantu`, and published books only. Empty text skips its filter; `False` includes
both published and unpublished books. The unique book Id breaks title ties;
page 2 skips 10 rows and returns at most 10. No SQL string concatenation is needed.

<!-- mssql:SearchBooks -->
**Generated parameterized MSSQL SQL (default `@p` prefix; line breaks added):**

```sql
SELECT [b].[Id], [b].[Title], [a].[Name] AS [AuthorName]
FROM [Books] AS [b]
INNER JOIN [Authors] AS [a] ON [a].[Id] = [b].[AuthorId]
WHERE [b].[Title] like @p0 AND [a].[Name] like @p1
  AND [b].[IsPublished] = cast(1 as bit)
ORDER BY [b].[Title], [b].[Id]
OFFSET @p2 ROWS FETCH NEXT @p3 ROWS ONLY
```

Ordered bindings (`WhereTrue` emits a SQL Server bit literal):

```text
@p0 = "%Delphi%"
@p1 = "%Cantu%"
@p2 = 10
@p3 = 10
```
<!-- /mssql:SearchBooks -->

Both examples are [checked against the compiler](test/DocumentationExamples.pas).
See [advanced queries](docs/EXAMPLES.md#advanced-queries) for more JOINs,
conditional filters and pagination options.

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

Read and write mapping share `[Column]`, `[Key]` and `[Ignore]` resolution,
including renamed columns and validation of conflicting mappings. See the
[shared DTO example](docs/OBJECT_MAPPING.md#shared-readwrite-attributes).

Import `QueryBuilder4Delphi.Mapping` for fluent mapping into ordinary classes
with writable RTTI properties. With [TBook](test/MappingExamples.pas):

```delphi
Books := TQuery.Create('Books').Select(['Id', 'Title as BookTitle'])
  .OrderBy('Id').Execute(Executor).ToList<TBook>();
try
  for Book in Books do
    Writeln(Book.Title);
finally
  Books.Free; // The list owns and frees every mapped book.
end;
```

Declare `Books: TObjectList<TBook>` and `Book: TBook` (import
`System.Generics.Collections`). Individually mapped objects are caller-owned;
lazy fallbacks retain their existing ownership. Fluent terminal calls release
their result reference before returning; independently retained copies stay valid.

Use `ToList<T>` for an owning list, `First<T>`/`Single<T>` for required rows,
and `ForEach<T>` to borrow one mapped object per callback. `Single` variants
detect multiple rows. All accept optional mapping options. The static mapper,
including `MapCurrent<T>`, remains available for advanced cursor control.
See [examples and ownership](docs/EXAMPLES.md#object-mapping),
[mapping and compatibility](docs/OBJECT_MAPPING.md) and
[benchmarks](docs/MAPPING_PERFORMANCE.md).

SQL NULL maps to the actual Delphi type default for supported non-nullable
properties, overwriting constructor values. Pass `TQueryMappingOptions` with
`NullBehavior := nmbThrow` for strict errors or `nmbSkip` to preserve existing
values. The default loses the distinction between NULL and zero/False/empty;
use `TNullable<T>` to retain it. The same nullable DTO also works with
object INSERT, UPDATE, WHERE and HAVING: present values keep their native types,
including 0, False and empty strings/bytes; absent values become typed SQL NULL.
NULL predicates use `IS NULL`; NULL UPDATE keys are rejected. See the
[read/write roundtrip](docs/OBJECT_MAPPING.md#writing-nullable-properties).
Nullable properties always receive `.Null` for
SQL NULL under all three policies, and keep non-NULL defaults as present values.
See [NULL policy and compatibility](docs/OBJECT_MAPPING.md#nullable-properties-and-scoped-options).

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
