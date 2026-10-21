unit QueryWrites.Tests;

interface

uses
  DUnitX.TestFramework;

type

  [TestFixture]
  TQueryWriteTests = class
  public
    [Test]
    procedure WriteMethodsKeepFluentIdentity;
    [Test]
    procedure InvalidMultirowInsertPreservesExistingData;
    [Test]
    procedure InsertSelectKeepsIndependentSource;
    [Test]
    procedure EngineSpecificWritesReplaceOnlyTheirOwnScope;
    [TestCase('Where', 'where')]
    [TestCase('Having', 'having')]
    procedure ConditionPairsPreserveBooleanFlags(const Component: string);
    [Test]
    procedure MapperSkipsIgnoredAndUnreadableProperties;
    [Test]
    procedure ObjectKeysAddPredicatesOnlyForUpdates;
  end;

implementation

uses
  System.SysUtils, System.Rtti, System.Generics.Collections,
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Query,
  QueryBuilder4Delphi.Query.DataMapper,
  QueryBuilder4Delphi.Compilers.Compiler,
  QueryBuilder4Delphi.Compilers.SqlServerCompiler,
  QueryBuilder4Delphi.Compilers.PostgresCompiler,
  QueryBuilder4Delphi.Compilers.MySqlCompiler,
  QueryBuilder4Delphi.Compilers.SqliteCompiler,
  QueryBuilder4Delphi.Compilers.OracleCompiler,
  QueryBuilder4Delphi.Compilers.FirebirdCompiler;

type
  TMappedData = class
  private
    FId: Integer;
    FName, FSecret: string;
    function GetIgnored: string;
  public
    [QueryBuilder4Delphi.Query.Core.Key('UserId')]
    property Id: Integer read FId write FId;
    [QueryBuilder4Delphi.Query.Core.Column('DisplayName')]
    property Name: string read FName write FName;
    property Secret: string write FSecret;
    [QueryBuilder4Delphi.Query.Core.Ignore]
    property Ignored: string read GetIgnored;
  end;

function TMappedData.GetIgnored: string;
begin
  raise EQueryException.Create('An ignored property must not be read');
end;

procedure TQueryWriteTests.WriteMethodsKeepFluentIdentity;
var
  Query, Source: IQuery;
  Pairs: TArray<TPair<string, TValue>>;
begin
  Query := TQuery.Create('Users');
  Source := TQuery.Create('Authors').Select('Id');
  Pairs := TArray < TPair < string,
    TValue >>.Create(TPair<string, TValue>.Create('Id', 1));
  Assert.IsTrue(Query.AsInsert(['Id'], [1]) = Query);
  Assert.IsTrue(Query.AsInsert(['Id'], TRows.Create(TValues.Create(1)))
    = Query);
  Assert.IsTrue(Query.AsInsert(['Id'], Source) = Query);
  Assert.IsTrue(Query.AsInsert(Pairs, True) = Query);
  Assert.IsTrue(Query.GetOne('insert', '').ReturnId);
  Assert.IsTrue(Query.AsUpdate(['Id'], [2]) = Query);
  Assert.IsTrue(Query.AsUpdate(Pairs) = Query);
  Assert.IsTrue(Query.AsDelete = Query);
  Assert.IsTrue(Query.AsIncrement('Id', 2) = Query);
  Assert.IsTrue(Query.AsDecrement('Id', 2) = Query);
  Assert.IsTrue(Query.AsAggregate('count', ['Id']) = Query);
end;

procedure TQueryWriteTests.InvalidMultirowInsertPreservesExistingData;
var
  Query: IQuery;
  Rows: TRows;
  Compiled: ISqlResult;
begin
  Query := TQuery.Create('Books').AsInsert(['Title'], ['Original']);
  Rows := TRows.Create(TValues.Create('First'), TValues.Create('Second', 2));
  Assert.WillRaise(
    procedure
    begin
      Query.AsInsert(['Title'], Rows);
    end, EQueryException);
  Compiled := TSqliteCompiler.Create.Compile(Query);
  Assert.AreEqual('INSERT INTO "Books" ("Title") VALUES (@p0)', Compiled.Sql);
  Assert.AreEqual<NativeInt>(1, Compiled.Bindings.Count);
  Assert.AreEqual('Original', Compiled.Bindings[0].AsString);
end;

procedure TQueryWriteTests.InsertSelectKeepsIndependentSource;
var
  Source, Query: IQuery;
  Compiled: ISqlResult;
begin
  Source := TQuery.Create('Authors').Select('Id').Where('Country', 'AT');
  Query := TQuery.Create('Users').AsInsert(['AuthorId'], Source);
  Source.ClearComponent('where').Where('Country', 'DE');
  Source := nil;
  Compiled := TSqliteCompiler.Create.Compile(Query);
  Assert.AreEqual('INSERT INTO "Users" ("AuthorId") ' +
    'SELECT "Id" FROM "Authors" WHERE "Country" = @p0', Compiled.Sql);
  Assert.AreEqual('AT', Compiled.Bindings[0].AsString);
end;

procedure TQueryWriteTests.EngineSpecificWritesReplaceOnlyTheirOwnScope;
var
  Query: IQuery;
  Compiled: ISqlResult;
begin
  Query := TQuery.Create('Books').AsUpdate(['Title'], ['Default']);
  Query.SetEngineScope('mysql').AsUpdate(['Title'], ['Old']);
  Query.AsUpdate(['Title'], ['MySQL']);
  Query.SetEngineScope('');
  Assert.AreEqual<NativeInt>(2, Length(Query.GetComponents('update')));
  Compiled := TMySqlCompiler.Create.Compile(Query);
  Assert.AreEqual('MySQL', Compiled.Bindings[0].AsString);
  Compiled := TSqliteCompiler.Create.Compile(Query);
  Assert.AreEqual('Default', Compiled.Bindings[0].AsString);
end;

procedure TQueryWriteTests.ConditionPairsPreserveBooleanFlags
  (const Component: string);
var
  Query: IQuery;
  Pairs, EmptyPairs: TArray<TPair<string, TValue>>;
  Clauses: TArray<TClause>;
  I: Integer;
begin
  Query := TQuery.Create('Books');
  Pairs := TArray < TPair < string,
    TValue >>.Create(TPair<string, TValue>.Create('First', 1),
    TPair<string, TValue>.Create('Second', 2));
  if Component = 'where' then
    Query.Where('Seed', 0).&Or.&Not.Where(Pairs).Where('Tail', 3)
  else
    Query.Having('Seed', 0).&Or.&Not.Having(Pairs).Having('Tail', 3);
  Clauses := Query.GetComponents(Component);
  Assert.AreEqual<NativeInt>(4, Length(Clauses));
  for I := 1 to 2 do
  begin
    Assert.IsTrue(Clauses[I].IsOr);
    Assert.IsTrue(Clauses[I].IsNot);
  end;
  Assert.IsFalse(Clauses[3].IsOr);
  Assert.IsFalse(Clauses[3].IsNot);

  EmptyPairs := nil;
  Query.&Or.&Not;
  if Component = 'where' then
    Query.Where(EmptyPairs).Where('AfterEmpty', 4)
  else
    Query.Having(EmptyPairs).Having('AfterEmpty', 4);
  Clauses := Query.GetComponents(Component);
  Assert.AreEqual<NativeInt>(5, Length(Clauses));
  Assert.IsTrue(Clauses[4].IsOr);
  Assert.IsTrue(Clauses[4].IsNot);
end;

procedure TQueryWriteTests.MapperSkipsIgnoredAndUnreadableProperties;
var
  Data: TMappedData;
  Pairs: TArray<TPair<string, TValue>>;
  KeyName: string;
  KeyValue: TValue;
begin
  Data := TMappedData.Create;
  try
    Data.Id := 42;
    Data.Name := 'Jane';
    Pairs := TQueryDataMapper.GetPairs(Data,
      procedure(Name: string; Value: TValue)
      begin
        KeyName := Name;
        KeyValue := Value;
      end);
    Assert.AreEqual<NativeInt>(2, Length(Pairs));
    Assert.AreEqual('UserId', KeyName);
    Assert.AreEqual(42, KeyValue.AsInteger);
    Assert.WillRaise(
      procedure
      begin
        Pairs := TQueryDataMapper.GetPairs(nil);
      end, EArgumentNilException);
    Assert.WillRaise(
      procedure
      begin
        Pairs := TQueryDataMapper.GetPairs(Data,
          procedure(Name: string; Value: TValue)
          begin
            raise EQueryException.Create('Key callback failed');
          end);
      end, EQueryException);
  finally
    Data.Free;
  end;
end;

procedure TQueryWriteTests.ObjectKeysAddPredicatesOnlyForUpdates;
var
  Data: TMappedData;
  Query: IQuery;
begin
  Data := TMappedData.Create;
  try
    Data.Id := 42;
    Data.Name := 'Jane';
    Query := TQuery.Create('Users').AsInsert(Data, True);
    Assert.IsFalse(Query.HasConditions);
    Assert.IsTrue(Query.GetOne('insert', '').ReturnId);
    Query := TQuery.Create('Users').Where(Data);
    Assert.AreEqual<NativeInt>(2, Length(Query.GetComponents('where')));
    Query := TQuery.Create('Users').Having(Data);
    Assert.IsFalse(Query.HasConditions);
    Assert.AreEqual<NativeInt>(2, Length(Query.GetComponents('having')));
    Query := TQuery.Create('Users').AsUpdate(Data);
    Assert.AreEqual<NativeInt>(1, Length(Query.GetComponents('where')));
    Assert.AreEqual('UserId', Query.GetOne('where', '').Name);
    Assert.AreEqual(42, Query.GetOne('where', '').Value.AsInteger);
    Assert.AreEqual<NativeInt>(2, Length(Query.GetOne('update', '').Columns));
  finally
    Data.Free;
  end;
end;

initialization

TDUnitX.RegisterTestFixture(TQueryWriteTests);

end.
