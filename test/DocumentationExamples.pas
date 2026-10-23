unit DocumentationExamples;

interface

uses System.SysUtils, System.Rtti, QueryBuilder4Delphi.Query.Core,
  QueryBuilder4Delphi.Query;

function AllBooks: IQuery;
function BookTitles: IQuery;
function TypedFilters: IQuery;
function LogicalFilters: IQuery;
function NullFilters: IQuery;
function RangeFilters: IQuery;
function TextFilters: IQuery;
function OrderedBooks: IQuery;
function OffsetBooks: IQuery;
function PagedBooks: IQuery;
function DistinctLanguages: IQuery;
function BooksAndAuthors: IQuery;
function OptionalAuthors: IQuery;
function AuthorTotals: IQuery;
function CountBooks: IQuery;
function NestedFilters: IQuery;
function AuthorSubquery: IQuery;
function BooksWithOrders: IQuery;
function BooksWithoutOrders: IQuery;
function PublishedBooksCte: IQuery;
function CombinedBooks: IQuery;
function AllCombinedBooks: IQuery;
function ConditionalBooks: IQuery;
function ClonedBooks: IQuery;
function RawBooks: IQuery;
function InsertBook: IQuery;
function InsertBooks: IQuery;
function UpdateBook: IQuery;
function DeleteBook: IQuery;
function NullPrice: IQuery;

function FilteredBooks(const Search: string; AuthorId: Integer): IQuery;
procedure ShowCompilation;

implementation

uses DUnitX.TestFramework, DUnitX.Assert,
  QueryBuilder4Delphi.Compilers.Compiler, QueryBuilder4Delphi.Compilers.Factory;

type

  [TestFixture]
  TDocumentationTests = class
  public
    [TestCase('MSSql', '0')]
    [TestCase('MySql', '1')]
    [TestCase('PostgreSql', '2')]
    [TestCase('Sqlite', '3')]
    [TestCase('Oracle', '4')]
    [TestCase('Firebird', '5')]
    procedure CompileExamples(DialectIndex: Integer);
    [Test]
    procedure DocumentedSqlAndBindings;
  end;

function AllBooks: IQuery;
begin
  Result := TQuery.Create('Books');
end;

function BookTitles: IQuery;
begin
  Result := TQuery.Create('Books').Select(['Id', 'Title']);
end;

function TypedFilters: IQuery;
begin
  Result := TQuery.Create('Books').Where('AuthorId', 7).Where('Lang', 'en')
    .Where('IsPublished', True).Where('Price', '<', TValue.From<Currency>(25.50)
    ).Where('PublishedAt', '>=',
    TValue.From<TDateTime>(EncodeDate(2025, 1, 1)));
end;

function LogicalFilters: IQuery;
begin
  Result := TQuery.Create('Books').Where('Lang', 'en').OrWhere('Lang', 'de')
    .WhereNot('Status', 'withdrawn');
end;

function NullFilters: IQuery;
begin
  Result := TQuery.Create('Books').WhereNull('DeletedAt')
    .WhereNotNull('PublishedAt');
end;

function RangeFilters: IQuery;
begin
  Result := TQuery.Create('Books').WhereIn('AuthorId', [1, 3, 7])
    .WhereBetween('Price', 10, 30);
end;

function TextFilters: IQuery;
begin
  Result := TQuery.Create('Books').WhereLike('Title', '%Delphi%')
    .WhereContains('Summary', 'database').WhereStarts('Code', 'DB-');
end;

function OrderedBooks: IQuery;
begin
  Result := TQuery.Create('Books').OrderBy('Title').OrderByDesc('Id');
end;

function OffsetBooks: IQuery;
begin
  Result := TQuery.Create('Books').OrderBy('Id').Limit(10).Offset(20);
end;

function PagedBooks: IQuery;
begin
  Result := TQuery.Create('Books').OrderBy('Id').ForPage(3, 10);
end;

function DistinctLanguages: IQuery;
begin
  Result := TQuery.Create('Books').Select('Lang').Distinct;
end;

function BooksAndAuthors: IQuery;
begin
  Result := TQuery.Create('Books as b').Join('Authors as a', 'a.Id',
    'b.AuthorId').Select(['b.Id', 'b.Title', 'a.Name as AuthorName']);
end;

function OptionalAuthors: IQuery;
begin
  Result := TQuery.Create('Books as b').LeftJoin('Authors as a', 'a.Id',
    'b.AuthorId').Select(['b.Title', 'a.Name as AuthorName']);
end;

function AuthorTotals: IQuery;
begin
  Result := TQuery.Create('Books').Select('AuthorId')
    .SelectCount('Id as BookCount').GroupBy('AuthorId')
    .HavingRaw('COUNT(*) >= ?', [5]);
end;

function CountBooks: IQuery;
begin
  Result := TQuery.Create('Books').WhereTrue('IsPublished').AsCount;
end;

function NestedFilters: IQuery;
begin
  Result := TQuery.Create('Books').Where(
    function(Q: IQuery): IQuery
    begin
      Result := Q.Where('Lang', 'en').OrWhere('Lang', 'de');
    end).WhereNot('Status', 'withdrawn');
end;

function AuthorSubquery: IQuery;
begin
  Result := TQuery.Create('Books').WhereIn('AuthorId', TQuery.Create('Authors')
    .Select('Id').Where('Country', 'AT'));
end;

function BooksWithOrders: IQuery;
begin
  Result := TQuery.Create('Books').WhereExists(TQuery.Create('Orders')
    .WhereColumns('Orders.BookId', '=', 'Books.Id').Where('Status', 'paid'));
end;

function BooksWithoutOrders: IQuery;
begin
  Result := TQuery.Create('Books').WhereNotExists(TQuery.Create('Orders')
    .WhereColumns('Orders.BookId', '=', 'Books.Id'));
end;

function PublishedBooksCte: IQuery;
begin
  Result := TQuery.Create('published').&With('published',
    TQuery.Create('Books').WhereTrue('IsPublished')).Select(['Id', 'Title']);
end;

function CombinedBooks: IQuery;
begin
  Result := TQuery.Create('Books').Select('Title').Where('Lang', 'en')
    .Union(TQuery.Create('Books').Select('Title').Where('Lang', 'de'));
end;

function AllCombinedBooks: IQuery;
begin
  Result := TQuery.Create('Books').Select('Title').Where('Lang', 'en')
    .UnionAll(TQuery.Create('Books').Select('Title').Where('Lang', 'de'));
end;

function ConditionalBooks: IQuery;
begin
  Result := TQuery.Create('Books').When(True,
    function(Q: IQuery): IQuery
    begin
      Result := Q.WhereTrue('IsPublished');
    end);
end;

function ClonedBooks: IQuery;
var
  Base: IQuery;
begin
  Base := TQuery.Create('Books').WhereTrue('IsPublished');
  Result := Base.Clone.Where('Lang', 'en');
end;

function RawBooks: IQuery;
begin
  Result := TQuery.Create('Books')
    .WhereRaw('COALESCE([Subtitle], [Title]) = ? AND [AuthorId] = ?',
    ['Database design', 7]);
end;

function InsertBook: IQuery;
begin
  Result := TQuery.Create('Books').AsInsert(['Id', 'Title'], [42, 'New book']);
end;

function InsertBooks: IQuery;
begin
  Result := TQuery.Create('Books').AsInsert(['Id', 'Title'],
    TRows.Create(TValues.Create(42, 'First book'), TValues.Create(43,
    'Second book')));
end;

function UpdateBook: IQuery;
begin
  Result := TQuery.Create('Books').Where('Id', 42).AsUpdate(['Title', 'Price'],
    ['Revised book', TValue.From<Currency>(19.95)]);
end;

function DeleteBook: IQuery;
begin
  Result := TQuery.Create('Books').Where('Id', 42).AsDelete;
end;

function NullPrice: IQuery;
begin
  Result := TQuery.Create('Books').Where('Id', 42)
    .AsUpdate(['Price', 'Subtitle'], [TQueryNull.Create(qtDecimal),
    TValue.Empty]);
end;

function FilteredBooks(const Search: string; AuthorId: Integer): IQuery;
begin
  Result := TQuery.Create('Books');
  if Search <> '' then
    Result.WhereContains('Title', Search);
  if AuthorId > 0 then
    Result.Where('AuthorId', AuthorId);
end;

procedure ShowCompilation;
var
  Q: IQuery;
  Compiler: ICompiler;
  Statement: ISqlResult;
begin
  Q := TQuery.Create('Books').Select(['Id', 'Title']).Where('Id', 42);
  Compiler := CreateCompiler(TSqlDialect.MSSql);
  Statement := Compiler.Compile(Q);
  Writeln(Statement.Sql);
  Writeln(Statement.Bindings[0].AsInteger);
  Compiler := CreateCompiler(TSqlDialect.Oracle);
  Statement := Compiler.Compile(Q);
  Writeln(Statement.Sql);
  Compiler.ParameterPrefix := ':item';
  Statement := Compiler.Compile(Q);
  Writeln(Statement.Sql);
  Writeln(Q.Compile); // SQL preview with values; never execute this string.
end;

procedure TDocumentationTests.CompileExamples(DialectIndex: Integer);
var
  Queries: TArray<IQuery>;
  Q: IQuery;
  C: ICompiler;
  S: ISqlResult;
  I: Integer;
begin
  Queries := TArray<IQuery>.Create(AllBooks, BookTitles, TypedFilters,
    LogicalFilters, NullFilters, RangeFilters, TextFilters, OrderedBooks,
    OffsetBooks, PagedBooks, DistinctLanguages, BooksAndAuthors,
    OptionalAuthors, AuthorTotals, CountBooks, NestedFilters, AuthorSubquery,
    BooksWithOrders, BooksWithoutOrders, PublishedBooksCte, CombinedBooks,
    AllCombinedBooks, ConditionalBooks, ClonedBooks, RawBooks, InsertBook,
    InsertBooks, UpdateBook, DeleteBook, NullPrice, FilteredBooks('Delphi', 7));
  C := CreateCompiler(TSqlDialect(DialectIndex));
  C.ParameterPrefix := ':p';
  for Q in Queries do
  begin
    S := C.Compile(Q);
    Assert.IsTrue(S.Sql <> '');
    Assert.AreEqual<NativeInt>(S.Bindings.Count, S.NamedBindings.Count);
    for I := 0 to S.Bindings.Count - 1 do
      Assert.IsTrue(S.NamedBindings.ContainsKey(':p' + IntToStr(I)));
  end;
end;

procedure TDocumentationTests.DocumentedSqlAndBindings;
var
  Q: IQuery;
  C: ICompiler;
  S: ISqlResult;
begin
  ShowCompilation;
  Q := TQuery.Create('Books').Select(['Id', 'Title']).Where('Id', 42);
  C := CreateCompiler(TSqlDialect.MSSql);
  S := C.Compile(Q);
  Assert.AreEqual('SELECT [Id], [Title] FROM [Books] WHERE [Id] = @p0', S.Sql);
  Assert.AreEqual(42, S.Bindings[0].AsInteger);
  Assert.AreEqual('SELECT [Id], [Title] FROM [Books] WHERE [Id] = 42',
    Q.Compile);
  C := CreateCompiler(TSqlDialect.Oracle);
  S := C.Compile(Q);
  Assert.AreEqual('SELECT "Id", "Title" FROM "Books" WHERE "Id" = :p0', S.Sql);
  Assert.AreEqual(42, S.Bindings[0].AsInteger);
  C.ParameterPrefix := ':item';
  S := C.Compile(Q);
  Assert.AreEqual
    ('SELECT "Id", "Title" FROM "Books" WHERE "Id" = :item0', S.Sql);
  Assert.AreEqual(42, S.NamedBindings[':item0'].AsInteger);
  S := CreateCompiler(TSqlDialect.MSSql).Compile(UpdateBook);
  Assert.AreEqual
    ('UPDATE [Books] SET [Title] = @p0, [Price] = @p1 WHERE [Id] = @p2', S.Sql);
  Assert.AreEqual('Revised book', S.Bindings[0].AsString);
  Assert.AreEqual<Currency>(19.95, S.Bindings[1].AsType<Currency>);
  Assert.AreEqual(42, S.Bindings[2].AsInteger);
end;

initialization

TDUnitX.RegisterTestFixture(TDocumentationTests);

end.
