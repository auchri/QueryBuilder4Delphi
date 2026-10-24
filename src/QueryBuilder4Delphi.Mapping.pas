unit QueryBuilder4Delphi.Mapping;

interface

uses
  System.SysUtils, System.Rtti, System.TypInfo, System.Generics.Collections,
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Nullable;

type
  EQueryMappingException = class(EQueryException);

  TQueryMappingOptions = class
  private type
    TConverter = record
      Source, Target: PTypeInfo;
      Convert: TFunc<TValue, TValue>;
    end;
  private
    FSkipNullAssignment: Boolean;
    FNullables: TDictionary<PTypeInfo, TFunc<TValue, Boolean, TValue>>;
    FConverters: TList<TConverter>;
    function Convert(const Value: TValue; Target: PTypeInfo;
      IsNull: Boolean): TValue;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterNullable<T>;
    procedure RegisterConverter<TSource, TTarget>(const Converter
      : TFunc<TSource, TTarget>);
    // Configure before use; do not mutate/free during a mapping operation.
    property SkipNullAssignment: Boolean read FSkipNullAssignment
      write FSkipNullAssignment;
  end;

  TQueryResultMappingHelper = record helper for TQueryResult
    function ToList<T: class, constructor>(Options: TQueryMappingOptions = nil)
      : TObjectList<T>;
    function FirstOrDefault<T: class, constructor>
      (Options: TQueryMappingOptions = nil): T;
  end;

  TQueryMapper = class
  private type
    TPropertyMapping = record
      Prop: TRttiProperty;
      Target: PTypeInfo;
      Column: string;
    end;

    TColumnMapping = record
      Metadata: TPropertyMapping;
      Index: Integer;
    end;

    TMappingPlan = TArray<TColumnMapping>;

  private
    class function BuildPlan(AClass: TClass; const Rows: IQueryResult)
      : TMappingPlan; static;
    class procedure MapObject(Instance: TObject; const Rows: IQueryResult;
      const Plan: TMappingPlan; RowNumber: Integer;
      Options: TQueryMappingOptions); static;
  public
    // Calls Next: ToList consumes all remaining rows; FirstOrDefault consumes
    // at most one. The caller owns the returned list/object.
    class function ToList<T: class, constructor>(const Rows: IQueryResult;
      Options: TQueryMappingOptions = nil): TObjectList<T>; static;
    class function FirstOrDefault<T: class, constructor>
      (const Rows: IQueryResult; Options: TQueryMappingOptions = nil)
      : T; static;
  end;

implementation

uses
  System.SyncObjs, System.Math, Data.FmtBcd, Data.SqlTimSt;

function TQueryResultMappingHelper.ToList<T>(Options: TQueryMappingOptions)
  : TObjectList<T>;
var
  Rows: IQueryResult;
begin
  Rows := Self.TakeRaw;
  try
    Result := TQueryMapper.ToList<T>(Rows, Options);
  finally
    Rows := nil;
  end;
end;

function TQueryResultMappingHelper.FirstOrDefault<T>
  (Options: TQueryMappingOptions): T;
var
  Rows: IQueryResult;
begin
  Rows := Self.TakeRaw;
  try
    Result := TQueryMapper.FirstOrDefault<T>(Rows, Options);
  finally
    Rows := nil;
  end;
end;

type
  TPropertyMapping = TQueryMapper.TPropertyMapping;
  TClassMapping = TArray<TPropertyMapping>;

var
  // Retaining this context keeps every cached RTTI property/type alive.
  MappingContext: TRttiContext;
  MetadataLock: TCriticalSection;
  MetadataCache: TDictionary<TClass, TClassMapping>;

function ClassMapping(AClass: TClass): TClassMapping;
var
  RttiType: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  Item, Existing: TPropertyMapping;
  Items: TList<TPropertyMapping>;
  Skip: Boolean;
  ColumnAttributes: Integer;
begin
  MetadataLock.Acquire;
  try
    if MetadataCache.TryGetValue(AClass, Result) then
      Exit;
    Items := TList<TPropertyMapping>.Create;
    try
      RttiType := MappingContext.GetType(AClass);
      if RttiType <> nil then
        for Prop in RttiType.GetProperties do
        begin
          if not Prop.IsWritable or
            not(Prop.Visibility in [mvPublic, mvPublished]) or
            (Prop.PropertyType = nil) then
            Continue;
          Item.Prop := Prop;
          Item.Target := Prop.PropertyType.Handle;
          Item.Column := Prop.Name;
          Skip := False;
          ColumnAttributes := 0;
          for Attr in Prop.GetAttributes do
          begin
            if Attr is IgnoreAttribute then
              Skip := True;
            // KeyAttribute inherits ColumnAttribute; no persistence semantics.
            if Attr is ColumnAttribute then
            begin
              Inc(ColumnAttributes);
              Item.Column := ColumnAttribute(Attr).Name;
            end;
          end;
          if Skip then
            Continue;
          if ColumnAttributes > 1 then
            raise EQueryMappingException.CreateFmt
              ('%s.%s has multiple column mapping attributes',
              [AClass.ClassName, Prop.Name]);
          for Existing in Items do
            if SameText(Existing.Column, Item.Column) then
              raise EQueryMappingException.CreateFmt
                ('%s: properties "%s" and "%s" map to the same column "%s"',
                [AClass.ClassName, Existing.Prop.Name, Prop.Name, Item.Column]);
          Items.Add(Item);
        end;
      if Items.Count = 0 then
        raise EQueryMappingException.CreateFmt
          ('%s has no public/published writable properties with RTTI',
          [AClass.ClassName]);
      Result := Items.ToArray;
      MetadataCache.Add(AClass, Result);
    finally
      Items.Free;
    end;
  finally
    MetadataLock.Release;
  end;
end;

class function TQueryMapper.BuildPlan(AClass: TClass; const Rows: IQueryResult)
  : TMappingPlan;
var
  Metadata: TClassMapping;
  Names: TArray<string>;
  Item: TPropertyMapping;
  Binding: TColumnMapping;
  Bindings: TList<TColumnMapping>;
  I, Found: Integer;
  AvailableColumns: string;
begin
  if Rows = nil then
    raise EArgumentNilException.Create('Rows');
  if not Rows.HasResultSet then
    raise EQueryMappingException.Create('Object mapping requires a resultset');
  SetLength(Names, Rows.ColumnCount);
  for I := 0 to High(Names) do
    Names[I] := Rows.GetColumnName(I);
  AvailableColumns := Format('Available result columns: [%s]',
    [string.Join(', ', Names)]);
  try
    Metadata := ClassMapping(AClass);
  except
    on E: EQueryMappingException do
    begin
      E.Message := E.Message + '. ' + AvailableColumns;
      raise;
    end;
  end;
  Bindings := TList<TColumnMapping>.Create;
  try
    for Item in Metadata do
    begin
      Found := -1;
      for I := 0 to High(Names) do
        if SameText(Names[I], Item.Column) then
        begin
          if Found >= 0 then
            raise EQueryMappingException.CreateFmt
              ('%s.%s: ambiguous result column "%s"',
              [AClass.ClassName, Item.Prop.Name, Item.Column]);
          Found := I;
        end;
      if Found >= 0 then
      begin
        Binding.Metadata := Item;
        Binding.Index := Found;
        Bindings.Add(Binding);
      end;
    end;
    if Bindings.Count = 0 then
      raise EQueryMappingException.CreateFmt
        ('%s: no result columns match writable, non-ignored properties. ' +
        '%s', [AClass.ClassName, AvailableColumns]);
    Result := Bindings.ToArray;
  finally
    Bindings.Free;
  end;
end;

function TypeName(Info: PTypeInfo): string;
begin
  if Info = nil then
    Result := '<empty>'
  else
    Result := string(Info.Name);
end;

function IsIntegerType(Info: PTypeInfo): Boolean;
begin
  Result := (Info = TypeInfo(Integer)) or (Info = TypeInfo(Int64)) or
    (Info = TypeInfo(ShortInt)) or (Info = TypeInfo(SmallInt)) or
    (Info = TypeInfo(Byte)) or (Info = TypeInfo(Word)) or
    (Info = TypeInfo(Cardinal)) or (Info = TypeInfo(UInt64));
end;

function IsFloatType(Info: PTypeInfo): Boolean;
begin
  Result := (Info = TypeInfo(Single)) or (Info = TypeInfo(Double)) or
    (Info = TypeInfo(Extended));
end;

function ConvertValue(const Value: TValue; Target: PTypeInfo): TValue;
var
  Number: Int64;
  Unsigned: UInt64;
  FloatValue: Extended;
  AsSingle: Single;
  AsDouble: Double;
  Decimal, Back: TBcd;
  Money: Currency;
  Bits, Mantissa: Integer;
begin
  // Preserve native records and managed arrays through TValue's public API.
  // A concrete source type, never GetColumnType, determines conversion.
  if (Value.TypeInfo = Target) and (IsIntegerType(Target) or IsFloatType(Target)
    or (Target = TypeInfo(string)) or (Target = TypeInfo(Boolean)) or
    (Target = TypeInfo(Currency)) or (Target = TypeInfo(TDateTime)) or
    (Target = TypeInfo(TBcd)) or (Target = TypeInfo(TSQLTimeStamp)) or
    (Target = TypeInfo(TSQLTimeStampOffset)) or (Target = TypeInfo(TGUID)) or
    (Target = TypeInfo(TBytes))) then
    Exit(Value);

  if IsIntegerType(Target) and IsIntegerType(Value.TypeInfo) then
  begin
    Number := 0;
    // Never read UInt64 through AsInt64, even with range checking disabled.
    if Value.TypeInfo = TypeInfo(UInt64) then
    begin
      Unsigned := Value.AsUInt64;
      if Target = TypeInfo(UInt64) then
        Exit(Value);
      if Unsigned > UInt64(High(Int64)) then
        raise EQueryMappingException.Create
          ('Integer overflow: UInt64 exceeds Int64');
      Number := Int64(Unsigned);
    end;
    if Value.TypeInfo <> TypeInfo(UInt64) then
      Number := Value.AsInt64;
    if Target = TypeInfo(Int64) then
      Exit(TValue.From<Int64>(Number));
    if (Target = TypeInfo(UInt64)) and (Number >= 0) then
      Exit(TValue.From<UInt64>(UInt64(Number)));
    if (Target = TypeInfo(Integer)) and (Number >= Low(Integer)) and
      (Number <= High(Integer)) then
      Exit(TValue.From<Integer>(Integer(Number)));
    if (Target = TypeInfo(Cardinal)) and (Number >= 0) and
      (Number <= High(Cardinal)) then
      Exit(TValue.From<Cardinal>(Cardinal(Number)));
    if (Target = TypeInfo(ShortInt)) and (Number >= Low(ShortInt)) and
      (Number <= High(ShortInt)) then
      Exit(TValue.From<ShortInt>(ShortInt(Number)));
    if (Target = TypeInfo(SmallInt)) and (Number >= Low(SmallInt)) and
      (Number <= High(SmallInt)) then
      Exit(TValue.From<SmallInt>(SmallInt(Number)));
    if (Target = TypeInfo(Byte)) and (Number >= 0) and (Number <= High(Byte))
    then
      Exit(TValue.From<Byte>(Byte(Number)));
    if (Target = TypeInfo(Word)) and (Number >= 0) and (Number <= High(Word))
    then
      Exit(TValue.From<Word>(Word(Number)));
    raise EQueryMappingException.Create
      ('Integer overflow or negative unsigned value');
  end
  else if (Target = TypeInfo(TBcd)) and (Value.TypeInfo = TypeInfo(Currency))
  then
  begin
    Money := Value.AsType<Currency>;
    if CurrToBcd(Money, Decimal, 32, 4) then
      Exit(TValue.From<TBcd>(Decimal));
  end
  else if (Target = TypeInfo(Currency)) and (Value.TypeInfo = TypeInfo(TBcd))
  then
  begin
    Decimal := Value.AsType<TBcd>;
    // BcdToCurr may round: compare in BCD space before accepting the result.
    try
      if BcdToCurr(Decimal, Money) and CurrToBcd(Money, Back, 32, 4) and
        (BcdCompare(Decimal, Back) = 0) then
        Exit(TValue.From<Currency>(Money));
    except
      on E: EConvertError do
        raise EQueryMappingException.Create
          ('Decimal overflow converting to Currency: ' + E.Message);
    end;
    raise EQueryMappingException.Create
      ('Decimal cannot be represented exactly as Currency');
  end
  else if IsFloatType(Target) and IsIntegerType(Value.TypeInfo) then
  begin
    // Test significant binary digits before any integer -> float conversion.
    // A rounded float converted back to float could otherwise hide lost bits.
    if Value.TypeInfo = TypeInfo(UInt64) then
    begin
      Unsigned := Value.AsUInt64;
      FloatValue := Unsigned;
    end
    else
    begin
      Number := Value.AsInt64;
      if Number < 0 then
        Unsigned := UInt64(-(Number + 1)) + 1
      else
        Unsigned := UInt64(Number);
      FloatValue := Number;
    end;
    while (Unsigned <> 0) and ((Unsigned and 1) = 0) do
      Unsigned := Unsigned shr 1;
    Bits := 0;
    while Unsigned <> 0 do
    begin
      Inc(Bits);
      Unsigned := Unsigned shr 1;
    end;
    Mantissa := 53;
    if Target = TypeInfo(Single) then
      Mantissa := 24
    else if (Target = TypeInfo(Extended)) and (SizeOf(Extended) > 8) then
      Mantissa := 64;
    if Bits <= Mantissa then
    begin
      if Target = TypeInfo(Single) then
        Exit(TValue.From<Single>(FloatValue));
      if Target = TypeInfo(Double) then
        Exit(TValue.From<Double>(FloatValue));
      Exit(TValue.From<Extended>(FloatValue));
    end;
  end
  else if IsIntegerType(Target) and IsFloatType(Value.TypeInfo) then
  begin
    FloatValue := Value.AsExtended;
    if not IsNan(FloatValue) and not IsInfinite(FloatValue) and
      (Frac(FloatValue) = 0) then
    begin
      // Exclusive powers-of-two upper bounds avoid rounded High(Int64/UInt64).
      if (FloatValue >= -9223372036854775808.0) and
        (FloatValue < 9223372036854775808.0) then
        Exit(ConvertValue(TValue.From<Int64>(Trunc(FloatValue)), Target));
      if (FloatValue >= 9223372036854775808.0) and
        (FloatValue < 18446744073709551616.0) then
      begin
        Unsigned := UInt64(Trunc(FloatValue - 9223372036854775808.0)) +
          (UInt64(1) shl 63);
        Exit(ConvertValue(TValue.From<UInt64>(Unsigned), Target));
      end;
    end;
  end
  else if IsFloatType(Target) and IsFloatType(Value.TypeInfo) then
  begin
    if Value.TypeInfo = Target then
      Exit(Value);
    FloatValue := Value.AsExtended;
    if not IsNan(FloatValue) and not IsInfinite(FloatValue) then
    begin
      if Target = TypeInfo(Extended) then
        Exit(TValue.From<Extended>(FloatValue));
      if (Target = TypeInfo(Single)) and (Abs(FloatValue) <= MaxSingle) then
      begin
        AsSingle := FloatValue;
        if Extended(AsSingle) = FloatValue then
          Exit(TValue.From<Single>(AsSingle));
      end;
      if (Target = TypeInfo(Double)) and (Abs(FloatValue) <= MaxDouble) then
      begin
        AsDouble := FloatValue;
        if Extended(AsDouble) = FloatValue then
          Exit(TValue.From<Double>(AsDouble));
      end;
    end;
  end;
  raise EQueryMappingException.Create
    ('Unsupported or lossy conversion; use a native target type or an explicit converter');
end;

constructor TQueryMappingOptions.Create;
begin
  inherited;
  FNullables := TDictionary < PTypeInfo, TFunc < TValue, Boolean,
    TValue >>.Create;
  FConverters := TList<TConverter>.Create;
end;

destructor TQueryMappingOptions.Destroy;
begin
  FConverters.Free;
  FNullables.Free;
  inherited;
end;

procedure TQueryMappingOptions.RegisterNullable<T>;
begin
  if FNullables.ContainsKey(TypeInfo(TNullable<T>)) then
    raise EQueryMappingException.Create('Nullable type is already registered');
  FNullables.Add(TypeInfo(TNullable<T>),
    function(Value: TValue; IsNull: Boolean): TValue
    var
      Inner: TValue;
    begin
      if IsNull then
        Exit(TValue.From < TNullable < T >> (TNullable<T>.Null));
      Inner := Self.Convert(Value, TypeInfo(T), False);
      Result := TValue.From < TNullable < T >>
        (TNullable<T>.Create(Inner.AsType<T>));
    end);
end;

procedure TQueryMappingOptions.RegisterConverter<TSource, TTarget>
  (const Converter: TFunc<TSource, TTarget>);
var
  Item: TConverter;
begin
  if not Assigned(Converter) then
    raise EArgumentNilException.Create('Converter');
  for Item in FConverters do
    if (Item.Source = TypeInfo(TSource)) and (Item.Target = TypeInfo(TTarget))
    then
      raise EQueryMappingException.Create
        ('Source/target converter is already registered');
  Item.Source := TypeInfo(TSource);
  Item.Target := TypeInfo(TTarget);
  Item.Convert := function(Value: TValue): TValue
    begin
      Result := TValue.From<TTarget>(Converter(Value.AsType<TSource>));
    end;
  FConverters.Add(Item);
end;

function TQueryMappingOptions.Convert(const Value: TValue; Target: PTypeInfo;
IsNull: Boolean): TValue;
var
  Nullable: TFunc<TValue, Boolean, TValue>;
  Item: TConverter;
begin
  if FNullables.TryGetValue(Target, Nullable) then
    Exit(Nullable(Value, IsNull));
  if IsNull then
    raise EQueryMappingException.Create
      ('SQL NULL requires a registered nullable target');
  // Explicit registrations override one exact source/target pair in this call.
  for Item in FConverters do
    if (Item.Source = Value.TypeInfo) and (Item.Target = Target) then
      Exit(Item.Convert(Value));
  Result := ConvertValue(Value, Target);
end;

class procedure TQueryMapper.MapObject(Instance: TObject;
const Rows: IQueryResult; const Plan: TMappingPlan; RowNumber: Integer;
Options: TQueryMappingOptions);
var
  Binding: TColumnMapping;
  Value: TValue;
  Source: string;
begin
  for Binding in Plan do
  begin
    Source := '<unread>';
    try
      // Do not use TValue.IsEmpty: a typed empty byte array can be IsEmpty.
      if Rows.IsNull(Binding.Index) then
      begin
        Source := 'SQL NULL';
        if (Options <> nil) and Options.SkipNullAssignment then
          Continue;
        if Options = nil then
          raise EQueryMappingException.Create
            ('SQL NULL requires a registered nullable target');
        Value := Options.Convert(TValue.Empty, Binding.Metadata.Target, True);
      end
      else
      begin
        Value := Rows.GetValue(Binding.Index);
        Source := TypeName(Value.TypeInfo);
        if Options = nil then
          Value := ConvertValue(Value, Binding.Metadata.Target)
        else
          Value := Options.Convert(Value, Binding.Metadata.Target, False);
      end;
      Binding.Metadata.Prop.SetValue(Instance, Value);
    except
      on E: Exception do
      begin
        // Keep the original exception class and object (including setter/provider
        // errors), adding the mapping site before a bare re-raise.
        E.Message :=
          Format('%s.%s, row %d, column "%s" [%d], source %s, target %s: %s',
          [Instance.ClassName, Binding.Metadata.Prop.Name, RowNumber,
          Binding.Metadata.Column, Binding.Index, Source,
          TypeName(Binding.Metadata.Target), E.Message]);
        raise;
      end;
    end;
  end;
end;

class function TQueryMapper.ToList<T>(const Rows: IQueryResult;
Options: TQueryMappingOptions): TObjectList<T>;
var
  Plan: TMappingPlan;
  Instance: T;
  RowNumber: Integer;
begin
  Plan := BuildPlan(GetTypeData(TypeInfo(T))^.ClassType, Rows);
  Result := TObjectList<T>.Create(True);
  try
    RowNumber := 0;
    while Rows.Next do
    begin
      Inc(RowNumber);
      Instance := T.Create;
      try
        MapObject(Instance, Rows, Plan, RowNumber, Options);
        Result.Add(Instance);
      except
        Instance.Free;
        raise;
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

class function TQueryMapper.FirstOrDefault<T>(const Rows: IQueryResult;
Options: TQueryMappingOptions): T;
var
  Plan: TMappingPlan;
begin
  Plan := BuildPlan(GetTypeData(TypeInfo(T))^.ClassType, Rows);
  Result := nil;
  if not Rows.Next then
    Exit;
  Result := T.Create;
  try
    MapObject(Result, Rows, Plan, 1, Options);
  except
    Result.Free;
    raise;
  end;
end;

initialization

MappingContext := TRttiContext.Create;
MetadataLock := TCriticalSection.Create;
MetadataCache := TDictionary<TClass, TClassMapping>.Create;

finalization

MetadataCache.Free;
MetadataLock.Free;
MappingContext.Free;

end.
