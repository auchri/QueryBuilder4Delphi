program QueryBuilderTests;
{$APPTYPE CONSOLE}
uses
  System.SysUtils, System.IOUtils,
  DUnitX.TestFramework, DUnitX.Loggers.Console, DUnitX.Loggers.XML.NUnit,
  SqlKata in '..\src\SqlKata.pas',
  SqlKata.Compilers in '..\src\SqlKata.Compilers.pas',
  SqlKata.Compilers.Compiler in '..\src\SqlKata.Compilers.Compiler.pas',
  SqlKata.Compilers.SqlServerCompiler in '..\src\SqlKata.Compilers.SqlServerCompiler.pas',
  SqlKata.Compilers.PostgresCompiler in '..\src\SqlKata.Compilers.PostgresCompiler.pas',
  SqlKata.Compilers.MySqlCompiler in '..\src\SqlKata.Compilers.MySqlCompiler.pas',
  SqlKata.Compilers.SqliteCompiler in '..\src\SqlKata.Compilers.SqliteCompiler.pas',
  SqlKata.Compilers.OracleCompiler in '..\src\SqlKata.Compilers.OracleCompiler.pas',
  SqlKata.Compilers.FirebirdCompiler in '..\src\SqlKata.Compilers.FirebirdCompiler.pas',
  CompilerClasses.Tests in 'CompilerClasses.Tests.pas',
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
