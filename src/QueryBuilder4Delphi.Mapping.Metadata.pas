unit QueryBuilder4Delphi.Mapping.Metadata;

interface

uses
  System.SysUtils, System.Rtti, System.TypInfo, System.Generics.Collections,
  QueryBuilder4Delphi.Query.Core;

type
  /// <summary>
  /// Mapping exception for invalid property metadata, unsupported conversions, NULL policy violations, and
  /// row cardinality errors. Provider, constructor, callback, and property setter exceptions may propagate
  /// with their original classes.
  /// </summary>
  EQueryMappingException = class(EQueryException);

  /// <summary>
  /// Low-level mapping metadata shared by read and write mapping. Its RTTI references are borrowed from a
  /// context that must remain alive while metadata is used.
  /// </summary>
  TQueryPropertyMapping = record
    /// <summary>Borrowed RTTI property; the originating TRttiContext must remain alive.</summary>
    Prop: TRttiProperty;
    /// <summary>RTTI handle of the mapped property type.</summary>
    Target: PTypeInfo;
    /// <summary>Database column name resolved from the property name or its Column/Key attribute.</summary>
    Column: string;
    /// <summary>
    /// True when the property carries KeyAttribute and participates in object UPDATE predicates.
    /// </summary>
    IsKey: Boolean;
  end;

  // The caller keeps Context alive for the lifetime of the returned RTTI.
  // Validate the entire eligible set before reading values or invoking callbacks.
/// <summary>Validates and returns eligible property-to-column metadata.</summary>
/// <param name="AClass">Class with RTTI properties to inspect; field mappings are not supported.</param>
/// <param name="Context">Borrowed RTTI context; keep it alive while using the returned metadata.</param>
/// <param name="ForReading">
/// True selects writable public/published properties for row mapping; False selects readable RTTI properties
/// for object writes, including explicit nonpublic RTTI.
/// </param>
/// <returns>Managed metadata array containing borrowed RTTI; keep Context alive while using it.</returns>
/// <remarks>
/// Ignore wins. Multiple column attributes, blank names, or duplicate column names ignoring case raise
/// EQueryMappingException before any property values are read.
/// </remarks>
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
