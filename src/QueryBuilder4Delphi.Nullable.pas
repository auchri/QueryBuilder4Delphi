unit QueryBuilder4Delphi.Nullable;

interface

uses System.SysUtils;

type
  EQueryNullValue = class(EInvalidOp);

  // Ordinary managed record: compiler-generated copies/finalization own T.
  // Object references in T retain Delphi's usual non-owning semantics.
  TNullable<T> = record
  private
    FHasValue: Boolean;
    FValue: T;
    function GetValue: T;
  public
    constructor Create(const Value: T);
    class function Null: TNullable<T>; static;
    property HasValue: Boolean read FHasValue;
    property Value: T read GetValue;
  end;

implementation

constructor TNullable<T>.Create(const Value: T);
begin
  FValue := Value;
  FHasValue := True;
end;

class function TNullable<T>.Null: TNullable<T>;
begin
  Result := Default (TNullable<T>);
end;

function TNullable<T>.GetValue: T;
begin
  if not FHasValue then
    raise EQueryNullValue.Create('Cannot read Value of a NULL TNullable');
  Result := FValue;
end;

end.
