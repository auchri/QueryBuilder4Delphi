unit ExecutionExamples;

interface

implementation

uses
  System.SysUtils, FireDAC.Comp.Client,
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Query,
  QueryBuilder4Delphi.Providers.FireDAC;

procedure PrintBooks(Connection: TFDConnection);
var
  Executor: IQueryExecutor;
  Rows: IQueryResult;
begin
  // Connection is already configured and connected by the application.
  Executor := TFireDACQueryExecutor.Create(Connection, TSqlDialect.MSSql);
  Rows := TQuery.Create('Books').Select(['Id', 'Title'])
    .Where('IsPublished', True).OrderBy('Title').Execute(Executor);
  while Rows.Next do
    if not Rows.IsNull(1) then
      Writeln(Rows.GetValue('Title').AsString);
end;

procedure ChangeBook(Connection: TFDConnection);
var
  Executor: IQueryExecutor;
  Command: IQueryResult;
begin
  Executor := TFireDACQueryExecutor.Create(Connection, TSqlDialect.MSSql);
  Connection.StartTransaction;
  try
    Command := TQuery.Create('Books').AsInsert(['Id', 'Title'], [42, 'New book']
      ).Execute(Executor);
    Writeln(Command.RowsAffected);
    Command := TQuery.Create('Books').Where('Id', 42)
      .AsUpdate(['Title'], ['Changed book']).Execute(Executor);
    Command := TQuery.Create('Books').Where('Id', 42)
      .AsDelete.Execute(Executor);
    Command := nil;
    Connection.Commit;
  except
    Connection.Rollback;
    raise;
  end;
end;

end.
