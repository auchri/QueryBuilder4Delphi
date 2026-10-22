unit Execution.Tests;

interface

uses DUnitX.TestFramework;

type

  [TestFixture]
  TExecutionTests = class
  public
    [Test]
    procedure DelegatesWithoutProvider;
    [Test]
    procedure ResolvesModesAndClones;
    [Test]
    procedure RejectsInvalidArguments;
  end;

implementation

uses
  DUnitX.Assert, System.Rtti, System.Generics.Collections, System.SysUtils,
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Query,
  QueryBuilder4Delphi.Execution, QueryBuilder4Delphi.Compilers.Compiler;

type
  TMockExecutor = class(TQueryExecutor)
  public
    LastMode: TQueryExecutionMode;
    Sql: string;
    BindingCount: Integer;
    function ExecuteCompiled(const Statement: ISqlResult;
      Mode: TQueryExecutionMode): IQueryResult; override;
  end;

function TMockExecutor.ExecuteCompiled(const Statement: ISqlResult;
  Mode: TQueryExecutionMode): IQueryResult;
begin
  LastMode := Mode;
  Sql := Statement.Sql;
  BindingCount := Statement.Bindings.Count;
  // Prove the compiler sees an isolated snapshot.
  Statement.Query.Method := 'changed';
  Result := nil;
end;

procedure TExecutionTests.DelegatesWithoutProvider;
var
  E: IQueryExecutor;
  M: TMockExecutor;
  Q: IQuery;
begin
  M := TMockExecutor.Create(TSqlDialect.PostgreSql);
  E := M;
  Q := TQuery.Create('Books').Where('Title', 'Alpha');
  Q.Execute(E);
  Assert.IsTrue(M.LastMode = emRows);
  Assert.AreEqual('SELECT * FROM "Books" WHERE "Title" = :p0', M.Sql);
  Assert.AreEqual(1, M.BindingCount);
  Assert.AreEqual('select', Q.Method);
end;

procedure TExecutionTests.ResolvesModesAndClones;
var
  E: IQueryExecutor;
  M: TMockExecutor;
  Q: IQuery;
begin
  M := TMockExecutor.Create(TSqlDialect.Sqlite);
  E := M;
  Q := TQuery.Create('Books').AsInsert(['Title'], ['Alpha']);
  Q.Execute(E);
  Assert.IsTrue(M.LastMode = emCommand);
  Q.Execute(E, emRows);
  Assert.IsTrue(M.LastMode = emRows);
  Assert.AreEqual('insert', Q.Method);
  TQuery.Create('Books').AsUpdate(['Title'], ['Beta']).Execute(E);
  Assert.IsTrue(M.LastMode = emCommand);
  TQuery.Create('Books').AsDelete.Execute(E);
  Assert.IsTrue(M.LastMode = emCommand);
  TQuery.Create('Books').AsCount.Execute(E);
  Assert.IsTrue(M.LastMode = emRows);
end;

procedure TExecutionTests.RejectsInvalidArguments;
var
  E: IQueryExecutor;
  Q: IQuery;
begin
  E := TMockExecutor.Create(TSqlDialect.Sqlite);
  Assert.WillRaise(
    procedure
    begin
      E.Execute(nil);
    end, EArgumentNilException);
  Assert.WillRaise(
    procedure
    begin
      TQuery.Create.Execute(nil);
    end, EArgumentNilException);
  Q := TQuery.Create('Books');
  Q.Method := 'custom';
  Assert.WillRaise(
    procedure
    begin
      Q.Execute(E);
    end, EQueryException);
  Assert.WillRaise(
    procedure
    begin
      TQuery.Create('Books').AsInsert([TPair<string, TValue>.Create('Title',
        'A')], True).Execute(E);
    end, EQueryException);
end;

initialization

TDUnitX.RegisterTestFixture(TExecutionTests);

end.
