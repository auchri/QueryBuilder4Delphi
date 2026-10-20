function TCompiler.AggregateQuery(Query: TQuery): TQuery;
var A, Outer: TClause; Inner: TQuery; S: string;
begin
  A := Query.GetOne('aggregate',EngineCode);
  if A = nil then raise EQueryException.Create('Missing aggregate');
  Inner := Query.Clone;
  try
    Inner.ClearComponent('limit').ClearComponent('order').ClearComponent('group');
    if (Length(A.Columns) = 1) and not Query.IsDistinct then
    begin Result := Inner; Inner := nil; Exit; end;
    if Query.IsDistinct then
    begin
      Inner.ClearComponent('aggregate').ClearComponent('select').Select(A.Columns);
      Inner.Method := 'select';
    end
    else
      for S in A.Columns do Inner.WhereNotNull(S);
    Result := TQuery.Create;
    try
      Result.&From(Inner,A.Op+'Query');
      Outer := Result.Add('aggregate',ckAggregate); Outer.Op := A.Op;
      Outer.Columns := TArray<string>.Create('*');
    except Result.Free; raise; end;
  finally Inner.Free; end;
end;

function TCompiler.JoinTarget(Clause: TClause): string;
var Expr, Alias: string;
begin
  SplitAlias(Clause.Name,Expr,Alias);
  if Alias <> '' then Exit(WrapValue(Alias.Trim(['[',']','"','`'])));
  if Clause.Kind = ckRaw then Exit(WrapIdentifiers(Clause.Name));
  Result := WrapValue(Copy(Expr,LastDelimiter('.',Expr)+1,MaxInt));
end;

function TCompiler.CompileWrite(Context: TCompileContext; Query: TQuery): string;
var F, C: TClause; Inserts: TArray<TClause>; TableSql, Target, Columns, Sets, S, Sign: string;
  I, J: Integer; HasJoins: Boolean;
begin
  F := Query.GetOne('from',EngineCode);
  if (F = nil) or not (F.Kind in [ckIdentifier,ckRaw]) then raise EQueryException.Create('No valid table set for write');
  HasJoins := Query.HasComponent('join',EngineCode);
  if HasJoins and MatchStr(EngineCode,['sqlite','postgres','oracle','firebird']) then
    raise EQueryException.Create(EngineCode+' does not support writes with JOIN clauses');
  if Query.Method = 'insert' then
  begin
    TableSql := Table(Context,F);
    Inserts := Query.GetComponents('insert',EngineCode);
    if Length(Inserts) = 0 then raise EQueryException.Create('No insert data');
    C := Inserts[0]; Columns := '';
    if Length(C.Columns) > 0 then Columns := ' ('+WrapList(C.Columns)+')';
    if C.Kind = ckQuery then Exit('INSERT INTO '+TableSql+Columns+' '+CompileQuery(Context,C.Query,False));
    if (Length(Inserts) > 1) and (EngineCode = 'oracle') then
    begin
      Result := 'INSERT ALL';
      for C in Inserts do Result := Result+' INTO '+TableSql+Columns+' VALUES ('+Parameterize(Context,C.Values)+')';
      Exit(Result+' SELECT 1 FROM DUAL');
    end;
    if (Length(Inserts) > 1) and (EngineCode = 'firebird') then
    begin
      Result := 'INSERT INTO '+TableSql+Columns+' ';
      for I := 0 to High(Inserts) do
      begin
        if I > 0 then Result := Result+' UNION ALL ';
        Result := Result+'SELECT '+Parameterize(Context,Inserts[I].Values)+' FROM RDB$DATABASE';
      end;
      Exit;
    end;
    Result := 'INSERT INTO '+TableSql+Columns+' VALUES ';
    for I := 0 to High(Inserts) do
    begin
      if I > 0 then Result := Result+', ';
      Result := Result+'('+Parameterize(Context,Inserts[I].Values)+')';
    end;
    if (Length(Inserts) = 1) and C.ReturnId and (FLastId <> '') then Result := Result+';'+FLastId;
    Exit;
  end;
  if Query.Method = 'delete' then
  begin
    TableSql := Table(Context,F);
    if HasJoins then Result := 'DELETE '+JoinTarget(F)+' FROM '+TableSql+CompileJoins(Context,Query)
    else Result := 'DELETE FROM '+TableSql;
  end
  else
  begin
    C := Query.GetOne('update',EngineCode);
    if C = nil then raise EQueryException.Create('No update data');
    // SQL Server writes SET bindings before the raw FROM/JOIN bindings.
    if HasJoins and (EngineCode <> 'mysql') then
    begin
      if F.Kind = ckRaw then TableSql := WrapIdentifiers(F.Name) else TableSql := Wrap(F.Name);
      Target := JoinTarget(F);
    end
    else begin TableSql := Table(Context,F); Target := TableSql; end;
    if HasJoins and (EngineCode = 'mysql') then TableSql := TableSql+CompileJoins(Context,Query);
    Sets := '';
    if C.Kind = ckIncrement then
    begin
      if C.Value.AsInteger < 0 then Sign := '-' else Sign := '+';
      Sets := Wrap(C.Name)+' = '+Wrap(C.Name)+' '+Sign+' '+Parameter(Context,Int64(Abs(Int64(C.Value.AsInteger))));
    end
    else for J := 0 to High(C.Columns) do
    begin
      if J > 0 then Sets := Sets+', ';
      Sets := Sets+Wrap(C.Columns[J])+' = '+Parameter(Context,C.Values[J]);
    end;
    if HasJoins and (EngineCode <> 'mysql') then
    begin
      Result := 'UPDATE '+Target+' SET '+Sets+' FROM '+Table(Context,F)+CompileJoins(Context,Query);
    end
    else Result := 'UPDATE '+TableSql+' SET '+Sets;
  end;
  S := Conditions(Context,Query,'where');
  if S <> '' then Result := Result+' WHERE '+S;
end;
