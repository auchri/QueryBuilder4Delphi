unit QueryBuilder4Delphi.FireDAC;

interface

uses
  System.Rtti, Data.DB, FireDAC.Comp.Client,
  QueryBuilder4Delphi.Query.Core;

type
  // Use when a NULL binding needs a specific database parameter type.
  TFireDACNull = record
    DataType: TFieldType;
    constructor Create(ADataType: TFieldType);
    class operator Implicit(const Value: TFireDACNull): TValue;
  end;

  TFireDACAdapter = record
    class procedure Apply(Target: TFDQuery; const Query: IQuery;
      Dialect: TSqlDialect = TSqlDialect.MSSql); static;
    class procedure Open(Target: TFDQuery; const Query: IQuery;
      Dialect: TSqlDialect = TSqlDialect.MSSql); static;
    class function ExecSQL(Target: TFDQuery; const Query: IQuery;
      Dialect: TSqlDialect = TSqlDialect.MSSql): Int64; static;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.TypInfo, System.Variants, Data.FmtBcd,
  FireDAC.Stan.Param,
  QueryBuilder4Delphi.Compilers.Compiler,
  QueryBuilder4Delphi.Compilers.Factory;

constructor TFireDACNull.Create(ADataType: TFieldType);
begin
  if ADataType = ftUnknown then
    raise EQueryException.Create('A typed NULL requires a parameter data type');
  DataType := ADataType;
end;

class operator TFireDACNull.Implicit(const Value: TFireDACNull): TValue;
begin Result := TValue.From<TFireDACNull>(Value); end;

procedure BindNull(Param: TFDParam; DataType: TFieldType);
begin
  if DataType = ftUnknown then DataType := ftWideString;
  Param.DataType := DataType;
  Param.Clear;
  Param.Bound := True;
end;

procedure BindValue(Param: TFDParam; const Value: TValue;
  DefaultNullType: TFieldType);
var
  V: Variant;
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
    if VarIsNull(V) or VarIsEmpty(V) then BindNull(Param, DefaultNullType)
    else BindValue(Param, TValue.FromVariant(V), DefaultNullType);
    Exit;
  end;
  if Value.TypeInfo = TypeInfo(Boolean) then Param.AsBoolean := Value.AsBoolean
  else if Value.TypeInfo = TypeInfo(TDateTime) then
    Param.AsDateTime := Value.AsType<TDateTime>
  else if Value.TypeInfo = TypeInfo(Currency) then
    Param.AsCurrency := Value.AsType<Currency>
  else if Value.IsType<TGUID> then Param.AsGUID := Value.AsType<TGUID>
  else if Value.IsType<TBcd> then Param.AsFMTBCD := Value.AsType<TBcd>
  else if Value.IsType<TBytes> then
  begin
    Bytes := Value.AsType<TBytes>;
    SetString(Blob, PAnsiChar(Pointer(Bytes)), Length(Bytes));
    Param.AsBlob := Blob;
  end
  else if Value.TypeInfo = TypeInfo(UInt64) then
  begin
    U := Value.AsUInt64;
    if U <= UInt64(High(Int64)) then Param.AsLargeInt := Int64(U)
    else Param.AsFMTBCD := StrToBcd(UIntToStr(U));
  end
  else case Value.Kind of
    tkInteger:
      if GetTypeData(Value.TypeInfo).OrdType = otULong then
        Param.AsLongword := Value.AsType<Cardinal>
      else Param.AsInteger := Value.AsInteger;
    tkInt64: Param.AsLargeInt := Value.AsInt64;
    tkFloat: Param.AsExtended := Value.AsExtended;
    tkString, tkLString, tkWString, tkUString:
      Param.AsWideString := Value.AsString;
    tkChar, tkWChar: Param.AsWideString := Value.ToString;
  else
    raise EQueryException.CreateFmt('Unsupported FireDAC binding type: %s',
      [string(Value.TypeInfo.Name)]);
  end;
end;

class procedure TFireDACAdapter.Apply(Target: TFDQuery; const Query: IQuery;
  Dialect: TSqlDialect);
var
  Compiler: ICompiler;
  Compiled: ISqlResult;
  Params: TFDParams;
  Param: TFDParam;
  I: Integer;
begin
  if Target = nil then raise EArgumentNilException.Create('Target');
  if Query = nil then raise EArgumentNilException.Create('Query');
  Compiler := CreateCompiler(Dialect);
  Compiler.ParameterPrefix := ':p';
  Compiled := Compiler.Compile(Query);
  // Validate bindings before closing or changing the caller's query.
  Params := TFDParams.Create;
  try
    Params.BindMode := pbByName;
    for I := 0 to Compiled.Bindings.Count-1 do
    begin
      Param := Params.Add;
      Param.Name := 'p'+IntToStr(I);
      Param.Position := I+1;
      Param.ParamType := ptInput;
      BindValue(Param, Compiled.Bindings[I], Target.FormatOptions.DefaultParamDataType);
    end;
    Target.Close;
    Target.Unprepare;
    Target.ResourceOptions.ParamCreate := False;
    Target.ResourceOptions.ParamExpand := True;
    Target.ResourceOptions.MacroCreate := False;
    Target.ResourceOptions.MacroExpand := False;
    Target.ResourceOptions.EscapeExpand := False;
    Target.SQL.Text := Compiled.Sql;
    Target.Params.Assign(Params);
    Target.Params.BindMode := pbByName;
  finally
    Params.Free;
  end;
end;

class procedure TFireDACAdapter.Open(Target: TFDQuery; const Query: IQuery;
  Dialect: TSqlDialect);
begin
  Apply(Target, Query, Dialect);
  Target.Open;
end;

class function TFireDACAdapter.ExecSQL(Target: TFDQuery; const Query: IQuery;
  Dialect: TSqlDialect): Int64;
begin
  Apply(Target, Query, Dialect);
  Target.ExecSQL;
  Result := Target.RowsAffected;
end;

end.
