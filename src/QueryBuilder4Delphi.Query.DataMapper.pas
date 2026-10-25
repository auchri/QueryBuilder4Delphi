unit QueryBuilder4Delphi.Query.DataMapper;

interface

uses
  System.SysUtils, System.Rtti, System.Generics.Collections,
  QueryBuilder4Delphi.Mapping;

type
  TQueryDataMapper = class
  public
    class function GetPairs(Data: TObject;
      const OnKey: TProc<string, TValue> = nil;
      Options: TQueryMappingOptions = nil)
      : TArray<TPair<string, TValue>>; static;
  end;

implementation

uses
  QueryBuilder4Delphi.Mapping.Metadata, QueryBuilder4Delphi.Query.Core;

class function TQueryDataMapper.GetPairs(Data: TObject;
  const OnKey: TProc<string, TValue>; Options: TQueryMappingOptions)
  : TArray<TPair<string, TValue>>;
var
  Context: TRttiContext;
  Item: TQueryPropertyMapping;
  Metadata: TArray<TQueryPropertyMapping>;
  Pairs: TList<TPair<string, TValue>>;
  Value: TValue;
  I: Integer;
begin
  if Data = nil then
    raise EArgumentNilException.Create('Data');
  Context := TRttiContext.Create;
  Pairs := TList < TPair < string, TValue >>.Create;
  try
    Metadata := QueryPropertyMappings(Data.ClassType, Context, False);
    for Item in Metadata do
    begin
      Value := TQueryMappingOptions.ToParameter
        (Item.Prop.GetValue(Data), Options);
      if Item.IsKey and Assigned(OnKey) and Value.IsType<TQueryNull>(False) then
        raise EQueryMappingException.CreateFmt('UPDATE key "%s" cannot be NULL',
          [Item.Column]);
      Pairs.Add(TPair<string, TValue>.Create(Item.Column, Value));

    end;
    Result := Pairs.ToArray;
    // Validate the entire DTO before callbacks mutate the query.
    if Assigned(OnKey) then
      for I := 0 to High(Metadata) do
        if Metadata[I].IsKey then
          OnKey(Metadata[I].Column, Result[I].Value);
  finally
    Pairs.Free;
    Context.Free;
  end;
end;

end.
