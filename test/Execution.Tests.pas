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
    [Test]
    procedure ResultContract;
    [Test]
    procedure NamedNullAccess;
    [Test]
    procedure EmptyBinaryIsNotNull;
    [Test]
    procedure EmptyResult;
    [Test]
    procedure DuplicateNames;
    [Test]
    procedure InterfaceLifetimes;
    [Test]
    procedure CompilerExtension;
    [Test]
    procedure DelegatesCompilerSql;
    [Test]
    procedure RawParameterScanning;
    [Test]
    procedure TypedNullContract;
    [TestCase('MSSql', '0')]
    [TestCase('MySql', '1')]
    [TestCase('PostgreSql', '2')]
    [TestCase('Sqlite', '3')]
    [TestCase('Oracle', '4')]
    [TestCase('Firebird', '5')]
    procedure ParameterContract(DialectIndex: Integer);
  end;

implementation

uses
  DUnitX.Assert, System.Rtti, System.TypInfo, System.Generics.Collections,
  System.SysUtils,
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Query,
  QueryBuilder4Delphi.Execution, QueryBuilder4Delphi.Compilers.Compiler,
  QueryBuilder4Delphi.Compilers.SqliteCompiler,
  QueryBuilder4Delphi.Compilers.Factory,
  Execution.Mock;

type
  TMockExecutor = class(TMockQueryExecutor)
    function ExecuteCompiled(const Statement: ISqlResult;
      Mode: TQueryExecutionMode): IQueryResult; override;
  end;

  TCustomCompiler = class(TSqliteCompiler)
  public
    function Compile(Query: IQuery): ISqlResult; overload; override;
  end;

  TCustomExecutor = class(TMockQueryExecutor)
  protected
    function CreateCompiler: ICompiler; override;
  end;

type
  TCommandCompiler = class(TSqliteCompiler)
  public
    function Compile(Query: IQuery): ISqlResult; overload; override;
  end;

  TCommandExecutor = class(TMockQueryExecutor)
  protected
    function CreateCompiler: ICompiler; override;
  end;

function TCommandCompiler.Compile(Query: IQuery): ISqlResult;
begin
  Result := TSqlResult.Create;
  Result.Sql := 'EXEC dbo.RebuildBookIndex;';
end;

function TCommandExecutor.CreateCompiler: ICompiler;
begin
  Result := TCommandCompiler.Create;
end;

function TMockExecutor.ExecuteCompiled(const Statement: ISqlResult;
  Mode: TQueryExecutionMode): IQueryResult;
begin
  Result := inherited;
  Statement.Query.Method := 'changed';
end;

function TCustomCompiler.Compile(Query: IQuery): ISqlResult;
begin
  Result := inherited Compile(Query);
  Result.Sql := Result.Sql + ' /* custom compiler */';
end;

function TCustomExecutor.CreateCompiler: ICompiler;
begin
  Result := TCustomCompiler.Create;
  Result.ParameterPrefix := ParameterPrefix;
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

procedure TExecutionTests.ResultContract;
var
  E: IQueryExecutor;
  R: IQueryResult;
begin
  E := TMockQueryExecutor.Create(TSqlDialect.Sqlite);
  R := TQuery.Create('Books').Execute(E);
  Assert.AreEqual(3, R.ColumnCount);
  Assert.AreEqual('Title', R.GetColumnName(1));
  Assert.IsTrue(R.GetColumnType(2) = qtDecimal);
  Assert.WillRaise(
    procedure
    begin
      R.GetValue(0);
    end, EQueryException);
  Assert.WillRaise(
    procedure
    begin
      R.GetColumnName(-1);
    end, EQueryException);
  Assert.WillRaise(
    procedure
    begin
      R.GetColumnType(3);
    end, EQueryException);
  Assert.WillRaise(
    procedure
    begin
      R.GetColumnIndex('missing');
    end, EQueryException);
  Assert.IsTrue(R.Next);
  Assert.AreEqual<Int64>(1, R.GetValue(0).AsInt64);
  Assert.AreEqual('Alpha', R.GetValue('title').AsString);
  Assert.IsTrue(R.IsNull(2));
  Assert.IsTrue(R.GetValue(2).IsEmpty);
  Assert.IsTrue(R.Next);
  Assert.AreEqual('Beta', R.GetValue(1).AsString);
  Assert.IsFalse(R.Next);
  Assert.IsFalse(R.Next);
  Assert.WillRaise(
    procedure
    begin
      R.GetValue(0);
    end, EQueryException);
end;

procedure TExecutionTests.NamedNullAccess;
var
  M: TMockQueryExecutor;
  E: IQueryExecutor;
  R: IQueryResult;
  procedure CheckCursorError;
  begin
    Assert.WillRaise(
      procedure
      begin
        R.IsNull(1);
      end, EQueryException);
    Assert.WillRaise(
      procedure
      begin
        R.IsNull('Title');
      end, EQueryException);
  end;

begin
  M := TMockQueryExecutor.Create(TSqlDialect.Sqlite);
  E := M;
  M.Data := TRows.Create(TValues.Create(1, TValue.Empty, TValue.Empty),
    TValues.Create(2, 'Beta', TValue.Empty));
  R := TQuery.Create('Books').Execute(E);
  CheckCursorError;
  Assert.IsTrue(R.Next);
  Assert.IsTrue(R.IsNull('Title'));
  Assert.IsTrue(R.IsNull(1) = R.IsNull('tItLe'));
  Assert.WillRaiseWithMessage(
    procedure
    begin
      R.GetValue('missing');
    end, EQueryException, 'Column not found: missing');
  Assert.WillRaiseWithMessage(
    procedure
    begin
      R.IsNull('missing');
    end, EQueryException, 'Column not found: missing');
  Assert.IsTrue(R.Next);
  Assert.IsFalse(R.IsNull('Title'));
  Assert.IsTrue(R.IsNull(1) = R.IsNull('TITLE'));
  Assert.IsFalse(R.Next);
  CheckCursorError;
end;

procedure TExecutionTests.EmptyBinaryIsNotNull;
var
  M: TMockQueryExecutor;
  E: IQueryExecutor;
  R: IQueryResult;
begin
  M := TMockQueryExecutor.Create(TSqlDialect.Sqlite);
  E := M;
  M.Names := TArray<string>.Create('Bytes', 'Text', 'Absent');
  M.Types := TArray<TQueryValueType>.Create(qtBinary, qtString, qtDecimal);
  M.Data := TRows.Create(TValues.Create(TValue.From<TBytes>(nil), '',
    TValue.Empty));
  R := TQuery.Create('Books').Execute(E);
  Assert.IsTrue(R.Next);
  Assert.IsFalse(R.IsNull(0));
  Assert.IsTrue(R.GetValue(0).TypeInfo = TypeInfo(TBytes));
  Assert.IsTrue(R.GetValue(0).IsEmpty); // Delphi's rule, not a SQL NULL test.
  Assert.IsFalse(R.IsNull(1));
  Assert.IsTrue(R.IsNull(2));
  Assert.IsTrue(R.GetValue(2).TypeInfo = nil);
end;

procedure TExecutionTests.EmptyResult;
var
  M: TMockQueryExecutor;
  E: IQueryExecutor;
  R: IQueryResult;
begin
  M := TMockQueryExecutor.Create(TSqlDialect.Sqlite);
  E := M;
  M.Data := nil;
  R := TQuery.Create('Books').Execute(E);
  Assert.AreEqual(3, R.ColumnCount);
  Assert.IsTrue(R.GetColumnType(2) = qtDecimal);
  Assert.IsFalse(R.Next);
  Assert.WillRaise(
    procedure
    begin
      R.IsNull(0);
    end, EQueryException);
end;

procedure TExecutionTests.DuplicateNames;
var
  M: TMockQueryExecutor;
  E: IQueryExecutor;
  R: IQueryResult;
begin
  M := TMockQueryExecutor.Create(TSqlDialect.Sqlite);
  E := M;
  M.Names := TArray<string>.Create('X', 'X', 'N');
  R := TQuery.Create('Books').Execute(E);
  Assert.WillRaise(
    procedure
    begin
      R.GetValue('X');
    end, EQueryException);
  Assert.WillRaiseWithMessage(
    procedure
    begin
      R.IsNull('x');
    end, EQueryException, 'Ambiguous column name: x');
  Assert.WillRaiseWithMessage(
    procedure
    begin
      R.GetValue('x');
    end, EQueryException, 'Ambiguous column name: x');
  Assert.IsTrue(R.Next);
  Assert.AreEqual<Int64>(1, R.GetValue(0).AsInt64);
  Assert.AreEqual('Alpha', R.GetValue(1).AsString);
end;

procedure TExecutionTests.InterfaceLifetimes;
var
  ResultBefore, ExecutorBefore: Integer;
  procedure Exercise;
  var
    E: IQueryExecutor;
    R, S: IQueryResult;
    M: TMockQueryExecutor;
  begin
    M := TMockQueryExecutor.Create(TSqlDialect.Sqlite);
    E := M;
    R := TQuery.Create('Books').Execute(E);
    Assert.IsTrue(R.Next);
    M.Affected := 7;
    S := TQuery.Create('Books').AsDelete.Execute(E);
    Assert.IsFalse(S.HasResultSet);
    Assert.AreEqual<Int64>(7, S.RowsAffected);
    Assert.WillRaise(
      procedure
      begin
        S.Next;
      end, EQueryException);
    Assert.WillRaise(
      procedure
      begin
        S.GetColumnType(0);
      end, EQueryException);
    E := nil;
    Assert.AreEqual(ExecutorBefore, TMockQueryExecutor.LiveCount,
      'Executor lifetime');
    Assert.IsTrue(R.Next);
    S := nil;
    R := nil;
    // Delphi can retain temporary return interfaces until this scope exits.
  end;

begin
  ResultBefore := TMockQueryResult.LiveCount;
  ExecutorBefore := TMockQueryExecutor.LiveCount;
  Exercise;
  Assert.AreEqual(ResultBefore, TMockQueryResult.LiveCount, 'Result lifetime');
  Assert.AreEqual(ExecutorBefore, TMockQueryExecutor.LiveCount,
    'Executor lifetime');
end;

procedure TExecutionTests.CompilerExtension;
var
  M: TCustomExecutor;
  E: IQueryExecutor;
begin
  M := TCustomExecutor.Create(TSqlDialect.Sqlite, ':Parameter');
  E := M;
  TQuery.Create('Books').Where('Id', 1).Execute(E);
  Assert.IsTrue(Pos(':Parameter0', M.Sql) > 0);
  Assert.IsTrue(Pos('/* custom compiler */', M.Sql) > 0);
  Assert.AreEqual(':Parameter0', M.Tokens[0]);
  Assert.AreEqual(1, M.Values[0].AsInteger);
end;

procedure TExecutionTests.DelegatesCompilerSql;
var
  E: IQueryExecutor;
  M: TCommandExecutor;
begin
  M := TCommandExecutor.Create(TSqlDialect.MSSql);
  E := M;
  TQuery.Create('Books').Execute(E, emCommand);
  Assert.AreEqual('EXEC dbo.RebuildBookIndex;', M.Sql);
  Assert.IsTrue(M.LastMode = emCommand);
end;

procedure TExecutionTests.RawParameterScanning;
var
  C: ICompiler;
  S: ISqlResult;
  procedure Check(const Raw: string; const Values: array of TValue;
  const Expected: string);
  var
    I: Integer;
  begin
    S := C.Compile(TQuery.Create.SelectRaw(Raw, Values));
    Assert.AreEqual('SELECT ' + Expected, S.Sql);
    Assert.AreEqual<NativeInt>(Length(Values), S.Bindings.Count);
    for I := 0 to High(Values) do
    begin
      Assert.AreEqual(Values[I].ToString, S.Bindings[I].ToString);
      Assert.AreEqual(Values[I].ToString, S.NamedBindings[':p' + IntToStr(I)
        ].ToString);
    end;
  end;

begin
  C := TSqliteCompiler.Create;
  C.ParameterPrefix := ':p';
  Check('?', [11], ':p0');
  Check('''Warum?'', ''it''''s ?'', "a?""b", `c?``d`, ? /* ? /* ? */ */ -- ?' +
    #10 + ', ?', [11, 22],
    '''Warum?'', ''it''''s ?'', "a?""b", `c?``d`, :p0 /* ? /* ? */ */ -- ?' +
    #10 + ', :p1');
  C := CreateCompiler(TSqlDialect.PostgreSql);
  C.ParameterPrefix := ':p';
  Check('$$why ? '' $$, $tag$what ?$tag$, E''it\''s ?'', ?', [33],
    '$$why ? '' $$, $tag$what ?$tag$, E''it\''s ?'', :p0');
  C := CreateCompiler(TSqlDialect.Oracle);
  C.ParameterPrefix := ':p';
  Check('q''\[it''s ?\]'', q''!why ?!'', ?', [44],
    'q''[it''s ?]'', q''!why ?!'', :p0');
  C := CreateCompiler(TSqlDialect.PostgreSql);
  C.ParameterPrefix := ':p';
  Check('doc \? ''key'', doc \?| keys, doc \?& keys, ?', [55],
    'doc \? ''key'', doc \?| keys, doc \?& keys, :p0');
  // Incomplete SQL reaches the database; this scanner only finds bindings.
  Check('''unfinished ?', [], '''unfinished ?');
  Check('1 /* unfinished ?', [], '1 /* unfinished ?');
  C := CreateCompiler(TSqlDialect.MSSql);
  C.ParameterPrefix := ':p';
  Check('[a?]]b], ?', [66], '[a?]]b], :p0');
  C := CreateCompiler(TSqlDialect.MySql);
  C.ParameterPrefix := ':p';
  Check('''it\''s ?'', ?', [77], '''it\''s ?'', :p0');
end;

procedure TExecutionTests.TypedNullContract;
var
  V: TValue;
  M: TMockQueryExecutor;
  E: IQueryExecutor;
begin
  V := TQueryNull.Create(qtDecimal);
  Assert.AreEqual('INSERT INTO [Books] ([Price]) VALUES (NULL)',
    TQuery.Create('Books').AsInsert(['Price'], [V]).Compile);
  Assert.IsFalse(V.IsEmpty);
  Assert.IsTrue(V.AsType<TQueryNull>.ValueType = qtDecimal);
  Assert.WillRaise(
    procedure
    begin
      TQueryNull.Create(qtUnknown);
    end, EQueryException);
  M := TMockQueryExecutor.Create(TSqlDialect.Sqlite);
  E := M;
  TQuery.Create('Books').AsInsert(['Price', 'Title', 'Payload', 'Absent'],
    [V, '', TValue.From<TBytes>(nil), TValue.Empty]).Execute(E);
  Assert.IsTrue(M.Values[0].IsType<TQueryNull>);
  Assert.AreEqual('', M.Values[1].AsString);
  Assert.IsTrue(M.Values[2].IsType<TBytes>);
  Assert.IsTrue(M.Values[3].IsEmpty);
end;

procedure TExecutionTests.ParameterContract(DialectIndex: Integer);
var
  M: TMockQueryExecutor;
  E: IQueryExecutor;
  Q: IQuery;
  procedure Check(const Expected: array of string);
  var
    I: Integer;
  begin
    Q.Execute(E);
    Assert.AreEqual<NativeInt>(Length(Expected), M.BindingCount);
    for I := 0 to High(Expected) do
      Assert.AreEqual(Expected[I], M.Values[I].ToString);
  end;

begin
  M := TMockQueryExecutor.Create(TSqlDialect(DialectIndex));
  E := M;
  Q := TQuery.Create('Books').Where('A', 'first').Where('B', 'second');
  Check(['first', 'second']);
  Q := TQuery.Create('Books').WhereIn('Id', TQuery.Create('Other').Select('Id')
    .Where('A', 'nested'));
  Check(['nested']);
  Q := TQuery.Create('b').&With('b', TQuery.Create('Books').Where('A', 'cte'))
    .Where('B', 'outer');
  Check(['cte', 'outer']);
  Q := TQuery.Create('Books').AsInsert(['A', 'B'], ['one', 'two']);
  Check(['one', 'two']);
  Q := TQuery.Create('Books').Where('Id', 'where').AsUpdate(['A', 'B'],
    ['set1', 'set2']);
  Check(['set1', 'set2', 'where']);
  Q := TQuery.Create('Books').Define('v', 'repeated').WhereRaw('A = ? OR B = ?',
    [TVariable.Create('v'), TVariable.Create('v')]);
  Check(['repeated', 'repeated']);
  Q := TQuery.Create.SelectRaw
    ('''literal ? :p0'' as Literal, ? as Bound /* ? */', ['value']);
  Check(['value']);
  Assert.IsTrue(Pos('''literal ? :p0''', M.Sql) > 0);
  Q := TQuery.Create('Books').AsInsert(['Absent', 'Bytes'],
    [TQueryNull.Create(qtDecimal), TValue.From<TBytes>(TBytes.Create(0, 255))]);
  Q.Execute(E);
  Assert.AreEqual(2, M.BindingCount);
  Assert.IsTrue(M.Values[0].AsType<TQueryNull>.ValueType = qtDecimal);
  Assert.AreEqual(255, Integer(M.Values[1].AsType<TBytes>[1]));
  Q := TQuery.Create('Books').Where('Bytes', TValue.From<TBytes>(nil));
  Q.Execute(E);
  Assert.AreEqual(1, M.BindingCount);
  Assert.IsTrue(M.Values[0].TypeInfo = TypeInfo(TBytes));
  Assert.IsTrue(Pos('IS NULL', M.Sql) = 0);
end;

initialization

TDUnitX.RegisterTestFixture(TExecutionTests);

end.
