unit QueryBuilder4Delphi.Mapping;

interface

uses
  System.SysUtils, System.Rtti, System.TypInfo, System.Generics.Collections,
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Nullable,
  QueryBuilder4Delphi.Mapping.Metadata;

type
  EQueryMappingException = QueryBuilder4Delphi.Mapping.Metadata.
    EQueryMappingException;

  TNullMappingBehavior = (nmbDefault, nmbThrow, nmbSkip);

  TQueryMappingOptions = class
  private type
    TNullableConverter = TFunc<TValue, Boolean, TQueryMappingOptions, TValue>;

    TConverter = record
      Source, Target: PTypeInfo;
      Convert: TFunc<TValue, TValue>;
    end;
  private
    FNullBehavior: TNullMappingBehavior;
    FNullables: TDictionary<PTypeInfo, TNullableConverter>;
    FConverters: TList<TConverter>;
    function GetSkipNullAssignment: Boolean;
    procedure SetSkipNullAssignment(Value: Boolean);
    class function ConvertMappedValue(const Value: TValue; Target: PTypeInfo;
      IsNull: Boolean; Options: TQueryMappingOptions): TValue; static;
    class function NullableConverter<T>: TNullableConverter; static;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterNullable<T>;
    procedure RegisterConverter<TSource, TTarget>(const Converter
      : TFunc<TSource, TTarget>);
    // Configure before use; do not mutate/free during a mapping operation.
    property NullBehavior: TNullMappingBehavior read FNullBehavior
      write FNullBehavior;
    // Compatibility alias: True selects nmbSkip; False selects nmbThrow.
    property SkipNullAssignment: Boolean read GetSkipNullAssignment
      write SetSkipNullAssignment;
  end;

  TQueryResultMappingHelper = record helper for TQueryResult
    function ToList<T: class, constructor>(Options: TQueryMappingOptions = nil)
      : TObjectList<T>;
    function FirstOrDefault<T: class, constructor>
      (Options: TQueryMappingOptions = nil): T;
    function First<T: class, constructor>
      (Options: TQueryMappingOptions = nil): T;
    function Single<T: class, constructor>
      (Options: TQueryMappingOptions = nil): T;
    function SingleOrDefault<T: class, constructor>
      (Options: TQueryMappingOptions = nil): T;
    procedure ForEach<T: class, constructor>(const Callback: TProc<T>;
      Options: TQueryMappingOptions = nil);
    function FirstOrElse<T: class, constructor>(const Fallback: TFunc<T>;
      Options: TQueryMappingOptions = nil): T;
    function SingleOrElse<T: class, constructor>(const Fallback: TFunc<T>;
      Options: TQueryMappingOptions = nil): T;
  end;

  TQueryMapper = class
  private type
    TPropertyMapping = TQueryPropertyMapping;

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
    class function CreateMapped<T: class, constructor>(const Rows: IQueryResult;
      const Plan: TMappingPlan; RowNumber: Integer;
      Options: TQueryMappingOptions): T; static;
  public
    // Validate schema before Next. ToList/ForEach consume all remaining rows;
    // First/FirstOrDefault call Next once; Single variants call it at most twice
    // (on multiple rows the cursor remains on row two, which is not mapped).
    // Returned lists own their objects; database-mapped objects belong to the caller.
    // OrElse fallback references retain their application's existing ownership.
    // Static methods never consume the caller's IQueryResult reference.
    class function ToList<T: class, constructor>(const Rows: IQueryResult;
      Options: TQueryMappingOptions = nil): TObjectList<T>; static;
    class function FirstOrDefault<T: class, constructor>
      (const Rows: IQueryResult; Options: TQueryMappingOptions = nil)
      : T; static;
    class function First<T: class, constructor>(const Rows: IQueryResult;
      Options: TQueryMappingOptions = nil): T; static;
    class function Single<T: class, constructor>(const Rows: IQueryResult;
      Options: TQueryMappingOptions = nil): T; static;
    class function SingleOrDefault<T: class, constructor>
      (const Rows: IQueryResult; Options: TQueryMappingOptions = nil)
      : T; static;
    // Never calls Next. Provider row access must reject an unpositioned cursor.
    class function MapCurrent<T: class, constructor>(const Rows: IQueryResult;
      Options: TQueryMappingOptions = nil): T; static;
    // Callback objects are borrowed, valid only until the callback returns.
    class procedure ForEach<T: class, constructor>(const Rows: IQueryResult;
      const Callback: TProc<T>; Options: TQueryMappingOptions = nil); static;
    // Validate Fallback before schema/cursor access, even if a row exists.
    // Only empty, valid results invoke it. Return its exact reference (or nil)
    // without modifying ownership; only database-mapped objects are caller-owned.
    class function FirstOrElse<T: class, constructor>(const Rows: IQueryResult;
      const Fallback: TFunc<T>; Options: TQueryMappingOptions = nil): T; static;
    class function SingleOrElse<T: class, constructor>(const Rows: IQueryResult;
      const Fallback: TFunc<T>; Options: TQueryMappingOptions = nil): T; static;
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

function TQueryResultMappingHelper.First<T>(Options: TQueryMappingOptions): T;
var
  Rows: IQueryResult;
begin
  Rows := Self.TakeRaw;
  try
    Result := TQueryMapper.First<T>(Rows, Options);
  finally
    Rows := nil;
  end;
end;

function TQueryResultMappingHelper.Single<T>(Options: TQueryMappingOptions): T;
var
  Rows: IQueryResult;
begin
  Rows := Self.TakeRaw;
  try
    Result := TQueryMapper.Single<T>(Rows, Options);
  finally
    Rows := nil;
  end;
end;

function TQueryResultMappingHelper.SingleOrDefault<T>
  (Options: TQueryMappingOptions): T;
var
  Rows: IQueryResult;
begin
  Rows := Self.TakeRaw;
  try
    Result := TQueryMapper.SingleOrDefault<T>(Rows, Options);
  finally
    Rows := nil;
  end;
end;

procedure TQueryResultMappingHelper.ForEach<T>(const Callback: TProc<T>;
  Options: TQueryMappingOptions);
var
  Rows: IQueryResult;
begin
  Rows := Self.TakeRaw;
  try
    TQueryMapper.ForEach<T>(Rows, Callback, Options);
  finally
    Rows := nil;
  end;
end;

function TQueryResultMappingHelper.FirstOrElse<T>(const Fallback: TFunc<T>;
  Options: TQueryMappingOptions): T;
var
  Rows: IQueryResult;
begin
  Rows := Self.TakeRaw;
  try
    if not Assigned(Fallback) then
      raise EArgumentNilException.Create('Fallback');
    Result := TQueryMapper.FirstOrDefault<T>(Rows, Options);
  finally
    Rows := nil;
  end;
  // Deliberately invoke outside the result's lifetime: the callback may query
  // the same connection. Static OrDefault supplies all mapping/validation.
  if Result = nil then
    Result := Fallback();
end;

function TQueryResultMappingHelper.SingleOrElse<T>(const Fallback: TFunc<T>;
  Options: TQueryMappingOptions): T;
var
  Rows: IQueryResult;
begin
  Rows := Self.TakeRaw;
  try
    if not Assigned(Fallback) then
      raise EArgumentNilException.Create('Fallback');
    Result := TQueryMapper.SingleOrDefault<T>(Rows, Options);
  finally
    Rows := nil;
  end;
  if Result = nil then
    Result := Fallback();
end;

type
  TPropertyMapping = TQueryMapper.TPropertyMapping;
  TClassMapping = TArray<TPropertyMapping>;

  TBuiltInNullables = class
  private
    class procedure Add<T>; static;
  public
    class procedure Initialize; static;
  end;

var
  // Retaining this context keeps every cached RTTI property/type alive.
  MappingContext: TRttiContext;
  MetadataLock: TCriticalSection;
  MetadataCache: TDictionary<TClass, TClassMapping>;
  // Published by unit initialization; never mutated during mapping.
  BuiltInNullables
    : TDictionary<PTypeInfo, TQueryMappingOptions.TNullableConverter>;
  BuiltInInnerTypes: TDictionary<PTypeInfo, PTypeInfo>;

class procedure TBuiltInNullables.Add<T>;
var
  Inner: PTypeInfo;
begin
  if BuiltInInnerTypes.TryGetValue(TypeInfo(TNullable<T>), Inner) then
  begin
    // Compiler aliases can share the same closed generic RTTI identity.
    if Inner <> TypeInfo(T) then
      raise EQueryMappingException.Create
        ('Conflicting built-in nullable RTTI identity');
    Exit;
  end;
  BuiltInInnerTypes.Add(TypeInfo(TNullable<T>), TypeInfo(T));
  BuiltInNullables.Add(TypeInfo(TNullable<T>),
    TQueryMappingOptions.NullableConverter<T>());
end;

class procedure TBuiltInNullables.Initialize;
begin
  Add<ShortInt>;
  Add<SmallInt>;
  Add<Integer>;
  Add<Int64>;
  Add<Byte>;
  Add<Word>;
  Add<Cardinal>;
  Add<UInt64>;
  Add<Boolean>;
  Add<string>;
  Add<Single>;
  Add<Double>;
  Add<Extended>;
  Add<Currency>;
  Add<TDateTime>;
  Add<TBcd>;
  Add<TSQLTimeStamp>;
  Add<TSQLTimeStampOffset>;
  Add<TGUID>;
  Add<TBytes>;
end;

function ClassMapping(AClass: TClass): TClassMapping;
begin
  MetadataLock.Acquire;
  try
    if MetadataCache.TryGetValue(AClass, Result) then
      Exit;
    Result := QueryPropertyMappings(AClass, MappingContext, True);
    if Length(Result) = 0 then
      raise EQueryMappingException.CreateFmt
        ('%s has no public/published writable properties with RTTI',
        [AClass.ClassName]);
    MetadataCache.Add(AClass, Result);
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

function IsSupportedTarget(Target: PTypeInfo): Boolean;
begin
  Result := (IsIntegerType(Target) or IsFloatType(Target) or
    (Target = TypeInfo(string)) or (Target = TypeInfo(Boolean)) or
    (Target = TypeInfo(Currency)) or (Target = TypeInfo(TDateTime)) or
    (Target = TypeInfo(TBcd)) or (Target = TypeInfo(TSQLTimeStamp)) or
    (Target = TypeInfo(TSQLTimeStampOffset)) or (Target = TypeInfo(TGUID)) or
    (Target = TypeInfo(TBytes)));
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
  if (Value.TypeInfo = Target) and IsSupportedTarget(Target) then
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
  FNullBehavior := nmbDefault;
  FNullables := TDictionary<PTypeInfo, TNullableConverter>.Create;
  FConverters := TList<TConverter>.Create;
end;

function TQueryMappingOptions.GetSkipNullAssignment: Boolean;
begin
  Result := FNullBehavior = nmbSkip;
end;

procedure TQueryMappingOptions.SetSkipNullAssignment(Value: Boolean);
begin
  if Value then
    FNullBehavior := nmbSkip
  else
    FNullBehavior := nmbThrow;
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
  FNullables.Add(TypeInfo(TNullable<T>), NullableConverter<T>());
end;

class function TQueryMappingOptions.NullableConverter<T>: TNullableConverter;
begin
  Result := function(Value: TValue; IsNull: Boolean;
      Options: TQueryMappingOptions): TValue
    var
      Inner: TValue;
    begin
      if IsNull then
        Exit(TValue.From < TNullable < T >> (TNullable<T>.Null));
      Inner := ConvertMappedValue(Value, TypeInfo(T), False, Options);
      Result := TValue.From < TNullable < T >>
        (TNullable<T>.Create(Inner.AsType<T>));
    end;
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

class function TQueryMappingOptions.ConvertMappedValue(const Value: TValue;
  Target: PTypeInfo; IsNull: Boolean; Options: TQueryMappingOptions): TValue;
var
  Nullable: TQueryMappingOptions.TNullableConverter;
  Item: TQueryMappingOptions.TConverter;
begin
  if (Options <> nil) and Options.FNullables.TryGetValue(Target, Nullable) then
    Exit(Nullable(Value, IsNull, Options));
  // Preserve exact converters returning the complete destination, including
  // nullable records. SQL NULL always follows nullable construction/policy.
  if not IsNull and (Options <> nil) then
    for Item in Options.FConverters do
      if (Item.Source = Value.TypeInfo) and (Item.Target = Target) then
        Exit(Item.Convert(Value));
  if BuiltInNullables.TryGetValue(Target, Nullable) then
    Exit(Nullable(Value, IsNull, Options));
  if IsNull then
  begin
    if ((Options = nil) or (Options.NullBehavior = nmbDefault)) and
      IsSupportedTarget(Target) then
    begin
      // RTL initializes a typed default, including records and managed arrays.
      TValue.Make(nil, Target, Result);
      Exit;
    end;
    raise EQueryMappingException.Create
      ('SQL NULL requires a nullable target or nmbDefault for a supported type');
  end;
  Result := ConvertValue(Value, Target);
end;

class procedure TQueryMapper.MapObject(Instance: TObject;
  const Rows: IQueryResult; const Plan: TMappingPlan; RowNumber: Integer;
  Options: TQueryMappingOptions);
var
  Binding: TColumnMapping;
  Value: TValue;
  Source: string;
  ReadValue, NullValue: Boolean;
  SourceInfo: PTypeInfo;
begin
  for Binding in Plan do
  begin
    ReadValue := False;
    NullValue := False;
    SourceInfo := nil;
    try
      // Do not use TValue.IsEmpty: a typed empty byte array can be IsEmpty.
      if Rows.IsNull(Binding.Index) then
      begin
        NullValue := True;
        if (Options <> nil) and (Options.NullBehavior = nmbSkip) and
          not Options.FNullables.ContainsKey(Binding.Metadata.Target) and
          not BuiltInNullables.ContainsKey(Binding.Metadata.Target) then
          Continue;
        Value := TQueryMappingOptions.ConvertMappedValue(TValue.Empty,
          Binding.Metadata.Target, True, Options);
      end
      else
      begin
        Value := Rows.GetValue(Binding.Index);
        SourceInfo := Value.TypeInfo;
        ReadValue := True;
        Value := TQueryMappingOptions.ConvertMappedValue(Value,
          Binding.Metadata.Target, False, Options);
      end;
      Binding.Metadata.Prop.SetValue(Instance, Value);
    except
      on E: Exception do
      begin
        // Allocate diagnostic strings only on failure, never per mapped value.
        Source := '<unread>';
        if NullValue then
          Source := 'SQL NULL'
        else if ReadValue then
          Source := TypeName(SourceInfo);
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
      Instance := CreateMapped<T>(Rows, Plan, RowNumber, Options);
      try
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
  Result := CreateMapped<T>(Rows, Plan, 1, Options);
end;

class function TQueryMapper.CreateMapped<T>(const Rows: IQueryResult;
  const Plan: TMappingPlan; RowNumber: Integer;
  Options: TQueryMappingOptions): T;
begin
  Result := T.Create;
  try
    MapObject(Result, Rows, Plan, RowNumber, Options);
  except
    Result.Free;
    raise;
  end;
end;

class function TQueryMapper.First<T>(const Rows: IQueryResult;
  Options: TQueryMappingOptions): T;
begin
  Result := FirstOrDefault<T>(Rows, Options);
  if Result = nil then
    raise EQueryMappingException.Create
      ('First requires at least one remaining row');
end;

class function TQueryMapper.SingleOrDefault<T>(const Rows: IQueryResult;
  Options: TQueryMappingOptions): T;
begin
  Result := FirstOrDefault<T>(Rows, Options);
  if Result = nil then
    Exit;
  try
    if Rows.Next then
      raise EQueryMappingException.Create
        ('Single requires exactly one remaining row; multiple rows found');
  except
    Result.Free;
    raise;
  end;
end;

class function TQueryMapper.Single<T>(const Rows: IQueryResult;
  Options: TQueryMappingOptions): T;
begin
  Result := SingleOrDefault<T>(Rows, Options);
  if Result = nil then
    raise EQueryMappingException.Create
      ('Single requires exactly one remaining row; no rows found');
end;

class function TQueryMapper.MapCurrent<T>(const Rows: IQueryResult;
  Options: TQueryMappingOptions): T;
var
  Plan: TMappingPlan;
begin
  Plan := BuildPlan(GetTypeData(TypeInfo(T))^.ClassType, Rows);
  Result := CreateMapped<T>(Rows, Plan, 0, Options);
end;

class procedure TQueryMapper.ForEach<T>(const Rows: IQueryResult;
  const Callback: TProc<T>; Options: TQueryMappingOptions);
var
  Plan: TMappingPlan;
  Instance: T;
  RowNumber: Integer;
begin
  if not Assigned(Callback) then
    raise EArgumentNilException.Create('Callback');
  Plan := BuildPlan(GetTypeData(TypeInfo(T))^.ClassType, Rows);
  RowNumber := 0;
  while Rows.Next do
  begin
    Inc(RowNumber);
    Instance := CreateMapped<T>(Rows, Plan, RowNumber, Options);
    try
      Callback(Instance);
    finally
      Instance.Free;
    end;
  end;
end;

class function TQueryMapper.FirstOrElse<T>(const Rows: IQueryResult;
  const Fallback: TFunc<T>; Options: TQueryMappingOptions): T;
begin
  if not Assigned(Fallback) then
    raise EArgumentNilException.Create('Fallback');
  Result := FirstOrDefault<T>(Rows, Options);
  if Result = nil then
    Result := Fallback();
end;

class function TQueryMapper.SingleOrElse<T>(const Rows: IQueryResult;
  const Fallback: TFunc<T>; Options: TQueryMappingOptions): T;
begin
  if not Assigned(Fallback) then
    raise EArgumentNilException.Create('Fallback');
  Result := SingleOrDefault<T>(Rows, Options);
  if Result = nil then
    Result := Fallback();
end;

initialization

MappingContext := TRttiContext.Create;
BuiltInNullables :=
  TDictionary<PTypeInfo, TQueryMappingOptions.TNullableConverter>.Create;
BuiltInInnerTypes := TDictionary<PTypeInfo, PTypeInfo>.Create;
TBuiltInNullables.Initialize;
FreeAndNil(BuiltInInnerTypes);
MetadataLock := TCriticalSection.Create;
MetadataCache := TDictionary<TClass, TClassMapping>.Create;

finalization

BuiltInNullables.Free;
MetadataCache.Free;
MetadataLock.Free;
MappingContext.Free;

end.
