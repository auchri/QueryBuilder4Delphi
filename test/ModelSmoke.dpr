program ModelSmoke;
{$APPTYPE CONSOLE}
uses System.SysUtils, SqlKata in '..\src\SqlKata.pas';
var Q, CopyQ: TQuery;
begin
  ReportMemoryLeaksOnShutdown := True;
  Q := TQuery.Create('Books');
  try
    Q.Select(['Id', 'Title']).Where('Id', 1).OrWhereNull('Title').Limit(10);
    CopyQ := Q.Clone;
    try
      if CopyQ.Clauses.Count <> Q.Clauses.Count then Halt(1);
      CopyQ.Where('Other', 2);
      if CopyQ.Clauses.Count = Q.Clauses.Count then Halt(2);
    finally FreeAndNil(CopyQ); end;
  finally FreeAndNil(Q); end;
end.
