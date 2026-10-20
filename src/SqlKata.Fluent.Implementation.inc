function TQueryObject.Where(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckBasic);
  C.Name := Column; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQueryObject.Where(const Column: string; const Value: TValue): IQuery;

begin
  Result := Where(Column, '=', Value);
end;

function TQueryObject.Where(Group: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.Where(const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := Where(Q);
end;

function TQueryObject.Where(const Column, Op: string; Query: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckQuery);
  C.Name := Column; C.Op := Op; C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.Where(const Column, Op: string; const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := Where(Column, Op, Q);
end;

function TQueryObject.WhereNull(const Column: string): IQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.WhereTrue(const Column: string): IQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckBoolean);
  C.Name := Column; C.Value := True;
  Result := Self;
end;

function TQueryObject.WhereFalse(const Column: string): IQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckBoolean);
  C.Name := Column; C.Value := False;
  Result := Self;
end;

function TQueryObject.WhereBetween(const Column: string; const Lower, Higher: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckBetween);
  C.Name := Column; C.Value := Lower; C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.WhereIn(const Column: string; const Values: array of TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckIn);
  C.Name := Column; C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.WhereIn(const Column: string; Query: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckInQuery);
  C.Name := Column; C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.WhereIn(const Column: string; const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := WhereIn(Column, Q);
end;

function TQueryObject.WhereExists(Query: IQuery): IQuery;
var C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('where', False, False, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.WhereExists(const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := WhereExists(Q);
end;

function TQueryObject.WhereLike(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'like'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereStarts(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'starts'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereEnds(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'ends'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereContains(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'contains'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereDate(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.WhereDate(const Column: string; const Value: TValue): IQuery;

begin
  Result := WhereDate(Column, '=', Value);
end;

function TQueryObject.WhereTime(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.WhereTime(const Column: string; const Value: TValue): IQuery;

begin
  Result := WhereTime(Column, '=', Value);
end;

function TQueryObject.WhereDatePart(const Part, Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := Part;
  Result := Self;
end;

function TQueryObject.WhereDatePart(const Part, Column: string; const Value: TValue): IQuery;

begin
  Result := WhereDatePart(Part, Column, '=', Value);
end;

function TQueryObject.WhereNot(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckBasic);
  C.Name := Column; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQueryObject.WhereNot(const Column: string; const Value: TValue): IQuery;

begin
  Result := WhereNot(Column, '=', Value);
end;

function TQueryObject.WhereNot(Group: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.WhereNot(const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := WhereNot(Q);
end;

function TQueryObject.WhereNot(const Column, Op: string; Query: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckQuery);
  C.Name := Column; C.Op := Op; C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.WhereNot(const Column, Op: string; const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := WhereNot(Column, Op, Q);
end;

function TQueryObject.WhereNotNull(const Column: string): IQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.WhereNotBetween(const Column: string; const Lower, Higher: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckBetween);
  C.Name := Column; C.Value := Lower; C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.WhereNotIn(const Column: string; const Values: array of TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckIn);
  C.Name := Column; C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.WhereNotIn(const Column: string; Query: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckInQuery);
  C.Name := Column; C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.WhereNotIn(const Column: string; const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := WhereNotIn(Column, Q);
end;

function TQueryObject.WhereNotExists(Query: IQuery): IQuery;
var C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('where', False, True, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.WhereNotExists(const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := WhereNotExists(Q);
end;

function TQueryObject.WhereNotLike(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'like'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereNotStarts(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'starts'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereNotEnds(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'ends'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereNotContains(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'contains'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereNotDate(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.WhereNotDate(const Column: string; const Value: TValue): IQuery;

begin
  Result := WhereNotDate(Column, '=', Value);
end;

function TQueryObject.WhereNotTime(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.WhereNotTime(const Column: string; const Value: TValue): IQuery;

begin
  Result := WhereNotTime(Column, '=', Value);
end;

function TQueryObject.WhereNotDatePart(const Part, Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', False, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := Part;
  Result := Self;
end;

function TQueryObject.WhereNotDatePart(const Part, Column: string; const Value: TValue): IQuery;

begin
  Result := WhereNotDatePart(Part, Column, '=', Value);
end;

function TQueryObject.WhereRaw(const Sql: string; const Bindings: array of TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckRaw);
  C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.WhereRaw(const Sql: string): IQuery;

begin
  Result := WhereRaw(Sql, []);
end;

function TQueryObject.WhereColumns(const First, Op, Second: string): IQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckColumns);
  C.Name := First; C.Op := Op; C.Extra := Second;
  Result := Self;
end;

function TQueryObject.WhereSub(Query: IQuery; const Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', False, False, ckSubQuery);
  C.Query := Query.Clone; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQueryObject.WhereSub(Query: IQuery; const Value: TValue): IQuery;

begin
  Result := WhereSub(Query, '=', Value);
end;

function TQueryObject.OrWhere(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckBasic);
  C.Name := Column; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQueryObject.OrWhere(const Column: string; const Value: TValue): IQuery;

begin
  Result := OrWhere(Column, '=', Value);
end;

function TQueryObject.OrWhere(Group: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.OrWhere(const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhere(Q);
end;

function TQueryObject.OrWhere(const Column, Op: string; Query: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckQuery);
  C.Name := Column; C.Op := Op; C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrWhere(const Column, Op: string; const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhere(Column, Op, Q);
end;

function TQueryObject.OrWhereNull(const Column: string): IQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.OrWhereTrue(const Column: string): IQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckBoolean);
  C.Name := Column; C.Value := True;
  Result := Self;
end;

function TQueryObject.OrWhereFalse(const Column: string): IQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckBoolean);
  C.Name := Column; C.Value := False;
  Result := Self;
end;

function TQueryObject.OrWhereBetween(const Column: string; const Lower, Higher: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckBetween);
  C.Name := Column; C.Value := Lower; C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.OrWhereIn(const Column: string; const Values: array of TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckIn);
  C.Name := Column; C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.OrWhereIn(const Column: string; Query: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckInQuery);
  C.Name := Column; C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrWhereIn(const Column: string; const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhereIn(Column, Q);
end;

function TQueryObject.OrWhereExists(Query: IQuery): IQuery;
var C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('where', True, False, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrWhereExists(const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhereExists(Q);
end;

function TQueryObject.OrWhereLike(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'like'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereStarts(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'starts'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereEnds(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'ends'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereContains(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'contains'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereDate(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.OrWhereDate(const Column: string; const Value: TValue): IQuery;

begin
  Result := OrWhereDate(Column, '=', Value);
end;

function TQueryObject.OrWhereTime(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.OrWhereTime(const Column: string; const Value: TValue): IQuery;

begin
  Result := OrWhereTime(Column, '=', Value);
end;

function TQueryObject.OrWhereDatePart(const Part, Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := Part;
  Result := Self;
end;

function TQueryObject.OrWhereDatePart(const Part, Column: string; const Value: TValue): IQuery;

begin
  Result := OrWhereDatePart(Part, Column, '=', Value);
end;

function TQueryObject.OrWhereNot(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckBasic);
  C.Name := Column; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQueryObject.OrWhereNot(const Column: string; const Value: TValue): IQuery;

begin
  Result := OrWhereNot(Column, '=', Value);
end;

function TQueryObject.OrWhereNot(Group: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.OrWhereNot(const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhereNot(Q);
end;

function TQueryObject.OrWhereNot(const Column, Op: string; Query: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckQuery);
  C.Name := Column; C.Op := Op; C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrWhereNot(const Column, Op: string; const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhereNot(Column, Op, Q);
end;

function TQueryObject.OrWhereNotNull(const Column: string): IQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.OrWhereNotBetween(const Column: string; const Lower, Higher: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckBetween);
  C.Name := Column; C.Value := Lower; C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.OrWhereNotIn(const Column: string; const Values: array of TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckIn);
  C.Name := Column; C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.OrWhereNotIn(const Column: string; Query: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckInQuery);
  C.Name := Column; C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrWhereNotIn(const Column: string; const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhereNotIn(Column, Q);
end;

function TQueryObject.OrWhereNotExists(Query: IQuery): IQuery;
var C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('where', True, True, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrWhereNotExists(const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhereNotExists(Q);
end;

function TQueryObject.OrWhereNotLike(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'like'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereNotStarts(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'starts'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereNotEnds(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'ends'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereNotContains(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'contains'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereNotDate(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.OrWhereNotDate(const Column: string; const Value: TValue): IQuery;

begin
  Result := OrWhereNotDate(Column, '=', Value);
end;

function TQueryObject.OrWhereNotTime(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.OrWhereNotTime(const Column: string; const Value: TValue): IQuery;

begin
  Result := OrWhereNotTime(Column, '=', Value);
end;

function TQueryObject.OrWhereNotDatePart(const Part, Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', True, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := Part;
  Result := Self;
end;

function TQueryObject.OrWhereNotDatePart(const Part, Column: string; const Value: TValue): IQuery;

begin
  Result := OrWhereNotDatePart(Part, Column, '=', Value);
end;

function TQueryObject.OrWhereRaw(const Sql: string; const Bindings: array of TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckRaw);
  C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.OrWhereRaw(const Sql: string): IQuery;

begin
  Result := OrWhereRaw(Sql, []);
end;

function TQueryObject.OrWhereColumns(const First, Op, Second: string): IQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckColumns);
  C.Name := First; C.Op := Op; C.Extra := Second;
  Result := Self;
end;

function TQueryObject.OrWhereSub(Query: IQuery; const Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('where', True, False, ckSubQuery);
  C.Query := Query.Clone; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQueryObject.OrWhereSub(Query: IQuery; const Value: TValue): IQuery;

begin
  Result := OrWhereSub(Query, '=', Value);
end;

function TQueryObject.Having(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckBasic);
  C.Name := Column; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQueryObject.Having(const Column: string; const Value: TValue): IQuery;

begin
  Result := Having(Column, '=', Value);
end;

function TQueryObject.Having(Group: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.Having(const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := Having(Q);
end;

function TQueryObject.Having(const Column, Op: string; Query: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckQuery);
  C.Name := Column; C.Op := Op; C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.Having(const Column, Op: string; const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := Having(Column, Op, Q);
end;

function TQueryObject.HavingNull(const Column: string): IQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.HavingTrue(const Column: string): IQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckBoolean);
  C.Name := Column; C.Value := True;
  Result := Self;
end;

function TQueryObject.HavingFalse(const Column: string): IQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckBoolean);
  C.Name := Column; C.Value := False;
  Result := Self;
end;

function TQueryObject.HavingBetween(const Column: string; const Lower, Higher: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckBetween);
  C.Name := Column; C.Value := Lower; C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.HavingIn(const Column: string; const Values: array of TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckIn);
  C.Name := Column; C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.HavingIn(const Column: string; Query: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckInQuery);
  C.Name := Column; C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.HavingIn(const Column: string; const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := HavingIn(Column, Q);
end;

function TQueryObject.HavingExists(Query: IQuery): IQuery;
var C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('having', False, False, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.HavingExists(const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := HavingExists(Q);
end;

function TQueryObject.HavingLike(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'like'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingStarts(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'starts'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingEnds(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'ends'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingContains(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'contains'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingDate(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.HavingDate(const Column: string; const Value: TValue): IQuery;

begin
  Result := HavingDate(Column, '=', Value);
end;

function TQueryObject.HavingTime(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.HavingTime(const Column: string; const Value: TValue): IQuery;

begin
  Result := HavingTime(Column, '=', Value);
end;

function TQueryObject.HavingDatePart(const Part, Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := Part;
  Result := Self;
end;

function TQueryObject.HavingDatePart(const Part, Column: string; const Value: TValue): IQuery;

begin
  Result := HavingDatePart(Part, Column, '=', Value);
end;

function TQueryObject.HavingNot(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckBasic);
  C.Name := Column; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQueryObject.HavingNot(const Column: string; const Value: TValue): IQuery;

begin
  Result := HavingNot(Column, '=', Value);
end;

function TQueryObject.HavingNot(Group: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.HavingNot(const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := HavingNot(Q);
end;

function TQueryObject.HavingNot(const Column, Op: string; Query: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckQuery);
  C.Name := Column; C.Op := Op; C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.HavingNot(const Column, Op: string; const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := HavingNot(Column, Op, Q);
end;

function TQueryObject.HavingNotNull(const Column: string): IQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.HavingNotBetween(const Column: string; const Lower, Higher: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckBetween);
  C.Name := Column; C.Value := Lower; C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.HavingNotIn(const Column: string; const Values: array of TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckIn);
  C.Name := Column; C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.HavingNotIn(const Column: string; Query: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckInQuery);
  C.Name := Column; C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.HavingNotIn(const Column: string; const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := HavingNotIn(Column, Q);
end;

function TQueryObject.HavingNotExists(Query: IQuery): IQuery;
var C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('having', False, True, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.HavingNotExists(const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := HavingNotExists(Q);
end;

function TQueryObject.HavingNotLike(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'like'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingNotStarts(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'starts'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingNotEnds(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'ends'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingNotContains(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'contains'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingNotDate(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.HavingNotDate(const Column: string; const Value: TValue): IQuery;

begin
  Result := HavingNotDate(Column, '=', Value);
end;

function TQueryObject.HavingNotTime(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.HavingNotTime(const Column: string; const Value: TValue): IQuery;

begin
  Result := HavingNotTime(Column, '=', Value);
end;

function TQueryObject.HavingNotDatePart(const Part, Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', False, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := Part;
  Result := Self;
end;

function TQueryObject.HavingNotDatePart(const Part, Column: string; const Value: TValue): IQuery;

begin
  Result := HavingNotDatePart(Part, Column, '=', Value);
end;

function TQueryObject.HavingRaw(const Sql: string; const Bindings: array of TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckRaw);
  C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.HavingRaw(const Sql: string): IQuery;

begin
  Result := HavingRaw(Sql, []);
end;

function TQueryObject.HavingColumns(const First, Op, Second: string): IQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckColumns);
  C.Name := First; C.Op := Op; C.Extra := Second;
  Result := Self;
end;

function TQueryObject.HavingSub(Query: IQuery; const Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', False, False, ckSubQuery);
  C.Query := Query.Clone; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQueryObject.HavingSub(Query: IQuery; const Value: TValue): IQuery;

begin
  Result := HavingSub(Query, '=', Value);
end;

function TQueryObject.OrHaving(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckBasic);
  C.Name := Column; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQueryObject.OrHaving(const Column: string; const Value: TValue): IQuery;

begin
  Result := OrHaving(Column, '=', Value);
end;

function TQueryObject.OrHaving(Group: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.OrHaving(const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHaving(Q);
end;

function TQueryObject.OrHaving(const Column, Op: string; Query: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckQuery);
  C.Name := Column; C.Op := Op; C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrHaving(const Column, Op: string; const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHaving(Column, Op, Q);
end;

function TQueryObject.OrHavingNull(const Column: string): IQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.OrHavingTrue(const Column: string): IQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckBoolean);
  C.Name := Column; C.Value := True;
  Result := Self;
end;

function TQueryObject.OrHavingFalse(const Column: string): IQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckBoolean);
  C.Name := Column; C.Value := False;
  Result := Self;
end;

function TQueryObject.OrHavingBetween(const Column: string; const Lower, Higher: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckBetween);
  C.Name := Column; C.Value := Lower; C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.OrHavingIn(const Column: string; const Values: array of TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckIn);
  C.Name := Column; C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.OrHavingIn(const Column: string; Query: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckInQuery);
  C.Name := Column; C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrHavingIn(const Column: string; const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHavingIn(Column, Q);
end;

function TQueryObject.OrHavingExists(Query: IQuery): IQuery;
var C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('having', True, False, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrHavingExists(const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHavingExists(Q);
end;

function TQueryObject.OrHavingLike(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'like'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingStarts(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'starts'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingEnds(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'ends'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingContains(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'contains'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingDate(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.OrHavingDate(const Column: string; const Value: TValue): IQuery;

begin
  Result := OrHavingDate(Column, '=', Value);
end;

function TQueryObject.OrHavingTime(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.OrHavingTime(const Column: string; const Value: TValue): IQuery;

begin
  Result := OrHavingTime(Column, '=', Value);
end;

function TQueryObject.OrHavingDatePart(const Part, Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := Part;
  Result := Self;
end;

function TQueryObject.OrHavingDatePart(const Part, Column: string; const Value: TValue): IQuery;

begin
  Result := OrHavingDatePart(Part, Column, '=', Value);
end;

function TQueryObject.OrHavingNot(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckBasic);
  C.Name := Column; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQueryObject.OrHavingNot(const Column: string; const Value: TValue): IQuery;

begin
  Result := OrHavingNot(Column, '=', Value);
end;

function TQueryObject.OrHavingNot(Group: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.OrHavingNot(const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHavingNot(Q);
end;

function TQueryObject.OrHavingNot(const Column, Op: string; Query: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckQuery);
  C.Name := Column; C.Op := Op; C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrHavingNot(const Column, Op: string; const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHavingNot(Column, Op, Q);
end;

function TQueryObject.OrHavingNotNull(const Column: string): IQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.OrHavingNotBetween(const Column: string; const Lower, Higher: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckBetween);
  C.Name := Column; C.Value := Lower; C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.OrHavingNotIn(const Column: string; const Values: array of TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckIn);
  C.Name := Column; C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.OrHavingNotIn(const Column: string; Query: IQuery): IQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckInQuery);
  C.Name := Column; C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrHavingNotIn(const Column: string; const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHavingNotIn(Column, Q);
end;

function TQueryObject.OrHavingNotExists(Query: IQuery): IQuery;
var C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('having', True, True, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrHavingNotExists(const Callback: TQueryCallback): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHavingNotExists(Q);
end;

function TQueryObject.OrHavingNotLike(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'like'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingNotStarts(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'starts'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingNotEnds(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'ends'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingNotContains(const Column: string; const Value: TValue; const EscapeCharacter: string): IQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckString);
  C.Name := Column; C.Value := Value; C.Op := 'contains'; C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingNotDate(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.OrHavingNotDate(const Column: string; const Value: TValue): IQuery;

begin
  Result := OrHavingNotDate(Column, '=', Value);
end;

function TQueryObject.OrHavingNotTime(const Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.OrHavingNotTime(const Column: string; const Value: TValue): IQuery;

begin
  Result := OrHavingNotTime(Column, '=', Value);
end;

function TQueryObject.OrHavingNotDatePart(const Part, Column, Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', True, True, ckDate);
  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := Part;
  Result := Self;
end;

function TQueryObject.OrHavingNotDatePart(const Part, Column: string; const Value: TValue): IQuery;

begin
  Result := OrHavingNotDatePart(Part, Column, '=', Value);
end;

function TQueryObject.OrHavingRaw(const Sql: string; const Bindings: array of TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckRaw);
  C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.OrHavingRaw(const Sql: string): IQuery;

begin
  Result := OrHavingRaw(Sql, []);
end;

function TQueryObject.OrHavingColumns(const First, Op, Second: string): IQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckColumns);
  C.Name := First; C.Op := Op; C.Extra := Second;
  Result := Self;
end;

function TQueryObject.OrHavingSub(Query: IQuery; const Op: string; const Value: TValue): IQuery;
var C: TClause;
begin
  C := Condition('having', True, False, ckSubQuery);
  C.Query := Query.Clone; C.Op := Op; C.Value := Value;
  Result := Self;
end;

function TQueryObject.OrHavingSub(Query: IQuery; const Value: TValue): IQuery;

begin
  Result := OrHavingSub(Query, '=', Value);
end;

function TQueryObject.Select(const Columns: array of string): IQuery;
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

function TQueryObject.Select(const Column: string): IQuery;

begin
  Result := Select([Column]);
end;

function TQueryObject.GroupBy(const Columns: array of string): IQuery;
var S, E: string; C: TClause;
begin
  for S in Columns do
    for E in ExpandExpression(S) do
    begin
      C := Add('group', ckIdentifier); C.Name := E; C.IsNot := False;
    end;
  Result := Self;
end;

function TQueryObject.GroupBy(const Column: string): IQuery;

begin
  Result := GroupBy([Column]);
end;

function TQueryObject.OrderBy(const Columns: array of string): IQuery;
var S, E: string; C: TClause;
begin
  for S in Columns do
    for E in ExpandExpression(S) do
    begin
      C := Add('order', ckIdentifier); C.Name := E; C.IsNot := False;
    end;
  Result := Self;
end;

function TQueryObject.OrderBy(const Column: string): IQuery;

begin
  Result := OrderBy([Column]);
end;

function TQueryObject.OrderByDesc(const Columns: array of string): IQuery;
var S, E: string; C: TClause;
begin
  for S in Columns do
    for E in ExpandExpression(S) do
    begin
      C := Add('order', ckIdentifier); C.Name := E; C.IsNot := True;
    end;
  Result := Self;
end;

function TQueryObject.OrderByDesc(const Column: string): IQuery;

begin
  Result := OrderByDesc([Column]);
end;

function TQueryObject.SelectRaw(const Sql: string; const Bindings: array of TValue): IQuery;
var C: TClause;
begin
  Method := 'select';
  C := Add('select', ckRaw); C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.SelectRaw(const Sql: string): IQuery;

begin
  Result := SelectRaw(Sql, []);
end;

function TQueryObject.FromRaw(const Sql: string; const Bindings: array of TValue): IQuery;
var C: TClause;
begin
  Remove('from', EngineScope);
  C := Add('from', ckRaw); C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.FromRaw(const Sql: string): IQuery;

begin
  Result := FromRaw(Sql, []);
end;

function TQueryObject.OrderByRaw(const Sql: string; const Bindings: array of TValue): IQuery;
var C: TClause;
begin
  C := Add('order', ckRaw); C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.OrderByRaw(const Sql: string): IQuery;

begin
  Result := OrderByRaw(Sql, []);
end;

function TQueryObject.GroupByRaw(const Sql: string; const Bindings: array of TValue): IQuery;
var C: TClause;
begin
  C := Add('group', ckRaw); C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.GroupByRaw(const Sql: string): IQuery;

begin
  Result := GroupByRaw(Sql, []);
end;

function TQueryObject.CombineRaw(const Sql: string; const Bindings: array of TValue): IQuery;
var C: TClause;
begin
  if Method <> 'select' then raise EQueryException.Create('Only select queries can be combined');
  C := Add('combine', ckRaw); C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.CombineRaw(const Sql: string): IQuery;

begin
  Result := CombineRaw(Sql, []);
end;

function TQueryObject.UnionRaw(const Sql: string; const Bindings: array of TValue): IQuery;
var C: TClause;
begin
  if Method <> 'select' then raise EQueryException.Create('Only select queries can be combined');
  C := Add('combine', ckRaw); C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.UnionRaw(const Sql: string): IQuery;

begin
  Result := UnionRaw(Sql, []);
end;

function TQueryObject.ExceptRaw(const Sql: string; const Bindings: array of TValue): IQuery;
var C: TClause;
begin
  if Method <> 'select' then raise EQueryException.Create('Only select queries can be combined');
  C := Add('combine', ckRaw); C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.ExceptRaw(const Sql: string): IQuery;

begin
  Result := ExceptRaw(Sql, []);
end;

function TQueryObject.IntersectRaw(const Sql: string; const Bindings: array of TValue): IQuery;
var C: TClause;
begin
  if Method <> 'select' then raise EQueryException.Create('Only select queries can be combined');
  C := Add('combine', ckRaw); C.Name := Sql; C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.IntersectRaw(const Sql: string): IQuery;

begin
  Result := IntersectRaw(Sql, []);
end;

function TQueryObject.AsCount(const Columns: array of string): IQuery;

begin
  if Length(Columns) = 0 then Result := AsAggregate('count', ['*'])
  else Result := AsAggregate('count', Columns);
end;

function TQueryObject.AsCount(): IQuery;

begin
  Result := AsCount([]);
end;

function TQueryObject.AsSum(const Column: string): IQuery;

begin
  Result := AsAggregate('sum', [Column]);
end;

function TQueryObject.AsAvg(const Column: string): IQuery;

begin
  Result := AsAggregate('avg', [Column]);
end;

function TQueryObject.AsAverage(const Column: string): IQuery;

begin
  Result := AsAggregate('avg', [Column]);
end;

function TQueryObject.AsMin(const Column: string): IQuery;

begin
  Result := AsAggregate('min', [Column]);
end;

function TQueryObject.AsMax(const Column: string): IQuery;

begin
  Result := AsAggregate('max', [Column]);
end;

function TQueryObject.SelectSum(const Column: string; const Filter: TQueryCallback): IQuery;

begin
  Result := SelectAggregate('sum', Column, Filter);
end;

function TQueryObject.SelectCount(const Column: string; const Filter: TQueryCallback): IQuery;

begin
  Result := SelectAggregate('count', Column, Filter);
end;

function TQueryObject.SelectAvg(const Column: string; const Filter: TQueryCallback): IQuery;

begin
  Result := SelectAggregate('avg', Column, Filter);
end;

function TQueryObject.SelectMin(const Column: string; const Filter: TQueryCallback): IQuery;

begin
  Result := SelectAggregate('min', Column, Filter);
end;

function TQueryObject.SelectMax(const Column: string; const Filter: TQueryCallback): IQuery;

begin
  Result := SelectAggregate('max', Column, Filter);
end;

function TQueryObject.Union(Query: IQuery; All: Boolean): IQuery;

begin
  Result := Combine('union', All, Query);
end;

function TQueryObject.Union(const Callback: TQueryCallback; All: Boolean): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := Union(Q, All);
end;

function TQueryObject.UnionAll(Query: IQuery): IQuery;

begin
  Result := Union(Query, True);
end;

function TQueryObject.UnionAll(const Callback: TQueryCallback): IQuery;

begin
  Result := Union(Callback, True);
end;

function TQueryObject.&Except(Query: IQuery; All: Boolean): IQuery;

begin
  Result := Combine('except', All, Query);
end;

function TQueryObject.&Except(const Callback: TQueryCallback; All: Boolean): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := &Except(Q, All);
end;

function TQueryObject.ExceptAll(Query: IQuery): IQuery;

begin
  Result := &Except(Query, True);
end;

function TQueryObject.ExceptAll(const Callback: TQueryCallback): IQuery;

begin
  Result := &Except(Callback, True);
end;

function TQueryObject.Intersect(Query: IQuery; All: Boolean): IQuery;

begin
  Result := Combine('intersect', All, Query);
end;

function TQueryObject.Intersect(const Callback: TQueryCallback; All: Boolean): IQuery;
var Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := Intersect(Q, All);
end;

function TQueryObject.IntersectAll(Query: IQuery): IQuery;

begin
  Result := Intersect(Query, True);
end;

function TQueryObject.IntersectAll(const Callback: TQueryCallback): IQuery;

begin
  Result := Intersect(Callback, True);
end;

function TQueryObject.ForSqlServer(const Callback: TQueryCallback): IQuery;

begin
  Result := &For('sqlsrv', Callback);
end;

function TQueryObject.ForPostgreSql(const Callback: TQueryCallback): IQuery;

begin
  Result := &For('postgres', Callback);
end;

function TQueryObject.ForMySql(const Callback: TQueryCallback): IQuery;

begin
  Result := &For('mysql', Callback);
end;

function TQueryObject.ForSqlite(const Callback: TQueryCallback): IQuery;

begin
  Result := &For('sqlite', Callback);
end;

function TQueryObject.ForOracle(const Callback: TQueryCallback): IQuery;

begin
  Result := &For('oracle', Callback);
end;

function TQueryObject.ForFirebird(const Callback: TQueryCallback): IQuery;

begin
  Result := &For('firebird', Callback);
end;
