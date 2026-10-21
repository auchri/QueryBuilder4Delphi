unit QueryModel.Tests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TQueryModelTests = class
  public
    [Test] procedure FacadeAndDirectImportsShareTypes;
    [Test] procedure ClonePreservesSubclassAndIndependentState;
    [Test] procedure ScopedClausesKeepFallbackAndRemovalRules;
    [Test] procedure CallbacksRejectReplacementAndRestoreScope;
    [Test] procedure SubqueryComponentsKeepSnapshots;
    [Test] procedure JoinCallbacksKeepIndependentConditionGroups;
    [Test] procedure PaginationUsesInt64AndClampsNegativeValues;
    [Test] procedure ValueHelpersCopyAndPreserveTypes;
  end;

implementation

uses
  System.SysUtils, System.Rtti, System.TypInfo,
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Query, SqlKata;

type
  TCustomQuery = class(QueryBuilder4Delphi.Query.TQueryObject)
  public
    function NewQuery: QueryBuilder4Delphi.Query.Core.IQuery; override;
  end;

function TCustomQuery.NewQuery: QueryBuilder4Delphi.Query.Core.IQuery;
begin
  Result := TCustomQuery.Create;
end;

procedure TQueryModelTests.FacadeAndDirectImportsShareTypes;
var
  Direct: QueryBuilder4Delphi.Query.Core.IQuery;
  Legacy: SqlKata.IQuery;
begin
  Direct := QueryBuilder4Delphi.Query.TQuery.Create('Books');
  Legacy := Direct;
  Assert.IsTrue(Legacy = Direct);
  Assert.IsTrue(SqlKata.TQueryObject = QueryBuilder4Delphi.Query.TQueryObject);
  Assert.IsTrue(TypeInfo(SqlKata.TQueryCallback) =
    TypeInfo(QueryBuilder4Delphi.Query.Core.TQueryCallback));
  Assert.IsTrue(TypeInfo(SqlKata.TValues) = TypeInfo(QueryBuilder4Delphi.Query.Core.TValues));
  Assert.IsTrue(SqlKata.ColumnAttribute = QueryBuilder4Delphi.Query.Core.ColumnAttribute);
  Assert.IsTrue(SqlKata.KeyAttribute = QueryBuilder4Delphi.Query.Core.KeyAttribute);
  Assert.IsTrue(SqlKata.IgnoreAttribute = QueryBuilder4Delphi.Query.Core.IgnoreAttribute);
  Assert.IsTrue(SqlKata.ckQuery = QueryBuilder4Delphi.Query.Core.ckQuery);
  Legacy := SqlKata.TQuery.Create('Authors');
  Direct := Legacy;
  Assert.IsTrue((Direct as QueryBuilder4Delphi.Query.TQueryObject).ClassType =
    QueryBuilder4Delphi.Query.TQueryObject);
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
  Query := QueryBuilder4Delphi.Query.TQuery.Create('Books').SetEngineScope('sqlite');
  Assert.WillRaise(procedure begin
    Query.&For('mysql', function(Q: IQuery): IQuery
      begin
        Assert.AreEqual('mysql', Q.EngineScope);
        Result := QueryBuilder4Delphi.Query.TQuery.Create;
      end);
  end, EQueryException);
  Assert.AreEqual('sqlite', Query.EngineScope);
  Assert.WillRaise(procedure begin
    Query.&From(function(Q: IQuery): IQuery
      begin
        Result := nil;
      end);
  end, EQueryException);
  Assert.IsTrue(Query.WhenNot(True, function(Q: IQuery): IQuery
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
  Source := QueryBuilder4Delphi.Query.TQuery.Create('Authors').Select('Id').Where('Id', 42);
  Query := QueryBuilder4Delphi.Query.TQuery.Create.&From(Source, 'a')
    .Select(Source, 'author').SelectAggregate('count', 'Id', Source)
    .&With('authors', Source).Combine('union', False, Source);
  Source.GetOne('where', '').Value := 7;
  Source := nil;
  for Component in TArray<string>.Create('from', 'select', 'cte', 'combine') do
    Assert.AreEqual(42, Query.GetOne(Component, '').Query.GetOne('where', '').Value.AsInteger);
  Assert.AreEqual(42, Query.GetComponents('select')[1].Query.GetOne('where', '').Value.AsInteger);
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
      Result := Q.On('Authors.Id', 'Books.AuthorId').OrWhere('Authors.Active', True);
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
  Query := QueryBuilder4Delphi.Query.TQuery.Create('Books').ForPage(100000, 100000);
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
  Original := SqlKata.TSqlValues.&Of<Integer>([1, 1, 2]);
  Copied := SqlKata.CopyValues(Original);
  Unique := QueryBuilder4Delphi.Query.Core.DistinctValues(Original);
  Original[0] := 99;
  Assert.AreEqual(1, Copied[0].AsInteger);
  Assert.AreEqual<NativeInt>(2, Length(Unique));
  Assert.AreEqual(1, Unique[0].AsInteger);
  Assert.AreEqual(2, Unique[1].AsInteger);
  Assert.IsTrue(Copied[0].TypeInfo = TypeInfo(Integer));
  Expanded := SqlKata.ExpandExpression('Books.{Id, Title}');
  Assert.AreEqual('Books.Id', Expanded[0]);
  Assert.AreEqual('Books.Title', Expanded[1]);
  Expanded := SqlKata.CopyStrings(Expanded);
  Assert.AreEqual<NativeInt>(2, Length(Expanded));
end;

initialization
  TDUnitX.RegisterTestFixture(TQueryModelTests);

end.
