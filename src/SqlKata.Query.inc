function CopyValues(const Values: array of TValue): TValues;
var I: Integer;
begin
  SetLength(Result, Length(Values));
  for I := 0 to High(Values) do Result[I] := Values[I];
end;

function CopyStrings(const Values: array of string): TArray<string>;
var I: Integer;
begin
  SetLength(Result, Length(Values));
  for I := 0 to High(Values) do Result[I] := Values[I];
end;

function ExpandExpression(const Expression: string): TArray<string>;
var P, I: Integer; Prefix: string;
begin
  P := Pos('.{', Expression);
  if (P = 0) or not Expression.EndsWith('}') then begin Result := TArray<string>.Create(Expression); Exit; end;
  Prefix := Copy(Expression, 1, P);
  Result := Copy(Expression, P+2, Length(Expression)-P-2).Split([',']);
  for I := 0 to High(Result) do Result[I] := Prefix + Trim(Result[I]);
end;

constructor TUnsafeLiteral.Create(const AValue: string; ReplaceQuotes: Boolean);
begin
  Value := AValue;
  if ReplaceQuotes then Value := StringReplace(Value, '''', '''''', [rfReplaceAll]);
end;

class operator TUnsafeLiteral.Implicit(const Literal: TUnsafeLiteral): TValue;
begin Result := TValue.From<TUnsafeLiteral>(Literal); end;

constructor TVariable.Create(const AName: string);
begin Name := AName; end;

class operator TVariable.Implicit(const Variable: TVariable): TValue;
begin Result := TValue.From<TVariable>(Variable); end;

constructor ColumnAttribute.Create(const AName: string);
begin inherited Create; Name := AName; end;

destructor TClause.Destroy;
begin Query.Free; inherited; end;

function TClause.Clone: TClause;
begin
  Result := TClause.Create;
  try
    Result.Component := Component; Result.Engine := Engine; Result.Kind := Kind;
    Result.Name := Name; Result.Op := Op; Result.Extra := Extra; Result.Alias := Alias;
    Result.IsOr := IsOr; Result.IsNot := IsNot; Result.ReturnId := ReturnId;
    Result.Value := Value; Result.Value2 := Value2;
    Result.Values := Copy(Values); Result.Columns := Copy(Columns);
    if Query <> nil then Result.Query := Query.Clone;
  except Result.Free; raise; end;
end;

constructor TQuery.Create(const Table, Comment: string);
begin
  inherited Create;
  FClauses := TObjectList<TClause>.Create(True);
  FVariables := TDictionary<string,TValue>.Create;
  Method := 'select'; JoinType := 'INNER JOIN';
  FComment := Comment;
  if Table <> '' then &From(Table);
end;

destructor TQuery.Destroy;
begin FVariables.Free; FClauses.Free; inherited; end;

function TQuery.Clone: TQuery;
var Pair: TPair<string,TValue>;
begin
  Result := NewQuery;
  try
    Result.CopyClausesFrom(Self); Result.EngineScope := EngineScope;
    Result.QueryAlias := QueryAlias; Result.Method := Method;
    Result.JoinType := JoinType; Result.IsDistinct := IsDistinct;
    Result.FComment := FComment;
    for Pair in FVariables do Result.FVariables.Add(Pair.Key, Pair.Value);
  except Result.Free; raise; end;
end;

function TQuery.CopyClausesFrom(Source: TQuery): TQuery;
var C: TClause;
begin
  if Source = Self then Exit(Self);
  FClauses.Clear;
  for C in Source.Clauses do FClauses.Add(C.Clone);
  Result := Self;
end;

function TQuery.NewQuery: TQuery;
begin Result := TQuery.Create; end;

function TQuery.Add(const Component: string; Kind: TClauseKind): TClause;
begin
  Result := TClause.Create; Result.Component := Component;
  Result.Kind := Kind; Result.Engine := EngineScope;
  FClauses.Add(Result);
end;

procedure TQuery.Remove(const Component, Engine: string);
var I: Integer;
begin
  for I := FClauses.Count-1 downto 0 do
    if (FClauses[I].Component = Component) and (FClauses[I].Engine = Engine) then
      FClauses.Delete(I);
end;

function TQuery.GetOne(const Component, Engine: string): TClause;
var C: TClause;
begin
  Result := nil;
  for C in FClauses do
    if C.Component = Component then
    begin
      if C.Engine = Engine then Exit(C);
      if (C.Engine = '') and (Result = nil) then Result := C;
    end;
end;

function TQuery.GetComponents(const Component, Engine: string): TArray<TClause>;
var C: TClause; List: TList<TClause>;
begin
  List := TList<TClause>.Create;
  try
    for C in FClauses do
      if (C.Component = Component) and ((C.Engine = '') or (C.Engine = Engine) or (Engine = '')) then List.Add(C);
    Result := List.ToArray;
  finally List.Free; end;
end;

function TQuery.HasComponent(const Component, Engine: string): Boolean;
begin Result := Length(GetComponents(Component, Engine)) > 0; end;

function TQuery.ClearComponent(const Component, Engine: string): TQuery;
var I: Integer; E: string;
begin
  E := Engine; if E = '' then E := EngineScope;
  for I := FClauses.Count-1 downto 0 do
    if (FClauses[I].Component = Component) and ((E = '') or
      (FClauses[I].Engine = '') or (FClauses[I].Engine = E)) then FClauses.Delete(I);
  Result := Self;
end;

function TQuery.HasConditions(const Engine: string): Boolean;
begin Result := HasComponent('where', Engine); end;

function TQuery.Condition(const Component: string; IsOr, IsNot: Boolean; Kind: TClauseKind): TClause;
begin
  Result := Add(Component, Kind); Result.IsOr := IsOr or FOrFlag;
  Result.IsNot := IsNot or FNot; FOrFlag := False; FNot := False;
end;

function TQuery.CallbackQuery(const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  if not Assigned(Callback) then raise EArgumentNilException.Create('Callback');
  Q := NewQuery;
  Q.EngineScope := EngineScope;
  try
    if Callback(Q) <> Q then raise EQueryException.Create('Callback must return its supplied query');
  except Q.Free; raise; end;
  Result := Q;
end;

function TQuery.SetEngineScope(const Engine: string): TQuery;
begin EngineScope := Engine; Result := Self; end;
function TQuery.&Or: TQuery;
begin FOrFlag := True; Result := Self; end;
function TQuery.&And: TQuery;
begin FOrFlag := False; Result := Self; end;
function TQuery.&Not(Flag: Boolean): TQuery;
begin FNot := Flag; Result := Self; end;
function TQuery.&As(const Alias: string): TQuery;
begin QueryAlias := Alias; Result := Self; end;
function TQuery.Comment(const Text: string): TQuery;
begin FComment := Text; Result := Self; end;
function TQuery.GetComment: string;
begin Result := FComment; end;

function TQuery.&For(const Engine: string; const Callback: TQueryCallback): TQuery;
var Previous: string;
begin
  Previous := EngineScope; EngineScope := Engine;
  try
    Result := Callback(Self);
    if Result <> Self then raise EQueryException.Create('Callback must return its supplied query');
  finally EngineScope := Previous; end;
end;

function TQuery.When(Condition: Boolean; const WhenTrue, WhenFalse: TQueryCallback): TQuery;
begin
  Result := Self;
  if Condition and Assigned(WhenTrue) then Result := WhenTrue(Self)
  else if not Condition and Assigned(WhenFalse) then Result := WhenFalse(Self);
  if Result <> Self then raise EQueryException.Create('Callback must return its supplied query');
end;
function TQuery.WhenNot(Condition: Boolean; const Callback: TQueryCallback): TQuery;
begin Result := When(not Condition, Callback); end;
function TQuery.Define(const Name: string; const Value: TValue): TQuery;
begin FVariables.Add(Name, Value); Result := Self; end;
function TQuery.FindVariable(const Name: string): TValue;
begin
  if not FVariables.TryGetValue(Name, Result) then raise EQueryException.CreateFmt('Variable ''%s'' not found', [Name]);
end;

function TQuery.&From(const Table: string): TQuery;
begin Remove('from', EngineScope); Add('from', ckIdentifier).Name := Table; Result := Self; end;
function TQuery.&From(Query: TQuery; const Alias: string): TQuery;
var C: TClause;
begin
  Remove('from', EngineScope); C := Add('from', ckQuery); C.Query := Query.Clone;
  if Alias <> '' then C.Query.&As(Alias); Result := Self;
end;
function TQuery.&From(const Callback: TQueryCallback; const Alias: string): TQuery;
var Q: TQuery;
begin Q := CallbackQuery(Callback); try Result := &From(Q, Alias); finally Q.Free; end; end;
function TQuery.Select(Query: TQuery; const Alias: string): TQuery;
var C: TClause;
begin C := Add('select', ckQuery); C.Query := Query.Clone.&As(Alias); Method := 'select'; Result := Self; end;
function TQuery.Select(const Callback: TQueryCallback; const Alias: string): TQuery;
var Q: TQuery;
begin Q := CallbackQuery(Callback); try Result := Select(Q, Alias); finally Q.Free; end; end;
function TQuery.SelectAggregate(const Aggregate, Column: string; const Filter: TQueryCallback): TQuery;
var C: TClause;
begin
  C := Add('select', ckAggregate); C.Op := Aggregate; C.Name := Column;
  if Assigned(Filter) then C.Query := CallbackQuery(Filter);
  Method := 'select'; Result := Self;
end;

function TQuery.&With(const Alias: string; Query: TQuery): TQuery;
var C: TClause;
begin
  if Trim(Alias) = '' then raise EQueryException.Create('No alias found for CTE');
  C := Add('cte', ckQuery); C.Alias := Trim(Alias); C.Query := Query.Clone;
  C.Query.QueryAlias := ''; Result := Self;
end;
function TQuery.&With(Query: TQuery): TQuery;
begin Result := &With(Query.QueryAlias, Query); end;
function TQuery.&With(const Alias: string; const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin Q := CallbackQuery(Callback); try Result := &With(Alias, Q); finally Q.Free; end; end;
function TQuery.&With(const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin Q := CallbackQuery(Callback); try Result := &With(Q); finally Q.Free; end; end;
function TQuery.&With(const Alias: string; const Columns: array of string; const Rows: TRows): TQuery;
var C: TClause; Row: TValues; V: TValue; List: TList<TValue>;
begin
  if (Length(Columns) = 0) or (Length(Rows) = 0) then raise EQueryException.Create('Columns and rows cannot be empty');
  for Row in Rows do if Length(Row) <> Length(Columns) then raise EQueryException.Create('Column/value count mismatch');
  C := Add('cte', ckAdHoc); C.Alias := Alias; C.Columns := CopyStrings(Columns);
  List := TList<TValue>.Create;
  try for Row in Rows do for V in Row do List.Add(V); C.Values := List.ToArray;
  finally List.Free; end;
  Result := Self;
end;
function TQuery.WithRaw(const Alias, Sql: string; const Bindings: array of TValue): TQuery;
var C: TClause;
begin C := Add('cte', ckRaw); C.Alias := Alias; C.Name := Sql; C.Values := CopyValues(Bindings); Result := Self; end;
function TQuery.WithRaw(const Alias, Sql: string): TQuery;
begin Result := WithRaw(Alias, Sql, []); end;

function TQuery.Join(const Table, First, Second, Op, JoinType: string): TQuery;
var C: TClause;
begin
  C := Add('join', ckJoin); C.Query := NewQuery;
  C.Query.&From(Table).WhereColumns(First, Op, Second).AsType(JoinType); Result := Self;
end;
function TQuery.Join(const Table: string; const Callback: TQueryCallback; const JoinType: string): TQuery;
var C: TClause; Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Q.&From(Table).AsType(JoinType); C := Add('join', ckJoin); C.Query := Q; except Q.Free; raise; end;
  Result := Self;
end;
function TQuery.Join(Query: TQuery; const Callback: TQueryCallback; const JoinType: string): TQuery;
var C: TClause; Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Q.&From(Query).AsType(JoinType); C := Add('join', ckJoin); C.Query := Q; except Q.Free; raise; end;
  Result := Self;
end;
function TQuery.LeftJoin(const Table, First, Second, Op: string): TQuery;
begin Result := Join(Table, First, Second, Op, 'left join'); end;
function TQuery.LeftJoin(const Table: string; const Callback: TQueryCallback): TQuery;
begin Result := Join(Table, Callback, 'left join'); end;
function TQuery.LeftJoin(Query: TQuery; const Callback: TQueryCallback): TQuery;
begin Result := Join(Query, Callback, 'left join'); end;
function TQuery.RightJoin(const Table, First, Second, Op: string): TQuery;
begin Result := Join(Table, First, Second, Op, 'right join'); end;
function TQuery.RightJoin(const Table: string; const Callback: TQueryCallback): TQuery;
begin Result := Join(Table, Callback, 'right join'); end;
function TQuery.RightJoin(Query: TQuery; const Callback: TQueryCallback): TQuery;
begin Result := Join(Query, Callback, 'right join'); end;
function TQuery.CrossJoin(const Table: string): TQuery;
var C: TClause;
begin C := Add('join', ckJoin); C.Query := NewQuery.&From(Table).AsCross; Result := Self; end;
function TQuery.On(const First, Second, Op: string): TQuery;
begin Result := WhereColumns(First, Op, Second); end;
function TQuery.OrOn(const First, Second, Op: string): TQuery;
begin Result := OrWhereColumns(First, Op, Second); end;
function TQuery.JoinWith(const Table: string): TQuery;
begin Result := &From(Table); end;
function TQuery.JoinWith(Query: TQuery; const Alias: string): TQuery;
begin Result := &From(Query, Alias); end;
function TQuery.JoinWithRaw(const Sql: string; const Bindings: array of TValue): TQuery;
begin Result := FromRaw(Sql, Bindings); end;
function TQuery.AsType(const Value: string): TQuery;
begin JoinType := UpperCase(Value); Result := Self; end;
function TQuery.AsInner: TQuery;
begin Result := AsType('inner join'); end;
function TQuery.AsOuter: TQuery;
begin Result := AsType('outer join'); end;
function TQuery.AsLeft: TQuery;
begin Result := AsType('left join'); end;
function TQuery.AsRight: TQuery;
begin Result := AsType('right join'); end;
function TQuery.AsCross: TQuery;
begin Result := AsType('cross join'); end;

function TQuery.Limit(Value: Integer): TQuery;
begin Remove('limit', EngineScope); Add('limit', ckLimit).Value := Value; Result := Self; end;
function TQuery.Offset(Value: Int64): TQuery;
begin Remove('offset', EngineScope); Add('offset', ckOffset).Value := Value; Result := Self; end;
function TQuery.Take(Value: Integer): TQuery;
begin Result := Limit(Value); end;
function TQuery.Skip(Value: Int64): TQuery;
begin Result := Offset(Value); end;
function TQuery.ForPage(Page, PerPage: Integer): TQuery;
begin Result := Offset(Int64(Page-1)*PerPage).Limit(PerPage); end;
function TQuery.GetLimit(const Engine: string): Integer;
var C: TClause;
begin C := GetOne('limit', Engine); Result := 0; if C <> nil then Result := C.Value.AsInteger; if Result < 0 then Result := 0; end;
function TQuery.GetOffset(const Engine: string): Int64;
var C: TClause;
begin C := GetOne('offset', Engine); Result := 0; if C <> nil then Result := C.Value.AsInt64; if Result < 0 then Result := 0; end;
function TQuery.HasLimit(const Engine: string): Boolean;
begin Result := GetLimit(Engine) > 0; end;
function TQuery.HasOffset(const Engine: string): Boolean;
begin Result := GetOffset(Engine) > 0; end;
function TQuery.Distinct: TQuery;
begin IsDistinct := True; Result := Self; end;
function TQuery.OrderByRandom: TQuery;
begin Add('order', ckRandom); Result := Self; end;
function TQuery.OrderByRandom(Seed: Integer): TQuery;
begin Add('order', ckRandom).Value := Seed; Result := Self; end;
function TQuery.Combine(const Operation: string; All: Boolean; Query: TQuery): TQuery;
var C: TClause;
begin
  if (Method <> 'select') or (Query.Method <> 'select') then raise EQueryException.Create('Only select queries can be combined');
  if not MatchText(Operation, ['union','except','intersect']) then raise EQueryException.Create('Invalid combine operation');
  C := Add('combine', ckCombine); C.Op := Operation; C.IsNot := All; C.Query := Query.Clone; Result := Self;
end;

{$I SqlKata.Writes.inc}


