unit Execution.Mock;

interface

uses
  System.Rtti, System.TypInfo, QueryBuilder4Delphi.Query.Core,
  QueryBuilder4Delphi.Execution, QueryBuilder4Delphi.Compilers.Compiler;

type
  // Reusable provider-free fixture for execution and future mapping tests.
  TMockQueryResult = class(TInterfacedObject, IQueryResult)
  private
    FNames: TArray<string>;
    FTypes: TArray<TQueryValueType>;
    FRows: TRows;
    FPosition: Integer;
    FHasRows: Boolean;
    FAffected: Int64;
    procedure CheckIndex(Index: Integer);
    procedure RequireRows;
  public
    class var LiveCount: Integer;
  public
    ColumnNameReads: Integer;
    ColumnIndexLookups: Integer;
    NextCalls: Integer;
    NextFailureAt: Integer;
    constructor Create(const Names: TArray<string>;
      const Types: TArray<TQueryValueType>; const Rows: TRows; HasRows: Boolean;
      Affected: Int64);
    destructor Destroy; override;
    function Next: Boolean;
    function GetHasResultSet: Boolean;
    function GetRowsAffected: Int64;
    function GetColumnCount: Integer;
    function GetColumnName(Index: Integer): string;
    function GetColumnType(Index: Integer): TQueryValueType;
    function GetColumnIndex(const Name: string): Integer;
    function GetValue(Index: Integer): TValue; overload;
    function GetValue(const Name: string): TValue; overload;
    function IsNull(Index: Integer): Boolean; overload;
    function IsNull(const Name: string): Boolean; overload;
  end;

  TMockQueryExecutor = class(TQueryExecutor)
  public
  class var
    LiveCount: Integer;
    Names: TArray<string>;
    Types: TArray<TQueryValueType>;
    Data: TRows;
    Affected: Int64;
    LastMode: TQueryExecutionMode;
    Sql: string;
    BindingCount: Integer;
    Values: TValues;
    Tokens: TArray<string>;
    constructor Create(Dialect: TSqlDialect; const Prefix: string = ':p');
    destructor Destroy; override;
    function ExecuteCompiled(const Statement: ISqlResult;
      Mode: TQueryExecutionMode): IQueryResult; override;
  end;

implementation

uses System.SysUtils, System.SyncObjs;

constructor TMockQueryResult.Create(const Names: TArray<string>;
  const Types: TArray<TQueryValueType>; const Rows: TRows; HasRows: Boolean;
  Affected: Int64);
begin
  inherited Create;
  FNames := Copy(Names);
  FTypes := Copy(Types);
  FRows := Copy(Rows);
  FHasRows := HasRows;
  FAffected := Affected;
  FPosition := -1;
  TInterlocked.Increment(LiveCount);
end;

destructor TMockQueryResult.Destroy;
begin
  TInterlocked.Decrement(LiveCount);
  inherited;
end;

procedure TMockQueryResult.RequireRows;
begin
  if not FHasRows then
    raise EQueryException.Create('This command has no resultset');
end;

procedure TMockQueryResult.CheckIndex(Index: Integer);
begin
  RequireRows;
  if (Index < 0) or (Index >= Length(FNames)) then
    raise EQueryException.CreateFmt('Column index %d is out of range', [Index]);
end;

function TMockQueryResult.Next: Boolean;
begin
  Inc(NextCalls);
  if (NextFailureAt > 0) and (NextCalls = NextFailureAt) then
    raise EInvalidOp.Create('Provider Next failed');
  RequireRows;
  if FPosition < Length(FRows) then
    Inc(FPosition);
  Result := FPosition < Length(FRows);
end;

function TMockQueryResult.GetHasResultSet: Boolean;
begin
  Result := FHasRows;
end;

function TMockQueryResult.GetRowsAffected: Int64;
begin
  Result := FAffected;
end;

function TMockQueryResult.GetColumnCount: Integer;
begin
  RequireRows;
  Result := Length(FNames);
end;

function TMockQueryResult.GetColumnName(Index: Integer): string;
begin
  Inc(ColumnNameReads);
  CheckIndex(Index);
  Result := FNames[Index];
end;

function TMockQueryResult.GetColumnType(Index: Integer): TQueryValueType;
begin
  CheckIndex(Index);
  Result := FTypes[Index];
end;

function TMockQueryResult.GetColumnIndex(const Name: string): Integer;
var
  I: Integer;
begin
  Inc(ColumnIndexLookups);
  RequireRows;
  Result := -1;
  for I := 0 to High(FNames) do
    if SameText(FNames[I], Name) then
    begin
      if Result >= 0 then
        raise EQueryException.Create('Ambiguous column name: ' + Name);
      Result := I;
    end;
  if Result < 0 then
    raise EQueryException.Create('Column not found: ' + Name);
end;

function TMockQueryResult.GetValue(Index: Integer): TValue;
begin
  CheckIndex(Index);
  if (FPosition < 0) or (FPosition >= Length(FRows)) then
    raise EQueryException.Create('The result cursor is not on a row');
  Result := FRows[FPosition][Index];
end;

function TMockQueryResult.GetValue(const Name: string): TValue;
begin
  Result := GetValue(GetColumnIndex(Name));
end;

function TMockQueryResult.IsNull(const Name: string): Boolean;
begin
  Result := IsNull(GetColumnIndex(Name));
end;

function TMockQueryResult.IsNull(Index: Integer): Boolean;
begin
  Result := GetValue(Index).TypeInfo = nil;
end;

constructor TMockQueryExecutor.Create(Dialect: TSqlDialect;
  const Prefix: string);
begin
  inherited Create(Dialect, Prefix);
  Names := TArray<string>.Create('Id', 'Title', 'Price');
  Types := TArray<TQueryValueType>.Create(qtInt64, qtString, qtDecimal);
  Data := TRows.Create(TValues.Create(TValue.From<Int64>(1), 'Alpha',
    TValue.Empty), TValues.Create(TValue.From<Int64>(2), 'Beta', TValue.Empty));
  Affected := -1;
  Inc(LiveCount);
end;

destructor TMockQueryExecutor.Destroy;
begin
  Dec(LiveCount);
  inherited;
end;

function TMockQueryExecutor.ExecuteCompiled(const Statement: ISqlResult;
  Mode: TQueryExecutionMode): IQueryResult;
var
  I: Integer;
begin
  LastMode := Mode;
  Sql := Statement.Sql;
  BindingCount := Statement.Bindings.Count;
  Values := Statement.Bindings.ToArray;
  SetLength(Tokens, BindingCount);
  for I := 0 to BindingCount - 1 do
  begin
    Tokens[I] := ParameterPrefix + IntToStr(I);
    if not Statement.NamedBindings.ContainsKey(Tokens[I]) then
      raise EQueryException.Create
        ('Compiler violated the ordered/named parameter contract');
  end;
  Result := TMockQueryResult.Create(Names, Types, Data, Mode = emRows,
    Affected);
end;

end.
