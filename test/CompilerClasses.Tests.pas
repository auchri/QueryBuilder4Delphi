unit CompilerClasses.Tests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TCompilerClassTests = class
  public
    [TestCase('SQL Server', 'sqlsrv')]
    [TestCase('PostgreSQL', 'postgres')]
    [TestCase('MySQL', 'mysql')]
    [TestCase('SQLite', 'sqlite')]
    [TestCase('Oracle', 'oracle')]
    [TestCase('Firebird', 'firebird')]
    procedure FactoryCreatesRequestedClass(const Engine: string);
    [Test] procedure CustomMySqlCompilerInheritsDialectBehavior;
    [Test] procedure CustomSqlServerCompilerInheritsLegacyPagination;
  end;

implementation

uses
  System.SysUtils, System.Rtti, SqlKata,
  QueryBuilder4Delphi.Compilers.Compiler,
  QueryBuilder4Delphi.Compilers.SqlServerCompiler,
  QueryBuilder4Delphi.Compilers.PostgresCompiler,
  QueryBuilder4Delphi.Compilers.MySqlCompiler,
  QueryBuilder4Delphi.Compilers.SqliteCompiler,
  QueryBuilder4Delphi.Compilers.OracleCompiler,
  QueryBuilder4Delphi.Compilers.FirebirdCompiler;

type
  TCompilerClass = class of TCompiler;

  TCustomMySqlCompiler = class(TMySqlCompiler)
  protected
    constructor CreateInstance; override;
  public
    function CompileRandom(const Seed: TValue): string; override;
  end;

  TCustomSqlServerCompiler = class(TSqlServerCompiler)
  protected
    constructor CreateInstance; override;
  end;

constructor TCustomMySqlCompiler.CreateInstance;
begin
  inherited;
  FEngineCode := 'custom_mysql';
end;

function TCustomMySqlCompiler.CompileRandom(const Seed: TValue): string;
begin
  Result := 'CUSTOM_RANDOM()';
end;

constructor TCustomSqlServerCompiler.CreateInstance;
begin
  inherited;
  FEngineCode := 'custom_sqlsrv';
end;

procedure TCompilerClassTests.FactoryCreatesRequestedClass(const Engine: string);
var
  CompilerClass: TCompilerClass;
  Compiler: ICompiler;
begin
  if Engine = 'sqlsrv' then CompilerClass := TSqlServerCompiler
  else if Engine = 'postgres' then CompilerClass := TPostgresCompiler
  else if Engine = 'mysql' then CompilerClass := TMySqlCompiler
  else if Engine = 'sqlite' then CompilerClass := TSqliteCompiler
  else if Engine = 'oracle' then CompilerClass := TOracleCompiler
  else if Engine = 'firebird' then CompilerClass := TFirebirdCompiler
  else raise EArgumentException.Create('Unknown test engine');

  Compiler := CompilerClass.Create;
  Assert.IsTrue((Compiler as TCompiler).ClassType = CompilerClass);
  Assert.AreEqual(Engine, Compiler.EngineCode);
end;

procedure TCompilerClassTests.CustomMySqlCompilerInheritsDialectBehavior;
var
  Compiler: ICompiler;
  Compiled: ISqlResult;
begin
  Compiler := TCustomMySqlCompiler.Create;
  Compiled := Compiler.Compile(TQuery.Create('Books').WhereDate('PublishedAt', '2026-10-20')
    .OrderByRandom.Offset(2));
  Assert.AreEqual('SELECT * FROM `Books` WHERE DATE(`PublishedAt`) = @p0 '+
    'ORDER BY CUSTOM_RANDOM() LIMIT 18446744073709551615 OFFSET @p1', Compiled.Sql);
  Assert.AreEqual('2026-10-20', Compiled.Bindings[0].AsString);
  Assert.AreEqual<Int64>(2, Compiled.Bindings[1].AsInt64);

  Compiled := Compiler.Compile(TQuery.Create('Books')
    .Join('Authors', 'Authors.Id', 'Books.AuthorId').AsUpdate(['Title'], ['Revised']));
  Assert.IsTrue(Compiled.Sql.StartsWith('UPDATE `Books` '+#10+'INNER JOIN `Authors`'));
  Assert.IsTrue(Compiled.Sql.EndsWith(' SET `Title` = @p0'));
end;

procedure TCompilerClassTests.CustomSqlServerCompilerInheritsLegacyPagination;
var
  Compiler: ICompiler;
  Compiled: ISqlResult;
begin
  Compiler := TCustomSqlServerCompiler.Create;
  Compiler.UseLegacyPagination := True;
  Compiled := Compiler.Compile(TQuery.Create('Books').WhereTrue('Published').Limit(3));
  Assert.AreEqual('SELECT TOP (@p0) * FROM [Books] WHERE [Published] = cast(1 as bit)',
    Compiled.Sql);
  Assert.AreEqual(3, Compiled.Bindings[0].AsInteger);
  Assert.IsTrue((Compiler as TCompiler).InheritsFrom(TSqlServerCompiler));
end;

initialization
  TDUnitX.RegisterTestFixture(TCompilerClassTests);

end.
