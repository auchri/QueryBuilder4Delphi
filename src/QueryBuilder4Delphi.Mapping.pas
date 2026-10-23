unit QueryBuilder4Delphi.Mapping;

interface

uses
  System.SysUtils, System.Rtti, System.TypInfo, System.Generics.Collections,
  QueryBuilder4Delphi.Query.Core;

type
  EQueryMappingException = class(EQueryException);

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
      const Plan: TMappingPlan; RowNumber: Integer); static;
  public
    // Calls Next: ToList consumes all remaining rows; FirstOrDefault consumes
    // at most one. The caller owns the returned list/object.
    class function ToList<T: class, constructor>(const Rows: IQueryResult)
      : TObjectList<T>; static;
    class function FirstOrDefault<T: class, constructor>
      (const Rows: IQueryResult): T; static;
  end;

implementation

uses
  System.SyncObjs, System.Math;

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
    (Info = TypeInfo(Cardinal));
end;

function IsFloatType(Info: PTypeInfo): Boolean;
begin
  Result := (Info = TypeInfo(Single)) or (Info = TypeInfo(Double)) or
    (Info = TypeInfo(Extended));
end;

function ConvertValue(const Value: TValue; Target: PTypeInfo): TValue;
var
  Number: Int64;
  FloatValue: Extended;
  AsSingle: Single;
  AsDouble: Double;
begin
  // Explicit scalar whitelist, even for same-type assignments. Records, arrays,
  // objects, enums, variants and other advanced types belong to later versions.
  if (Target = TypeInfo(Integer)) or (Target = TypeInfo(Int64)) then
  begin
    if IsIntegerType(Value.TypeInfo) then
    begin
      Number := Value.AsInt64;
      if Target = TypeInfo(Int64) then
        Exit(TValue.From<Int64>(Number));
      if (Number >= Low(Integer)) and (Number <= High(Integer)) then
        Exit(TValue.From<Integer>(Integer(Number)));
    end;
  end
  else if (Target = TypeInfo(string)) or (Target = TypeInfo(Boolean)) or
    (Target = TypeInfo(Currency)) or (Target = TypeInfo(TDateTime)) then
  begin
    if Value.TypeInfo = Target then
      Exit(Value);
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
  raise EQueryMappingException.Create('Unsupported or lossy scalar conversion');
end;

class procedure TQueryMapper.MapObject(Instance: TObject;
  const Rows: IQueryResult; const Plan: TMappingPlan; RowNumber: Integer);
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
        raise EQueryMappingException.Create
          ('SQL NULL has no supported nullable representation');
      end;
      Value := Rows.GetValue(Binding.Index);
      Source := TypeName(Value.TypeInfo);
      Binding.Metadata.Prop.SetValue(Instance,
        ConvertValue(Value, Binding.Metadata.Target));
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

class function TQueryMapper.ToList<T>(const Rows: IQueryResult): TObjectList<T>;
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
        MapObject(Instance, Rows, Plan, RowNumber);
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

class function TQueryMapper.FirstOrDefault<T>(const Rows: IQueryResult): T;
var
  Plan: TMappingPlan;
begin
  Plan := BuildPlan(GetTypeData(TypeInfo(T))^.ClassType, Rows);
  Result := nil;
  if not Rows.Next then
    Exit;
  Result := T.Create;
  try
    MapObject(Result, Rows, Plan, 1);
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
