unit QueryBuilder4Delphi.Compilers.SqliteCompiler;

interface

uses System.SysUtils, System.Rtti, QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Compilers.Compiler;

type
  TSqliteCompiler = class(TCompiler)
  protected
    constructor CreateInstance; override;
    function CompileLimit(Context: TCompileContext; Query: IQuery): string; override;
    function DateCondition(Context: TCompileContext; Clause: TClause): string; override;
  public
    function CompileTrue: string; override;
    function CompileFalse: string; override;
  end;

implementation

uses System.StrUtils;

constructor TSqliteCompiler.CreateInstance;
begin
  inherited;
  FEngineCode := TEngineCodes.Sqlite;
  SupportsFilterClause := True;
  FLastId := 'select last_insert_rowid() as id';
  FSupportsJoinWrites := False;
end;

function TSqliteCompiler.CompileTrue: string;
begin
  Result := '1';
end;

function TSqliteCompiler.CompileFalse: string;
begin
  Result := '0';
end;

function TSqliteCompiler.CompileLimit(Context: TCompileContext; Query: IQuery): string;
begin
  if (Query.GetLimit(EngineCode) = 0) and (Query.GetOffset(EngineCode) > 0) then
    Exit('LIMIT -1 OFFSET '+Parameter(Context,Query.GetOffset(EngineCode)));
  Result := inherited CompileLimit(Context,Query);
end;

function TSqliteCompiler.DateCondition(Context: TCompileContext; Clause: TClause): string;
var Col, Part, Op, V, Fmt: string;
begin
  Col := Wrap(Clause.Name);
  Part := CheckDatePart(Clause.Extra);
  Op := CheckOperator(Clause.Op);
  V := Parameter(Context,Clause.Value);
  Fmt := '';
  if Part = 'date' then Fmt := '%Y-%m-%d' else if Part = 'time' then Fmt := '%H:%M:%S'
  else if Part = 'year' then Fmt := '%Y' else if Part = 'month' then Fmt := '%m'
  else if Part = 'day' then Fmt := '%d' else if Part = 'hour' then Fmt := '%H' else if Part = 'minute' then Fmt := '%M';
  if Fmt <> '' then Exit('strftime('+QuotedStr(Fmt)+', '+Col+') '+Op+' cast('+V+' as text)');
  Result := Col+' '+Op+' '+V;
end;

end.
