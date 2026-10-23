# Examples

Build queries first, inspect SQL when useful, then execute through a provider.
These examples target Delphi 12+ on Windows (Win32 and Win64).

- [Getting started](#getting-started)
- [Basic queries](#basic-queries)
- [Advanced queries](#advanced-queries)
- [Writing data](#writing-data)
- [SQL compilation](#sql-compilation)
- [Query execution](#query-execution)
- [Custom providers](#custom-providers)
- [Example verification](#example-verification)

## Getting started

Add `src` to the project search path. The query examples below are complete
functions that can be placed in a unit's implementation section with these imports:

```delphi
uses
  System.SysUtils,
  System.Rtti,
  QueryBuilder4Delphi.Query.Core,
  QueryBuilder4Delphi.Query;
```

The examples use Books, Authors and Orders. Columns such as AuthorId,
IsPublished, Lang, Price and PublishedAt are illustrative application schema
fields; the library does not create tables. Related tables must exist before
executing a query. Building and compiling SQL needs no connection.

Keep query instances in `IQuery` variables. Fluent methods modify and return
the same query. Use Clone for an independent variation, and return the supplied
IQuery from callbacks. Interfaces release themselves when their last reference
goes away; never call Free on their implementations.

Selected MSSQL outputs below use
`TQueryCompilerFactory.CreateCompiler(TSqlDialect.MSSql)` with
`Compiler.ParameterPrefix := ':p'`, matching the executor convention. A direct
MSSQL compiler defaults to `@p`; examples using that default are labeled.
These are **parameterized SQL**, not debug previews. SQL line breaks are added
for readability; SQL tokens and ordered bindings are verified against the compiler.

## Basic queries

### Simple SELECT

Select all columns. Query construction does not execute anything.

```delphi
function AllBooks: IQuery;
begin
  Result := TQuery.Create('Books');
end;
```

### Choose columns

Keep projections explicit when the caller only needs a few columns.

```delphi
function BookTitles: IQuery;
begin
  Result := TQuery.Create('Books')
    .Select(['Id', 'Title']);
end;
```

### Filter by different types

Strings, integers and Boolean values convert implicitly to TValue. Use explicit Currency and TDateTime wrappers to retain their Delphi types.

```delphi
function TypedFilters: IQuery;
begin
  Result := TQuery.Create('Books')
    .Where('AuthorId', 7)
    .Where('Lang', 'en')
    .Where('IsPublished', True)
    .Where('Price', '<', TValue.From<Currency>(25.50))
    .Where(
      'PublishedAt', '>=',
      TValue.From<TDateTime>(EncodeDate(2025, 1, 1))
    );
end;
```

### AND, OR and NOT

Chained conditions default to AND. This expression follows SQL precedence: Lang=en OR (Lang=de AND NOT Status=withdrawn). Use a group, shown below, when both languages must share the status filter.

```delphi
function LogicalFilters: IQuery;
begin
  Result := TQuery.Create('Books')
    .Where('Lang', 'en')
    .OrWhere('Lang', 'de')
    .WhereNot('Status', 'withdrawn');
end;
```

### NULL conditions

NULL conditions emit IS NULL / IS NOT NULL, with no NULL comparison binding.

```delphi
function NullFilters: IQuery;
begin
  Result := TQuery.Create('Books')
    .WhereNull('DeletedAt')
    .WhereNotNull('PublishedAt');
end;
```

### IN and BETWEEN

Values remain parameters. For a typed array, pass TSqlValues.&Of<Integer>(Ids) to WhereIn.

```delphi
function RangeFilters: IQuery;
begin
  Result := TQuery.Create('Books')
    .WhereIn('AuthorId', [1, 3, 7])
    .WhereBetween('Price', 10, 30);
end;
```

### LIKE, Contains and Starts

The public method is WhereStarts, rather than StartsWith. WhereContains and WhereStarts add wildcard patterns. Case sensitivity, collation and wildcard interpretation follow the database; these helpers do not add a lower-case transformation.

```delphi
function TextFilters: IQuery;
begin
  Result := TQuery.Create('Books')
    .WhereLike('Title', '%Delphi%')
    .WhereContains('Summary', 'database')
    .WhereStarts('Code', 'DB-');
end;
```

### Sort rows

A final unique key makes ordering deterministic when titles tie.

```delphi
function OrderedBooks: IQuery;
begin
  Result := TQuery.Create('Books')
    .OrderBy('Title')
    .OrderByDesc('Id');
end;
```

### LIMIT and OFFSET

The compiler translates pagination to the chosen dialect. Always supply a stable ORDER BY.

```delphi
function OffsetBooks: IQuery;
begin
  Result := TQuery.Create('Books')
    .OrderBy('Id')
    .Limit(10)
    .Offset(20);
end;
```

<!-- mssql:OffsetBooks -->
**Generated parameterized MSSQL SQL:**

```sql
SELECT *
FROM [Books]
ORDER BY [Id]
OFFSET :p0 ROWS
FETCH NEXT :p1 ROWS ONLY
```

Bindings:

```text
:p0 = 20
:p1 = 10
```
<!-- /mssql:OffsetBooks -->

### Page numbers

ForPage is one-based: page 3 skips 20 rows. It builds SQL pagination; it does not return a page object or a total count.

```delphi
function PagedBooks: IQuery;
begin
  Result := TQuery.Create('Books')
    .OrderBy('Id')
    .ForPage(3, 10);
end;
```

### DISTINCT

DISTINCT applies to the complete selected row.

```delphi
function DistinctLanguages: IQuery;
begin
  Result := TQuery.Create('Books')
    .Select('Lang')
    .Distinct;
end;
```

## Advanced queries

### INNER JOIN and aliases

Use qualified column names when joining tables. Both table and column aliases use the text as Alias notation.

```delphi
function BooksAndAuthors: IQuery;
begin
  Result := TQuery.Create('Books as b')
    .Join('Authors as a', 'a.Id', 'b.AuthorId')
    .Select(['b.Id', 'b.Title', 'a.Name as AuthorName']);
end;
```

<!-- mssql:BooksAndAuthors -->
**Generated parameterized MSSQL SQL:**

```sql
SELECT [b].[Id], [b].[Title], [a].[Name] AS [AuthorName]
FROM [Books] AS [b]
INNER JOIN [Authors] AS [a] ON [a].[Id] = [b].[AuthorId]
```

Bindings: none.
<!-- /mssql:BooksAndAuthors -->

### LEFT JOIN

Books without an author remain in the result. Check IsNull before reading AuthorName.

```delphi
function OptionalAuthors: IQuery;
begin
  Result := TQuery.Create('Books as b')
    .LeftJoin('Authors as a', 'a.Id', 'b.AuthorId')
    .Select(['b.Title', 'a.Name as AuthorName']);
end;
```

<!-- mssql:OptionalAuthors -->
**Generated parameterized MSSQL SQL:**

```sql
SELECT [b].[Title], [a].[Name] AS [AuthorName]
FROM [Books] AS [b]
LEFT JOIN [Authors] AS [a] ON [a].[Id] = [b].[AuthorId]
```

Bindings: none.
<!-- /mssql:OptionalAuthors -->

### GROUP BY and HAVING

HAVING filters groups after aggregation. The threshold is a binding, not interpolated SQL.

```delphi
function AuthorTotals: IQuery;
begin
  Result := TQuery.Create('Books')
    .Select('AuthorId')
    .SelectCount('Id as BookCount')
    .GroupBy('AuthorId')
    .HavingRaw('COUNT(*) >= ?', [5]);
end;
```

<!-- mssql:AuthorTotals -->
**Generated parameterized MSSQL SQL:**

```sql
SELECT [AuthorId], COUNT([Id]) AS [BookCount]
FROM [Books]
GROUP BY [AuthorId]
HAVING COUNT(*) >= :p0
```

Bindings:

```text
:p0 = 5
```
<!-- /mssql:AuthorTotals -->

### Aggregate functions

AsCount makes a count query. AsSum, AsAverage, AsMin and AsMax are also available. SelectCount and SelectSum add aggregate expressions to a projection.

```delphi
function CountBooks: IQuery;
begin
  Result := TQuery.Create('Books')
    .WhereTrue('IsPublished')
    .AsCount;
end;
```

### Group conditions

This produces (Lang=en OR Lang=de) AND NOT Status=withdrawn. Every query callback must return the IQuery it receives.

```delphi
function NestedFilters: IQuery;
begin
  Result := TQuery.Create('Books')
    .Where(
      function(Q: IQuery): IQuery
      begin
        Result := Q
          .Where('Lang', 'en')
          .OrWhere('Lang', 'de');
      end
    )
    .WhereNot('Status', 'withdrawn');
end;
```

### Subqueries

The subquery is copied into the outer query; its bindings become part of the compiled statement.

```delphi
function AuthorSubquery: IQuery;
begin
  Result := TQuery.Create('Books')
    .WhereIn(
      'AuthorId',
      TQuery.Create('Authors')
        .Select('Id')
        .Where('Country', 'AT')
    );
end;
```

<!-- mssql:AuthorSubquery -->
**Generated parameterized MSSQL SQL:**

```sql
SELECT *
FROM [Books]
WHERE [AuthorId] IN (
  SELECT [Id]
  FROM [Authors]
  WHERE [Country] = :p0
)
```

Bindings:

```text
:p0 = "AT"
```
<!-- /mssql:AuthorSubquery -->

### EXISTS

Correlate an EXISTS subquery with WhereColumns so both operands are identifiers.

```delphi
function BooksWithOrders: IQuery;
begin
  Result := TQuery.Create('Books')
    .WhereExists(
      TQuery.Create('Orders')
        .WhereColumns('Orders.BookId', '=', 'Books.Id')
        .Where('Status', 'paid')
    );
end;
```

<!-- mssql:BooksWithOrders -->
**Generated parameterized MSSQL SQL:**

```sql
SELECT *
FROM [Books]
WHERE EXISTS (
  SELECT 1
  FROM [Orders]
  WHERE [Orders].[BookId] = [Books].[Id]
    AND [Status] = :p0
)
```

Bindings:

```text
:p0 = "paid"
```
<!-- /mssql:BooksWithOrders -->

### NOT EXISTS

NOT EXISTS selects books with no matching order.

```delphi
function BooksWithoutOrders: IQuery;
begin
  Result := TQuery.Create('Books')
    .WhereNotExists(
      TQuery.Create('Orders')
        .WhereColumns('Orders.BookId', '=', 'Books.Id')
    );
end;
```

### Common table expressions

&With names the CTE and the outer query selects from it. CTE bindings are emitted before outer-query bindings.

```delphi
function PublishedBooksCte: IQuery;
begin
  Result := TQuery.Create('published')
    .&With(
      'published',
      TQuery.Create('Books')
        .WhereTrue('IsPublished')
    )
    .Select(['Id', 'Title']);
end;
```

<!-- mssql:PublishedBooksCte -->
**Generated parameterized MSSQL SQL:**

```sql
WITH [published] AS (
  SELECT *
  FROM [Books]
  WHERE [IsPublished] = cast(1 as bit)
)
SELECT [Id], [Title]
FROM [published]
```

Bindings: none.
<!-- /mssql:PublishedBooksCte -->

### UNION

UNION removes duplicate rows. Both sides must expose compatible projections.

```delphi
function CombinedBooks: IQuery;
begin
  Result := TQuery.Create('Books')
    .Select('Title')
    .Where('Lang', 'en')
    .Union(
      TQuery.Create('Books')
        .Select('Title')
        .Where('Lang', 'de')
    );
end;
```

### UNION ALL

UNION ALL retains duplicates and avoids the distinct step.

```delphi
function AllCombinedBooks: IQuery;
begin
  Result := TQuery.Create('Books')
    .Select('Title')
    .Where('Lang', 'en')
    .UnionAll(
      TQuery.Create('Books')
        .Select('Title')
        .Where('Lang', 'de')
    );
end;
```

### Conditional queries with When

Replace True with an application condition. When mutates the query only when that condition is true.

```delphi
function ConditionalBooks: IQuery;
begin
  Result := TQuery.Create('Books')
    .When(
      True,
      function(Q: IQuery): IQuery
      begin
        Result := Q.WhereTrue('IsPublished');
      end
    );
end;
```

### Add optional filters dynamically

Build a fresh query for each request. Identifiers and sort directions should
come from trusted application choices; user input belongs in values.

```delphi
function FilteredBooks(const Search: string; AuthorId: Integer): IQuery;
begin
  Result := TQuery.Create('Books');
  if Search <> '' then
    Result.WhereContains('Title', Search);
  if AuthorId > 0 then
    Result.Where('AuthorId', AuthorId);
end;
```

### Clone a reusable query

Clone creates an independent query. Assigning another IQuery variable shares the same instance instead.

```delphi
function ClonedBooks: IQuery;
var
  Base: IQuery;
begin
  Base := TQuery.Create('Books')
    .WhereTrue('IsPublished');
  Result := Base.Clone
    .Where('Lang', 'en');
end;
```

### Raw SQL and bindings

Square brackets in raw fragments are identifier markers translated by the compiler. Supply values separately; never concatenate user input into SQL. Quoted question marks and comments do not consume bindings. Unquoted non-placeholder question marks use the existing \? convention; executable SQL preserves that escape, so ensure driver compatibility or use an equivalent function.

```delphi
function RawBooks: IQuery;
begin
  Result := TQuery.Create('Books')
    .WhereRaw(
      'COALESCE([Subtitle], [Title]) = ? AND [AuthorId] = ?',
      ['Database design', 7]
    );
end;
```

## Writing data

Values passed to writes are bindings, just as they are in WHERE conditions.
Use explicit column/value arrays when column order matters.

### INSERT

AsInsert builds a statement. Compile it or execute it through a provider.

```delphi
function InsertBook: IQuery;
begin
  Result := TQuery.Create('Books')
    .AsInsert(['Id', 'Title'], [42, 'New book']);
end;
```

### Insert multiple rows

TRows supplies a value array for each row. Keep row widths aligned with the column list. Multirow SQL varies by dialect; Oracle uses its own insert form.

```delphi
function InsertBooks: IQuery;
begin
  Result := TQuery.Create('Books')
    .AsInsert(
      ['Id', 'Title'],
      TRows.Create(
        TValues.Create(42, 'First book'),
        TValues.Create(43, 'Second book')
      )
    );
end;
```

### UPDATE

SET values precede WHERE values in the ordered binding list. Omitting WHERE updates every row.

```delphi
function UpdateBook: IQuery;
begin
  Result := TQuery.Create('Books')
    .Where('Id', 42)
    .AsUpdate(
      ['Title', 'Price'],
      ['Revised book', TValue.From<Currency>(19.95)]
    );
end;
```

**Generated parameterized MSSQL SQL (default `@p` prefix):**

```sql
UPDATE [Books] SET [Title] = @p0, [Price] = @p1 WHERE [Id] = @p2
```

Bindings:

```text
@p0 = "Revised book"
@p1 = Currency(19.95)
@p2 = 42
```

The example tests check the exact values and ordering.

### DELETE

Omitting WHERE deletes every row. Inspect the query before executing writes.

```delphi
function DeleteBook: IQuery;
begin
  Result := TQuery.Create('Books')
    .Where('Id', 42)
    .AsDelete;
end;
```

### Write NULL values

TQueryNull carries a provider-neutral type hint. TValue.Empty is an untyped SQL NULL. Empty strings and empty TBytes are values, not NULL; a database may impose its own empty-value semantics.

```delphi
function NullPrice: IQuery;
begin
  Result := TQuery.Create('Books')
    .Where('Id', 42)
    .AsUpdate(
      ['Price', 'Subtitle'],
      [TQueryNull.Create(qtDecimal), TValue.Empty]
    );
end;
```

AsInsert/AsUpdate/AsDelete construct statements;
execution returns an IQueryResult with HasResultSet=False and RowsAffected.
ReturnId-based identity batches are not supported by execution. Joined writes
are supported only by the SQL Server and MySQL compilers.

## SQL compilation

| Type | Responsibility |
| --- | --- |
| `IQuery` | Mutable description of a query; no database connection |
| `ICompiler` | Dialect-specific SQL generation and compiler settings |
| `ISqlResult` | Parameterized Sql, ordered Bindings and NamedBindings |
| `IQueryExecutor` | Executes the compiled statement through a provider |
| `IQueryResult` | Sequential cursor or affected-row count |

The same query can be compiled for SQL Server and Oracle. For the next
procedure, add these compiler imports to the common imports above:

```delphi
uses
  QueryBuilder4Delphi.Compilers.Compiler,
  QueryBuilder4Delphi.Compilers.Factory;
```

```delphi
procedure ShowCompilation;
var
  Q: IQuery;
  Compiler: ICompiler;
  Statement: ISqlResult;
begin
  Q := TQuery.Create('Books')
    .Select(['Id', 'Title'])
    .Where('Id', 42);
  Compiler := TQueryCompilerFactory.CreateCompiler(TSqlDialect.MSSql);
  Statement := Compiler.Compile(Q);
  Writeln(Statement.Sql);
  Writeln(Statement.Bindings[0].AsInteger);
  Compiler := TQueryCompilerFactory.CreateCompiler(TSqlDialect.Oracle);
  Statement := Compiler.Compile(Q);
  Writeln(Statement.Sql);
  Compiler.ParameterPrefix := ':item';
  Statement := Compiler.Compile(Q);
  Writeln(Statement.Sql);
  Writeln(Q.Compile); // SQL preview with values; never execute this string.
end;
```

**Generated parameterized MSSQL SQL (default `@p` prefix):**

```sql
SELECT [Id], [Title] FROM [Books] WHERE [Id] = @p0
```

Bindings:

```text
@p0 = 42
```

Oracle uses different quoting and a colon prefix:

```sql
SELECT "Id", "Title" FROM "Books" WHERE "Id" = :p0
```

Bindings:

```text
:p0 = 42
```

With ParameterPrefix set to `:item`, Oracle emits:

```sql
SELECT "Id", "Title" FROM "Books" WHERE "Id" = :item0
```

Bindings:

```text
:item0 = 42
```

The final `Q.Compile` call is a **debug SQL preview (values substituted)**:

```sql
SELECT [Id], [Title] FROM [Books] WHERE [Id] = 42
```

`IQuery.Compile` returns a string with values substituted. `ISqlResult.ToString`
is another preview. Never execute either preview as a replacement for SQL plus
bindings. Preview text is diagnostic and can expose sensitive values in logs.
`ISqlResult.Sql` is the parameterized statement; RawSql is its intermediate
question-mark form. Iterate Bindings by index, not dictionary enumeration order.

`TQueryCompilerFactory.CreateCompiler` supports MSSql (the default), MySql,
PostgreSql, Sqlite, Oracle and Firebird. The method is static; no factory
instance is needed.
You can instead create `TSqlServerCompiler.Create` or `TOracleCompiler.Create`
from their `QueryBuilder4Delphi.Compilers.SqlServerCompiler` and
`QueryBuilder4Delphi.Compilers.OracleCompiler` units. Both return ICompiler.
Compilers are configurable and not thread safe; use independent instances.

`ICompiler.ParameterPrefix` configures named markers. `UseLegacyPagination`
selects legacy SQL Server or Oracle pagination rather than the default
OFFSET/FETCH. Keep this setting in an ICompiler and compile the query with that
instance; the IQuery.Compile shortcut always uses compiler defaults.

All built-in executors default to `:pN`; the FireDAC provider requires that
convention even for SQL Server. Direct compiler defaults shown in the
[README dialect table](../README.md#sql-dialects) can differ from executor defaults.
Do not replace placeholder strings in finished SQL: the compiler must produce
SQL and consistent bindings together.

## Query execution

### Read from an existing FireDAC connection

The application configures, opens and owns the connection. This example uses
an existing TFDConnection and accepts its SQL dialect explicitly. No automatic
dialect or driver detection is performed.

```delphi
uses
  System.SysUtils,
  FireDAC.Comp.Client,
  QueryBuilder4Delphi.Query.Core,
  QueryBuilder4Delphi.Query,
  QueryBuilder4Delphi.Providers.FireDAC;
```

```delphi
procedure PrintBooks(Connection: TFDConnection; Dialect: TSqlDialect);
var
  Executor: IQueryExecutor;
  Rows: IQueryResult;
begin
  // Connection is already configured and connected by the application.
  Executor := TFireDACQueryExecutor.Create(Connection, Dialect);
  Rows := TQuery.Create('Books')
    .Select(['Id', 'Title'])
    .Where('IsPublished', True)
    .OrderBy('Title')
    .Execute(Executor);
  while Rows.Next do
    if not Rows.IsNull('Title') then
      Writeln(Rows.GetValue(0).AsInt64, ': ', Rows.GetValue('Title').AsString);
end;
```

For example, call `PrintBooks(Connection, TSqlDialect.MSSql)` for SQL Server,
or use `TSqlDialect.Sqlite` with a connected SQLite driver. The connection's
actual server must support the chosen dialect. FireDAC driver setup and schema
creation remain application responsibilities.

`IQueryResult` begins before the first row. Next advances and returns false for
an empty or exhausted result. GetValue(0) uses a zero-based index;
GetValue('Title') uses a case-insensitive name. IsNull accepts either an index
or a name. Missing and ambiguous names raise EQueryException; use indices for
duplicate names (the driver may also disambiguate them).

Check IsNull before converting TValue. SQL NULL is TValue.Empty without
TypeInfo. An empty string or typed empty TBytes is not SQL NULL, even though
Delphi reports IsEmpty=True for an empty dynamic array. GetColumnType supplies
a broad provider-neutral category, including for all-NULL columns when the
driver can describe them. Reading values before/after the cursor's current row
raises EQueryException. Commands have no row/column access.

### Writes inside an existing transaction

The next function deliberately requires an already-started transaction. It
inserts a book, updates it, then deletes it and returns the DELETE's RowsAffected.
Use a spare Id appropriate for the application's schema. The example uses 42.
The transaction belongs to the caller, so this function never commits it.

```delphi
function ChangeBookInTransaction(Connection: TFDConnection;
  Dialect: TSqlDialect): Int64;
var
  Executor: IQueryExecutor;
  Command: IQueryResult;
begin
  if not Connection.InTransaction then
    raise EInvalidOp.Create('The caller must start a transaction');
  Executor := TFireDACQueryExecutor.Create(Connection, Dialect);
  Command := TQuery.Create('Books')
    .AsInsert(['Id', 'Title'], [42, 'New book'])
    .Execute(Executor, emCommand);
  Command := TQuery.Create('Books')
    .Where('Id', 42)
    .AsUpdate(['Title'], ['Changed book'])
    .Execute(Executor);
  Command := TQuery.Create('Books')
    .Where('Id', 42)
    .AsDelete
    .Execute(Executor);
  Result := Command.RowsAffected;
end;
```

RowsAffected is the count supplied by the driver, or -1 when unknown. It is
available on each INSERT/UPDATE/DELETE result, not only the final one.
Release result interfaces before disconnecting or freeing the connection.

### Own the transaction boundary at the application call site

This wrapper is for an operation that owns a new transaction. When participating
in someone else's transaction, call ChangeBookInTransaction directly and let
that owner decide whether to commit or roll back. Do not nest this wrapper in
an existing transaction.

```delphi
procedure ChangeBook(Connection: TFDConnection; Dialect: TSqlDialect);
begin
  Connection.StartTransaction;
  try
    ChangeBookInTransaction(Connection, Dialect);
    Connection.Commit;
  except
    Connection.Rollback;
    raise;
  end;
end;
```

The except block rolls back and re-raises errors; it does not silently report
success. The executor does not start/commit/roll back transactions and does not
connect or disconnect. FireDAC's configured automatic transaction behavior still
applies outside explicit transactions. Keep error handling at the layer that
owns the transaction; provider/database exceptions propagate to the caller.
Do not log passwords or sensitive binding values when recording failures.

### Modes, lifetimes and limitations

`Execute(Executor)` uses emAuto: select/aggregate queries return rows, while
insert/update/delete queries return a command result. CTEs do not change that
metadata-based rule. emCommand explicitly requests a non-row command, as shown
above. Use emRows for a supported single-statement DML RETURNING/OUTPUT supplied
by a custom compiler/raw extension; execution does not add that syntax itself.
The compiler and driver must support the syntax and chosen mode.

There is at most one accessible resultset, no NextResult, no output-parameter
API and no result object mapper. Raw/custom SQL must respect that contract.
Execution does not count statements or validate SQL syntax; the database does.
ReturnId requests are rejected based on query metadata because their compiled
identity retrieval can require a batch. A mismatched explicit mode can raise a
driver exception. Unsupported result types fail explicitly rather than being
guessed; see the [type reference](API.md#execution-and-optional-firedac-provider).

The FireDAC provider creates and owns a separate TFDQuery for each result.
Releasing the final IQueryResult reference closes that cursor and frees its
query. Earlier results are not invalidated by another execution. An executor
can be released before its result, but the caller-owned connection must remain
alive and connected until every dependent result is released. Interfaces handle
normal exits and exceptions; no manual Free is needed for interface objects.
Executors, mutable queries and cursors must not be shared unsafely across threads.

## Custom providers

The SQL dialect chooses grammar. The provider chooses a driver and how values
are bound/read. For example, different drivers can execute SQL Server SQL;
changing the driver should not require changing the query's portable NULL hints.

Implement IQueryExecutor directly, or derive from TQueryExecutor to reuse query
cloning, compilation, metadata-based modes and ReturnId checks. Implement
IQueryResult for your own cursor, including names/indices, both IsNull overloads,
NULL values, type categories, RowsAffected and sequential Next behavior.
No FireDAC/Data.DB types are required by these core contracts.

The following complete unit adapts an external database abstraction. The
application implements ICommandAdapter with its actual parameterized database
calls; it is intentionally an interface rather than a fictitious driver:

```delphi
unit Execution.ProviderExample;

interface

uses
  QueryBuilder4Delphi.Query.Core,
  QueryBuilder4Delphi.Execution,
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
  if Adapter = nil then
    raise EArgumentNilException.Create('Adapter');
  FAdapter := Adapter;
end;

function TAdapterQueryExecutor.ExecuteCompiled(const Statement: ISqlResult;
  Mode: TQueryExecutionMode): IQueryResult;
begin
  // The bridge binds Values[I] to :Parameter<I>, interpreting TQueryNull hints.
  // It returns its own cursor implementation and defines connection ownership.
  Result := FAdapter.ExecuteParameterized(
    Statement.Sql,
    Statement.Bindings.ToArray,
    Mode
  );
end;

end.
```

The bridge binds Values[I] to `:Parameter<I>` without interpolating SQL. A
TQueryNull value carries an optional type hint; TValue.Empty is untyped SQL NULL.
The adapter must distinguish these from empty text/binary data and reject
unsupported values clearly. Bindings are ordered even when a query contains
CTEs, subqueries or repeated variables. The compiler and adapter must agree on
names/order and generate SQL and bindings together.

The application defines and documents connection ownership in its adapter. Each
returned cursor should own/release its command resources, while any borrowed
connection must outlive the cursor. Keep transaction decisions with the caller.
The example's interface field keeps the adapter alive for the executor lifetime;
its own result implementation must retain any resources needed after execution.

The protected virtual CreateCompiler hook can return a configured built-in or
application-defined ICompiler. FireDAC retains its fixed :pN binding convention;
other providers may use the base constructor's parameter prefix as shown.
This bridge does not implement connection management, a database driver or an ORM.

## Example verification

Selected MSSQL SQL blocks and ordered binding lists are also checked directly
against compiler output by MssqlDocumentation (presentation whitespace only
is ignored).

The query functions and ShowCompilation are compiled in
[test/DocumentationExamples.pas](../test/DocumentationExamples.pas). DUnitX
compiles 31 example query variants against each of the six dialects, checks
parameter tokens, and asserts the SQL Server/Oracle SQL and write binding order
shown here. This validates compilation, not live execution against all servers.

[test/ExecutionExamples.pas](../test/ExecutionExamples.pas) contains the read and
transaction procedures. The optional SQLite in-memory test executes them,
checks affected rows, transaction participation and connection lifetime. It
adds the IsPublished field used by PrintBooks to its test schema. Production
applications supply their own schema and driver configuration.

[test/Execution.ProviderExample.pas](../test/Execution.ProviderExample.pas)
compiles in the core project without FireDAC. Its ICommandAdapter is a contract;
no live external adapter execution is claimed. The two short README snippets
use the same query/execution operations; these examples are not a schema or
connection-management framework.

See [validation](VALIDATION.md) for actual run results, [API details](API.md) for
contracts, and [LICENSE](../LICENSE) for retained copyright and permission terms.
