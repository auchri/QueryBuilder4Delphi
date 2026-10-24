unit MappingApiExamples;

interface

uses
  System.SysUtils, System.Generics.Collections,
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Nullable;

type
{$RTTI EXPLICIT METHODS([vcPublic]) PROPERTIES([vcPublic]) FIELDS([])}
  TBookView = class
  private
    FId: Integer;
    FTitle: string;
    FPrice: TNullable<Currency>;
    FLocalNote: string;
  public
    property Id: Integer read FId write FId;
    [Column('BookTitle')]
    property Title: string read FTitle write FTitle;
    property Price: TNullable<Currency> read FPrice write FPrice;
    [Ignore]
    property LocalNote: string read FLocalNote write FLocalNote;
  end;

  TBookAuthorView = class(TBookView)
  private
    FAuthorName: TNullable<string>;
  public
    property AuthorName: TNullable<string> read FAuthorName write FAuthorName;
  end;
{$RTTI INHERIT}

function LoadBookViews(const Executor: IQueryExecutor): TObjectList<TBookView>;
function LoadTitleViews(const Executor: IQueryExecutor): TObjectList<TBookView>;
function LoadBookAuthors(const Executor: IQueryExecutor)
  : TObjectList<TBookAuthorView>;
function FirstBook(const Executor: IQueryExecutor): TBookView;
function SingleBook(const Executor: IQueryExecutor; Id: Integer): TBookView;
function FindBookView(const Executor: IQueryExecutor; Id: Integer): TBookView;
function FindUniqueBookView(const Executor: IQueryExecutor; Id: Integer)
  : TBookView;
procedure StreamBooks(const Executor: IQueryExecutor;
  const ProcessBook: TProc<TBookView>);
procedure PrintMappingExamples(const Executor: IQueryExecutor);
function FindBookOrExisting(const Executor: IQueryExecutor; Id: Integer;
  ExistingBook: TBookView): TBookView;
function FindSingleBookOrCreate(const Executor: IQueryExecutor; Id: Integer;
  CachedBook: TBookView): TBookView;

implementation

uses QueryBuilder4Delphi.Query, QueryBuilder4Delphi.Mapping;

function LoadBookViews(const Executor: IQueryExecutor): TObjectList<TBookView>;
begin
  Result := TQuery.Create('Books').Select(['Id', 'Title as BookTitle', 'Price'])
    .OrderBy('Id').Execute(Executor).ToList<TBookView>();
end;

function LoadTitleViews(const Executor: IQueryExecutor): TObjectList<TBookView>;
begin
  Result := TQuery.Create('Books').Select('Title as BookTitle').OrderBy('Id')
    .Execute(Executor).ToList<TBookView>();
end;

function LoadBookAuthors(const Executor: IQueryExecutor)
  : TObjectList<TBookAuthorView>;
begin
  Result := TQuery.Create('Books as b').LeftJoin('Authors as a', 'a.Id',
    'b.AuthorId').Select(['b.Id', 'b.Title as BookTitle', 'b.Price',
    'a.Name as AuthorName']).OrderBy('b.Id').Execute(Executor)
    .ToList<TBookAuthorView>();
end;

function FirstBook(const Executor: IQueryExecutor): TBookView;
begin
  Result := TQuery.Create('Books').Select(['Id', 'Title as BookTitle', 'Price'])
    .OrderBy('Id').Execute(Executor).First<TBookView>();
end;

function SingleBook(const Executor: IQueryExecutor; Id: Integer): TBookView;
begin
  Result := TQuery.Create('Books').Select(['Id', 'Title as BookTitle', 'Price'])
    .Where('Id', Id).Execute(Executor).Single<TBookView>();
end;

function FindBookView(const Executor: IQueryExecutor; Id: Integer): TBookView;
begin
  Result := TQuery.Create('Books').Select(['Id', 'Title as BookTitle', 'Price'])
    .Where('Id', Id).Execute(Executor).FirstOrDefault<TBookView>();
end;

function FindUniqueBookView(const Executor: IQueryExecutor; Id: Integer)
  : TBookView;
begin
  Result := TQuery.Create('Books').Select(['Id', 'Title as BookTitle', 'Price'])
    .Where('Id', Id).Execute(Executor).SingleOrDefault<TBookView>();
end;

function FindBookOrExisting(const Executor: IQueryExecutor; Id: Integer;
  ExistingBook: TBookView): TBookView;
begin
  Result := TQuery.Create('Books').Select(['Id', 'Title as BookTitle', 'Price'])
    .Where('Id', Id).Execute(Executor).FirstOrElse<TBookView>(
    function: TBookView
    begin
      Result := ExistingBook;
    end);
end;

function FindSingleBookOrCreate(const Executor: IQueryExecutor; Id: Integer;
CachedBook: TBookView): TBookView;
begin
  Result := TQuery.Create('Books').Select(['Id', 'Title as BookTitle', 'Price'])
    .Where('Id', Id).Execute(Executor).SingleOrElse<TBookView>(
    function: TBookView
    begin
      if Assigned(CachedBook) then
        Result := CachedBook
      else
        Result := TBookView.Create;
    end);
end;

procedure StreamBooks(const Executor: IQueryExecutor;
const ProcessBook: TProc<TBookView>);
begin
  TQuery.Create('Books').Select(['Id', 'Title as BookTitle', 'Price'])
    .OrderBy('Id').Execute(Executor).ForEach<TBookView>(ProcessBook);
end;

procedure PrintMappingExamples(const Executor: IQueryExecutor);
var
  Books: TObjectList<TBookView>;
  Book: TBookView;
  Titles: TList<string>;
begin
  Books := LoadBookViews(Executor);
  try
    for Book in Books do
      if Book.Price.HasValue then
        Writeln(Book.Title, ': ', Book.Price.Value:0:2)
      else
        Writeln(Book.Title, ': price unknown');
  finally
    Books.Free; // Frees every contained object.
  end;
  try
    Book := FirstBook(Executor);
    try
      Writeln(Book.Title);
    finally
      Book.Free; // A returned object belongs to the caller.
    end;
  except
    on E: EQueryMappingException do
      Writeln('Cannot map the first book: ', E.Message);
  end;
  Titles := TList<string>.Create;
  try
    StreamBooks(Executor,
      procedure(BorrowedBook: TBookView)
      begin
        // Retain a value copy, never BorrowedBook itself. Do not Free it.
        Titles.Add(BorrowedBook.Title);
      end);
    Writeln('Processed ', Titles.Count, ' books');
  finally
    Titles.Free;
  end;
end;

end.
