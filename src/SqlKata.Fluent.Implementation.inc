function TQuery.Where(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckBasic);
  C.Name := Column; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQuery.Where(const Column: string; const Value: TValue): TQuery;

begin
  Result := Where(Column, '=', Value);
end;

function TQuery.Where(Group: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQuery.Where(const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := Where(Q); finally Q.Free; end;
end;

function TQuery.Where(const Column, Op: string; Query: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckQuery);
  C.Name := Column; C.Op := Op; C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.Where(const Column, Op: string; const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := Where(Column, Op, Q); finally Q.Free; end;
end;

function TQuery.WhereNull(const Column: string): TQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQuery.WhereTrue(const Column: string): TQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckBoolean);
  C.Name := Column; C.Value := True;
  Result := Self;
end;

function TQuery.WhereFalse(const Column: string): TQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckBoolean);
  C.Name := Column; C.Value := False;
  Result := Self;
end;

function TQuery.WhereBetween(const Column: string; const Lower, Higher: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckBetween);
  C.Name := Column; C.Value := Lower; C.Value2 := Higher;
  Result := Self;
end;

function TQuery.WhereIn(const Column: string; const Values: array of TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckIn);
  C.Name := Column; C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQuery.WhereIn(const Column: string; Query: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckInQuery);
  C.Name := Column; C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.WhereIn(const Column: string; const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := WhereIn(Column, Q); finally Q.Free; end;
end;

function TQuery.WhereExists(Query: TQuery): TQuery;
var C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('where', False, False, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.WhereExists(const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := WhereExists(Q); finally Q.Free; end;
end;

function TQuery.WhereLike(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'like'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.WhereStarts(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'starts'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.WhereEnds(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'ends'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.WhereContains(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'contains'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.WhereDate(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'date';
  Result := Self;
end;

function TQuery.WhereDate(const Column: string; const Value: TValue): TQuery;

begin
  Result := WhereDate(Column, '=', Value);
end;

function TQuery.WhereTime(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'time';
  Result := Self;
end;

function TQuery.WhereTime(const Column: string; const Value: TValue): TQuery;

begin
  Result := WhereTime(Column, '=', Value);
end;

function TQuery.WhereDatePart(const Part, Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := Part;
  Result := Self;
end;

function TQuery.WhereDatePart(const Part, Column: string; const Value: TValue): TQuery;

begin
  Result := WhereDatePart(Part, Column, '=', Value);
end;

function TQuery.WhereNot(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckBasic);
  C.Name := Column; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQuery.WhereNot(const Column: string; const Value: TValue): TQuery;

begin
  Result := WhereNot(Column, '=', Value);
end;

function TQuery.WhereNot(Group: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQuery.WhereNot(const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := WhereNot(Q); finally Q.Free; end;
end;

function TQuery.WhereNot(const Column, Op: string; Query: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckQuery);
  C.Name := Column; C.Op := Op; C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.WhereNot(const Column, Op: string; const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := WhereNot(Column, Op, Q); finally Q.Free; end;
end;

function TQuery.WhereNotNull(const Column: string): TQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQuery.WhereNotBetween(const Column: string; const Lower, Higher: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckBetween);
  C.Name := Column; C.Value := Lower; C.Value2 := Higher;
  Result := Self;
end;

function TQuery.WhereNotIn(const Column: string; const Values: array of TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckIn);
  C.Name := Column; C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQuery.WhereNotIn(const Column: string; Query: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckInQuery);
  C.Name := Column; C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.WhereNotIn(const Column: string; const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := WhereNotIn(Column, Q); finally Q.Free; end;
end;

function TQuery.WhereNotExists(Query: TQuery): TQuery;
var C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('where', False, True, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.WhereNotExists(const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := WhereNotExists(Q); finally Q.Free; end;
end;

function TQuery.WhereNotLike(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'like'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.WhereNotStarts(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'starts'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.WhereNotEnds(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'ends'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.WhereNotContains(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'contains'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.WhereNotDate(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'date';
  Result := Self;
end;

function TQuery.WhereNotDate(const Column: string; const Value: TValue): TQuery;

begin
  Result := WhereNotDate(Column, '=', Value);
end;

function TQuery.WhereNotTime(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'time';
  Result := Self;
end;

function TQuery.WhereNotTime(const Column: string; const Value: TValue): TQuery;

begin
  Result := WhereNotTime(Column, '=', Value);
end;

function TQuery.WhereNotDatePart(const Part, Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := Part;
  Result := Self;
end;

function TQuery.WhereNotDatePart(const Part, Column: string; const Value: TValue): TQuery;

begin
  Result := WhereNotDatePart(Part, Column, '=', Value);
end;

function TQuery.WhereRaw(const Sql: string; const Bindings: array of TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckRaw);
  C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQuery.WhereRaw(const Sql: string): TQuery;

begin
  Result := WhereRaw(Sql, []);
end;

function TQuery.WhereColumns(const First, Op, Second: string): TQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckColumns);
  C.Name := First; C.Op := Op; C.Extra := Second;
  Result := Self;
end;

function TQuery.WhereSub(Query: TQuery; const Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckSubQuery);
  C.Query := Query.Clone; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQuery.WhereSub(Query: TQuery; const Value: TValue): TQuery;

begin
  Result := WhereSub(Query, '=', Value);
end;

function TQuery.OrWhere(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckBasic);
  C.Name := Column; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQuery.OrWhere(const Column: string; const Value: TValue): TQuery;

begin
  Result := OrWhere(Column, '=', Value);
end;

function TQuery.OrWhere(Group: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQuery.OrWhere(const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := OrWhere(Q); finally Q.Free; end;
end;

function TQuery.OrWhere(const Column, Op: string; Query: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckQuery);
  C.Name := Column; C.Op := Op; C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.OrWhere(const Column, Op: string; const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := OrWhere(Column, Op, Q); finally Q.Free; end;
end;

function TQuery.OrWhereNull(const Column: string): TQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQuery.OrWhereTrue(const Column: string): TQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckBoolean);
  C.Name := Column; C.Value := True;
  Result := Self;
end;

function TQuery.OrWhereFalse(const Column: string): TQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckBoolean);
  C.Name := Column; C.Value := False;
  Result := Self;
end;

function TQuery.OrWhereBetween(const Column: string; const Lower, Higher: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckBetween);
  C.Name := Column; C.Value := Lower; C.Value2 := Higher;
  Result := Self;
end;

function TQuery.OrWhereIn(const Column: string; const Values: array of TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckIn);
  C.Name := Column; C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQuery.OrWhereIn(const Column: string; Query: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckInQuery);
  C.Name := Column; C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.OrWhereIn(const Column: string; const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := OrWhereIn(Column, Q); finally Q.Free; end;
end;

function TQuery.OrWhereExists(Query: TQuery): TQuery;
var C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('where', True, False, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.OrWhereExists(const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := OrWhereExists(Q); finally Q.Free; end;
end;

function TQuery.OrWhereLike(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'like'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.OrWhereStarts(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'starts'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.OrWhereEnds(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'ends'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.OrWhereContains(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'contains'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.OrWhereDate(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'date';
  Result := Self;
end;

function TQuery.OrWhereDate(const Column: string; const Value: TValue): TQuery;

begin
  Result := OrWhereDate(Column, '=', Value);
end;

function TQuery.OrWhereTime(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'time';
  Result := Self;
end;

function TQuery.OrWhereTime(const Column: string; const Value: TValue): TQuery;

begin
  Result := OrWhereTime(Column, '=', Value);
end;

function TQuery.OrWhereDatePart(const Part, Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := Part;
  Result := Self;
end;

function TQuery.OrWhereDatePart(const Part, Column: string; const Value: TValue): TQuery;

begin
  Result := OrWhereDatePart(Part, Column, '=', Value);
end;

function TQuery.OrWhereNot(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckBasic);
  C.Name := Column; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQuery.OrWhereNot(const Column: string; const Value: TValue): TQuery;

begin
  Result := OrWhereNot(Column, '=', Value);
end;

function TQuery.OrWhereNot(Group: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQuery.OrWhereNot(const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := OrWhereNot(Q); finally Q.Free; end;
end;

function TQuery.OrWhereNot(const Column, Op: string; Query: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckQuery);
  C.Name := Column; C.Op := Op; C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.OrWhereNot(const Column, Op: string; const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := OrWhereNot(Column, Op, Q); finally Q.Free; end;
end;

function TQuery.OrWhereNotNull(const Column: string): TQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQuery.OrWhereNotBetween(const Column: string; const Lower, Higher: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckBetween);
  C.Name := Column; C.Value := Lower; C.Value2 := Higher;
  Result := Self;
end;

function TQuery.OrWhereNotIn(const Column: string; const Values: array of TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckIn);
  C.Name := Column; C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQuery.OrWhereNotIn(const Column: string; Query: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckInQuery);
  C.Name := Column; C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.OrWhereNotIn(const Column: string; const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := OrWhereNotIn(Column, Q); finally Q.Free; end;
end;

function TQuery.OrWhereNotExists(Query: TQuery): TQuery;
var C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('where', True, True, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.OrWhereNotExists(const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := OrWhereNotExists(Q); finally Q.Free; end;
end;

function TQuery.OrWhereNotLike(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'like'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.OrWhereNotStarts(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'starts'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.OrWhereNotEnds(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'ends'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.OrWhereNotContains(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'contains'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.OrWhereNotDate(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'date';
  Result := Self;
end;

function TQuery.OrWhereNotDate(const Column: string; const Value: TValue): TQuery;

begin
  Result := OrWhereNotDate(Column, '=', Value);
end;

function TQuery.OrWhereNotTime(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'time';
  Result := Self;
end;

function TQuery.OrWhereNotTime(const Column: string; const Value: TValue): TQuery;

begin
  Result := OrWhereNotTime(Column, '=', Value);
end;

function TQuery.OrWhereNotDatePart(const Part, Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := Part;
  Result := Self;
end;

function TQuery.OrWhereNotDatePart(const Part, Column: string; const Value: TValue): TQuery;

begin
  Result := OrWhereNotDatePart(Part, Column, '=', Value);
end;

function TQuery.OrWhereRaw(const Sql: string; const Bindings: array of TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckRaw);
  C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQuery.OrWhereRaw(const Sql: string): TQuery;

begin
  Result := OrWhereRaw(Sql, []);
end;

function TQuery.OrWhereColumns(const First, Op, Second: string): TQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckColumns);
  C.Name := First; C.Op := Op; C.Extra := Second;
  Result := Self;
end;

function TQuery.OrWhereSub(Query: TQuery; const Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckSubQuery);
  C.Query := Query.Clone; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQuery.OrWhereSub(Query: TQuery; const Value: TValue): TQuery;

begin
  Result := OrWhereSub(Query, '=', Value);
end;

function TQuery.Having(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckBasic);
  C.Name := Column; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQuery.Having(const Column: string; const Value: TValue): TQuery;

begin
  Result := Having(Column, '=', Value);
end;

function TQuery.Having(Group: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQuery.Having(const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := Having(Q); finally Q.Free; end;
end;

function TQuery.Having(const Column, Op: string; Query: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckQuery);
  C.Name := Column; C.Op := Op; C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.Having(const Column, Op: string; const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := Having(Column, Op, Q); finally Q.Free; end;
end;

function TQuery.HavingNull(const Column: string): TQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQuery.HavingTrue(const Column: string): TQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckBoolean);
  C.Name := Column; C.Value := True;
  Result := Self;
end;

function TQuery.HavingFalse(const Column: string): TQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckBoolean);
  C.Name := Column; C.Value := False;
  Result := Self;
end;

function TQuery.HavingBetween(const Column: string; const Lower, Higher: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckBetween);
  C.Name := Column; C.Value := Lower; C.Value2 := Higher;
  Result := Self;
end;

function TQuery.HavingIn(const Column: string; const Values: array of TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckIn);
  C.Name := Column; C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQuery.HavingIn(const Column: string; Query: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckInQuery);
  C.Name := Column; C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.HavingIn(const Column: string; const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := HavingIn(Column, Q); finally Q.Free; end;
end;

function TQuery.HavingExists(Query: TQuery): TQuery;
var C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('having', False, False, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.HavingExists(const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := HavingExists(Q); finally Q.Free; end;
end;

function TQuery.HavingLike(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'like'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.HavingStarts(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'starts'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.HavingEnds(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'ends'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.HavingContains(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'contains'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.HavingDate(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'date';
  Result := Self;
end;

function TQuery.HavingDate(const Column: string; const Value: TValue): TQuery;

begin
  Result := HavingDate(Column, '=', Value);
end;

function TQuery.HavingTime(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'time';
  Result := Self;
end;

function TQuery.HavingTime(const Column: string; const Value: TValue): TQuery;

begin
  Result := HavingTime(Column, '=', Value);
end;

function TQuery.HavingDatePart(const Part, Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := Part;
  Result := Self;
end;

function TQuery.HavingDatePart(const Part, Column: string; const Value: TValue): TQuery;

begin
  Result := HavingDatePart(Part, Column, '=', Value);
end;

function TQuery.HavingNot(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckBasic);
  C.Name := Column; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQuery.HavingNot(const Column: string; const Value: TValue): TQuery;

begin
  Result := HavingNot(Column, '=', Value);
end;

function TQuery.HavingNot(Group: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQuery.HavingNot(const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := HavingNot(Q); finally Q.Free; end;
end;

function TQuery.HavingNot(const Column, Op: string; Query: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckQuery);
  C.Name := Column; C.Op := Op; C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.HavingNot(const Column, Op: string; const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := HavingNot(Column, Op, Q); finally Q.Free; end;
end;

function TQuery.HavingNotNull(const Column: string): TQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQuery.HavingNotBetween(const Column: string; const Lower, Higher: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckBetween);
  C.Name := Column; C.Value := Lower; C.Value2 := Higher;
  Result := Self;
end;

function TQuery.HavingNotIn(const Column: string; const Values: array of TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckIn);
  C.Name := Column; C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQuery.HavingNotIn(const Column: string; Query: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckInQuery);
  C.Name := Column; C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.HavingNotIn(const Column: string; const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := HavingNotIn(Column, Q); finally Q.Free; end;
end;

function TQuery.HavingNotExists(Query: TQuery): TQuery;
var C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('having', False, True, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.HavingNotExists(const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := HavingNotExists(Q); finally Q.Free; end;
end;

function TQuery.HavingNotLike(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'like'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.HavingNotStarts(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'starts'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.HavingNotEnds(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'ends'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.HavingNotContains(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'contains'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.HavingNotDate(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'date';
  Result := Self;
end;

function TQuery.HavingNotDate(const Column: string; const Value: TValue): TQuery;

begin
  Result := HavingNotDate(Column, '=', Value);
end;

function TQuery.HavingNotTime(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'time';
  Result := Self;
end;

function TQuery.HavingNotTime(const Column: string; const Value: TValue): TQuery;

begin
  Result := HavingNotTime(Column, '=', Value);
end;

function TQuery.HavingNotDatePart(const Part, Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := Part;
  Result := Self;
end;

function TQuery.HavingNotDatePart(const Part, Column: string; const Value: TValue): TQuery;

begin
  Result := HavingNotDatePart(Part, Column, '=', Value);
end;

function TQuery.HavingRaw(const Sql: string; const Bindings: array of TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckRaw);
  C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQuery.HavingRaw(const Sql: string): TQuery;

begin
  Result := HavingRaw(Sql, []);
end;

function TQuery.HavingColumns(const First, Op, Second: string): TQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckColumns);
  C.Name := First; C.Op := Op; C.Extra := Second;
  Result := Self;
end;

function TQuery.HavingSub(Query: TQuery; const Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckSubQuery);
  C.Query := Query.Clone; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQuery.HavingSub(Query: TQuery; const Value: TValue): TQuery;

begin
  Result := HavingSub(Query, '=', Value);
end;

function TQuery.OrHaving(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckBasic);
  C.Name := Column; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQuery.OrHaving(const Column: string; const Value: TValue): TQuery;

begin
  Result := OrHaving(Column, '=', Value);
end;

function TQuery.OrHaving(Group: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQuery.OrHaving(const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := OrHaving(Q); finally Q.Free; end;
end;

function TQuery.OrHaving(const Column, Op: string; Query: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckQuery);
  C.Name := Column; C.Op := Op; C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.OrHaving(const Column, Op: string; const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := OrHaving(Column, Op, Q); finally Q.Free; end;
end;

function TQuery.OrHavingNull(const Column: string): TQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQuery.OrHavingTrue(const Column: string): TQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckBoolean);
  C.Name := Column; C.Value := True;
  Result := Self;
end;

function TQuery.OrHavingFalse(const Column: string): TQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckBoolean);
  C.Name := Column; C.Value := False;
  Result := Self;
end;

function TQuery.OrHavingBetween(const Column: string; const Lower, Higher: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckBetween);
  C.Name := Column; C.Value := Lower; C.Value2 := Higher;
  Result := Self;
end;

function TQuery.OrHavingIn(const Column: string; const Values: array of TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckIn);
  C.Name := Column; C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQuery.OrHavingIn(const Column: string; Query: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckInQuery);
  C.Name := Column; C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.OrHavingIn(const Column: string; const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := OrHavingIn(Column, Q); finally Q.Free; end;
end;

function TQuery.OrHavingExists(Query: TQuery): TQuery;
var C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('having', True, False, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.OrHavingExists(const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := OrHavingExists(Q); finally Q.Free; end;
end;

function TQuery.OrHavingLike(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'like'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.OrHavingStarts(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'starts'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.OrHavingEnds(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'ends'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.OrHavingContains(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'contains'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.OrHavingDate(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'date';
  Result := Self;
end;

function TQuery.OrHavingDate(const Column: string; const Value: TValue): TQuery;

begin
  Result := OrHavingDate(Column, '=', Value);
end;

function TQuery.OrHavingTime(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'time';
  Result := Self;
end;

function TQuery.OrHavingTime(const Column: string; const Value: TValue): TQuery;

begin
  Result := OrHavingTime(Column, '=', Value);
end;

function TQuery.OrHavingDatePart(const Part, Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := Part;
  Result := Self;
end;

function TQuery.OrHavingDatePart(const Part, Column: string; const Value: TValue): TQuery;

begin
  Result := OrHavingDatePart(Part, Column, '=', Value);
end;

function TQuery.OrHavingNot(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckBasic);
  C.Name := Column; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQuery.OrHavingNot(const Column: string; const Value: TValue): TQuery;

begin
  Result := OrHavingNot(Column, '=', Value);
end;

function TQuery.OrHavingNot(Group: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQuery.OrHavingNot(const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := OrHavingNot(Q); finally Q.Free; end;
end;

function TQuery.OrHavingNot(const Column, Op: string; Query: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckQuery);
  C.Name := Column; C.Op := Op; C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.OrHavingNot(const Column, Op: string; const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := OrHavingNot(Column, Op, Q); finally Q.Free; end;
end;

function TQuery.OrHavingNotNull(const Column: string): TQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQuery.OrHavingNotBetween(const Column: string; const Lower, Higher: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckBetween);
  C.Name := Column; C.Value := Lower; C.Value2 := Higher;
  Result := Self;
end;

function TQuery.OrHavingNotIn(const Column: string; const Values: array of TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckIn);
  C.Name := Column; C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQuery.OrHavingNotIn(const Column: string; Query: TQuery): TQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckInQuery);
  C.Name := Column; C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.OrHavingNotIn(const Column: string; const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := OrHavingNotIn(Column, Q); finally Q.Free; end;
end;

function TQuery.OrHavingNotExists(Query: TQuery): TQuery;
var C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('having', True, True, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQuery.OrHavingNotExists(const Callback: TQueryCallback): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := OrHavingNotExists(Q); finally Q.Free; end;
end;

function TQuery.OrHavingNotLike(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'like'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.OrHavingNotStarts(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'starts'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.OrHavingNotEnds(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'ends'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.OrHavingNotContains(const Column: string; const Value: TValue; const EscapeCharacter: string): TQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'contains'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQuery.OrHavingNotDate(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'date';
  Result := Self;
end;

function TQuery.OrHavingNotDate(const Column: string; const Value: TValue): TQuery;

begin
  Result := OrHavingNotDate(Column, '=', Value);
end;

function TQuery.OrHavingNotTime(const Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'time';
  Result := Self;
end;

function TQuery.OrHavingNotTime(const Column: string; const Value: TValue): TQuery;

begin
  Result := OrHavingNotTime(Column, '=', Value);
end;

function TQuery.OrHavingNotDatePart(const Part, Column, Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := Part;
  Result := Self;
end;

function TQuery.OrHavingNotDatePart(const Part, Column: string; const Value: TValue): TQuery;

begin
  Result := OrHavingNotDatePart(Part, Column, '=', Value);
end;

function TQuery.OrHavingRaw(const Sql: string; const Bindings: array of TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckRaw);
  C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQuery.OrHavingRaw(const Sql: string): TQuery;

begin
  Result := OrHavingRaw(Sql, []);
end;

function TQuery.OrHavingColumns(const First, Op, Second: string): TQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckColumns);
  C.Name := First; C.Op := Op; C.Extra := Second;
  Result := Self;
end;

function TQuery.OrHavingSub(Query: TQuery; const Op: string; const Value: TValue): TQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckSubQuery);
  C.Query := Query.Clone; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQuery.OrHavingSub(Query: TQuery; const Value: TValue): TQuery;

begin
  Result := OrHavingSub(Query, '=', Value);
end;

function TQuery.Select(const Columns: array of string): TQuery;
var S, E: string; C: TClause;
begin
  for S in Columns do
    for E in ExpandExpression(S) do
    begin
      C := Add('select', ckIdentifier); C.Name := E; C.IsNot := False;
    end;
  Method := 'select';
  Result := Self;
end;

function TQuery.Select(const Column: string): TQuery;

begin
  Result := Select([Column]);
end;

function TQuery.GroupBy(const Columns: array of string): TQuery;
var S, E: string; C: TClause;
begin
  for S in Columns do
    for E in ExpandExpression(S) do
    begin
      C := Add('group', ckIdentifier); C.Name := E; C.IsNot := False;
    end;
  Result := Self;
end;

function TQuery.GroupBy(const Column: string): TQuery;

begin
  Result := GroupBy([Column]);
end;

function TQuery.OrderBy(const Columns: array of string): TQuery;
var S, E: string; C: TClause;
begin
  for S in Columns do
    for E in ExpandExpression(S) do
    begin
      C := Add('order', ckIdentifier); C.Name := E; C.IsNot := False;
    end;
  Result := Self;
end;

function TQuery.OrderBy(const Column: string): TQuery;

begin
  Result := OrderBy([Column]);
end;

function TQuery.OrderByDesc(const Columns: array of string): TQuery;
var S, E: string; C: TClause;
begin
  for S in Columns do
    for E in ExpandExpression(S) do
    begin
      C := Add('order', ckIdentifier); C.Name := E; C.IsNot := True;
    end;
  Result := Self;
end;

function TQuery.OrderByDesc(const Column: string): TQuery;

begin
  Result := OrderByDesc([Column]);
end;

function TQuery.SelectRaw(const Sql: string; const Bindings: array of TValue): TQuery;
var C: TClause;
begin
  Method := 'select';
  C := Add('select', ckRaw); C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQuery.SelectRaw(const Sql: string): TQuery;

begin
  Result := SelectRaw(Sql, []);
end;

function TQuery.FromRaw(const Sql: string; const Bindings: array of TValue): TQuery;
var C: TClause;
begin
  Remove('from', EngineScope);
  C := Add('from', ckRaw); C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQuery.FromRaw(const Sql: string): TQuery;

begin
  Result := FromRaw(Sql, []);
end;

function TQuery.OrderByRaw(const Sql: string; const Bindings: array of TValue): TQuery;
var C: TClause;
begin
  C := Add('order', ckRaw); C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQuery.OrderByRaw(const Sql: string): TQuery;

begin
  Result := OrderByRaw(Sql, []);
end;

function TQuery.GroupByRaw(const Sql: string; const Bindings: array of TValue): TQuery;
var C: TClause;
begin
  C := Add('group', ckRaw); C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQuery.GroupByRaw(const Sql: string): TQuery;

begin
  Result := GroupByRaw(Sql, []);
end;

function TQuery.CombineRaw(const Sql: string; const Bindings: array of TValue): TQuery;
var C: TClause;
begin
  if Method <> 'select' then raise EQueryException.Create('Only select queries can be combined');
  C := Add('combine', ckRaw); C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQuery.CombineRaw(const Sql: string): TQuery;

begin
  Result := CombineRaw(Sql, []);
end;

function TQuery.UnionRaw(const Sql: string; const Bindings: array of TValue): TQuery;
var C: TClause;
begin
  if Method <> 'select' then raise EQueryException.Create('Only select queries can be combined');
  C := Add('combine', ckRaw); C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQuery.UnionRaw(const Sql: string): TQuery;

begin
  Result := UnionRaw(Sql, []);
end;

function TQuery.ExceptRaw(const Sql: string; const Bindings: array of TValue): TQuery;
var C: TClause;
begin
  if Method <> 'select' then raise EQueryException.Create('Only select queries can be combined');
  C := Add('combine', ckRaw); C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQuery.ExceptRaw(const Sql: string): TQuery;

begin
  Result := ExceptRaw(Sql, []);
end;

function TQuery.IntersectRaw(const Sql: string; const Bindings: array of TValue): TQuery;
var C: TClause;
begin
  if Method <> 'select' then raise EQueryException.Create('Only select queries can be combined');
  C := Add('combine', ckRaw); C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQuery.IntersectRaw(const Sql: string): TQuery;

begin
  Result := IntersectRaw(Sql, []);
end;

function TQuery.AsCount(const Columns: array of string): TQuery;

begin
  if Length(Columns) = 0 then Result := AsAggregate('count', ['*'])
  else Result := AsAggregate('count', Columns);
end;

function TQuery.AsCount(): TQuery;

begin
  Result := AsCount([]);
end;

function TQuery.AsSum(const Column: string): TQuery;

begin
  Result := AsAggregate('sum', [Column]);
end;

function TQuery.AsAvg(const Column: string): TQuery;

begin
  Result := AsAggregate('avg', [Column]);
end;

function TQuery.AsAverage(const Column: string): TQuery;

begin
  Result := AsAggregate('avg', [Column]);
end;

function TQuery.AsMin(const Column: string): TQuery;

begin
  Result := AsAggregate('min', [Column]);
end;

function TQuery.AsMax(const Column: string): TQuery;

begin
  Result := AsAggregate('max', [Column]);
end;

function TQuery.SelectSum(const Column: string; const Filter: TQueryCallback): TQuery;

begin
  Result := SelectAggregate('sum', Column, Filter);
end;

function TQuery.SelectCount(const Column: string; const Filter: TQueryCallback): TQuery;

begin
  Result := SelectAggregate('count', Column, Filter);
end;

function TQuery.SelectAvg(const Column: string; const Filter: TQueryCallback): TQuery;

begin
  Result := SelectAggregate('avg', Column, Filter);
end;

function TQuery.SelectMin(const Column: string; const Filter: TQueryCallback): TQuery;

begin
  Result := SelectAggregate('min', Column, Filter);
end;

function TQuery.SelectMax(const Column: string; const Filter: TQueryCallback): TQuery;

begin
  Result := SelectAggregate('max', Column, Filter);
end;

function TQuery.Union(Query: TQuery; All: Boolean): TQuery;

begin
  Result := Combine('union', All, Query);
end;

function TQuery.Union(const Callback: TQueryCallback; All: Boolean): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := Union(Q, All); finally Q.Free; end;
end;

function TQuery.UnionAll(Query: TQuery): TQuery;

begin
  Result := Union(Query, True);
end;

function TQuery.UnionAll(const Callback: TQueryCallback): TQuery;

begin
  Result := Union(Callback, True);
end;

function TQuery.&Except(Query: TQuery; All: Boolean): TQuery;

begin
  Result := Combine('except', All, Query);
end;

function TQuery.&Except(const Callback: TQueryCallback; All: Boolean): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := &Except(Q, All); finally Q.Free; end;
end;

function TQuery.ExceptAll(Query: TQuery): TQuery;

begin
  Result := &Except(Query, True);
end;

function TQuery.ExceptAll(const Callback: TQueryCallback): TQuery;

begin
  Result := &Except(Callback, True);
end;

function TQuery.Intersect(Query: TQuery; All: Boolean): TQuery;

begin
  Result := Combine('intersect', All, Query);
end;

function TQuery.Intersect(const Callback: TQueryCallback; All: Boolean): TQuery;
var Q: TQuery;
begin
  Q := CallbackQuery(Callback);
  try Result := Intersect(Q, All); finally Q.Free; end;
end;

function TQuery.IntersectAll(Query: TQuery): TQuery;

begin
  Result := Intersect(Query, True);
end;

function TQuery.IntersectAll(const Callback: TQueryCallback): TQuery;

begin
  Result := Intersect(Callback, True);
end;

function TQuery.ForSqlServer(const Callback: TQueryCallback): TQuery;

begin
  Result := &For('sqlsrv', Callback);
end;

function TQuery.ForPostgreSql(const Callback: TQueryCallback): TQuery;

begin
  Result := &For('postgres', Callback);
end;

function TQuery.ForMySql(const Callback: TQueryCallback): TQuery;

begin
  Result := &For('mysql', Callback);
end;

function TQuery.ForSqlite(const Callback: TQueryCallback): TQuery;

begin
  Result := &For('sqlite', Callback);
end;

function TQuery.ForOracle(const Callback: TQueryCallback): TQuery;

begin
  Result := &For('oracle', Callback);
end;

function TQuery.ForFirebird(const Callback: TQueryCallback): TQuery;

begin
  Result := &For('firebird', Callback);
end;
