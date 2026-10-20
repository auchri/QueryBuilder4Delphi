unit SqlKata.Compilers.PostgresCompiler;

interface

uses System.SysUtils, System.Rtti, SqlKata, SqlKata.Compilers.Compiler;

type
  TPostgresCompiler = class(TCompiler)
  protected
    constructor CreateInstance; override;
    function DatePart(const Column, Part: string): string; override;
  end;

implementation

uses System.StrUtils;

constructor TPostgresCompiler.CreateInstance;
begin
  inherited;
  FEngineCode := TEngineCodes.PostgreSql;
  SupportsFilterClause := True;
  FLastId := 'SELECT lastval() AS id';
  FSupportsJoinWrites := False;
end;

function TPostgresCompiler.DatePart(const Column, Part: string): string;
begin
  if MatchStr(Part,['date','time']) then Result := Column+'::'+Part
  else Result := 'DATE_PART('+QuotedStr(UpperCase(Part))+', '+Column+')';
end;

end.
