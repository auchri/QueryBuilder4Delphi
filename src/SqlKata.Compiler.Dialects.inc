constructor TSqlServerCompilerObject.Create;
begin inherited; FEngineCode := 'sqlsrv'; FOpening := '['; FClosing := ']'; FLastId := 'SELECT scope_identity() as Id'; end;
constructor TPostgresCompilerObject.Create;
begin inherited; FEngineCode := 'postgres'; SupportsFilterClause := True; FLastId := 'SELECT lastval() AS id'; end;
constructor TMySqlCompilerObject.Create;
begin inherited; FEngineCode := 'mysql'; FOpening := '`'; FClosing := '`'; FLastId := 'SELECT last_insert_id() as Id'; end;
constructor TSqliteCompilerObject.Create;
begin inherited; FEngineCode := 'sqlite'; SupportsFilterClause := True; FLastId := 'select last_insert_rowid() as id'; end;
constructor TOracleCompilerObject.Create;
begin inherited; FEngineCode := 'oracle'; FParameterPrefix := ':p'; FColumnAs := ''; FTableAs := ''; FDummyTable := 'DUAL'; end;
constructor TFirebirdCompilerObject.Create;
begin inherited; FEngineCode := 'firebird'; FDummyTable := 'RDB$DATABASE'; end;
function TCompilerObject.CompileTrue: string;
begin
  if FEngineCode = 'sqlsrv' then Result := 'cast(1 as bit)'
  else if MatchStr(FEngineCode,['sqlite','firebird']) then Result := '1' else Result := 'true';
end;
function TCompilerObject.CompileFalse: string;
begin
  if FEngineCode = 'sqlsrv' then Result := 'cast(0 as bit)'
  else if MatchStr(FEngineCode,['sqlite','firebird']) then Result := '0' else Result := 'false';
end;
function TCompilerObject.CompileRandom(const Seed: TValue): string;
begin
  if FEngineCode = 'sqlsrv' then Result := 'NEWID()'
  else if FEngineCode = 'oracle' then Result := 'DBMS_RANDOM.VALUE'
  else if FEngineCode = 'firebird' then Result := 'RAND()'
  else if FEngineCode = 'mysql' then
    if Seed.IsEmpty then Result := 'RAND()' else Result := 'RAND('+IntToStr(Seed.AsInteger)+')'
  else Result := 'RANDOM()';
end;

function TCompilerObject.SelectPrefix(Context: TCompileContext; Query: IQuery): string;
var L: Integer; O: Int64; D: string;
begin
  D := ''; if Query.IsDistinct then D := 'DISTINCT ';
  if Query.GetOne('aggregate',EngineCode) <> nil then Exit('SELECT ');
  L := Query.GetLimit(EngineCode); O := Query.GetOffset(EngineCode);
  if (EngineCode = 'sqlsrv') and UseLegacyPagination and (L > 0) and (O = 0) then
    Exit('SELECT '+D+'TOP ('+Parameter(Context,L)+') ');
  if EngineCode = 'firebird' then
  begin
    if (L > 0) and (O = 0) then Exit('SELECT FIRST '+Parameter(Context,L)+' '+D);
    if (L = 0) and (O > 0) then Exit('SELECT SKIP '+Parameter(Context,O)+' '+D);
  end;
  Result := 'SELECT '+D;
end;

function TCompilerObject.CompileLimit(Context: TCompileContext; Query: IQuery): string;
var L: Integer; O: Int64;
begin
  Result := ''; L := Query.GetLimit(EngineCode); O := Query.GetOffset(EngineCode);
  if (L = 0) and (O = 0) then Exit;
  if MatchStr(EngineCode,['sqlsrv','oracle']) then
  begin
    if UseLegacyPagination then Exit;
    if not Query.HasComponent('order',EngineCode) then
      if EngineCode = 'oracle' then Result := 'ORDER BY (SELECT 0 FROM DUAL) '
      else Result := 'ORDER BY (SELECT 0) ';
    Result := Result+'OFFSET '+Parameter(Context,O)+' ROWS';
    if L > 0 then Result := Result+' FETCH NEXT '+Parameter(Context,L)+' ROWS ONLY';
    Exit;
  end;
  if EngineCode = 'firebird' then
  begin
    if (L > 0) and (O > 0) then Result := 'ROWS '+Parameter(Context,O+1)+' TO '+Parameter(Context,O+L);
    Exit;
  end;
  if L > 0 then Result := 'LIMIT '+Parameter(Context,L)
  else if EngineCode = 'sqlite' then Result := 'LIMIT -1'
  else if EngineCode = 'mysql' then Result := 'LIMIT 18446744073709551615';
  if O > 0 then
  begin
    if Result <> '' then Result := Result+' ';
    Result := Result+'OFFSET '+Parameter(Context,O);
  end;
end;

function TCompilerObject.CompileSelect(Context: TCompileContext; Query: IQuery): string;
var L, I, N: Integer; O: Int64; Q: IQuery; Order: string; Values: TValues;
begin
  L := Query.GetLimit(EngineCode); O := Query.GetOffset(EngineCode);
  if UseLegacyPagination and (EngineCode = 'sqlsrv') and (O > 0) then
  begin
    Q := Query.Clone;
    if not Q.HasComponent('select',EngineCode) then Q.Select('*');
    N := Context.Bindings.Count;
    Order := CompileOrders(Context,Q);
    if Order = '' then Order := 'ORDER BY (SELECT 0)';
    SetLength(Values,Context.Bindings.Count-N);
    for I := 0 to High(Values) do Values[I] := Context.Bindings[N+I];
    while Context.Bindings.Count > N do Context.Bindings.Delete(Context.Bindings.Count-1);
    Q.SelectRaw('ROW_NUMBER() OVER ('+Order+') AS [row_num]',Values);
    Q.ClearComponent('order').ClearComponent('limit').ClearComponent('offset');
    Result := 'SELECT * FROM ('+CompileSelectCore(Context,Q)+') AS [results_wrapper] WHERE [row_num] ';
    if L = 0 then Result := Result+'>= '+Parameter(Context,O+1)
    else Result := Result+'BETWEEN '+Parameter(Context,O+1)+' AND '+Parameter(Context,O+L);
    Exit;
  end;
  Result := CompileSelectCore(Context,Query);
  if UseLegacyPagination and (EngineCode = 'oracle') then
  begin
    if (L = 0) and (O = 0) then Exit;
    if L = 0 then Result := 'SELECT * FROM (SELECT "results_wrapper".*, ROWNUM "row_num" FROM ('+Result+') "results_wrapper") WHERE "row_num" > '+Parameter(Context,O)
    else if O = 0 then Result := 'SELECT * FROM ('+Result+') WHERE ROWNUM <= '+Parameter(Context,L)
    else Result := 'SELECT * FROM (SELECT "results_wrapper".*, ROWNUM "row_num" FROM ('+Result+') "results_wrapper" WHERE ROWNUM <= '+Parameter(Context,O+L)+') WHERE "row_num" > '+Parameter(Context,O);
  end;
end;

function TCompilerObject.DateCondition(Context: TCompileContext; Clause: TClause): string;
var Col, Part, Op, V, Fmt, ValueFmt: string;
begin
  Col := Wrap(Clause.Name); Part := LowerCase(Clause.Extra);
  if not TRegEx.IsMatch(Part,'^[a-z_]+$') then
    raise EQueryException.Create('Unsupported date part: '+Part);
  Op := CheckOperator(Clause.Op); V := Parameter(Context,Clause.Value);
  if EngineCode = 'sqlsrv' then
  begin
    if MatchStr(Part,['date','time']) then Col := 'CAST('+Col+' AS '+UpperCase(Part)+')'
    else Col := 'DATEPART('+UpperCase(Part)+', '+Col+')';
  end
  else if EngineCode = 'postgres' then
  begin
    if MatchStr(Part,['date','time']) then Col := Col+'::'+Part
    else Col := 'DATE_PART('+QuotedStr(UpperCase(Part))+', '+Col+')';
  end
  else if EngineCode = 'sqlite' then
  begin
    Fmt := '';
    if Part = 'date' then Fmt := '%Y-%m-%d' else if Part = 'time' then Fmt := '%H:%M:%S'
    else if Part = 'year' then Fmt := '%Y' else if Part = 'month' then Fmt := '%m'
    else if Part = 'day' then Fmt := '%d' else if Part = 'hour' then Fmt := '%H' else if Part = 'minute' then Fmt := '%M';
    if Fmt <> '' then Exit('strftime('+QuotedStr(Fmt)+', '+Col+') '+Op+' cast('+V+' as text)');
  end
  else if EngineCode = 'firebird' then
  begin
    if MatchStr(Part,['date','time']) then Col := 'CAST('+Col+' as '+UpperCase(Part)+')'
    else Col := 'EXTRACT('+UpperCase(Part)+' FROM '+Col+')';
  end
  else if EngineCode = 'oracle' then
  begin
    if MatchStr(Part,['date','time']) then
    begin
      if Part = 'date' then Fmt := 'YY-MM-DD' else Fmt := 'HH24:MI:SS';
      ValueFmt := V;
      if Clause.Value.TypeInfo <> TypeInfo(TDateTime) then
      begin
        if (Part = 'time') and (Length(Clause.Value.ToString.Split([':'])) = 2) then ValueFmt := 'HH24:MI' else ValueFmt := Fmt;
        ValueFmt := 'TO_DATE('+V+', '+QuotedStr(ValueFmt)+')';
      end;
      Exit('TO_CHAR('+Col+', '+QuotedStr(Fmt)+') '+Op+' TO_CHAR('+ValueFmt+', '+QuotedStr(Fmt)+')');
    end;
    if MatchStr(Part,['year','month','day','hour','minute','second']) then
      Col := 'EXTRACT('+UpperCase(Part)+' FROM '+Col+')';
  end
  else Col := UpperCase(Part)+'('+Col+')';
  Result := Col+' '+Op+' '+V;
end;
