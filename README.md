# QueryBuilder4Delphi

A Delphi port of the SqlKata query builder, based on local C# commit
`df4a2377750d34fc057c81886b481e7309ef975e`.
Targets **Delphi 12 or later on Windows, Win32 and Win64**.

The library builds SQL and parameter lists. `SqlKata.Execution`, FireDAC,
database connections, result mapping, `Get`, `First`, and `Paginate` are outside
the scope of this pilot. `ForPage` is supported: it generates LIMIT/OFFSET or
the equivalent SQL for the selected dialect.

## Installation

Add `src` to the Delphi search path. The library requires only the Delphi RTL.
No package or additional runtime libraries are required.

```pascal
uses
  System.SysUtils, System.Rtti,
  SqlKata, QueryBuilder4Delphi.Compilers;
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
  System.SysUtils, SqlKata, QueryBuilder4Delphi.Compilers;

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
do not use include files. `QueryBuilder4Delphi.Compilers` provides a facade
for importing all compiler types. Alternatively, import
`QueryBuilder4Delphi.Compilers.Compiler` and the required dialect unit directly.
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
The existing `SqlKata` unit remains a compatibility facade, so the examples
above keep their existing imports. To import the implementation directly, use
both `QueryBuilder4Delphi.Query.Core` and `QueryBuilder4Delphi.Query`.

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
and return a nonzero exit code when generated content is out of date.

## License

MIT, including the upstream C# copyright notice; see [LICENSE](LICENSE).
