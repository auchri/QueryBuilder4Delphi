program QueryBuilderTests;
{$APPTYPE CONSOLE}
uses
  System.SysUtils, System.IOUtils,
  DUnitX.TestFramework, DUnitX.Loggers.Console, DUnitX.Loggers.XML.NUnit,
  QueryBuilder4Delphi.Query.Core in '..\src\QueryBuilder4Delphi.Query.Core.pas',
  QueryBuilder4Delphi.Query in '..\src\QueryBuilder4Delphi.Query.pas',
  SqlKata in '..\src\SqlKata.pas',
  QueryBuilder4Delphi.Query.Writes in '..\src\QueryBuilder4Delphi.Query.Writes.pas',
  QueryBuilder4Delphi.Query.DataMapper in '..\src\QueryBuilder4Delphi.Query.DataMapper.pas',
  QueryBuilder4Delphi.Compilers in '..\src\QueryBuilder4Delphi.Compilers.pas',
  QueryBuilder4Delphi.Compilers.Compiler in '..\src\QueryBuilder4Delphi.Compilers.Compiler.pas',
  QueryBuilder4Delphi.Compilers.SqlServerCompiler in '..\src\QueryBuilder4Delphi.Compilers.SqlServerCompiler.pas',
  QueryBuilder4Delphi.Compilers.PostgresCompiler in '..\src\QueryBuilder4Delphi.Compilers.PostgresCompiler.pas',
  QueryBuilder4Delphi.Compilers.MySqlCompiler in '..\src\QueryBuilder4Delphi.Compilers.MySqlCompiler.pas',
  QueryBuilder4Delphi.Compilers.SqliteCompiler in '..\src\QueryBuilder4Delphi.Compilers.SqliteCompiler.pas',
  QueryBuilder4Delphi.Compilers.OracleCompiler in '..\src\QueryBuilder4Delphi.Compilers.OracleCompiler.pas',
  QueryBuilder4Delphi.Compilers.FirebirdCompiler in '..\src\QueryBuilder4Delphi.Compilers.FirebirdCompiler.pas',
  CompilerClasses.Tests in 'CompilerClasses.Tests.pas',
  QueryWrites.Tests in 'QueryWrites.Tests.pas',
  QueryModel.Tests in 'QueryModel.Tests.pas',
  QueryBuilder.Tests in 'QueryBuilder.Tests.pas';
var Runner: ITestRunner; Results: IRunResults;
begin
  ReportMemoryLeaksOnShutdown := True;
  try
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.AddLogger(TDUnitXConsoleLogger.Create(True));
    Runner.AddLogger(TDUnitXXMLNUnitFileLogger.Create(TPath.Combine(ExtractFilePath(ParamStr(0)), 'results.xml')));
    Results := Runner.Execute;
    if not Results.AllPassed then ExitCode := 1;
  except
    on E: Exception do begin Writeln(E.ClassName, ': ', E.Message); ExitCode := 2; end;
  end;
end.
