unit QueryBuilder4Delphi.Mapping.Metadata;

interface

uses
  System.SysUtils, System.Rtti, System.TypInfo, System.Generics.Collections,
  QueryBuilder4Delphi.Query.Core;

type
  EQueryMappingException = class(EQueryException);

  TQueryPropertyMapping = record
    Prop: TRttiProperty;
    Target: PTypeInfo;
    Column: string;
    IsKey: Boolean;
  end;

  // The caller keeps Context alive for the lifetime of the returned RTTI.
  // Validate the entire eligible set before reading values or invoking callbacks.
function QueryPropertyMappings(AClass: TClass; const Context: TRttiContext;
  ForReading: Boolean): TArray<TQueryPropertyMapping>;

implementation

function QueryPropertyMappings(AClass: TClass; const Context: TRttiContext;
  ForReading: Boolean): TArray<TQueryPropertyMapping>;
var
  RttiType: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  Item, Existing: TQueryPropertyMapping;
  Items: TList<TQueryPropertyMapping>;
  Skip: Boolean;
  ColumnAttributes: Integer;
begin
  Items := TList<TQueryPropertyMapping>.Create;
  try
    RttiType := Context.GetType(AClass);
    if RttiType <> nil then
      for Prop in RttiType.GetProperties do
      begin
        if Prop.PropertyType = nil then
          Continue;
        if ForReading then
        begin
          if not Prop.IsWritable or
            not(Prop.Visibility in [mvPublic, mvPublished]) then
            Continue;
        end
        // Preserve the write mapper's existing explicit nonpublic property RTTI
        // support. Fields (including private backing fields) are never inspected.
        else if not Prop.IsReadable then
          Continue;
        Item.Prop := Prop;
        Item.Target := Prop.PropertyType.Handle;
        Item.Column := Prop.Name;
        Item.IsKey := False;
        Skip := False;
        ColumnAttributes := 0;
        for Attr in Prop.GetAttributes do
        begin
          if Attr is IgnoreAttribute then
            Skip := True;
          if Attr is ColumnAttribute then
          begin
            Inc(ColumnAttributes);
            Item.Column := ColumnAttribute(Attr).Name;
          end;
          if Attr is KeyAttribute then
            Item.IsKey := True;
        end;
        // Ignore wins, including over otherwise invalid mapping attributes.
        if Skip then
          Continue;
        if ColumnAttributes > 1 then
          raise EQueryMappingException.CreateFmt
            ('%s.%s has multiple column mapping attributes',
            [AClass.ClassName, Prop.Name]);
        if Trim(Item.Column) = '' then
          raise EQueryMappingException.CreateFmt
            ('%s.%s has an empty column mapping name',
            [AClass.ClassName, Prop.Name]);
        for Existing in Items do
          if SameText(Existing.Column, Item.Column) then
            raise EQueryMappingException.CreateFmt
              ('%s: properties "%s" and "%s" map to the same column "%s"',
              [AClass.ClassName, Existing.Prop.Name, Prop.Name, Item.Column]);
        Items.Add(Item);
      end;
    Result := Items.ToArray;
  finally
    Items.Free;
  end;
end;

end.
