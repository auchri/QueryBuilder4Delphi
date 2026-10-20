unit QueryBuilder4Delphi.Compilers.OracleCompiler;

interface

uses System.SysUtils, System.Rtti, SqlKata, QueryBuilder4Delphi.Compilers.Compiler;

type
  TOracleCompiler = class(TCompiler)
  protected
    constructor CreateInstance; override;
    function CompileLimit(Context: TCompileContext; Query: IQuery): string; override;
    function CompileSelect(Context: TCompileContext; Query: IQuery): string; override;
    function CompileInsertRows(Context: TCompileContext; const TableSql, Columns: string; const Inserts: TArray<TClause>): string; override;
    function DateCondition(Context: TCompileContext; Clause: TClause): string; override;
  public
    function CompileRandom(const Seed: TValue): string; override;
  end;

implementation

uses System.StrUtils, System.TypInfo;

constructor TOracleCompiler.CreateInstance;
begin
  inherited;
  FEngineCode := TEngineCodes.Oracle;
  FParameterPrefix := ':p';
  FColumnAs := '';
  FTableAs := '';
  FDummyTable := 'DUAL';
  FSupportsJoinWrites := False;
end;

function TOracleCompiler.CompileLimit(Context: TCompileContext; Query: IQuery): string;
begin
  if UseLegacyPagination then Exit('');
  Result := CompileOffsetFetch(Context,Query,'ORDER BY (SELECT 0 FROM DUAL)');
end;

function TOracleCompiler.CompileSelect(Context: TCompileContext; Query: IQuery): string;
var L: Integer; O: Int64;
begin
  Result := inherited CompileSelect(Context,Query);
  if not UseLegacyPagination then Exit;
  L := Query.GetLimit(EngineCode);
  O := Query.GetOffset(EngineCode);
  if (L = 0) and (O = 0) then Exit;
  if L = 0 then Result := 'SELECT * FROM (SELECT "results_wrapper".*, ROWNUM "row_num" FROM ('+Result+') "results_wrapper") WHERE "row_num" > '+Parameter(Context,O)
  else if O = 0 then Result := 'SELECT * FROM ('+Result+') WHERE ROWNUM <= '+Parameter(Context,L)
  else Result := 'SELECT * FROM (SELECT "results_wrapper".*, ROWNUM "row_num" FROM ('+Result+') "results_wrapper" WHERE ROWNUM <= '+Parameter(Context,O+L)+') WHERE "row_num" > '+Parameter(Context,O);
end;

function TOracleCompiler.CompileRandom(const Seed: TValue): string;
begin
  Result := 'DBMS_RANDOM.VALUE';
end;

function TOracleCompiler.CompileInsertRows(Context: TCompileContext; const TableSql, Columns: string; const Inserts: TArray<TClause>): string;
var C: TClause;
begin
  if Length(Inserts) = 1 then Exit(inherited CompileInsertRows(Context,TableSql,Columns,Inserts));
  Result := 'INSERT ALL';
  for C in Inserts do
    Result := Result+' INTO '+TableSql+Columns+' VALUES ('+Parameterize(Context,C.Values)+')';
  Result := Result+' SELECT 1 FROM DUAL';
end;

function TOracleCompiler.DateCondition(Context: TCompileContext; Clause: TClause): string;
var Col, Part, Op, V, Fmt, ValueFmt: string;
begin
  Col := Wrap(Clause.Name);
  Part := CheckDatePart(Clause.Extra);
  Op := CheckOperator(Clause.Op);
  V := Parameter(Context,Clause.Value);
  if MatchStr(Part,['date','time']) then
  begin
    if Part = 'date' then Fmt := 'YY-MM-DD' else Fmt := 'HH24:MI:SS';
    ValueFmt := V;
    if Clause.Value.TypeInfo <> TypeInfo(TDateTime) then
    begin
      if (Part = 'time') and (Length(Clause.Value.ToString.Split([':'])) = 2) then ValueFmt := 'HH24:MI' else ValueFmt := Fmt;
      ValueFmt := 'TO_DATE('+V+', '+QuotedStr(ValueFmt)+')';
    end;
    Exit('TO_CHAR('+Col+', '+QuotedStr(Fmt)+') '+Op+' TO_CHAR('+ValueFmt+', '+QuotedStr(Fmt)+')');
  end;
  if MatchStr(Part,['year','month','day','hour','minute','second']) then
    Col := 'EXTRACT('+UpperCase(Part)+' FROM '+Col+')';
  Result := Col+' '+Op+' '+V;
end;

end.
