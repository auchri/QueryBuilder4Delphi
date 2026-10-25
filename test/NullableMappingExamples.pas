unit NullableMappingExamples;

interface

uses System.SysUtils, System.Generics.Collections,
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Nullable;

type
{$RTTI EXPLICIT METHODS([vcPublic]) PROPERTIES([vcPublic]) FIELDS([])}
  TRatedBook = class
  private
    FId: Integer;
    FRating: TNullable<Integer>;
    FTitle: TNullable<string>;
    FPayload: TNullable<TBytes>;
  public
    [Key('Id')]
    property Id: Integer read FId write FId;
    property Rating: TNullable<Integer> read FRating write FRating;
    property Title: TNullable<string> read FTitle write FTitle;
    property Payload: TNullable<TBytes> read FPayload write FPayload;
  end;
{$RTTI INHERIT}

function LoadRatedBooks(const Executor: IQueryExecutor)
  : TObjectList<TRatedBook>;

// Uses the same DTO for parameter writing and result mapping.
procedure InsertReadUpdateBook(const Executor: IQueryExecutor);

implementation

uses QueryBuilder4Delphi.Query, QueryBuilder4Delphi.Mapping;

function LoadRatedBooks(const Executor: IQueryExecutor)
  : TObjectList<TRatedBook>;
begin
  Result := TQuery.Create('NullableBooks')
    .Select(['Id', 'Rating', 'Title', 'Payload']).OrderBy('Id')
    .Execute(Executor).ToList<TRatedBook>();
end;

procedure InsertReadUpdateBook(const Executor: IQueryExecutor);
var
  Book: TRatedBook;
begin
  Book := TRatedBook.Create;
  try
    Book.Id := 10;
    Book.Title := TNullable<string>.Create('');
    Book.Rating := TNullable<Integer>.Create(0);
    TQuery.Create('NullableBooks').AsInsert(Book).Execute(Executor)
      .GetRowsAffected;
  finally
    Book.Free;
  end;
  Book := TQuery.Create('NullableBooks').Where('Id', 10).Execute(Executor)
    .Single<TRatedBook>();
  try
    Book.Rating := TNullable<Integer>.Null;
    Book.Payload := TNullable<TBytes>.Create(TBytes.Create(0, 255, 42));
    TQuery.Create('NullableBooks').AsUpdate(Book).Execute(Executor)
      .GetRowsAffected;
  finally
    Book.Free;
  end;
end;

end.
