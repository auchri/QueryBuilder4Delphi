unit ExecutionExamples;

interface

uses FireDAC.Comp.Client, QueryBuilder4Delphi.Query.Core;

procedure PrintBooks(Connection: TFDConnection;
  Dialect: TSqlDialect = TSqlDialect.MSSql);
function ChangeBookInTransaction(Connection: TFDConnection;
  Dialect: TSqlDialect = TSqlDialect.MSSql): Int64;
procedure ChangeBook(Connection: TFDConnection;
  Dialect: TSqlDialect = TSqlDialect.MSSql);

implementation

uses System.SysUtils, QueryBuilder4Delphi.Query,
  QueryBuilder4Delphi.Providers.FireDAC;

procedure PrintBooks(Connection: TFDConnection; Dialect: TSqlDialect);
var
  Executor: IQueryExecutor;
  Rows: IQueryResult;
begin
  // Connection is already configured and connected by the application.
  Executor := TFireDACQueryExecutor.Create(Connection, Dialect);
  Rows := TQuery.Create('Books').Select(['Id', 'Title'])
    .Where('IsPublished', True).OrderBy('Title').Execute(Executor);
  while Rows.Next do
    if not Rows.IsNull('Title') then
      Writeln(Rows.GetValue(0).AsInt64, ': ', Rows.GetValue('Title').AsString);
end;

function ChangeBookInTransaction(Connection: TFDConnection;
  Dialect: TSqlDialect): Int64;
var
  Executor: IQueryExecutor;
  Command: IQueryResult;
begin
  if not Connection.InTransaction then
    raise EInvalidOp.Create('The caller must start a transaction');
  Executor := TFireDACQueryExecutor.Create(Connection, Dialect);
  Command := TQuery.Create('Books').AsInsert(['Id', 'Title'], [42, 'New book'])
    .Execute(Executor, emCommand);
  Command := TQuery.Create('Books').Where('Id', 42)
    .AsUpdate(['Title'], ['Changed book']).Execute(Executor);
  Command := TQuery.Create('Books').Where('Id', 42).AsDelete.Execute(Executor);
  Result := Command.RowsAffected;
end;

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

end.
