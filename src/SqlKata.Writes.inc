function TQuery.AsAggregate(const Aggregate: string; const Columns: array of string): TQuery;
var C: TClause;
begin
  if not MatchText(Aggregate, ['count','sum','avg','min','max']) then
    raise EQueryException.Create('Invalid aggregate');
  ClearComponent('aggregate'); C := Add('aggregate', ckAggregate);
  C.Op := Aggregate; C.Columns := CopyStrings(Columns); Method := 'aggregate'; Result := Self;
end;

function TQuery.AsInsert(const Columns: array of string; const Values: array of TValue): TQuery;
var C: TClause;
begin
  if (Length(Columns) = 0) or (Length(Columns) <> Length(Values)) then
    raise EQueryException.Create('Columns and values must be nonempty with equal counts');
  Remove('insert', EngineScope); C := Add('insert', ckInsert);
  C.Columns := CopyStrings(Columns); C.Values := CopyValues(Values);
  Method := 'insert'; Result := Self;
end;

function TQuery.AsInsert(const Columns: array of string; const Rows: TRows): TQuery;
var Row: TValues; C: TClause;
begin
  if (Length(Columns) = 0) or (Length(Rows) = 0) then raise EQueryException.Create('Columns and rows cannot be empty');
  for Row in Rows do if Length(Row) <> Length(Columns) then raise EQueryException.Create('Column/value count mismatch');
  Remove('insert', EngineScope);
  for Row in Rows do begin C := Add('insert', ckInsert); C.Columns := CopyStrings(Columns); C.Values := Copy(Row); end;
  Method := 'insert'; Result := Self;
end;

function TQuery.AsInsert(const Columns: array of string; Query: TQuery): TQuery;
var C: TClause;
begin
  Remove('insert', EngineScope); C := Add('insert', ckQuery);
  C.Columns := CopyStrings(Columns); C.Query := Query.Clone;
  Method := 'insert'; Result := Self;
end;

function TQuery.AsInsert(const Values: array of TPair<string,TValue>; ReturnId: Boolean): TQuery;
var Columns: TArray<string>; Data: TValues; I: Integer;
begin
  SetLength(Columns, Length(Values)); SetLength(Data, Length(Values));
  for I := 0 to High(Values) do begin Columns[I] := Values[I].Key; Data[I] := Values[I].Value; end;
  Result := AsInsert(Columns, Data); GetOne('insert', EngineScope).ReturnId := ReturnId;
end;

function TQuery.AsUpdate(const Columns: array of string; const Values: array of TValue): TQuery;
var C: TClause;
begin
  if (Length(Columns) = 0) or (Length(Columns) <> Length(Values)) then
    raise EQueryException.Create('Columns and values must be nonempty with equal counts');
  Remove('update', EngineScope); C := Add('update', ckInsert);
  C.Columns := CopyStrings(Columns); C.Values := CopyValues(Values);
  Method := 'update'; Result := Self;
end;

function TQuery.AsUpdate(const Values: array of TPair<string,TValue>): TQuery;
var Columns: TArray<string>; Data: TValues; I: Integer;
begin
  SetLength(Columns, Length(Values)); SetLength(Data, Length(Values));
  for I := 0 to High(Values) do begin Columns[I] := Values[I].Key; Data[I] := Values[I].Value; end;
  Result := AsUpdate(Columns, Data);
end;

function TQuery.AsDelete: TQuery;
begin Method := 'delete'; Result := Self; end;
function TQuery.AsIncrement(const Column: string; Value: Integer): TQuery;
var C: TClause;
begin
  Remove('update', EngineScope); C := Add('update', ckIncrement);
  C.Name := Column; C.Value := Value; Method := 'update'; Result := Self;
end;
function TQuery.AsDecrement(const Column: string; Value: Integer): TQuery;
begin Result := AsIncrement(Column, -Value); end;

function TQuery.DataPairs(Data: TObject; ConsiderKeys: Boolean): TArray<TPair<string,TValue>>;
var Context: TRttiContext; Prop: TRttiProperty; Attr: TCustomAttribute;
  List: TList<TPair<string,TValue>>; Name: string; Skip, IsKey: Boolean; V: TValue;
begin
  if Data = nil then raise EArgumentNilException.Create('Data');
  Context := TRttiContext.Create;
  List := TList<TPair<string,TValue>>.Create;
  try
    for Prop in Context.GetType(Data.ClassType).GetProperties do
    begin
      if not Prop.IsReadable then Continue;
      Name := Prop.Name; Skip := False; IsKey := False;
      for Attr in Prop.GetAttributes do
      begin
        if Attr is IgnoreAttribute then Skip := True;
        if Attr is ColumnAttribute then Name := ColumnAttribute(Attr).Name;
        if Attr is KeyAttribute then IsKey := True;
      end;
      if Skip then Continue;
      V := Prop.GetValue(Data); List.Add(TPair<string,TValue>.Create(Name, V));
      if ConsiderKeys and IsKey then Where(Name, V);
    end;
    Result := List.ToArray;
  finally List.Free; Context.Free; end;
end;
function TQuery.AsInsert(Data: TObject; ReturnId: Boolean): TQuery;
begin Result := AsInsert(DataPairs(Data, False), ReturnId); end;
function TQuery.AsUpdate(Data: TObject): TQuery;
begin Result := AsUpdate(DataPairs(Data, True)); end;
function TQuery.Where(const Values: array of TPair<string,TValue>): TQuery;
var Pair: TPair<string,TValue>; OrFlag, NotFlag: Boolean;
begin
  OrFlag := FOrFlag; NotFlag := FNot;
  for Pair in Values do begin FOrFlag := OrFlag; FNot := NotFlag; Where(Pair.Key, Pair.Value); end;
  Result := Self;
end;
function TQuery.Where(Data: TObject): TQuery;
begin Result := Where(DataPairs(Data, False)); end;

