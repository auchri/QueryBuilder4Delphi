unit QueryBuilder4Delphi.Compilers.SqlServerCompiler;

interface

uses System.SysUtils, System.Rtti, QueryBuilder4Delphi.Query.Core,
  QueryBuilder4Delphi.Compilers.Compiler;

type
  /// <summary>
  /// Microsoft SQL Server SQL syntax compiler. Inherited Create returns a reference-counted ICompiler for
  /// this dialect. Compilation does not select a provider, connect, or execute SQL; server and driver
  /// capabilities still apply.
  /// </summary>
  TSqlServerCompiler = class(TCompiler)
  protected
    constructor CreateInstance; override;
    function CompileLimit(Context: TCompileContext; Query: IQuery)
      : string; override;
    function CompileSelect(Context: TCompileContext; Query: IQuery)
      : string; override;
    function SelectPrefix(Context: TCompileContext; Query: IQuery)
      : string; override;
    function CompileAdHocTable(Context: TCompileContext; Clause: TClause)
      : string; override;
    function DatePart(const Column, Part: string): string; override;
  public
    /// <summary>Produces the dialect Boolean true literal.</summary>
    /// <returns>SQL text representing true.</returns>
    function CompileTrue: string; override;
    /// <summary>Produces the dialect Boolean false literal.</summary>
    /// <returns>SQL text representing false.</returns>
    function CompileFalse: string; override;
    /// <summary>Produces the dialect random-order SQL expression.</summary>
    /// <param name="Seed">Ignored by this compiler.</param>
    /// <returns>NEWID() SQL.</returns>
    function CompileRandom(const Seed: TValue): string; override;
  end;

implementation

uses System.StrUtils;

constructor TSqlServerCompiler.CreateInstance;
begin
  inherited;
  FEngineCode := TSqlDialect.MSSql.EngineCode;
  FOpening := '[';
  FClosing := ']';
  FLastId := 'SELECT scope_identity() as Id';
end;

function TSqlServerCompiler.CompileLimit(Context: TCompileContext;
  Query: IQuery): string;
begin
  if UseLegacyPagination then
    Exit('');
  Result := CompileOffsetFetch(Context, Query, 'ORDER BY (SELECT 0)');
end;

function TSqlServerCompiler.CompileSelect(Context: TCompileContext;
  Query: IQuery): string;
var
  L, I, N: Integer;
  O: Int64;
  Q: IQuery;
  Order: string;
  Values: TValues;
begin
  L := Query.GetLimit(EngineCode);
  O := Query.GetOffset(EngineCode);
  if not UseLegacyPagination or (O = 0) then
    Exit(inherited CompileSelect(Context, Query));
  Q := Query.Clone;
  if not Q.HasComponent('select', EngineCode) then
    Q.Select('*');
  N := Context.Bindings.Count;
  Order := CompileOrders(Context, Q);
  if Order = '' then
    Order := 'ORDER BY (SELECT 0)';
  SetLength(Values, Context.Bindings.Count - N);
  for I := 0 to High(Values) do
    Values[I] := Context.Bindings[N + I];
  while Context.Bindings.Count > N do
    Context.Bindings.Delete(Context.Bindings.Count - 1);
  Q.SelectRaw('ROW_NUMBER() OVER (' + Order + ') AS [row_num]', Values);
  Q.ClearComponent('order').ClearComponent('limit').ClearComponent('offset');
  Result := 'SELECT * FROM (' + CompileSelectCore(Context, Q) +
    ') AS [results_wrapper] WHERE [row_num] ';
  if L = 0 then
    Result := Result + '>= ' + Parameter(Context, O + 1)
  else
    Result := Result + 'BETWEEN ' + Parameter(Context, O + 1) + ' AND ' +
      Parameter(Context, O + L);
end;

function TSqlServerCompiler.SelectPrefix(Context: TCompileContext;
  Query: IQuery): string;
var
  L: Integer;
  O: Int64;
  D: string;
begin
  L := Query.GetLimit(EngineCode);
  O := Query.GetOffset(EngineCode);
  if UseLegacyPagination and (L > 0) and (O = 0) and
    (Query.GetOne('aggregate', EngineCode) = nil) then
  begin
    D := '';
    if Query.IsDistinct then
      D := 'DISTINCT ';
    Exit('SELECT ' + D + 'TOP (' + Parameter(Context, L) + ') ');
  end;
  Result := inherited SelectPrefix(Context, Query);
end;

function TSqlServerCompiler.CompileAdHocTable(Context: TCompileContext;
  Clause: TClause): string;
var
  I, J: Integer;
begin
  Result := 'SELECT ' + WrapList(Clause.Columns) + ' FROM (VALUES ';
  for I := 0 to Length(Clause.Values) div Length(Clause.Columns) - 1 do
  begin
    if I > 0 then
      Result := Result + ', ';
    Result := Result + '(';
    for J := 0 to High(Clause.Columns) do
    begin
      if J > 0 then
        Result := Result + ', ';
      Result := Result + Parameter(Context,
        Clause.Values[I * Length(Clause.Columns) + J]);
    end;
    Result := Result + ')';
  end;
  Result := Result + ') AS tbl (' + WrapList(Clause.Columns) + ')';
end;

function TSqlServerCompiler.CompileTrue: string;
begin
  Result := 'cast(1 as bit)';
end;

function TSqlServerCompiler.CompileFalse: string;
begin
  Result := 'cast(0 as bit)';
end;

function TSqlServerCompiler.CompileRandom(const Seed: TValue): string;
begin
  Result := 'NEWID()';
end;

function TSqlServerCompiler.DatePart(const Column, Part: string): string;
begin
  if MatchStr(Part, ['date', 'time']) then
    Result := 'CAST(' + Column + ' AS ' + UpperCase(Part) + ')'
  else
    Result := 'DATEPART(' + UpperCase(Part) + ', ' + Column + ')';
end;

end.
