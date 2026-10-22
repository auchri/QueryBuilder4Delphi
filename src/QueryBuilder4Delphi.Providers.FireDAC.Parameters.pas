unit QueryBuilder4Delphi.Providers.FireDAC.Parameters;

interface

uses
  System.Rtti, Data.DB, FireDAC.Stan.Param,
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Compilers.Compiler;

type
  TFireDACNull = record
    DataType: TFieldType;
    constructor Create(ADataType: TFieldType);
    class operator Implicit(const Value: TFireDACNull): TValue;
  end;

  TFireDACParameterBinder = record
    class function Bind(const Statement: ISqlResult): TFDParams; static;
  end;

implementation

uses
  System.SysUtils, System.TypInfo, System.Variants, Data.FmtBcd;

constructor TFireDACNull.Create(ADataType: TFieldType);
begin
  if ADataType = ftUnknown then
    raise EQueryException.Create('A typed NULL requires a parameter data type');
  DataType := ADataType;
end;

class operator TFireDACNull.Implicit(const Value: TFireDACNull): TValue;
begin
  Result := TValue.From<TFireDACNull>(Value);
end;

procedure BindNull(Param: TFDParam; DataType: TFieldType);
begin
  if DataType = ftUnknown then
    DataType := ftWideString;
  Param.DataType := DataType;
  Param.Clear;
  Param.Bound := True;
end;

procedure BindValue(Param: TFDParam; const Value: TValue;
  DefaultNullType: TFieldType);
var
  V: Variant;
  Scalar: TValue;
  U: UInt64;
  Bytes: TBytes;
  Blob: RawByteString;
begin
  if Value.IsEmpty then
  begin
    BindNull(Param, DefaultNullType);
    Exit;
  end;
  if Value.IsType<TFireDACNull> then
  begin
    BindNull(Param, Value.AsType<TFireDACNull>.DataType);
    Exit;
  end;
  if Value.Kind = tkVariant then
  begin
    V := Value.AsVariant;
    if VarIsArray(V) or (VarType(V) in [varDispatch, varUnknown, varError]) then
      raise EQueryException.Create('Unsupported FireDAC Variant binding type');
    if VarIsNull(V) or VarIsEmpty(V) then
      BindNull(Param, DefaultNullType)
    else
    begin
      Scalar := TValue.FromVariant(V);
      if Scalar.Kind = tkVariant then
        raise EQueryException.Create
          ('Unsupported FireDAC Variant binding type');
      BindValue(Param, Scalar, DefaultNullType);
    end;
    Exit;
  end;
  if Value.TypeInfo = TypeInfo(Boolean) then
    Param.AsBoolean := Value.AsBoolean
  else if Value.TypeInfo = TypeInfo(TDateTime) then
    Param.AsDateTime := Value.AsType<TDateTime>
  else if Value.TypeInfo = TypeInfo(Currency) then
    Param.AsCurrency := Value.AsType<Currency>
  else if Value.IsType<TGUID> then
    Param.AsGUID := Value.AsType<TGUID>
  else if Value.IsType<TBcd> then
    Param.AsFMTBCD := Value.AsType<TBcd>
  else if Value.IsType<TBytes> then
  begin
    Bytes := Value.AsType<TBytes>;
    SetString(Blob, PAnsiChar(Pointer(Bytes)), Length(Bytes));
    Param.AsBlob := Blob;
  end
  else if Value.TypeInfo = TypeInfo(UInt64) then
  begin
    U := Value.AsUInt64;
    if U <= UInt64(High(Int64)) then
      Param.AsLargeInt := Int64(U)
    else
      Param.AsFMTBCD := StrToBcd(UIntToStr(U));
  end
  else
    case Value.Kind of
      tkInteger:
        if GetTypeData(Value.TypeInfo).OrdType = otULong then
          Param.AsLongword := Value.AsType<Cardinal>
        else
          Param.AsInteger := Value.AsInteger;
      tkInt64:
        Param.AsLargeInt := Value.AsInt64;
      tkFloat:
        Param.AsExtended := Value.AsExtended;
      tkString, tkLString, tkWString, tkUString:
        Param.AsWideString := Value.AsString;
      tkChar, tkWChar:
        Param.AsWideString := Value.ToString;
    else
      raise EQueryException.CreateFmt('Unsupported FireDAC binding type: %s',
        [string(Value.TypeInfo.Name)]);
    end;
end;

class function TFireDACParameterBinder.Bind(const Statement: ISqlResult)
  : TFDParams;
var
  I: Integer;
  Param: TFDParam;
begin
  Result := TFDParams.Create;
  try
    Result.BindMode := pbByName;
    for I := 0 to Statement.Bindings.Count - 1 do
    begin
      Param := Result.Add;
      Param.Name := 'p' + IntToStr(I);
      Param.Position := I + 1;
      Param.ParamType := ptInput;
      BindValue(Param, Statement.Bindings[I], ftUnknown);
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
