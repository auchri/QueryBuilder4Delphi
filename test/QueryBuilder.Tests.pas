unit QueryBuilder.Tests;

interface

uses System.SysUtils, System.Rtti, System.JSON, System.Generics.Collections,
  DUnitX.TestFramework, SqlKata, SqlKata.Compilers;

type
  [TestFixture]
  TQueryBuilderTests = class
  private
    FGolden: TJSONArray;
    function Build(const Name: string): TQuery;
    function Compiler(const Engine: string): TCompiler;
  public
    [SetupFixture] procedure LoadReference;
    [TearDownFixture] procedure FreeReference;
    {$I Oracle.Cases.inc}
    procedure MatchesCSharp(const Engine, Name: string);
    [Test] procedure CloneAndSubqueryOwnership;
    [Test] procedure CallbackExceptionAndScopeRestoration;
    [Test] procedure ParameterTypesAndInvariantDebugSql;
    [Test] procedure RejectsUnsafeOperator;
    [Test] procedure InvalidWritesDoNotReplaceValidData;
    [Test] procedure BatchParameterNumbering;
    [Test] procedure NestedVariableResolution;
    [Test] procedure RawArrayExpansion;
    [Test] procedure ReadmeExamplesProduceDocumentedSql;
    [Test] procedure TypedArraysAndEmptyGroups;
    [Test] procedure RttiMappingHonorsColumnKeyAndIgnore;
    [TestCase('sqlsrv','sqlsrv')]
    [TestCase('postgres','postgres')]
    [TestCase('mysql','mysql')]
    [TestCase('sqlite','sqlite')]
    [TestCase('oracle','oracle')]
    [TestCase('firebird','firebird')]
    [TestCase('sqlsrv_legacy','sqlsrv_legacy')]
    [TestCase('oracle_legacy','oracle_legacy')]
    procedure CorrectedHavingCallback(const Engine: string);
    [TestCase('OracleGroup','oracle,group')]
    [TestCase('OracleFilter','oracle,filter')]
    [TestCase('OracleLegacyGroup','oracle_legacy,group')]
    [TestCase('OracleLegacyFilter','oracle_legacy,filter')]
    procedure CorrectedOracleAggregateAlias(const Engine, Name: string);
  end;

implementation

uses System.IOUtils, System.RegularExpressions, System.TypInfo, ReadmeExamples;

type
  TUserData = class
  private
    FId: Integer;
    FName, FInternal: string;
  public
    [SqlKata.Key('UserId')]
    property Id: Integer read FId write FId;
    [SqlKata.Column('DisplayName')]
    property Name: string read FName write FName;
    [SqlKata.Ignore]
    property Internal: string read FInternal write FInternal;
  end;

function Normalize(const S: string): string;
begin Result := TRegEx.Replace(S, '\s+', ' ').Trim; end;
function TQueryBuilderTests.Build(const Name: string): TQuery;
begin
  {$I Oracle.Scenarios.inc}
end;
function TQueryBuilderTests.Compiler(const Engine: string): TCompiler;
begin
  if Engine.StartsWith('sqlsrv') then Result := TSqlServerCompiler.Create
  else if Engine.StartsWith('oracle') then Result := TOracleCompiler.Create
  else if Engine = 'postgres' then Result := TPostgresCompiler.Create
  else if Engine = 'mysql' then Result := TMySqlCompiler.Create
  else if Engine = 'sqlite' then Result := TSqliteCompiler.Create
  else if Engine = 'firebird' then Result := TFirebirdCompiler.Create
  else raise EQueryException.Create('Unknown engine');
  Result.UseLegacyPagination := Engine.EndsWith('_legacy');
end;
procedure TQueryBuilderTests.LoadReference;
var Filename: string;
begin
  Filename := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\test\golden.json'));
  FGolden := TJSONObject.ParseJSONValue(TFile.ReadAllText(Filename,TEncoding.UTF8)) as TJSONArray;
  Assert.IsNotNull(FGolden);
end;
procedure TQueryBuilderTests.FreeReference;
begin FreeAndNil(FGolden); end;
procedure TQueryBuilderTests.MatchesCSharp(const Engine, Name: string);
var Item, Expected: TJSONObject; Entry: TJSONValue; Binds: TJSONArray; Q: TQuery;
  C: TCompiler; R: TSqlResult; I: Integer; V: TValue; Actual: string; Raised: Boolean;
begin
  Expected := nil;
  for Entry in FGolden do
  begin
    Item := Entry as TJSONObject;
    if (Item.GetValue<string>('engine') = Engine) and (Item.GetValue<string>('name') = Name) then begin Expected := Item; Break; end;
  end;
  Assert.IsNotNull(Expected,'Missing C# fixture');
  Q := Build(Name); C := Compiler(Engine);
  try
    if Expected.GetValue('error') <> nil then
    begin
      Raised := False;
      try R := C.Compile(Q); R.Free; except on E: EQueryException do Raised := True; end;
      Assert.IsTrue(Raised,'C# rejects this query'); Exit;
    end;
    R := C.Compile(Q);
    try
      Assert.AreEqual(Normalize(Expected.GetValue<string>('sql')),Normalize(R.Sql),Engine+'.'+Name+' SQL');
      Assert.AreEqual(Normalize(Expected.GetValue<string>('raw')),Normalize(R.RawSql),Engine+'.'+Name+' RawSql');
      Binds := Expected.GetValue<TJSONArray>('bindings');
      Assert.AreEqual<NativeInt>(Binds.Count,R.Bindings.Count,'Binding count');
      for I := 0 to Binds.Count-1 do
      begin
        V := R.Bindings[I];
        if V.IsEmpty then Actual := '<NULL>'
        else if V.TypeInfo = TypeInfo(Boolean) then if V.AsBoolean then Actual := 'True' else Actual := 'False'
        else Actual := V.ToString;
        Assert.AreEqual(Binds.Items[I].Value,Actual,'Binding '+IntToStr(I));
      end;
      Assert.AreEqual<NativeInt>(R.Bindings.Count,R.NamedBindings.Count,'Named binding count');
    finally R.Free; end;
  finally Q.Free; C.Free; end;
end;

procedure TQueryBuilderTests.CloneAndSubqueryOwnership;
var Q, Sub, Clone: TQuery; C: TCompiler; R: TSqlResult;
begin
  Q := TQuery.Create('Books'); Sub := TQuery.Create('Authors'); C := TSqliteCompiler.Create;
  try
    Sub.Select('Id').Where('Country','AT'); Q.WhereIn('AuthorId',Sub);
    FreeAndNil(Sub);
    Clone := Q.Clone;
    try
      Q.ClearComponent('where');
      R := C.Compile(Clone);
      try Assert.AreEqual('SELECT * FROM "Books" WHERE "AuthorId" IN (SELECT "Id" FROM "Authors" WHERE "Country" = @p0)',R.Sql);
      finally R.Free; end;
    finally Clone.Free; end;
  finally Q.Free; Sub.Free; C.Free; end;
end;

procedure TQueryBuilderTests.CallbackExceptionAndScopeRestoration;
var Q: TQuery;
begin
  Q := TQuery.Create;
  try
    Q.SetEngineScope('oracle');
    Assert.WillRaise(procedure begin Q.&For('sqlsrv',function(Child:TQuery):TQuery
      begin raise EQueryException.Create('callback failure'); end); end,EQueryException);
    Assert.AreEqual('oracle',Q.EngineScope);
    Assert.WillRaise(procedure begin Q.Where(function(Child:TQuery):TQuery
      begin raise EQueryException.Create('callback failure'); end); end,EQueryException);
  finally Q.Free; end;
end;

procedure TQueryBuilderTests.ParameterTypesAndInvariantDebugSql;
var Q: TQuery; C: TCompiler; R: TSqlResult; Old: Char; D: TDateTime;
begin
  Q := TQuery.Create('Books'); C := TSqliteCompiler.Create; D := EncodeDate(2025,1,2);
  Old := FormatSettings.DecimalSeparator;
  try
    FormatSettings.DecimalSeparator := ',';
    Q.Where('Price',TValue.From<Double>(1.25)).Where('Created',TValue.From<TDateTime>(D)).Where('Title','O''Brien');
    R := C.Compile(Q);
    try
      Assert.IsTrue(R.Bindings[0].TypeInfo = TypeInfo(Double));
      Assert.IsTrue(R.Bindings[1].TypeInfo = TypeInfo(TDateTime));
      Assert.AreEqual('SELECT * FROM "Books" WHERE "Price" = 1.25 AND "Created" = ''2025-01-02'' AND "Title" = ''O''''Brien''',R.ToString);
    finally R.Free; end;
  finally FormatSettings.DecimalSeparator := Old; Q.Free; C.Free; end;
end;
procedure TQueryBuilderTests.RejectsUnsafeOperator;
var Q: TQuery; C: TCompiler; R: TSqlResult;
begin
  Q := TQuery.Create('Books').Where('Id','= 1; DROP TABLE Books --',1); C := TCompiler.Create;
  try
    Assert.WillRaise(procedure begin R := C.Compile(Q); R.Free; end,EQueryException);
    Q.ClearComponent('where').Where('Id','@>',1); C.Whitelist(['@>']);
    R := C.Compile(Q); try Assert.IsTrue(R.Sql.Contains(' @> @p0')); finally R.Free; end;
  finally Q.Free; C.Free; end;
end;
procedure TQueryBuilderTests.InvalidWritesDoNotReplaceValidData;
var Q: TQuery; C: TCompiler; R: TSqlResult;
begin
  Q := TQuery.Create('Books').AsInsert(['Title'],['A']); C := TCompiler.Create;
  try
    Assert.WillRaise(procedure begin Q.AsInsert(['Title','Id'],['B']); end,EQueryException);
    R := C.Compile(Q); try Assert.AreEqual('A',R.Bindings[0].AsString); finally R.Free; end;
  finally Q.Free; C.Free; end;
end;
procedure TQueryBuilderTests.BatchParameterNumbering;
var Q1, Q2: TQuery; C: TCompiler; R: TSqlResult;
begin
  Q1 := TQuery.Create('Books').Where('Id',1); Q2 := TQuery.Create('Authors').Where('Id',2); C := TCompiler.Create;
  try
    R := C.Compile([Q1,Q2]);
    try
      Assert.IsTrue(R.Sql.Contains('@p0;'+#10+'SELECT'));
      Assert.IsTrue(R.Sql.EndsWith('@p1')); Assert.AreEqual<NativeInt>(2,R.Bindings.Count);
    finally R.Free; end;
  finally Q1.Free; Q2.Free; C.Free; end;
end;
procedure TQueryBuilderTests.NestedVariableResolution;
var Q: TQuery; C: TCompiler; R: TSqlResult;
begin
  Q := TQuery.Create('Books').Define('id',5).WhereExists(function(Child:TQuery):TQuery
    begin Result := Child.&From('Authors').Where('Id',TVariable.Create('id')); end);
  C := TCompiler.Create;
  try R := C.Compile(Q); try Assert.AreEqual(5,R.Bindings[0].AsInteger); finally R.Free; end;
  finally Q.Free; C.Free; end;
end;
procedure TQueryBuilderTests.RawArrayExpansion;
var Q: TQuery; C: TCompiler; R: TSqlResult;
begin
  Q := TQuery.Create('Books').WhereRaw('[Id] IN (?)',[TValue.From<TArray<Integer>>(TArray<Integer>.Create(1,2,3))]);
  C := TCompiler.Create;
  try
    R := C.Compile(Q);
    try Assert.AreEqual('SELECT * FROM "Books" WHERE "Id" IN (@p0,@p1,@p2)',R.Sql); Assert.AreEqual<NativeInt>(3,R.Bindings.Count);
    finally R.Free; end;
  finally Q.Free; C.Free; end;
end;

procedure TQueryBuilderTests.TypedArraysAndEmptyGroups;
var Q: TQuery; C: TCompiler; R: TSqlResult;
begin
  Q := TQuery.Create('Books'); C := TCompiler.Create;
  try
    Q.WhereIn('Id',TSqlValues.&Of<Integer>(TArray<Integer>.Create(1,2))).Where(function(Child:TQuery):TQuery begin Result:=Child; end);
    R := C.Compile(Q);
    try Assert.AreEqual('SELECT * FROM "Books" WHERE "Id" IN (@p0, @p1)',R.Sql); finally R.Free; end;
  finally Q.Free; C.Free; end;
end;
procedure TQueryBuilderTests.RttiMappingHonorsColumnKeyAndIgnore;
var Q: TQuery; Data: TUserData; C: TCompiler; R: TSqlResult;
begin
  Data := TUserData.Create; Q := TQuery.Create('Users'); C := TCompiler.Create;
  try
    Data.Id := 5; Data.Name := 'Jane'; Data.Internal := 'ignored'; Q.AsUpdate(Data);
    R := C.Compile(Q);
    try
      Assert.IsTrue(R.Sql.Contains('"UserId" = @p0'));
      Assert.IsTrue(R.Sql.Contains('"DisplayName" = @p1'));
      Assert.IsTrue(R.Sql.EndsWith('WHERE "UserId" = @p2'));
      Assert.IsFalse(R.Sql.Contains('Internal')); Assert.AreEqual<NativeInt>(3,R.Bindings.Count);
    finally R.Free; end;
  finally Data.Free; Q.Free; C.Free; end;
end;

procedure TQueryBuilderTests.ReadmeExamplesProduceDocumentedSql;
var C: TCompiler;
  procedure Check(Q: TQuery; const Expected: string; BindingCount: Integer);
  var R: TSqlResult;
  begin
    try
      R := C.Compile(Q);
      try Assert.AreEqual(Normalize(Expected),Normalize(R.Sql)); Assert.AreEqual<NativeInt>(BindingCount,R.Bindings.Count);
      finally R.Free; end;
    finally Q.Free; end;
  end;
begin
  C := TSqlServerCompiler.Create;
  try
    Check(PublishedBooks,'SELECT [Id], [Title] FROM [Books] WHERE [IsPublished] = cast(1 as bit) AND [Lang] = @p0 ORDER BY [PublishedAt] DESC OFFSET @p1 ROWS FETCH NEXT @p2 ROWS ONLY',3);
    Check(BooksWithAuthors,'SELECT [Books].*, [Authors].[Name] AS [AuthorName] FROM [Books] INNER JOIN [Authors] ON [Authors].[Id] = [Books].[AuthorId]',0);
    Check(NestedConditions,'SELECT * FROM [Books] WHERE ([Lang] = @p0 OR [Lang] = @p1) AND [PublishedAt] IS NOT NULL',2);
    Check(PublishedCte,'WITH [published] AS (SELECT * FROM [Books] WHERE [IsPublished] = cast(1 as bit)) SELECT [Title] FROM [published]',0);
    Check(InsertUser,'INSERT INTO [Users] ([Name], [CountryId]) VALUES (@p0, @p1)',2);
    Check(UpdateUser,'UPDATE [Users] SET [Name] = @p0, [CountryId] = @p1 WHERE [Id] = @p2',3);
    Check(DeleteUser,'DELETE FROM [Users] WHERE [Id] = @p0',1);
  finally C.Free; end;
end;

procedure TQueryBuilderTests.CorrectedHavingCallback(const Engine: string);
var Q: TQuery; C: TCompiler; R: TSqlResult; Expected, P: string;
begin
  Q := Build('havingnested'); C := Compiler(Engine);
  try
    P := '@p'; if C.EngineCode = 'oracle' then P := ':p';
    Expected := 'SELECT * FROM '+C.Wrap('Books')+' GROUP BY '+C.Wrap('Id')+
      ' HAVING ('+C.Wrap('Id')+' = '+P+'0 OR '+C.Wrap('Id')+' = '+P+'1)';
    R := C.Compile(Q);
    try
      Assert.AreEqual(Expected,R.Sql);
      Assert.AreEqual<NativeInt>(2,R.Bindings.Count);
      Assert.AreEqual(1,R.Bindings[0].AsInteger); Assert.AreEqual(2,R.Bindings[1].AsInteger);
    finally R.Free; end;
  finally Q.Free; C.Free; end;
end;
procedure TQueryBuilderTests.CorrectedOracleAggregateAlias(const Engine, Name: string);
var Q: TQuery; C: TCompiler; R: TSqlResult; Expected: string;
begin
  Q := Build(Name); C := Compiler(Engine);
  try
    if Name = 'group' then Expected := 'SELECT "Category", COUNT("Id") "Count" FROM "Books" GROUP BY "Category" HAVING "Category" = :p0 OR "Category" IS NULL'
    else Expected := 'SELECT COUNT(CASE WHEN "Published" = true THEN "Id" END) "Published" FROM "Books"';
    R := C.Compile(Q);
    try
      Assert.AreEqual(Expected,R.Sql);
      if Name = 'group' then begin Assert.AreEqual<NativeInt>(1,R.Bindings.Count); Assert.AreEqual('A',R.Bindings[0].AsString); end
      else Assert.AreEqual<NativeInt>(0,R.Bindings.Count);
    finally R.Free; end;
  finally Q.Free; C.Free; end;
end;

initialization
  TDUnitX.RegisterTestFixture(TQueryBuilderTests);
end.
