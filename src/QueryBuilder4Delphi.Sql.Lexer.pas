unit QueryBuilder4Delphi.Sql.Lexer;

interface

// True only outside quoted values/identifiers and comments. Offsets are zero based.
function SqlCodeMask(const Sql: string; BackslashEscapes: Boolean = False)
  : TArray<Boolean>;
procedure ValidateSingleStatement(const Sql: string;
  BackslashEscapes: Boolean = False);

implementation

uses System.SysUtils, QueryBuilder4Delphi.Query.Core;

function SqlCodeMask(const Sql: string; BackslashEscapes: Boolean)
  : TArray<Boolean>;
var
  I, J, K, Start, Depth: Integer;
  Delimiter, Finish: Char;
  Tag: string;
  Escapes, Closed: Boolean;
begin
  SetLength(Result, Length(Sql));
  I := 1;
  while I <= Length(Sql) do
  begin
    Start := I;
    if (Copy(Sql, I, 2) = '--') then
    begin
      while (I <= Length(Sql)) and not CharInSet(Sql[I], [#10, #13]) do
        Inc(I);
      Continue;
    end;
    if Copy(Sql, I, 2) = '/*' then
    begin
      Inc(I, 2);
      Depth := 1;
      while (I <= Length(Sql)) and (Depth > 0) do
        if Copy(Sql, I, 2) = '/*' then
        begin
          Inc(Depth);
          Inc(I, 2);
        end
        else if Copy(Sql, I, 2) = '*/' then
        begin
          Dec(Depth);
          Inc(I, 2);
        end
        else
          Inc(I);
      if Depth <> 0 then
        raise EQueryException.Create('Unterminated SQL comment');
      Continue;
    end;
    // PostgreSQL dollar quoting.
    if Sql[I] = '$' then
    begin
      J := I + 1;
      while (J <= Length(Sql)) and
        CharInSet(Sql[J], ['a' .. 'z', 'A' .. 'Z', '0' .. '9', '_']) do
        Inc(J);
      if (J <= Length(Sql)) and (Sql[J] = '$') then
      begin
        Tag := Copy(Sql, I, J - I + 1);
        I := J + 1;
        while (I <= Length(Sql)) and (Copy(Sql, I, Length(Tag)) <> Tag) do
          Inc(I);
        if I > Length(Sql) then
          raise EQueryException.Create('Unterminated SQL dollar quote');
        Inc(I, Length(Tag));
        Continue;
      end;
    end;
    // Oracle alternative quoting: q'[text]', q'!text!', etc.
    if CharInSet(Sql[I], ['q', 'Q']) and (Copy(Sql, I + 1, 1) = #39) and
      (I + 2 <= Length(Sql)) then
    begin
      Finish := Sql[I + 2];
      case Finish of
        '[':
          Finish := ']';
        '(':
          Finish := ')';
        '{':
          Finish := '}';
        '<':
          Finish := '>';
      end;
      Inc(I, 3);
      while (I < Length(Sql)) and
        not((Sql[I] = Finish) and (Sql[I + 1] = #39)) do
        Inc(I);
      if I >= Length(Sql) then
        raise EQueryException.Create('Unterminated SQL alternative quote');
      Inc(I, 2);
      Continue;
    end;
    if CharInSet(Sql[I], [#39, '"', '`', '[']) then
    begin
      Delimiter := Sql[I];
      if Delimiter = '[' then
        Delimiter := ']';
      Escapes := BackslashEscapes or
        ((I > 1) and CharInSet(Sql[I - 1], ['e', 'E']) and (Sql[I] = #39));
      Inc(I);
      Closed := False;
      while I <= Length(Sql) do
      begin
        if Escapes and (Sql[I] = '\') then
          Inc(I, 2)
        else if Sql[I] = Delimiter then
        begin
          Inc(I);
          if (I <= Length(Sql)) and (Sql[I] = Delimiter) then
            Inc(I)
          else
          begin
            Closed := True;
            Break;
          end;
        end
        else
          Inc(I);
      end;
      // The server still validates complete SQL grammar. Catch an open quote.
      if not Closed then
        raise EQueryException.Create('Unterminated SQL quote');
      Continue;
    end;
    // Whitespace is code too, but ignored by statement validation.
    for K := Start to I do
      Result[K - 1] := True;
    Inc(I);
  end;
end;

procedure ValidateSingleStatement(const Sql: string; BackslashEscapes: Boolean);
var
  Mask: TArray<Boolean>;
  I, J, Depth: Integer;
  Ended, HasCode, InsertSelect: Boolean;
  Root, Word, Previous, BeforePrevious: string;

  procedure RejectBatch;
  begin
    raise EQueryException.Create
      ('Execution supports a single SQL statement; batches are not supported');
  end;

begin
  Mask := SqlCodeMask(Sql, BackslashEscapes);
  Ended := False;
  HasCode := False;
  for I := 1 to Length(Sql) do
    if Mask[I - 1] and not CharInSet(Sql[I], [#9, #10, #13, ' ']) then
    begin
      if Ended then
        RejectBatch;
      if Sql[I] = ';' then
        Ended := True
      else
        HasCode := True;
    end;
  if not HasCode then
    raise EQueryException.Create('Execution requires a nonempty SQL statement');
  // SQL Server also permits adjacent DML statements without semicolons.
  // Conservatively reject a second top-level DML root. This is a guard for
  // query-builder statements, not a parser for procedural SQL or MERGE.
  I := 1;
  Depth := 0;
  Root := '';
  Previous := '';
  BeforePrevious := '';
  InsertSelect := False;
  while I <= Length(Sql) do
  begin
    if not Mask[I - 1] then
    begin
      Inc(I);
      Continue;
    end;
    if Sql[I] = '(' then
      Inc(Depth)
    else if Sql[I] = ')' then
      Dec(Depth)
    else if (Depth = 0) and CharInSet(Sql[I], ['a' .. 'z', 'A' .. 'Z', '_'])
    then
    begin
      J := I;
      while (I <= Length(Sql)) and Mask[I - 1] and
        CharInSet(Sql[I], ['a' .. 'z', 'A' .. 'Z', '0' .. '9', '_', '$']) do
        Inc(I);
      Word := UpperCase(Copy(Sql, J, I - J));
      if (Word = 'EXEC') or (Word = 'EXECUTE') or (Word = 'CALL') or
        (Word = 'CREATE') or (Word = 'ALTER') or (Word = 'DROP') or
        (Word = 'TRUNCATE') or (Word = 'GRANT') or (Word = 'REVOKE') or
        (Word = 'BEGIN') or (Word = 'COMMIT') or (Word = 'ROLLBACK') or
        (Word = 'DECLARE') or (Word = 'MERGE') then
        raise EQueryException.Create
          ('Procedural/DDL SQL is outside single query execution');
      if (Word = 'SELECT') or (Word = 'INSERT') or (Word = 'UPDATE') or
        (Word = 'DELETE') then
      begin
        if Root = '' then
          Root := Word
        else if (Word = 'SELECT') and
          ((Previous = 'UNION') or (Previous = 'EXCEPT') or
          (Previous = 'INTERSECT') or ((Previous = 'ALL') and
          ((BeforePrevious = 'UNION') or (BeforePrevious = 'EXCEPT') or
          (BeforePrevious = 'INTERSECT')))) then
        begin
        end
        else if (Root = 'INSERT') and (Word = 'SELECT') and not InsertSelect
        then
          InsertSelect := True
        else if (Root = 'INSERT') and (Word = 'UPDATE') and (Previous = 'DO')
        then
        begin
        end // PostgreSQL/SQLite ON CONFLICT DO UPDATE.
        else if (Root = 'SELECT') and (Word = 'UPDATE') and
          ((Previous = 'FOR') or ((Previous = 'KEY') and
          (BeforePrevious = 'NO'))) then
        begin
        end // SELECT ... FOR [NO KEY] UPDATE.
        else
          RejectBatch;
      end;
      BeforePrevious := Previous;
      Previous := Word;
      Continue;
    end;
    Inc(I);
  end;
end;

end.
