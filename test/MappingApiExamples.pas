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
procedure StreamBooks(const Executor: IQueryExecutor;
  const ProcessBook: TProc<TBookView>);
procedure PrintMappingExamples(const Executor: IQueryExecutor);

implementation

uses QueryBuilder4Delphi.Query, QueryBuilder4Delphi.Mapping;

function LoadBookViews(const Executor: IQueryExecutor): TObjectList<TBookView>;
begin
  Result := TQueryMapper.ToList<TBookView>(TQuery.Create('Books')
    .Select(['Id', 'Title as BookTitle', 'Price']).OrderBy('Id')
    .Execute(Executor));
end;

function LoadTitleViews(const Executor: IQueryExecutor): TObjectList<TBookView>;
begin
  Result := TQueryMapper.ToList<TBookView>(TQuery.Create('Books')
    .Select('Title as BookTitle').OrderBy('Id').Execute(Executor));
end;

function LoadBookAuthors(const Executor: IQueryExecutor)
  : TObjectList<TBookAuthorView>;
begin
  Result := TQueryMapper.ToList<TBookAuthorView>(TQuery.Create('Books as b')
    .LeftJoin('Authors as a', 'a.Id', 'b.AuthorId')
    .Select(['b.Id', 'b.Title as BookTitle', 'b.Price', 'a.Name as AuthorName'])
    .OrderBy('b.Id').Execute(Executor));
end;

function FirstBook(const Executor: IQueryExecutor): TBookView;
begin
  Result := TQueryMapper.First<TBookView>(TQuery.Create('Books')
    .Select(['Id', 'Title as BookTitle', 'Price']).OrderBy('Id')
    .Execute(Executor));
end;

function SingleBook(const Executor: IQueryExecutor; Id: Integer): TBookView;
begin
  Result := TQueryMapper.Single<TBookView>(TQuery.Create('Books')
    .Select(['Id', 'Title as BookTitle', 'Price']).Where('Id', Id)
    .Execute(Executor));
end;

procedure StreamBooks(const Executor: IQueryExecutor;
  const ProcessBook: TProc<TBookView>);
var
  Rows: IQueryResult;
begin
  Rows := TQuery.Create('Books').Select(['Id', 'Title as BookTitle', 'Price'])
    .OrderBy('Id').Execute(Executor);
  TQueryMapper.ForEach<TBookView>(Rows, ProcessBook);
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
