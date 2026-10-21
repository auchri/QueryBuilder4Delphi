unit QueryBuilder4Delphi.Query.Writes;

interface

uses
  System.Rtti, System.Generics.Collections, QueryBuilder4Delphi.Query.Core;

type
  // Stateless implementation shared by the public fluent write overloads.
  TQueryWrites = class
  private
    class procedure SplitPairs(const Pairs: array of TPair<string, TValue>;
      out Columns: TArray<string>; out Values: TValues); static;
  public
    class function AsAggregate(const Target: IQuery; const Aggregate: string;
      const Columns: array of string): IQuery; static;
    class function AsInsert(const Target: IQuery;
      const Columns: array of string; const Values: array of TValue): IQuery;
      overload; static;
    class function AsInsert(const Target: IQuery;
      const Columns: array of string; const Rows: TRows): IQuery;
      overload; static;
    class function AsInsert(const Target: IQuery;
      const Columns: array of string; const Source: IQuery): IQuery;
      overload; static;
    class function AsInsert(const Target: IQuery;
      const Pairs: array of TPair<string, TValue>; ReturnId: Boolean): IQuery;
      overload; static;
    class function AsUpdate(const Target: IQuery;
      const Columns: array of string; const Values: array of TValue): IQuery;
      overload; static;
    class function AsUpdate(const Target: IQuery;
      const Pairs: array of TPair<string, TValue>): IQuery; overload; static;
    class function AsDelete(const Target: IQuery): IQuery; static;
    class function AsIncrement(const Target: IQuery; const Column: string;
      Value: Integer): IQuery; static;
    class function AsDecrement(const Target: IQuery; const Column: string;
      Value: Integer): IQuery; static;
  end;

implementation

uses
  System.RegularExpressions;

class procedure TQueryWrites.SplitPairs(const Pairs
  : array of TPair<string, TValue>; out Columns: TArray<string>;
  out Values: TValues);
var
  I: Integer;
begin
  SetLength(Columns, Length(Pairs));
  SetLength(Values, Length(Pairs));
  for I := 0 to High(Pairs) do
  begin
    Columns[I] := Pairs[I].Key;
    Values[I] := Pairs[I].Value;
  end;
end;

class function TQueryWrites.AsAggregate(const Target: IQuery;
  const Aggregate: string; const Columns: array of string): IQuery;
var
  Clause: TClause;
begin
  if not TRegEx.IsMatch(Aggregate, '^[A-Za-z_][A-Za-z_0-9]*$') then
    raise EQueryException.Create('Invalid aggregate');
  Target.ClearComponent('aggregate');
  Clause := Target.Add('aggregate', ckAggregate);
  Clause.Op := Aggregate;
  Clause.Columns := CopyStrings(Columns);
  Target.Method := 'aggregate';
  Result := Target;
end;

class function TQueryWrites.AsInsert(const Target: IQuery;
  const Columns: array of string; const Values: array of TValue): IQuery;
var
  Clause: TClause;
begin
  if (Length(Columns) = 0) or (Length(Columns) <> Length(Values)) then
    raise EQueryException.Create
      ('Columns and values must be nonempty with equal counts');
  Target.Remove('insert', Target.EngineScope);
  Clause := Target.Add('insert', ckInsert);
  Clause.Columns := CopyStrings(Columns);
  Clause.Values := CopyValues(Values);
  Target.Method := 'insert';
  Result := Target;
end;

class function TQueryWrites.AsInsert(const Target: IQuery;
  const Columns: array of string; const Rows: TRows): IQuery;
var
  Row: TValues;
  Clause: TClause;
begin
  if (Length(Columns) = 0) or (Length(Rows) = 0) then
    raise EQueryException.Create('Columns and rows cannot be empty');
  for Row in Rows do
    if Length(Row) <> Length(Columns) then
      raise EQueryException.Create('Column/value count mismatch');

  Target.Remove('insert', Target.EngineScope);
  for Row in Rows do
  begin
    Clause := Target.Add('insert', ckInsert);
    Clause.Columns := CopyStrings(Columns);
    Clause.Values := Copy(Row);
  end;
  Target.Method := 'insert';
  Result := Target;
end;

class function TQueryWrites.AsInsert(const Target: IQuery;
  const Columns: array of string; const Source: IQuery): IQuery;
var
  Clause: TClause;
begin
  Target.Remove('insert', Target.EngineScope);
  Clause := Target.Add('insert', ckQuery);
  Clause.Columns := CopyStrings(Columns);
  Clause.Query := Source.Clone;
  Target.Method := 'insert';
  Result := Target;
end;

class function TQueryWrites.AsInsert(const Target: IQuery;
  const Pairs: array of TPair<string, TValue>; ReturnId: Boolean): IQuery;
var
  Columns: TArray<string>;
  Values: TValues;
begin
  SplitPairs(Pairs, Columns, Values);
  Result := Target.AsInsert(Columns, Values);
  Target.GetOne('insert', Target.EngineScope).ReturnId := ReturnId;
end;

class function TQueryWrites.AsUpdate(const Target: IQuery;
  const Columns: array of string; const Values: array of TValue): IQuery;
var
  Clause: TClause;
begin
  if (Length(Columns) = 0) or (Length(Columns) <> Length(Values)) then
    raise EQueryException.Create
      ('Columns and values must be nonempty with equal counts');
  Target.Remove('update', Target.EngineScope);
  Clause := Target.Add('update', ckInsert);
  Clause.Columns := CopyStrings(Columns);
  Clause.Values := CopyValues(Values);
  Target.Method := 'update';
  Result := Target;
end;

class function TQueryWrites.AsUpdate(const Target: IQuery;
  const Pairs: array of TPair<string, TValue>): IQuery;
var
  Columns: TArray<string>;
  Values: TValues;
begin
  SplitPairs(Pairs, Columns, Values);
  Result := Target.AsUpdate(Columns, Values);
end;

class function TQueryWrites.AsDelete(const Target: IQuery): IQuery;
begin
  Target.Method := 'delete';
  Result := Target;
end;

class function TQueryWrites.AsIncrement(const Target: IQuery;
  const Column: string; Value: Integer): IQuery;
var
  Clause: TClause;
begin
  Target.Remove('update', Target.EngineScope);
  Clause := Target.Add('update', ckIncrement);
  Clause.Name := Column;
  Clause.Value := Value;
  Target.Method := 'update';
  Result := Target;
end;

class function TQueryWrites.AsDecrement(const Target: IQuery;
  const Column: string; Value: Integer): IQuery;
begin
  Result := Target.AsIncrement(Column, -Value);
end;

end.
