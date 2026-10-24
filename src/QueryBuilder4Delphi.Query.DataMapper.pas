unit QueryBuilder4Delphi.Query.DataMapper;

interface

uses
  System.SysUtils, System.Rtti, System.Generics.Collections;

type
  TQueryDataMapper = class
  public
    class function GetPairs(Data: TObject;
      const OnKey: TProc<string, TValue> = nil)
      : TArray<TPair<string, TValue>>; static;
  end;

implementation

uses
  QueryBuilder4Delphi.Mapping.Metadata;

class function TQueryDataMapper.GetPairs(Data: TObject;
  const OnKey: TProc<string, TValue>): TArray<TPair<string, TValue>>;
var
  Context: TRttiContext;
  Item: TQueryPropertyMapping;
  Metadata: TArray<TQueryPropertyMapping>;
  Pairs: TList<TPair<string, TValue>>;
  Value: TValue;
begin
  if Data = nil then
    raise EArgumentNilException.Create('Data');
  Context := TRttiContext.Create;
  Pairs := TList < TPair < string, TValue >>.Create;
  try
    Metadata := QueryPropertyMappings(Data.ClassType, Context, False);
    for Item in Metadata do
    begin
      Value := Item.Prop.GetValue(Data);
      Pairs.Add(TPair<string, TValue>.Create(Item.Column, Value));
      if Item.IsKey and Assigned(OnKey) then
        OnKey(Item.Column, Value);
    end;
    Result := Pairs.ToArray;
  finally
    Pairs.Free;
    Context.Free;
  end;
end;

end.
