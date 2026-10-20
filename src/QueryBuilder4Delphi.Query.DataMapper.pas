unit QueryBuilder4Delphi.Query.DataMapper;

interface

uses
  System.SysUtils, System.Rtti, System.Generics.Collections;

type
  TQueryDataMapper = class
  public
    class function GetPairs(Data: TObject;
      const OnKey: TProc<string, TValue> = nil): TArray<TPair<string, TValue>>; static;
  end;

implementation

uses
  QueryBuilder4Delphi.Query.Core;

class function TQueryDataMapper.GetPairs(Data: TObject;
  const OnKey: TProc<string, TValue>): TArray<TPair<string, TValue>>;
var
  Context: TRttiContext;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  Pairs: TList<TPair<string, TValue>>;
  Name: string;
  Skip, IsKey: Boolean;
  Value: TValue;
begin
  if Data = nil then
    raise EArgumentNilException.Create('Data');
  Context := TRttiContext.Create;
  Pairs := TList<TPair<string, TValue>>.Create;
  try
    for Prop in Context.GetType(Data.ClassType).GetProperties do
    begin
      if not Prop.IsReadable then
        Continue;
      Name := Prop.Name;
      Skip := False;
      IsKey := False;
      for Attr in Prop.GetAttributes do
      begin
        if Attr is IgnoreAttribute then
          Skip := True;
        if Attr is ColumnAttribute then
          Name := ColumnAttribute(Attr).Name;
        if Attr is KeyAttribute then
          IsKey := True;
      end;
      if Skip then
        Continue;
      Value := Prop.GetValue(Data);
      Pairs.Add(TPair<string, TValue>.Create(Name, Value));
      if IsKey and Assigned(OnKey) then
        OnKey(Name, Value);
    end;
    Result := Pairs.ToArray;
  finally
    Pairs.Free;
    Context.Free;
  end;
end;

end.
