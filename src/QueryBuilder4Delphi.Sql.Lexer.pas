unit QueryBuilder4Delphi.Sql.Lexer;

interface

// Parameter scanning only: True outside quoted text/identifiers and comments.
// Offsets are zero based. Incomplete quoted text/comments are masked to the end;
// SQL syntax validation belongs to the database.
/// <summary>Marks SQL character positions outside quoted text, identifiers, and comments.</summary>
/// <param name="Sql">SQL text to scan without changing or executing it.</param>
/// <param name="BackslashEscapes">
/// Enable backslash escapes within single-quoted text for MySQL-style scanning.
/// </param>
/// <returns>
/// One Boolean per SQL character, indexed from zero; True marks parameter-scannable SQL code.
/// </returns>
/// <remarks>
/// Masks incomplete quoted text or comments through the end. Handles common quotes, brackets, backticks,
/// dollar quotes and comments for parameter scanning; it is not a SQL syntax validator.
/// </remarks>
function SqlCodeMask(const Sql: string; BackslashEscapes: Boolean = False)
  : TArray<Boolean>;

implementation

uses System.SysUtils;

function SqlCodeMask(const Sql: string; BackslashEscapes: Boolean)
  : TArray<Boolean>;
var
  I, J, Depth: Integer;
  Delimiter, Finish: Char;
  Tag: string;
  Escapes: Boolean;
begin
  SetLength(Result, Length(Sql));
  I := 1;
  while I <= Length(Sql) do
  begin
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
            Break;
        end
        else
          Inc(I);
      end;
      Continue;
    end;
    Result[I - 1] := True;
    Inc(I);
  end;
end;

end.
