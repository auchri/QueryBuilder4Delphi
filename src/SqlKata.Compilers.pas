unit SqlKata.Compilers;

interface

uses System.SysUtils, System.Rtti, System.Generics.Collections, SqlKata;

type
  TEngineCodes = record
  const
    Generic = 'generic'; SqlServer = 'sqlsrv'; MySql = 'mysql';
    PostgreSql = 'postgres'; Sqlite = 'sqlite'; Oracle = 'oracle'; Firebird = 'firebird';
  end;

  TSqlResult = class
  public
    RawSql, Sql: string;
    Bindings: TList<TValue>;
    NamedBindings: TDictionary<string,TValue>;
    Query: TQuery; // borrowed; never freed by the result
    constructor Create;
    destructor Destroy; override;
    function ToString: string; override;
  end;

  TCompileContext = class
  public
    Bindings: TList<TValue>;
    Queries: TList<TQuery>;
    constructor Create;
    destructor Destroy; override;
    function FindVariable(const Name: string): TValue;
  end;

  TCompiler = class
  protected
    FEngineCode, FOpening, FClosing, FParameterPrefix, FLastId, FDummyTable: string;
    FColumnAs, FTableAs: string;
    FUserOperators: TList<string>;
    function CheckOperator(const Op: string): string;
    function Parameter(Context: TCompileContext; const Value: TValue): string; virtual;
    function Parameterize(Context: TCompileContext; const Values: array of TValue): string;
    function Raw(Context: TCompileContext; const Sql: string; const Values: array of TValue): string;
    function Resolve(Context: TCompileContext; const Value: TValue): TValue;
    function Column(Context: TCompileContext; Clause: TClause): string; virtual;
    function Table(Context: TCompileContext; Clause: TClause): string; virtual;
    function Conditions(Context: TCompileContext; Query: TQuery; const Component: string): string;
    function Condition(Context: TCompileContext; Clause: TClause): string; virtual;
    function DateCondition(Context: TCompileContext; Clause: TClause): string; virtual;
    function CompileQuery(Context: TCompileContext; Query: TQuery; WithCtes: Boolean = True): string;
    function CompileSelect(Context: TCompileContext; Query: TQuery): string; virtual;
    function CompileSelectCore(Context: TCompileContext; Query: TQuery): string;
    function CompileWrite(Context: TCompileContext; Query: TQuery): string; virtual;
    function CompileCtes(Context: TCompileContext; Query: TQuery): string;
    function CompileJoins(Context: TCompileContext; Query: TQuery): string;
    function CompileOrders(Context: TCompileContext; Query: TQuery): string;
    function SelectPrefix(Context: TCompileContext; Query: TQuery): string; virtual;
    function CompileLimit(Context: TCompileContext; Query: TQuery): string; virtual;
    function AggregateQuery(Query: TQuery): TQuery;
    function WrapList(const Values: array of string): string;
    function JoinTarget(Clause: TClause): string;
  public
    SupportsFilterClause, OmitSelectInsideExists, UseLegacyPagination: Boolean;
    constructor Create; virtual;
    destructor Destroy; override;
    function Compile(Query: TQuery): TSqlResult; overload; virtual;
    function Compile(const Queries: array of TQuery): TSqlResult; overload; virtual;
    function Wrap(const Value: string): string; virtual;
    function WrapValue(const Value: string): string; virtual;
    function WrapIdentifiers(const Value: string): string; virtual;
    procedure SplitAlias(const Value: string; out Expression, Alias: string);
    function Whitelist(const Operators: array of string): TCompiler;
    function CompileTrue: string; virtual;
    function CompileFalse: string; virtual;
    function CompileRandom(const Seed: TValue): string; virtual;
    function CompileLower(const Value: string): string;
    function CompileUpper(const Value: string): string;
    property EngineCode: string read FEngineCode;
  end;

  TSqlServerCompiler = class(TCompiler)
  public constructor Create; override; end;
  TPostgresCompiler = class(TCompiler)
  public constructor Create; override; end;
  TMySqlCompiler = class(TCompiler)
  public constructor Create; override; end;
  TSqliteCompiler = class(TCompiler)
  public constructor Create; override; end;
  TOracleCompiler = class(TCompiler)
  public constructor Create; override; end;
  TFirebirdCompiler = class(TCompiler)
  public constructor Create; override; end;

implementation

uses System.StrUtils, System.TypInfo, System.Variants, System.RegularExpressions;

function SqlValue(const Value: TValue): string;
var V: Variant; D: TDateTime;
begin
  if Value.IsEmpty then Exit('NULL');
  if Value.TypeInfo = TypeInfo(TDateTime) then
  begin
    D := Value.AsType<TDateTime>;
    if Frac(D) = 0 then Exit(QuotedStr(FormatDateTime('yyyy-mm-dd', D)))
    else Exit(QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss', D)));
  end;
  if Value.TypeInfo = TypeInfo(Boolean) then
    if Value.AsBoolean then Exit('true') else Exit('false');
  case Value.Kind of
    tkInteger, tkInt64: Exit(Value.ToString);
    tkFloat: Exit(FloatToStr(Value.AsExtended, TFormatSettings.Invariant));
    tkVariant:
      begin
        V := Value.AsVariant;
        if VarIsNull(V) or VarIsEmpty(V) then Exit('NULL');
        if VarIsNumeric(V) then Exit(FloatToStr(V, TFormatSettings.Invariant));
      end;
  end;
  Result := QuotedStr(Value.ToString);
end;

// Preserve escaped question marks exactly as in the C# Helper.ReplaceAll.
function ReplaceParameters(const Sql: string; const Bindings: TList<TValue>;
  const Prefix: string; InlineValues: Boolean): string;
var I, N: Integer;
begin
  Result := ''; I := 1; N := 0;
  while I <= Length(Sql) do
  begin
    if (Sql[I] = '?') and ((I = 1) or (Sql[I-1] <> '\')) then
    begin
      if N >= Bindings.Count then raise EQueryException.Create('Not enough bindings');
      if InlineValues then Result := Result + SqlValue(Bindings[N])
      else Result := Result + Prefix + IntToStr(N);
      Inc(N);
    end
    else Result := Result + Sql[I];
    Inc(I);
  end;
  if N <> Bindings.Count then raise EQueryException.Create('Binding/placeholder count mismatch');
  if InlineValues then Result := StringReplace(Result, '\?', '?', [rfReplaceAll]);
end;

constructor TSqlResult.Create;
begin inherited; Bindings := TList<TValue>.Create; NamedBindings := TDictionary<string,TValue>.Create; end;
destructor TSqlResult.Destroy;
begin NamedBindings.Free; Bindings.Free; inherited; end;
function TSqlResult.ToString: string;
begin Result := ReplaceParameters(RawSql, Bindings, '', True); end;
constructor TCompileContext.Create;
begin inherited; Bindings := TList<TValue>.Create; Queries := TList<TQuery>.Create; end;
destructor TCompileContext.Destroy;
begin Queries.Free; Bindings.Free; inherited; end;
function TCompileContext.FindVariable(const Name: string): TValue;
var I: Integer;
begin
  for I := Queries.Count-1 downto 0 do
    if Queries[I].Variables.TryGetValue(Name, Result) then Exit;
  raise EQueryException.CreateFmt('Variable ''%s'' not found', [Name]);
end;

constructor TCompiler.Create;
begin
  inherited; FUserOperators := TList<string>.Create;
  FEngineCode := 'generic'; FOpening := '"'; FClosing := '"';
  FParameterPrefix := '@p'; FColumnAs := 'AS '; FTableAs := 'AS ';
  OmitSelectInsideExists := True;
end;
destructor TCompiler.Destroy;
begin FUserOperators.Free; inherited; end;

function TCompiler.Whitelist(const Operators: array of string): TCompiler;
var Op: string;
begin for Op in Operators do FUserOperators.Add(LowerCase(Op)); Result := Self; end;
function TCompiler.CheckOperator(const Op: string): string;
begin
  Result := LowerCase(Op);
  if not MatchStr(Result, ['=','<','>','<=','>=','<>','!=','<=>','like','not like',
    'ilike','not ilike','like binary','not like binary','rlike','not rlike',
    'regexp','not regexp','similar to','not similar to']) and not FUserOperators.Contains(Result) then
    raise EQueryException.CreateFmt('Operator ''%s'' is not whitelisted', [Op]);
end;

procedure TCompiler.SplitAlias(const Value: string; out Expression, Alias: string);
var P: Integer;
begin
  P := LowerCase(Value).LastIndexOf(' as ') + 1;
  if P = 0 then begin Expression := Value; Alias := ''; end
  else begin Expression := Copy(Value, 1, P-1); Alias := Copy(Value, P+4, MaxInt); end;
end;
function TCompiler.WrapValue(const Value: string): string;
begin
  if Value = '*' then Exit('*');
  Result := FOpening + StringReplace(Value, FClosing, FClosing+FClosing, [rfReplaceAll]) + FClosing;
  if FEngineCode = 'firebird' then Result := UpperCase(Result);
end;
function TCompiler.Wrap(const Value: string): string;
var Expr, Alias, Part: string;
begin
  SplitAlias(Value, Expr, Alias);
  Result := '';
  for Part in Expr.Split(['.']) do begin if Result <> '' then Result := Result + '.'; Result := Result + WrapValue(Part); end;
  if Alias <> '' then Result := Result + ' '+FColumnAs+WrapValue(Alias);
end;
function TCompiler.WrapList(const Values: array of string): string;
var S: string;
begin Result := ''; for S in Values do begin if Result <> '' then Result := Result + ', '; Result := Result + Wrap(S); end; end;
function TCompiler.WrapIdentifiers(const Value: string): string;
var I: Integer; C: Char;
begin
  Result := ''; I := 1;
  while I <= Length(Value) do
  begin
    C := Value[I];
    if (C = '\') and (I < Length(Value)) and CharInSet(Value[I+1], ['{','}','[',']']) then
    begin Inc(I); Result := Result + Value[I]; end
    else case C of
      '{', '[': Result := Result + FOpening;
      '}', ']': Result := Result + FClosing;
    else Result := Result + C; end;
    Inc(I);
  end;
end;
function TCompiler.Resolve(Context: TCompileContext; const Value: TValue): TValue;
begin
  Result := Value;
  if Value.IsType<TVariable> then Result := Context.FindVariable(Value.AsType<TVariable>.Name)
  else if Value.IsType<TUnsafeLiteral> then Result := Value.AsType<TUnsafeLiteral>.Value;
end;
function TCompiler.Parameter(Context: TCompileContext; const Value: TValue): string;
begin
  if Value.IsType<TUnsafeLiteral> then Exit(Value.AsType<TUnsafeLiteral>.Value);
  Context.Bindings.Add(Resolve(Context, Value)); Result := '?';
end;
function TCompiler.Parameterize(Context: TCompileContext; const Values: array of TValue): string;
var V: TValue;
begin Result := ''; for V in Values do begin if Result <> '' then Result := Result + ', '; Result := Result + Parameter(Context, V); end; end;
function TCompiler.Raw(Context: TCompileContext; const Sql: string; const Values: array of TValue): string;
var I, N, J: Integer; V: TValue; S: string;
begin
  Result := ''; N := 0;
  S := WrapIdentifiers(Sql);
  for I := 1 to Length(S) do
  begin
    if (S[I] = '?') and ((I = 1) or (S[I-1] <> '\')) then
    begin
      if N >= Length(Values) then raise EQueryException.Create('Not enough raw bindings');
      V := Values[N]; Inc(N);
      if (V.Kind in [tkArray,tkDynArray]) and (V.TypeInfo <> TypeInfo(TBytes)) then
      begin
        for J := 0 to V.GetArrayLength-1 do
        begin if J > 0 then Result := Result + ','; Result := Result + Parameter(Context, V.GetArrayElement(J)); end;
      end
      else Result := Result + Parameter(Context, V);
    end
    else Result := Result + S[I];
  end;
  if N <> Length(Values) then raise EQueryException.Create('Too many raw bindings');
end;

function TCompiler.Compile(Query: TQuery): TSqlResult;
begin Result := Compile([Query]); Result.Query := Query; end;
function TCompiler.Compile(const Queries: array of TQuery): TSqlResult;
var Context: TCompileContext; Q: TQuery; N: Integer;
begin
  Context := TCompileContext.Create;
  Result := TSqlResult.Create;
  try
    try
      for Q in Queries do
      begin
        if Q = nil then raise EArgumentNilException.Create('Query');
        if Result.RawSql <> '' then Result.RawSql := Result.RawSql + ';'+#10;
        Result.RawSql := Result.RawSql + CompileQuery(Context, Q);
      end;
      Result.Bindings.AddRange(Context.Bindings);
      Result.Sql := ReplaceParameters(Result.RawSql, Result.Bindings, FParameterPrefix, False);
      for N := 0 to Result.Bindings.Count-1 do Result.NamedBindings.Add(FParameterPrefix+IntToStr(N), Result.Bindings[N]);
    except Result.Free; raise; end;
  finally Context.Free; end;
end;

function TCompiler.CompileQuery(Context: TCompileContext; Query: TQuery; WithCtes: Boolean): string;
var Q: TQuery;
begin
  Q := Query;
  if WithCtes and (Query.Method = 'aggregate') then Q := AggregateQuery(Query);
  Context.Queries.Add(Query);
  try
    Result := '';
    if WithCtes then Result := CompileCtes(Context, Q);
    if MatchStr(Q.Method, ['insert','update','delete']) then Result := Result + CompileWrite(Context,Q)
    else Result := Result + CompileSelect(Context,Q);
  finally
    Context.Queries.Delete(Context.Queries.Count-1);
    if Q <> Query then Q.Free;
  end;
end;

function TCompiler.Column(Context: TCompileContext; Clause: TClause): string;
var Expr, Alias, Filter: string;
begin
  case Clause.Kind of
    ckRaw: Result := Raw(Context, Clause.Name, Clause.Values);
    ckQuery:
      begin
        Result := '('+CompileQuery(Context, Clause.Query, False)+')';
        if Clause.Query.QueryAlias <> '' then Result := Result+' '+FColumnAs+WrapValue(Clause.Query.QueryAlias);
      end;
    ckAggregate:
      begin
        SplitAlias(Clause.Name, Expr, Alias); Expr := Wrap(Expr);
        Filter := '';
        if Clause.Query <> nil then Filter := Conditions(Context, Clause.Query, 'where');
        if Filter = '' then Result := UpperCase(Clause.Op)+'('+Expr+')'
        else if SupportsFilterClause then Result := UpperCase(Clause.Op)+'('+Expr+') FILTER (WHERE '+Filter+')'
        else Result := UpperCase(Clause.Op)+'(CASE WHEN '+Filter+' THEN '+Expr+' END)';
        if Alias <> '' then Result := Result+' '+FColumnAs+WrapValue(Alias);
      end;
  else Result := Wrap(Clause.Name); end;
end;
function TCompiler.Table(Context: TCompileContext; Clause: TClause): string;
var I, J: Integer; Row: string;
begin
  if Clause = nil then raise EQueryException.Create('No table set');
  case Clause.Kind of
    ckIdentifier: Result := Wrap(Clause.Name);
    ckRaw: Result := Raw(Context, Clause.Name, Clause.Values);
    ckQuery:
      begin
        Result := '('+CompileQuery(Context, Clause.Query, False)+')';
        if Clause.Query.QueryAlias <> '' then Result := Result+' '+FTableAs+WrapValue(Clause.Query.QueryAlias);
      end;
    ckAdHoc:
      begin
        if EngineCode = 'sqlsrv' then
        begin
          Result := 'SELECT '+WrapList(Clause.Columns)+' FROM (VALUES ';
          for I := 0 to Length(Clause.Values) div Length(Clause.Columns)-1 do
          begin
            if I > 0 then Result := Result+', ';
            Result := Result+'(';
            for J := 0 to High(Clause.Columns) do
            begin
              if J > 0 then Result := Result+', ';
              Result := Result+Parameter(Context,Clause.Values[I*Length(Clause.Columns)+J]);
            end;
            Result := Result+')';
          end;
          Exit(Result+') AS tbl ('+WrapList(Clause.Columns)+')');
        end;
        Result := '';
        for I := 0 to Length(Clause.Values) div Length(Clause.Columns)-1 do
        begin
          Row := 'SELECT ';
          for J := 0 to High(Clause.Columns) do
          begin
            if J > 0 then Row := Row+', ';
            Row := Row+Parameter(Context,Clause.Values[I*Length(Clause.Columns)+J])+' AS '+Wrap(Clause.Columns[J]);
          end;
          if FDummyTable <> '' then Row := Row+' FROM '+FDummyTable;
          if Result <> '' then Result := Result+' UNION ALL ';
          Result := Result+Row;
        end;
      end;
  else raise EQueryException.Create('Invalid table expression'); end;
end;

function TCompiler.Conditions(Context: TCompileContext; Query: TQuery; const Component: string): string;
var C: TClause; S: string;
begin
  Result := '';
  for C in Query.GetComponents(Component,EngineCode) do
  begin
    S := Condition(Context,C);
    if S = '' then Continue;
    if Result <> '' then if C.IsOr then Result := Result+' OR ' else Result := Result+' AND ';
    Result := Result+S;
  end;
end;
function TCompiler.Condition(Context: TCompileContext; Clause: TClause): string;
var C: TClause; V: TValue; S, Op: string; Neg: Boolean; Q: TQuery;
begin
  C := Clause; Neg := C.IsNot;
  case C.Kind of
    ckRaw: Exit(Raw(Context,C.Name,C.Values));
    ckNested:
      begin
        S := Conditions(Context,C.Query,'where');
        if S = '' then S := Conditions(Context,C.Query,'having');
        if S = '' then Exit('');
        Result := '('+S+')'; if Neg then Result := 'NOT '+Result; Exit;
      end;
    ckNull: begin Result := Wrap(C.Name)+' IS '; if Neg then Result := Result+'NOT '; Result := Result+'NULL'; Exit; end;
    ckBoolean:
      begin
        if C.Value.AsBoolean then S := CompileTrue else S := CompileFalse;
        if Neg then Op := ' != ' else Op := ' = '; Result := Wrap(C.Name)+Op+S; Exit;
      end;
    ckBasic:
      begin
        V := C.Value;
        if V.IsEmpty or ((V.Kind = tkVariant) and VarIsNull(V.AsVariant)) then
        begin
          Result := Wrap(C.Name)+' IS '; if Neg or (C.Op <> '=') then Result := Result+'NOT '; Exit(Result+'NULL');
        end;
        if V.TypeInfo = TypeInfo(Boolean) then
        begin
          if V.AsBoolean then S := CompileTrue else S := CompileFalse;
          if Neg or (C.Op <> '=') then Op := ' != ' else Op := ' = ';
          Exit(Wrap(C.Name)+Op+S);
        end;
        Result := Wrap(C.Name)+' '+CheckOperator(C.Op)+' '+Parameter(Context,V);
      end;
    ckColumns:
      begin Result := Wrap(C.Name)+' '+CheckOperator(C.Op)+' '+Wrap(C.Extra); if Neg then Result := 'NOT '+Result; Exit; end;
    ckString:
      begin
        V := Resolve(Context,C.Value);
        if not (V.Kind in [tkString,tkLString,tkWString,tkUString]) then raise EQueryException.Create('Expecting a non-null string');
        S := V.AsString; Op := 'like';
        if C.Op = 'starts' then S := S+'%' else if C.Op = 'ends' then S := '%'+S else if C.Op = 'contains' then S := '%'+S+'%';
        if C.Value.IsType<TUnsafeLiteral> then Result := Wrap(C.Name)+' '+Op+' '+S
        else Result := Wrap(C.Name)+' '+Op+' '+Parameter(Context,S);
        if C.Extra <> '' then Result := Result+' ESCAPE '+QuotedStr(C.Extra);
      end;
    ckDate: Result := DateCondition(Context,C);
    ckBetween:
      begin
        Result := Wrap(C.Name)+' '; if Neg then Result := Result+'NOT ';
        Result := Result+'BETWEEN '+Parameter(Context,C.Value)+' AND '+Parameter(Context,C.Value2); Exit;
      end;
    ckIn, ckInQuery:
      begin
        if (C.Kind = ckIn) and (Length(C.Values) = 0) then
          if Neg then Exit('1 = 1 /* NOT IN [empty list] */') else Exit('1 = 0 /* IN [empty list] */');
        Result := Wrap(C.Name)+' '; if Neg then Result := Result+'NOT ';
        Result := Result+'IN (';
        if C.Kind = ckIn then Result := Result+Parameterize(Context,C.Values)
        else Result := Result+CompileQuery(Context,C.Query,False);
        Exit(Result+')');
      end;
    ckExists:
      begin
        Q := C.Query.Clone;
        try
          if OmitSelectInsideExists then Q.ClearComponent('select').SelectRaw('1');
          Result := 'EXISTS ('+CompileQuery(Context,Q,False)+')';
          if Neg then Result := 'NOT '+Result;
        finally Q.Free; end;
        Exit;
      end;
    ckQuery: Result := Wrap(C.Name)+' '+CheckOperator(C.Op)+' ('+CompileQuery(Context,C.Query,False)+')';
    ckSubQuery: Result := '('+CompileQuery(Context,C.Query,False)+') '+CheckOperator(C.Op)+' '+Parameter(Context,C.Value);
  else raise EQueryException.Create('Unsupported condition'); end;
  if Neg then Result := 'NOT ('+Result+')';
end;

function TCompiler.CompileCtes(Context: TCompileContext; Query: TQuery): string;
var Seen: TList<string>;
  procedure Visit(Q: TQuery);
  var C: TClause; S: string;
  begin
    for C in Q.GetComponents('cte',EngineCode) do
    begin
      if Seen.Contains(C.Alias) then Continue;
      Seen.Add(C.Alias);
      if C.Query <> nil then Visit(C.Query);
      if Result <> '' then Result := Result+','+#10;
      if C.Kind = ckQuery then S := CompileQuery(Context,C.Query,False)
      else if C.Kind = ckRaw then S := Raw(Context,C.Name,C.Values)
      else S := Table(Context,C);
      Result := Result+WrapValue(C.Alias)+' AS ('+S+')';
    end;
  end;
begin
  Result := ''; Seen := TList<string>.Create;
  try Visit(Query); finally Seen.Free; end;
  if Result <> '' then Result := 'WITH '+Result+#10;
end;
function TCompiler.CompileJoins(Context: TCompileContext; Query: TQuery): string;
var C: TClause; S: string;
begin
  Result := '';
  for C in Query.GetComponents('join',EngineCode) do
  begin
    Result := Result+' '+#10+C.Query.JoinType+' '+Table(Context,C.Query.GetOne('from',EngineCode));
    S := Conditions(Context,C.Query,'where'); if S <> '' then Result := Result+' ON '+S;
  end;
end;
function TCompiler.CompileOrders(Context: TCompileContext; Query: TQuery): string;
var C: TClause; S: string;
begin
  Result := '';
  for C in Query.GetComponents('order',EngineCode) do
  begin
    if C.Kind = ckRandom then S := CompileRandom(C.Value)
    else begin S := Column(Context,C); if C.IsNot then S := S+' DESC'; end;
    if Result <> '' then Result := Result+', '; Result := Result+S;
  end;
  if Result <> '' then Result := 'ORDER BY '+Result;
end;
function TCompiler.CompileSelectCore(Context: TCompileContext; Query: TQuery): string;
var C, A: TClause; S, Columns: string;
begin
  Result := SelectPrefix(Context,Query); Columns := ''; A := Query.GetOne('aggregate',EngineCode);
  if A <> nil then
  begin
    if Length(A.Columns) = 1 then Columns := UpperCase(A.Op)+'('+Wrap(A.Columns[0])+') '+FColumnAs+WrapValue(A.Op)
    else Columns := '1';
  end
  else for C in Query.GetComponents('select',EngineCode) do
  begin if Columns <> '' then Columns := Columns+', '; Columns := Columns+Column(Context,C); end;
  if Columns = '' then Columns := '*'; Result := Result+Columns;
  C := Query.GetOne('from',EngineCode); if C <> nil then Result := Result+' FROM '+Table(Context,C);
  Result := Result+CompileJoins(Context,Query);
  S := Conditions(Context,Query,'where'); if S <> '' then Result := Result+' WHERE '+S;
  S := '';
  for C in Query.GetComponents('group',EngineCode) do begin if S <> '' then S := S+', '; S := S+Column(Context,C); end;
  if S <> '' then Result := Result+' GROUP BY '+S;
  S := Conditions(Context,Query,'having'); if S <> '' then Result := Result+' HAVING '+S;
  S := CompileOrders(Context,Query); if S <> '' then Result := Result+' '+S;
  S := CompileLimit(Context,Query); if S <> '' then Result := Result+' '+S;
  for C in Query.GetComponents('combine',EngineCode) do
  begin
    if C.Kind = ckRaw then S := Raw(Context,C.Name,C.Values)
    else begin S := UpperCase(C.Op)+' '; if C.IsNot then S := S+'ALL '; S := S+CompileQuery(Context,C.Query,False); end;
    Result := Result+' '+S;
  end;
end;

{$I SqlKata.Compiler.Writes.inc}
{$I SqlKata.Compiler.Dialects.inc}

function TCompiler.CompileLower(const Value: string): string;
begin Result := 'LOWER('+Value+')'; end;
function TCompiler.CompileUpper(const Value: string): string;
begin Result := 'UPPER('+Value+')'; end;

end.

