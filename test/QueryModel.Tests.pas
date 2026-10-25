unit QueryModel.Tests;

interface

uses
  DUnitX.TestFramework;

type

  [TestFixture]
  TQueryModelTests = class
  public
    [Test]
    procedure FactoryCreatesConcreteQuery;
    [Test]
    procedure CompileDefaultsToMSSql;
    [TestCase('MSSql', '0')]
    [TestCase('MySql', '1')]
    [TestCase('PostgreSql', '2')]
    [TestCase('Sqlite', '3')]
    [TestCase('Oracle', '4')]
    [TestCase('Firebird', '5')]
    procedure CompileSelectsDialect(DialectIndex: Integer);
    [Test]
    procedure CompilePropagatesErrors;
    [Test]
    procedure DebugSqlInlinesValues;
    [Test]
    procedure CompileReturnsSqlAndBindings;
    [Test]
    procedure CompilePreservesSpecialValues;
    [Test]
    procedure CompilationDoesNotMutateQueryOrEarlierResults;
    [Test]
    procedure SqlResultContractKeepsIdentity;
    [Test]
    procedure ClonePreservesSubclassAndIndependentState;
    [Test]
    procedure ScopedClausesKeepFallbackAndRemovalRules;
    [Test]
    procedure CallbacksRejectReplacementAndRestoreScope;
    [Test]
    procedure SubqueryComponentsKeepSnapshots;
    [Test]
    procedure JoinCallbacksKeepIndependentConditionGroups;
    [Test]
    procedure PaginationUsesInt64AndClampsNegativeValues;
    [Test]
    procedure ValueHelpersCopyAndPreserveTypes;
  end;

implementation

uses
  System.SysUtils, System.Rtti, System.TypInfo, System.Variants,
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Query,
  QueryBuilder4Delphi.Compilers.Compiler,
  QueryBuilder4Delphi.Compilers.SqlServerCompiler,
  QueryBuilder4Delphi.Compilers.MySqlCompiler,
  QueryBuilder4Delphi.Compilers.PostgresCompiler,
  QueryBuilder4Delphi.Compilers.SqliteCompiler,
  QueryBuilder4Delphi.Compilers.OracleCompiler,
  QueryBuilder4Delphi.Compilers.FirebirdCompiler;

type
  TCustomQuery = class(QueryBuilder4Delphi.Query.TQueryObject)
  public
    function NewQuery: QueryBuilder4Delphi.Query.Core.IQuery; override;
  end;

function TCustomQuery.NewQuery: QueryBuilder4Delphi.Query.Core.IQuery;
begin
  Result := TCustomQuery.Create;
end;

procedure TQueryModelTests.FactoryCreatesConcreteQuery;
var
  Query, Shared, Empty: IQuery;
begin
  Query := TQuery.Create('Books');
  Assert.IsTrue((Query as TQueryObject).ClassType = TQueryObject);
  Shared := Query;
  Query := nil;
  Assert.AreEqual('Books', Shared.GetOne('from', '').Name);
  Empty := Shared.NewQuery;
  Assert.IsTrue((Empty as TQueryObject).ClassType = TQueryObject);
  Assert.IsFalse(Empty.HasComponent('from'));
  Assert.IsTrue(Shared.HasComponent('from'));
end;

procedure TQueryModelTests.CompileDefaultsToMSSql;
begin
  Assert.AreEqual('SELECT [Title] FROM [Books] WHERE [Id] = @p0',
    TQuery.Create('Books').Select('Title').Where('Id', 42).Compile.Sql);
end;

procedure TQueryModelTests.CompileSelectsDialect(DialectIndex: Integer);
const
  Engines: array [TSqlDialect] of string = ('sqlsrv', 'mysql', 'postgres',
    'sqlite', 'oracle', 'firebird');
var
  Dialect, EngineDialect: TSqlDialect;
  Query: IQuery;
  Compiler: ICompiler;
  Expected, Actual: ISqlResult;
  I: Integer;
begin
  Dialect := TSqlDialect(DialectIndex);
  case Dialect of
    TSqlDialect.MSSql:
      Compiler := TSqlServerCompiler.Create;
    TSqlDialect.MySql:
      Compiler := TMySqlCompiler.Create;
    TSqlDialect.PostgreSql:
      Compiler := TPostgresCompiler.Create;
    TSqlDialect.Sqlite:
      Compiler := TSqliteCompiler.Create;
    TSqlDialect.Oracle:
      Compiler := TOracleCompiler.Create;
    TSqlDialect.Firebird:
      Compiler := TFirebirdCompiler.Create;
  end;
  Assert.AreEqual(Engines[Dialect], Dialect.EngineCode);
  Assert.AreEqual(Dialect.EngineCode, Compiler.EngineCode);
  Query := TQuery.Create('Books').Select('Title').Where('Id', 42)
    .OrderBy('Title').Limit(2).Offset(1);
  for EngineDialect := Low(TSqlDialect) to High(TSqlDialect) do
    Query.&For(EngineDialect.EngineCode,
      function(Q: IQuery): IQuery
      begin
        Result := Q.SelectRaw(IntToStr(Ord(EngineDialect)));
      end);
  Expected := Compiler.Compile(Query);
  Actual := Query.Compile(Dialect);
  Assert.AreEqual(Expected.Sql, Actual.Sql);
  Assert.AreEqual(Expected.RawSql, Actual.RawSql);
  Assert.AreEqual(Expected.Bindings.Count, Actual.Bindings.Count);
  Assert.AreEqual(Expected.NamedBindings.Count, Actual.NamedBindings.Count);
  for I := 0 to Expected.Bindings.Count - 1 do
  begin
    Assert.AreEqual(Expected.Bindings[I].ToString, Actual.Bindings[I].ToString);
    Assert.AreEqual(Expected.NamedBindings[Compiler.ParameterPrefix +
      IntToStr(I)].ToString, Actual.NamedBindings[Compiler.ParameterPrefix +
      IntToStr(I)].ToString);
  end;
  Assert.AreEqual(Expected.Sql, Query.Compile(Dialect).Sql);
  Assert.AreEqual(Expected.ToString, Query.ToDebugSql(Dialect));
  Assert.AreEqual('', Query.EngineScope);
  Assert.AreEqual<NativeInt>(7, Length(Query.GetComponents('select')));
end;

procedure TQueryModelTests.CompilePropagatesErrors;
begin
  Assert.WillRaise(
    procedure
    begin
      TQuery.Create('Books').WhereRaw('Id = ?', []).Compile;
    end, EQueryException);
  Assert.WillRaise(
    procedure
    begin
      TQuery.Create('Books').WhereRaw('Id = ?', []).ToDebugSql;
    end, EQueryException);
end;

procedure TQueryModelTests.DebugSqlInlinesValues;
begin
  Assert.AreEqual
    ('SELECT * FROM [Books] WHERE [Title] = ''O''''Reilly'' AND [Id] = 42',
    TQuery.Create('Books').Where('Title', 'O''Reilly').Where('Id', 42)
    .ToDebugSql);
  Assert.AreEqual('INSERT INTO [Books] ([Title]) VALUES (''New Book'')',
    TQuery.Create('Books').AsInsert(['Title'], ['New Book']).ToDebugSql);
  Assert.AreEqual('INSERT INTO [Books] ([Title]) VALUES (NULL)',
    TQuery.Create('Books').AsInsert(['Title'], [TValue.Empty]).ToDebugSql);
end;

procedure TQueryModelTests.CompileReturnsSqlAndBindings;
var
  Statement: QueryBuilder4Delphi.Query.Core.ISqlResult;
begin
  Statement := TQuery.Create('Books').Select(['Id', 'Title']).Where('Id', 42)
    .Where('Title', 'O''Reilly').Compile;
  Assert.AreEqual('SELECT [Id], [Title] FROM [Books] WHERE [Id] = @p0 ' +
    'AND [Title] = @p1', Statement.Sql);
  Assert.AreEqual('SELECT [Id], [Title] FROM [Books] WHERE [Id] = ? ' +
    'AND [Title] = ?', Statement.RawSql);
  Assert.AreEqual<NativeInt>(2, Statement.Bindings.Count);
  Assert.AreEqual<NativeInt>(2, Statement.NamedBindings.Count);
  Assert.AreEqual(42, Statement.Bindings[0].AsInteger);
  Assert.AreEqual('O''Reilly', Statement.Bindings[1].AsString);
  Assert.AreEqual(42, Statement.NamedBindings['@p0'].AsInteger);
  Assert.AreEqual('O''Reilly', Statement.NamedBindings['@p1'].AsString);
end;

procedure TQueryModelTests.CompilePreservesSpecialValues;
const
  Text = 'O''Reilly ? @p0 \ path' + #13#10 + #$00E4 + #$4E66;
var
  Q: IQuery;
  Statement: ISqlResult;
  TypedNull: TValue;
  I: Integer;
begin
  TypedNull := TQueryNull.Create(qtString);
  Q := TQuery.Create('Books').AsInsert(['Text', 'Empty', 'TypedNull',
    'VariantNull', 'Enabled', 'Disabled', 'Price', 'Date'],
    [Text, TValue.Empty, TypedNull, TValue.From<Variant>(Null), True, False,
    TValue.From<Double>(12.5), TValue.From<TDateTime>(EncodeDate(2026,
    10, 25))]);
  Statement := Q.Compile;
  Assert.AreEqual('INSERT INTO [Books] ([Text], [Empty], [TypedNull], ' +
    '[VariantNull], [Enabled], [Disabled], [Price], [Date]) VALUES ' +
    '(@p0, @p1, @p2, @p3, @p4, @p5, @p6, @p7)', Statement.Sql);
  Assert.AreEqual<NativeInt>(8, Statement.Bindings.Count);
  Assert.AreEqual<NativeInt>(8, Statement.NamedBindings.Count);
  for I := 0 to 7 do
    Assert.IsTrue(Statement.NamedBindings.ContainsKey('@p' + IntToStr(I)));
  Assert.AreEqual(Text, Statement.Bindings[0].AsString);
  Assert.IsTrue(Statement.Bindings[1].IsEmpty);
  Assert.IsTrue(Statement.Bindings[2].AsType<TQueryNull>.ValueType = qtString);
  Assert.IsTrue(VarIsNull(Statement.Bindings[3].AsVariant));
  Assert.IsTrue(Statement.Bindings[4].AsBoolean);
  Assert.IsFalse(Statement.Bindings[5].AsBoolean);
  Assert.IsTrue(Statement.Bindings[6].TypeInfo = TypeInfo(Double));
  Assert.IsTrue(Statement.Bindings[7].TypeInfo = TypeInfo(TDateTime));
  Assert.AreEqual('INSERT INTO [Books] ([Text], [Empty], [TypedNull], ' +
    '[VariantNull], [Enabled], [Disabled], [Price], [Date]) VALUES (' +
    QuotedStr(Text) + ', NULL, NULL, NULL, true, false, 12.5, ''2026-10-25'')',
    Q.ToDebugSql);
  Assert.AreEqual(Statement.ToString, Q.ToDebugSql);
end;

procedure TQueryModelTests.CompilationDoesNotMutateQueryOrEarlierResults;
var
  Q: IQuery;
  First, Second: ISqlResult;
begin
  Q := TQuery.Create('Books').Where('Id', 42);
  First := Q.Compile;
  Assert.AreEqual('SELECT * FROM [Books] WHERE [Id] = 42', Q.ToDebugSql);
  Second := Q.Compile;
  Assert.IsTrue(First <> Second);
  Second.Bindings[0] := 99;
  Second.NamedBindings['@p0'] := 99;
  Assert.AreEqual(42, First.Bindings[0].AsInteger);
  Assert.AreEqual(42, First.NamedBindings['@p0'].AsInteger);
  Assert.AreEqual(42, Q.GetOne('where', '').Value.AsInteger);
  Q.Where('Title', 'New');
  Second := Q.Compile;
  Assert.AreEqual<NativeInt>(1, First.Bindings.Count);
  Assert.AreEqual<NativeInt>(2, Second.Bindings.Count);
  Assert.AreEqual('SELECT * FROM [Books] WHERE [Id] = @p0', First.Sql);
  Assert.AreEqual('SELECT * FROM [Books] WHERE [Id] = 42', First.ToString);
end;

procedure TQueryModelTests.SqlResultContractKeepsIdentity;
var
  Shared: QueryBuilder4Delphi.Query.Core.ISqlResult;
  Legacy: QueryBuilder4Delphi.Compilers.Compiler.ISqlResult;
  Queried: QueryBuilder4Delphi.Query.Core.ISqlResult;
  OriginalId: TGUID;
begin
  Shared := TQuery.Create('Books').Compile;
  Legacy := Shared;
  Shared := Legacy;
  OriginalId := StringToGUID('{451A0775-C8EC-455D-B66A-7480EF77C28C}');
  Assert.IsTrue(Supports(Legacy, OriginalId, Queried));
  Assert.IsTrue(Shared = Queried);
end;

procedure TQueryModelTests.ClonePreservesSubclassAndIndependentState;
var
  Query, Clone: IQuery;
begin
  Query := TCustomQuery.Create('Books', 'original');
  Query.&As('b').AsLeft.Distinct.Define('Id', 42).Where('Id', 42);
  Query.SetEngineScope('mysql');
  Clone := Query.Clone;
  Assert.IsTrue((Clone as TCustomQuery).ClassType = TCustomQuery);
  Assert.AreEqual('mysql', Clone.EngineScope);
  Assert.AreEqual('b', Clone.QueryAlias);
  Assert.AreEqual('LEFT JOIN', Clone.JoinType);
  Assert.IsTrue(Clone.IsDistinct);
  Assert.AreEqual('original', Clone.GetComment);
  Assert.AreEqual(42, Clone.FindVariable('Id').AsInteger);
  Query.GetOne('where', '').Value := 7;
  Query.Variables['Id'] := 7;
  Query.Comment('changed');
  Assert.AreEqual(42, Clone.GetOne('where', '').Value.AsInteger);
  Assert.AreEqual(42, Clone.FindVariable('Id').AsInteger);
  Assert.AreEqual('original', Clone.GetComment);
  Assert.IsTrue(Clone.CopyClausesFrom(Clone) = Clone);
  Assert.IsTrue(Clone.HasConditions);
end;

procedure TQueryModelTests.ScopedClausesKeepFallbackAndRemovalRules;
var
  Query: IQuery;
begin
  Query := QueryBuilder4Delphi.Query.TQuery.Create('Books').Limit(5);
  Query.SetEngineScope('mysql').Limit(10);
  Query.SetEngineScope('postgres').Limit(20);
  Assert.AreEqual(10, Query.GetLimit('mysql'));
  Assert.AreEqual(5, Query.GetLimit('sqlite'));
  Assert.AreEqual<NativeInt>(3, Length(Query.GetComponents('limit')));
  Query.Remove('limit', 'mysql');
  Assert.AreEqual(5, Query.GetLimit('mysql'));
  Query.ClearComponent('limit', 'postgres');
  Assert.IsFalse(Query.HasLimit);
  Assert.AreEqual<NativeInt>(0, Length(Query.GetComponents('limit')));
end;

procedure TQueryModelTests.CallbacksRejectReplacementAndRestoreScope;
var
  Query: IQuery;
begin
  Query := QueryBuilder4Delphi.Query.TQuery.Create('Books')
    .SetEngineScope('sqlite');
  Assert.WillRaise(
    procedure
    begin
      Query.&For('mysql',
        function(Q: IQuery): IQuery
        begin
          Assert.AreEqual('mysql', Q.EngineScope);
          Result := QueryBuilder4Delphi.Query.TQuery.Create;
        end);
    end, EQueryException);
  Assert.AreEqual('sqlite', Query.EngineScope);
  Assert.WillRaise(
    procedure
    begin
      Query.&From(
        function(Q: IQuery): IQuery
        begin
          Result := nil;
        end);
    end, EQueryException);
  Assert.IsTrue(Query.WhenNot(True,
    function(Q: IQuery): IQuery
    begin
      Result := Q;
      raise EQueryException.Create('The inactive branch must not run');
    end) = Query);
end;

procedure TQueryModelTests.SubqueryComponentsKeepSnapshots;
var
  Source, Query: IQuery;
  Component: string;
begin
  Source := QueryBuilder4Delphi.Query.TQuery.Create('Authors').Select('Id')
    .Where('Id', 42);
  Query := QueryBuilder4Delphi.Query.TQuery.Create.&From(Source, 'a')
    .Select(Source, 'author').SelectAggregate('count', 'Id', Source)
    .&With('authors', Source).Combine('union', False, Source);
  Source.GetOne('where', '').Value := 7;
  Source := nil;
  for Component in TArray<string>.Create('from', 'select', 'cte', 'combine') do
    Assert.AreEqual(42, Query.GetOne(Component, '').Query.GetOne('where', '')
      .Value.AsInteger);
  Assert.AreEqual(42, Query.GetComponents('select')[1].Query.GetOne('where', '')
    .Value.AsInteger);
  Assert.AreEqual('', Query.GetOne('cte', '').Query.QueryAlias);
  Assert.AreEqual('a', Query.GetOne('from', '').Query.QueryAlias);
end;

procedure TQueryModelTests.JoinCallbacksKeepIndependentConditionGroups;
var
  Query, Join, Group: IQuery;
begin
  Query := QueryBuilder4Delphi.Query.TQuery.Create('Books').LeftJoin('Authors',
    function(Q: IQuery): IQuery
    begin
      Result := Q.On('Authors.Id', 'Books.AuthorId')
        .OrWhere('Authors.Active', True);
    end);
  Join := Query.GetOne('join', '').Query;
  Group := Join.GetOne('where', '').Query;
  Assert.AreEqual('LEFT JOIN', Join.JoinType);
  Assert.AreEqual<NativeInt>(2, Length(Group.GetComponents('where')));
  Assert.IsTrue(Group.GetComponents('where')[1].IsOr);
  Join.Where('Authors.Country', 'AT');
  Assert.AreEqual<NativeInt>(2, Length(Group.GetComponents('where')));
  Assert.AreEqual<NativeInt>(2, Length(Join.GetComponents('where')));
end;

procedure TQueryModelTests.PaginationUsesInt64AndClampsNegativeValues;
var
  Query: IQuery;
begin
  Query := QueryBuilder4Delphi.Query.TQuery.Create('Books')
    .ForPage(100000, 100000);
  Assert.AreEqual<Int64>(9999900000, Query.GetOffset);
  Assert.AreEqual(100000, Query.GetLimit);
  Query.Take(-1).Skip(-1);
  Assert.AreEqual<Int64>(0, Query.GetOffset);
  Assert.AreEqual(0, Query.GetLimit);
  Assert.IsFalse(Query.HasOffset);
  Assert.IsFalse(Query.HasLimit);
end;

procedure TQueryModelTests.ValueHelpersCopyAndPreserveTypes;
var
  Original, Copied, Unique: TValues;
  Expanded: TArray<string>;
begin
  Original := TSqlValues.&Of<Integer>([1, 1, 2]);
  Copied := CopyValues(Original);
  Unique := QueryBuilder4Delphi.Query.Core.DistinctValues(Original);
  Original[0] := 99;
  Assert.AreEqual(1, Copied[0].AsInteger);
  Assert.AreEqual<NativeInt>(2, Length(Unique));
  Assert.AreEqual(1, Unique[0].AsInteger);
  Assert.AreEqual(2, Unique[1].AsInteger);
  Assert.IsTrue(Copied[0].TypeInfo = TypeInfo(Integer));
  Expanded := ExpandExpression('Books.{Id, Title}');
  Assert.AreEqual('Books.Id', Expanded[0]);
  Assert.AreEqual('Books.Title', Expanded[1]);
  Expanded := CopyStrings(Expanded);
  Assert.AreEqual<NativeInt>(2, Length(Expanded));
end;

initialization

TDUnitX.RegisterTestFixture(TQueryModelTests);

end.
