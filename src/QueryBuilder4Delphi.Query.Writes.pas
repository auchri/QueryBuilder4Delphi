unit QueryBuilder4Delphi.Query.Writes;

interface

uses
  System.Rtti, System.Generics.Collections, QueryBuilder4Delphi.Query.Core;

type
  // Stateless implementation shared by the public fluent write overloads.
  /// <summary>
  /// Low-level stateless implementation of fluent write configuration. Methods mutate and return Target
  /// without executing SQL. Prefer IQuery write methods in application code.
  /// </summary>
  TQueryWrites = class
  private
    class procedure SplitPairs(const Pairs: array of TPair<string, TValue>;
      out Columns: TArray<string>; out Values: TValues); static;
  public
    /// <summary>Switches to a standalone aggregate query.</summary>
    /// <param name="Target">
    /// Non-nil query to modify and return; retained only through normal interface references.
    /// </param>
    /// <param name="Aggregate">SQL aggregate function identifier, for example count or sum.</param>
    /// <param name="Columns">
    /// Column names stored as supplied, in order; AsCount handles an empty column array specially.
    /// </param>
    /// <returns>Target, modified in place for further configuration; no SQL is executed.</returns>
    /// <remarks>
    /// Validates the function identifier. Compilation removes LIMIT, ORDER BY and GROUP BY from a clone,
    /// retains OFFSET, and may wrap DISTINCT or multiple-column queries. Only the DISTINCT rewrite expands
    /// column shorthand through Select.
    /// </remarks>
    class function AsAggregate(const Target: IQuery; const Aggregate: string;
      const Columns: array of string): IQuery; static;
    /// <summary>Configures an INSERT of one row with positional column/value pairs.</summary>
    /// <param name="Target">
    /// Non-nil query to modify and return; retained only through normal interface references.
    /// </param>
    /// <param name="Columns">Target columns in assignment order; must match Values in length.</param>
    /// <param name="Values">Values copied in column order; duplicate values are preserved.</param>
    /// <returns>Target, modified in place for further configuration; no SQL is executed.</returns>
    /// <remarks>
    /// Column and value counts must be nonzero and equal; every supplied row must match the columns,
    /// otherwise EQueryException is raised.
    /// </remarks>
    class function AsInsert(const Target: IQuery;
      const Columns: array of string; const Values: array of TValue): IQuery;
      overload; static;
    /// <summary>Configures an INSERT of multiple rows sharing the same columns.</summary>
    /// <param name="Target">
    /// Non-nil query to modify and return; retained only through normal interface references.
    /// </param>
    /// <param name="Columns">Target columns in row order; each row must have this many values.</param>
    /// <param name="Rows">Nonempty row-major values matching the column count in each row.</param>
    /// <returns>Target, modified in place for further configuration; no SQL is executed.</returns>
    /// <remarks>
    /// Column and value counts must be nonzero and equal; every supplied row must match the columns,
    /// otherwise EQueryException is raised.
    /// </remarks>
    class function AsInsert(const Target: IQuery;
      const Columns: array of string; const Rows: TRows): IQuery;
      overload; static;
    /// <summary>Configures INSERT ... SELECT from a cloned source query.</summary>
    /// <param name="Target">
    /// Non-nil query to modify and return; retained only through normal interface references.
    /// </param>
    /// <param name="Columns">Target columns in row order; each row must have this many values.</param>
    /// <param name="Source">Non-nil query whose clauses are cloned.</param>
    /// <returns>Target, modified in place for further configuration; no SQL is executed.</returns>
    /// <remarks>
    /// Builds INSERT ... SELECT from a clone of the source query; the caller is responsible for matching
    /// projected columns.
    /// </remarks>
    class function AsInsert(const Target: IQuery;
      const Columns: array of string; const Source: IQuery): IQuery;
      overload; static;
    /// <summary>Configures an INSERT from named column/value pairs.</summary>
    /// <param name="Target">
    /// Non-nil query to modify and return; retained only through normal interface references.
    /// </param>
    /// <param name="Pairs">
    /// Column/value pairs in assignment order; must provide at least one pair for writes.
    /// </param>
    /// <param name="ReturnId">
    /// Requests dialect-specific identity SQL where available. Built-in execution rejects ReturnId batches;
    /// compilation alone can produce them.
    /// </param>
    /// <returns>Target, modified in place for further configuration; no SQL is executed.</returns>
    /// <remarks>
    /// Column and value counts must be nonzero and equal; every supplied row must match the columns,
    /// otherwise EQueryException is raised.
    /// </remarks>
    class function AsInsert(const Target: IQuery;
      const Pairs: array of TPair<string, TValue>; ReturnId: Boolean): IQuery;
      overload; static;
    /// <summary>Configures an UPDATE with positional column/value assignments.</summary>
    /// <param name="Target">
    /// Non-nil query to modify and return; retained only through normal interface references.
    /// </param>
    /// <param name="Columns">Target columns in assignment order; must match Values in length.</param>
    /// <param name="Values">Values copied in column order; duplicate values are preserved.</param>
    /// <returns>Target, modified in place for further configuration; no SQL is executed.</returns>
    /// <remarks>
    /// Existing WHERE conditions are retained. Without predicates the statement can affect every row. Column
    /// and value counts must be nonzero and equal; every supplied row must match the columns, otherwise
    /// EQueryException is raised.
    /// </remarks>
    class function AsUpdate(const Target: IQuery;
      const Columns: array of string; const Values: array of TValue): IQuery;
      overload; static;
    /// <summary>Configures an UPDATE from named column/value pairs.</summary>
    /// <param name="Target">
    /// Non-nil query to modify and return; retained only through normal interface references.
    /// </param>
    /// <param name="Pairs">
    /// Column/value pairs in assignment order; must provide at least one pair for writes.
    /// </param>
    /// <returns>Target, modified in place for further configuration; no SQL is executed.</returns>
    /// <remarks>
    /// Existing WHERE conditions are retained. Without predicates the statement can affect every row. Column
    /// and value counts must be nonzero and equal; every supplied row must match the columns, otherwise
    /// EQueryException is raised.
    /// </remarks>
    class function AsUpdate(const Target: IQuery;
      const Pairs: array of TPair<string, TValue>): IQuery; overload; static;
    /// <summary>Switches to DELETE while retaining the source and WHERE clauses.</summary>
    /// <param name="Target">
    /// Non-nil query to modify and return; retained only through normal interface references.
    /// </param>
    /// <returns>Target, modified in place for further configuration; no SQL is executed.</returns>
    /// <remarks>Without WHERE predicates the statement can delete every row.</remarks>
    class function AsDelete(const Target: IQuery): IQuery; static;
    /// <summary>Replaces update assignments with an arithmetic column increment.</summary>
    /// <param name="Target">
    /// Non-nil query to modify and return; retained only through normal interface references.
    /// </param>
    /// <param name="Column">Column identifier, optionally qualified by a table name.</param>
    /// <param name="Value">Integer amount to add or subtract; negative amounts reverse the operation.</param>
    /// <returns>Target, modified in place for further configuration; no SQL is executed.</returns>
    /// <remarks>Retains WHERE predicates; without predicates the statement can affect every row.</remarks>
    class function AsIncrement(const Target: IQuery; const Column: string;
      Value: Integer): IQuery; static;
    /// <summary>Replaces update assignments with an arithmetic column decrement.</summary>
    /// <param name="Target">
    /// Non-nil query to modify and return; retained only through normal interface references.
    /// </param>
    /// <param name="Column">Column identifier, optionally qualified by a table name.</param>
    /// <param name="Value">Integer amount to add or subtract; negative amounts reverse the operation.</param>
    /// <returns>Target, modified in place for further configuration; no SQL is executed.</returns>
    /// <remarks>Retains WHERE predicates; without predicates the statement can affect every row.</remarks>
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
