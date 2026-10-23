unit MappingExamples;

interface

uses
  System.Generics.Collections, QueryBuilder4Delphi.Query.Core;

type
{$RTTI EXPLICIT METHODS([vcPublic]) PROPERTIES([vcPublic]) FIELDS([])}
  TBook = class
  private
    FId: Integer;
    FTitle: string;
  public
    property Id: Integer read FId write FId;
    [Column('BookTitle')]
    property Title: string read FTitle write FTitle;
  end;
{$RTTI INHERIT}

function LoadBooks(const Executor: IQueryExecutor): TObjectList<TBook>;
function FindBook(const Executor: IQueryExecutor; Id: Integer): TBook;

implementation

uses
  QueryBuilder4Delphi.Query, QueryBuilder4Delphi.Mapping;

function LoadBooks(const Executor: IQueryExecutor): TObjectList<TBook>;
begin
  Result := TQueryMapper.ToList<TBook>(TQuery.Create('Books')
    .Select(['Id', 'Title as BookTitle']).OrderBy('Id').Execute(Executor));
end;

function FindBook(const Executor: IQueryExecutor; Id: Integer): TBook;
begin
  Result := TQueryMapper.FirstOrDefault<TBook>(TQuery.Create('Books')
    .Select(['Title as BookTitle', 'Id']).Where('Id', Id).Execute(Executor));
end;

end.
