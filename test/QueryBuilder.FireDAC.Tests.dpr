program QueryBuilderFireDACTests;
{$APPTYPE CONSOLE}
uses
  System.SysUtils, System.IOUtils,
  DUnitX.TestFramework, DUnitX.Loggers.Console, DUnitX.Loggers.XML.NUnit,
  QueryBuilder4Delphi.FireDAC in '..\src\QueryBuilder4Delphi.FireDAC.pas',
  QueryBuilder4Delphi.Compilers.Factory in '..\src\QueryBuilder4Delphi.Compilers.Factory.pas',
  FireDAC.Tests in 'FireDAC.Tests.pas';
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
