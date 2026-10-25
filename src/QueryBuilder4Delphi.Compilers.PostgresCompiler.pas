unit QueryBuilder4Delphi.Compilers.PostgresCompiler;

interface

uses System.SysUtils, System.Rtti, QueryBuilder4Delphi.Query.Core,
  QueryBuilder4Delphi.Compilers.Compiler;

type
  /// <summary>
  /// PostgreSQL SQL syntax compiler. Inherited Create returns a reference-counted ICompiler for this dialect.
  /// Compilation does not select a provider, connect, or execute SQL; server and driver capabilities still
  /// apply.
  /// </summary>
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
  FEngineCode := TSqlDialect.PostgreSql.EngineCode;
  SupportsFilterClause := True;
  FLastId := 'SELECT lastval() AS id';
  FSupportsJoinWrites := False;
end;

function TPostgresCompiler.DatePart(const Column, Part: string): string;
begin
  if MatchStr(Part, ['date', 'time']) then
    Result := Column + '::' + Part
  else
    Result := 'DATE_PART(' + QuotedStr(UpperCase(Part)) + ', ' + Column + ')';
end;

end.
