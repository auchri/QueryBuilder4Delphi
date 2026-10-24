unit NullableMappingExamples;

interface

uses System.SysUtils, System.Generics.Collections,
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Nullable;

type
{$RTTI EXPLICIT METHODS([vcPublic]) PROPERTIES([vcPublic]) FIELDS([])}
  TRatedBook = class
  private
    FRating: TNullable<Integer>;
    FTitle: TNullable<string>;
    FPayload: TNullable<TBytes>;
  public
    property Rating: TNullable<Integer> read FRating write FRating;
    property Title: TNullable<string> read FTitle write FTitle;
    property Payload: TNullable<TBytes> read FPayload write FPayload;
  end;
{$RTTI INHERIT}

function LoadRatedBooks(const Executor: IQueryExecutor)
  : TObjectList<TRatedBook>;

implementation

uses QueryBuilder4Delphi.Query, QueryBuilder4Delphi.Mapping;

function LoadRatedBooks(const Executor: IQueryExecutor)
  : TObjectList<TRatedBook>;
begin
  Result := TQuery.Create('NullableBooks').Select(['Rating', 'Title', 'Payload']
    ).OrderBy('Id').Execute(Executor).ToList<TRatedBook>();
end;

end.
