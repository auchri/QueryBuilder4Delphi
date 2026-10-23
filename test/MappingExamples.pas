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
function LoadPublishedBooks(const Executor: IQueryExecutor): TObjectList<TBook>;
function FindBook(const Executor: IQueryExecutor; Id: Integer): TBook;

implementation

uses
  QueryBuilder4Delphi.Query, QueryBuilder4Delphi.Mapping;

function LoadBooks(const Executor: IQueryExecutor): TObjectList<TBook>;
begin
  Result := TQuery.Create('Books').Select(['Id', 'Title AS BookTitle'])
    .OrderBy('Id').Execute(Executor).ToList<TBook>();
end;

function FindBook(const Executor: IQueryExecutor; Id: Integer): TBook;
begin
  Result := TQuery.Create('Books').Select(['Title AS BookTitle', 'Id'])
    .Where('Id', Id).Execute(Executor).FirstOrDefault<TBook>();
end;

function LoadPublishedBooks(const Executor: IQueryExecutor): TObjectList<TBook>;
begin
  Result := TQuery.Create('Books').Select(['Id', 'Title AS BookTitle'])
    .Where('IsPublished', True).Execute(Executor).ToList<TBook>();
end;

end.
