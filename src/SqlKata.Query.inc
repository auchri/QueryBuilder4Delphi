function CopyValues(const Values: array of TValue): TValues;
var I: Integer;
begin
  SetLength(Result, Length(Values));
  for I := 0 to High(Values) do Result[I] := Values[I];
end;

function EqualValues(const A, B: TValue): Boolean;
begin
  if A.TypeInfo <> B.TypeInfo then Exit(False);
  if A.IsEmpty then Exit(True);
  case A.Kind of
    tkInteger, tkInt64, tkEnumeration: Result := A.AsOrdinal = B.AsOrdinal;
    tkFloat: Result := A.AsExtended = B.AsExtended;
    tkString, tkLString, tkWString, tkUString: Result := A.AsString = B.AsString;
    tkVariant: Result := VarSameValue(A.AsVariant,B.AsVariant);
    tkClass: Result := A.AsObject = B.AsObject;
  else Result := False; end;
end;

function DistinctValues(const Values: array of TValue): TValues;
var List: TList<TValue>; V, Other: TValue; Found: Boolean;
begin
  List := TList<TValue>.Create;
  try
    for V in Values do
    begin
      Found := False;
      for Other in List do if EqualValues(V, Other) then begin Found := True; Break; end;
      if not Found then List.Add(V);
    end;
    Result := List.ToArray;
  finally List.Free; end;
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

constructor TQueryObject.Create(const Table, Comment: string);
begin
  inherited Create;
  FClauses := TObjectList<TClause>.Create(True);
  FVariables := TDictionary<string,TValue>.Create;
  Method := 'select'; JoinType := 'INNER JOIN';
  FComment := Comment;
  if Table <> '' then &From(Table);
end;

destructor TQueryObject.Destroy;
begin FVariables.Free; FClauses.Free; inherited; end;

function TQueryObject.Clone: IQuery;
var Pair: TPair<string,TValue>;
begin
  Result := NewQuery;
  Result.CopyClausesFrom(Self); Result.EngineScope := EngineScope;
  Result.QueryAlias := QueryAlias; Result.Method := Method;
  Result.JoinType := JoinType; Result.IsDistinct := IsDistinct;
  Result.Comment(FComment);
  for Pair in FVariables do Result.Variables.Add(Pair.Key, Pair.Value);
end;

function TQueryObject.CopyClausesFrom(Source: IQuery): IQuery;
var C: TClause;
begin
  if Source = (Self as IQuery) then Exit(Self);
  FClauses.Clear;
  for C in Source.Clauses do FClauses.Add(C.Clone);
  Result := Self;
end;

function TQueryObject.NewQuery: IQuery;
begin Result := TQuery.Create; end;

function TQueryObject.Add(const Component: string; Kind: TClauseKind): TClause;
begin
  Result := TClause.Create; Result.Component := Component;
  Result.Kind := Kind; Result.Engine := EngineScope;
  FClauses.Add(Result);
end;

procedure TQueryObject.Remove(const Component, Engine: string);
var I: Integer;
begin
  for I := FClauses.Count-1 downto 0 do
    if (FClauses[I].Component = Component) and (FClauses[I].Engine = Engine) then
      FClauses.Delete(I);
end;

function TQueryObject.GetOne(const Component, Engine: string): TClause;
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

function TQueryObject.GetComponents(const Component, Engine: string): TArray<TClause>;
var C: TClause; List: TList<TClause>;
begin
  List := TList<TClause>.Create;
  try
    for C in FClauses do
      if (C.Component = Component) and ((C.Engine = '') or (C.Engine = Engine) or (Engine = '')) then List.Add(C);
    Result := List.ToArray;
  finally List.Free; end;
end;

function TQueryObject.HasComponent(const Component, Engine: string): Boolean;
begin Result := Length(GetComponents(Component, Engine)) > 0; end;

function TQueryObject.ClearComponent(const Component, Engine: string): IQuery;
var I: Integer; E: string;
begin
  E := Engine; if E = '' then E := EngineScope;
  for I := FClauses.Count-1 downto 0 do
    if (FClauses[I].Component = Component) and ((E = '') or
      (FClauses[I].Engine = '') or (FClauses[I].Engine = E)) then FClauses.Delete(I);
  Result := Self;
end;

function TQueryObject.HasConditions(const Engine: string): Boolean;
begin Result := HasComponent('where', Engine); end;

function TQueryObject.Condition(const Component: string; IsOr, IsNot: Boolean; Kind: TClauseKind): TClause;
begin
  Result := Add(Component, Kind); Result.IsOr := IsOr or FOrFlag;
  Result.IsNot := IsNot or FNot; FOrFlag := False; FNot := False;
end;

function TQueryObject.CallbackQuery(const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  if not Assigned(Callback) then raise EArgumentNilException.Create('Callback');
  Q := NewQuery;
  Q.EngineScope := EngineScope;
  if Callback(Q) <> Q then raise EQueryException.Create('Callback must return its supplied query');
  Result := Q;
end;

function TQueryObject.SetEngineScope(const Engine: string): IQuery;
begin EngineScope := Engine; Result := Self; end;
function TQueryObject.&Or: IQuery;
begin FOrFlag := True; Result := Self; end;
function TQueryObject.&And: IQuery;
begin FOrFlag := False; Result := Self; end;
function TQueryObject.&Not(Flag: Boolean): IQuery;
begin FNot := Flag; Result := Self; end;
function TQueryObject.&As(const Alias: string): IQuery;
begin QueryAlias := Alias; Result := Self; end;
function TQueryObject.Comment(const Text: string): IQuery;
begin FComment := Text; Result := Self; end;
function TQueryObject.GetComment: string;
begin Result := FComment; end;

function TQueryObject.&For(const Engine: string; const Callback: TQueryCallback): IQuery;
var Previous: string;
begin
  Previous := EngineScope; EngineScope := Engine;
  try
    Result := Callback(Self);
    if Result <> (Self as IQuery) then raise EQueryException.Create('Callback must return its supplied query');
  finally EngineScope := Previous; end;
end;

function TQueryObject.When(Condition: Boolean; const WhenTrue, WhenFalse: TQueryCallback): IQuery;
begin
  Result := Self;
  if Condition and Assigned(WhenTrue) then Result := WhenTrue(Self)
  else if not Condition and Assigned(WhenFalse) then Result := WhenFalse(Self);
  if Result <> (Self as IQuery) then raise EQueryException.Create('Callback must return its supplied query');
end;
function TQueryObject.WhenNot(Condition: Boolean; const Callback: TQueryCallback): IQuery;
begin Result := When(not Condition, Callback); end;
function TQueryObject.Define(const Name: string; const Value: TValue): IQuery;
begin FVariables.Add(Name, Value); Result := Self; end;
function TQueryObject.FindVariable(const Name: string): TValue;
begin
  if not FVariables.TryGetValue(Name, Result) then raise EQueryException.CreateFmt('Variable ''%s'' not found', [Name]);
end;

function TQueryObject.&From(const Table: string): IQuery;
begin Remove('from', EngineScope); Add('from', ckIdentifier).Name := Table; Result := Self; end;
function TQueryObject.&From(Query: IQuery; const Alias: string): IQuery;
var C: TClause;
begin
  Remove('from', EngineScope); C := Add('from', ckQuery); C.Query := Query.Clone;
  if Alias <> '' then C.Query.&As(Alias); Result := Self;
end;
function TQueryObject.&From(const Callback: TQueryCallback; const Alias: string): IQuery;
var Q: IQuery;
begin Q := CallbackQuery(Callback); Result := &From(Q, Alias); end;
function TQueryObject.Select(Query: IQuery; const Alias: string): IQuery;
var C: TClause;
begin C := Add('select', ckQuery); C.Query := Query.Clone.&As(Alias); Method := 'select'; Result := Self; end;
function TQueryObject.Select(const Callback: TQueryCallback; const Alias: string): IQuery;
var Q: IQuery;
begin Q := CallbackQuery(Callback); Result := Select(Q, Alias); end;
function TQueryObject.SelectAggregate(const Aggregate, Column: string; const Filter: TQueryCallback): IQuery;
var C: TClause;
begin
  C := Add('select', ckAggregate); C.Op := Aggregate; C.Name := Column;
  if Assigned(Filter) then C.Query := CallbackQuery(Filter);
  Method := 'select'; Result := Self;
end;
function TQueryObject.SelectAggregate(const Aggregate, Column: string; Filter: IQuery): IQuery;
var C: TClause;
begin
  C := Add('select',ckAggregate); C.Op := Aggregate; C.Name := Column;
  if Filter <> nil then C.Query := Filter.Clone;
  Method := 'select'; Result := Self;
end;

function TQueryObject.&With(const Alias: string; Query: IQuery): IQuery;
var C: TClause;
begin
  if Trim(Alias) = '' then raise EQueryException.Create('No alias found for CTE');
  C := Add('cte', ckQuery); C.Alias := Trim(Alias); C.Query := Query.Clone;
  C.Query.QueryAlias := ''; Result := Self;
end;
function TQueryObject.&With(Query: IQuery): IQuery;
begin Result := &With(Query.QueryAlias, Query); end;
function TQueryObject.&With(const Alias: string; const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin Q := CallbackQuery(Callback); Result := &With(Alias, Q); end;
function TQueryObject.&With(const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin Q := CallbackQuery(Callback); Result := &With(Q); end;
function TQueryObject.&With(const Alias: string; const Columns: array of string; const Rows: TRows): IQuery;
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
function TQueryObject.WithRaw(const Alias, Sql: string; const Bindings: array of TValue): IQuery;
var C: TClause;
begin C := Add('cte', ckRaw); C.Alias := Alias; C.Name := Sql; C.Values := CopyValues(Bindings); Result := Self; end;
function TQueryObject.WithRaw(const Alias, Sql: string): IQuery;
begin Result := WithRaw(Alias, Sql, []); end;

function TQueryObject.Join(const Table, First, Second, Op, JoinType: string): IQuery;
var C: TClause;
begin
  C := Add('join', ckJoin); C.Query := NewQuery;
  C.Query.&From(Table).WhereColumns(First, Op, Second).AsType(JoinType); Result := Self;
end;
function TQueryObject.Join(const Table: string; const Callback: TQueryCallback; const JoinType: string): IQuery;
var C: TClause; Q, Group: IQuery;
begin
  Q := CallbackQuery(Callback);
  Group := Q.Clone; Q.ClearComponent('where');
  C := Q.Add('where', ckNested); C.Query := Group;
  Q.&From(Table).AsType(JoinType); C := Add('join', ckJoin); C.Query := Q;

  Result := Self;
end;
function TQueryObject.Join(Query: IQuery; const Callback: TQueryCallback; const JoinType: string): IQuery;
var C: TClause; Q, Group: IQuery;
begin
  Q := CallbackQuery(Callback);
  Group := Q.Clone; Q.ClearComponent('where');
  C := Q.Add('where', ckNested); C.Query := Group;
  Q.&From(Query).AsType(JoinType); C := Add('join', ckJoin); C.Query := Q;

  Result := Self;
end;
function TQueryObject.LeftJoin(const Table, First, Second, Op: string): IQuery;
begin Result := Join(Table, First, Second, Op, 'left join'); end;
function TQueryObject.LeftJoin(const Table: string; const Callback: TQueryCallback): IQuery;
begin Result := Join(Table, Callback, 'left join'); end;
function TQueryObject.LeftJoin(Query: IQuery; const Callback: TQueryCallback): IQuery;
begin Result := Join(Query, Callback, 'left join'); end;
function TQueryObject.RightJoin(const Table, First, Second, Op: string): IQuery;
begin Result := Join(Table, First, Second, Op, 'right join'); end;
function TQueryObject.RightJoin(const Table: string; const Callback: TQueryCallback): IQuery;
begin Result := Join(Table, Callback, 'right join'); end;
function TQueryObject.RightJoin(Query: IQuery; const Callback: TQueryCallback): IQuery;
begin Result := Join(Query, Callback, 'right join'); end;
function TQueryObject.CrossJoin(const Table: string): IQuery;
var C: TClause;
begin C := Add('join', ckJoin); C.Query := NewQuery.&From(Table).AsCross; Result := Self; end;
function TQueryObject.On(const First, Second, Op: string): IQuery;
begin Result := WhereColumns(First, Op, Second); end;
function TQueryObject.OrOn(const First, Second, Op: string): IQuery;
begin Result := OrWhereColumns(First, Op, Second); end;
function TQueryObject.JoinWith(const Table: string): IQuery;
begin Result := &From(Table); end;
function TQueryObject.JoinWith(Query: IQuery; const Alias: string): IQuery;
begin Result := &From(Query, Alias); end;
function TQueryObject.JoinWith(const Callback: TQueryCallback; const Alias: string): IQuery;
begin Result := &From(Callback, Alias); end;
function TQueryObject.JoinWithRaw(const Sql: string; const Bindings: array of TValue): IQuery;
begin Result := FromRaw(Sql, Bindings); end;
function TQueryObject.AsType(const Value: string): IQuery;
begin JoinType := UpperCase(Value); Result := Self; end;
function TQueryObject.AsInner: IQuery;
begin Result := AsType('inner join'); end;
function TQueryObject.AsOuter: IQuery;
begin Result := AsType('outer join'); end;
function TQueryObject.AsLeft: IQuery;
begin Result := AsType('left join'); end;
function TQueryObject.AsRight: IQuery;
begin Result := AsType('right join'); end;
function TQueryObject.AsCross: IQuery;
begin Result := AsType('cross join'); end;

function TQueryObject.Limit(Value: Integer): IQuery;
begin Remove('limit', EngineScope); Add('limit', ckLimit).Value := Value; Result := Self; end;
function TQueryObject.Offset(Value: Int64): IQuery;
begin Remove('offset', EngineScope); Add('offset', ckOffset).Value := Value; Result := Self; end;
function TQueryObject.Take(Value: Integer): IQuery;
begin Result := Limit(Value); end;
function TQueryObject.Skip(Value: Int64): IQuery;
begin Result := Offset(Value); end;
function TQueryObject.ForPage(Page, PerPage: Integer): IQuery;
begin Result := Offset(Int64(Page-1)*PerPage).Limit(PerPage); end;
function TQueryObject.GetLimit(const Engine: string): Integer;
var C: TClause;
begin C := GetOne('limit', Engine); Result := 0; if C <> nil then Result := C.Value.AsInteger; if Result < 0 then Result := 0; end;
function TQueryObject.GetOffset(const Engine: string): Int64;
var C: TClause;
begin C := GetOne('offset', Engine); Result := 0; if C <> nil then Result := C.Value.AsInt64; if Result < 0 then Result := 0; end;
function TQueryObject.HasLimit(const Engine: string): Boolean;
begin Result := GetLimit(Engine) > 0; end;
function TQueryObject.HasOffset(const Engine: string): Boolean;
begin Result := GetOffset(Engine) > 0; end;
function TQueryObject.Distinct: IQuery;
begin IsDistinct := True; Result := Self; end;
function TQueryObject.OrderByRandom: IQuery;
begin Add('order', ckRandom); Result := Self; end;
function TQueryObject.OrderByRandom(Seed: Integer): IQuery;
begin Add('order', ckRandom).Value := Seed; Result := Self; end;
function TQueryObject.Combine(const Operation: string; All: Boolean; Query: IQuery): IQuery;
var C: TClause;
begin
  if (Method <> 'select') or (Query.Method <> 'select') then raise EQueryException.Create('Only select queries can be combined');
  if not MatchText(Operation, ['union','except','intersect']) then raise EQueryException.Create('Invalid combine operation');
  C := Add('combine', ckCombine); C.Op := Operation; C.IsNot := All; C.Query := Query.Clone; Result := Self;
end;
