unit QueryBuilder4Delphi.Nullable;

interface

uses System.SysUtils;

type
  /// <summary>Raised when Value is read from a TNullable that has no value.</summary>
  EQueryNullValue = class(EInvalidOp);

  // Ordinary managed record: compiler-generated copies/finalization own T.
  // Object references in T retain Delphi's usual non-owning semantics.
  /// <summary>
  /// Optional Delphi value distinct from SQL NULL until converted for binding. Default-initialized and Null
  /// records have no value. Managed contents follow normal record copy/finalization; object references in T
  /// are not owned.
  /// </summary>
  TNullable<T> = record
  private
    FHasValue: Boolean;
    FValue: T;
    function GetValue: T;
  public
    /// <summary>Creates a nullable containing Value, even when Value is its Delphi default.</summary>
    /// <param name="Value">Contained Delphi value; object references are not owned.</param>
    constructor Create(const Value: T);
    /// <summary>Creates a nullable without a value.</summary>
    /// <returns>An empty TNullable&lt;T&gt;; reading Value raises EQueryNullValue.</returns>
    /// <remarks>
    /// This is an optional Delphi value. Convert it through mapping options before using it as a SQL binding.
    /// </remarks>
    class function Null: TNullable<T>; static;
    /// <summary>
    /// True when the nullable contains a value, including a valid default such as zero, False, or an empty
    /// string.
    /// </summary>
    property HasValue: Boolean read FHasValue;
    /// <summary>
    /// Contained Delphi value. Reading an empty nullable raises EQueryNullValue. Object references are
    /// borrowed, not owned.
    /// </summary>
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
