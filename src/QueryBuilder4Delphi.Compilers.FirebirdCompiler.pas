unit QueryBuilder4Delphi.Compilers.FirebirdCompiler;

interface

uses System.SysUtils, System.Rtti, SqlKata, QueryBuilder4Delphi.Compilers.Compiler;

type
  TFirebirdCompiler = class(TCompiler)
  protected
    constructor CreateInstance; override;
    function SelectPrefix(Context: TCompileContext; Query: IQuery): string; override;
    function CompileLimit(Context: TCompileContext; Query: IQuery): string; override;
    function CompileInsertRows(Context: TCompileContext; const TableSql, Columns: string; const Inserts: TArray<TClause>): string; override;
    function DatePart(const Column, Part: string): string; override;
  public
    function CompileTrue: string; override;
    function CompileFalse: string; override;
    function CompileRandom(const Seed: TValue): string; override;
    function WrapValue(const Value: string): string; override;
  end;

implementation

uses System.StrUtils;

constructor TFirebirdCompiler.CreateInstance;
begin
  inherited;
  FEngineCode := TEngineCodes.Firebird;
  FDummyTable := 'RDB$DATABASE';
  FSupportsJoinWrites := False;
end;

function TFirebirdCompiler.CompileTrue: string;
begin
  Result := '1';
end;

function TFirebirdCompiler.CompileFalse: string;
begin
  Result := '0';
end;

function TFirebirdCompiler.CompileRandom(const Seed: TValue): string;
begin
  Result := 'RAND()';
end;

function TFirebirdCompiler.WrapValue(const Value: string): string;
begin
  Result := UpperCase(inherited WrapValue(Value));
end;

function TFirebirdCompiler.SelectPrefix(Context: TCompileContext; Query: IQuery): string;
var L: Integer; O: Int64; D: string;
begin
  if Query.GetOne('aggregate',EngineCode) <> nil then Exit('SELECT ');
  L := Query.GetLimit(EngineCode);
  O := Query.GetOffset(EngineCode);
  D := '';
  if Query.IsDistinct then D := 'DISTINCT ';
  if (L > 0) and (O = 0) then Exit('SELECT FIRST '+Parameter(Context,L)+' '+D);
  if (L = 0) and (O > 0) then Exit('SELECT SKIP '+Parameter(Context,O)+' '+D);
  Result := inherited SelectPrefix(Context,Query);
end;

function TFirebirdCompiler.CompileLimit(Context: TCompileContext; Query: IQuery): string;
var L: Integer; O: Int64;
begin
  L := Query.GetLimit(EngineCode);
  O := Query.GetOffset(EngineCode);
  Result := '';
  if (L > 0) and (O > 0) then
    Result := 'ROWS '+Parameter(Context,O+1)+' TO '+Parameter(Context,O+L);
end;

function TFirebirdCompiler.CompileInsertRows(Context: TCompileContext; const TableSql, Columns: string; const Inserts: TArray<TClause>): string;
var I: Integer;
begin
  if Length(Inserts) = 1 then Exit(inherited CompileInsertRows(Context,TableSql,Columns,Inserts));
  Result := 'INSERT INTO '+TableSql+Columns+' ';
  for I := 0 to High(Inserts) do
  begin
    if I > 0 then Result := Result+' UNION ALL ';
    Result := Result+'SELECT '+Parameterize(Context,Inserts[I].Values)+' FROM RDB$DATABASE';
  end;
end;

function TFirebirdCompiler.DatePart(const Column, Part: string): string;
begin
  if MatchStr(Part,['date','time']) then Result := 'CAST('+Column+' as '+UpperCase(Part)+')'
  else Result := 'EXTRACT('+UpperCase(Part)+' FROM '+Column+')';
end;

end.
