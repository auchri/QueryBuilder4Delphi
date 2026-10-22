unit QueryBuilder4Delphi.Providers.FireDAC;

interface

uses
  FireDAC.Comp.Client, QueryBuilder4Delphi.Query.Core,
  QueryBuilder4Delphi.Compilers.Compiler, QueryBuilder4Delphi.Execution;

type
  // The connection belongs to the caller and must outlive all results.
  TFireDACQueryExecutor = class(TQueryExecutor)
  private
    FConnection: TFDConnection;
  protected
    function ExecuteCompiled(const Statement: ISqlResult;
      Mode: TQueryExecutionMode): IQueryResult; override;
  public
    constructor Create(Connection: TFDConnection;
      Dialect: TSqlDialect = TSqlDialect.MSSql);
  end;

implementation

uses
  System.SysUtils, System.Classes, System.Rtti, Data.DB, Data.FmtBcd,
  FireDAC.Stan.Param, QueryBuilder4Delphi.Providers.FireDAC.Parameters,
  QueryBuilder4Delphi.Providers.FireDAC.Values;

type
  TFireDACQueryResult = class(TInterfacedObject, IQueryResult)
  private
    FQuery: TFDQuery;
    FHasRows, FStarted, FCurrent, FFinished: Boolean;
    FRowsAffected: Int64;
    procedure RequireRows;
    procedure CheckIndex(Index: Integer);
    function Field(Index: Integer): TField;
  public
    constructor Create(Query: TFDQuery; HasRows: Boolean);
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
    function IsNull(Index: Integer): Boolean;
  end;

constructor TFireDACQueryExecutor.Create(Connection: TFDConnection;
  Dialect: TSqlDialect);
begin
  inherited Create(Dialect);
  if Connection = nil then
    raise EArgumentNilException.Create('Connection');
  FConnection := Connection;
end;

function TFireDACQueryExecutor.ExecuteCompiled(const Statement: ISqlResult;
  Mode: TQueryExecutionMode): IQueryResult;
var
  Query: TFDQuery;
  Params: TFDParams;
begin
  // Never auto-connect or change the application's transaction boundaries.
  if not FConnection.Connected then
    raise EQueryException.Create
      ('The FireDAC connection must be connected before execution');
  Params := TFireDACParameterBinder.Bind(Statement);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      // Prefer TBcd storage to Currency for driver decimal values.
      Query.FormatOptions.MaxBcdPrecision := 0;
      Query.FormatOptions.MaxBcdScale := 0;
      Query.FormatOptions.StrsEmpty2Null := False;
      Query.ResourceOptions.ParamCreate := False;
      Query.ResourceOptions.ParamExpand := True;
      Query.ResourceOptions.MacroCreate := False;
      Query.ResourceOptions.MacroExpand := False;
      Query.ResourceOptions.EscapeExpand := False;
      // Expose the first result only; closing the result closes the command.
      Query.FetchOptions.AutoClose := False;
      Query.SQL.Text := Statement.SQL;
      Query.Params.Assign(Params);
      if Mode = emRows then
        Query.Open
      else
        Query.ExecSQL;
      Result := TFireDACQueryResult.Create(Query, Mode = emRows);
      Query := nil;
    finally
      Query.Free;
    end;
  finally
    Params.Free;
  end;
end;

constructor TFireDACQueryResult.Create(Query: TFDQuery; HasRows: Boolean);
begin
  inherited Create;
  FHasRows := HasRows;
  FRowsAffected := Query.RowsAffected;
  if FRowsAffected < 0 then
    FRowsAffected := -1;
  FQuery := Query;
end;

destructor TFireDACQueryResult.Destroy;
begin
  FQuery.Free;
  inherited;
end;

procedure TFireDACQueryResult.RequireRows;
begin
  if not FHasRows then
    raise EQueryException.Create('This command has no resultset');
end;

procedure TFireDACQueryResult.CheckIndex(Index: Integer);
begin
  RequireRows;
  if (Index < 0) or (Index >= FQuery.FieldCount) then
    raise EQueryException.CreateFmt
      ('Column index %d is out of range (count %d)',
      [Index, FQuery.FieldCount]);
end;

function TFireDACQueryResult.Field(Index: Integer): TField;
begin
  CheckIndex(Index);
  if not FCurrent then
    raise EQueryException.Create
      ('The result cursor is not on a row; call Next');
  Result := FQuery.Fields[Index];
end;

function TFireDACQueryResult.Next: Boolean;
begin
  RequireRows;
  if FFinished then
    Exit(False);
  FCurrent := False;
  if FStarted then
    FQuery.Next
  else
    FStarted := True;
  FCurrent := not FQuery.Eof;
  FFinished := not FCurrent;
  Result := FCurrent;
end;

function TFireDACQueryResult.GetHasResultSet: Boolean;
begin
  Result := FHasRows;
end;

function TFireDACQueryResult.GetRowsAffected: Int64;
begin
  Result := FRowsAffected;
end;

function TFireDACQueryResult.GetColumnCount: Integer;
begin
  RequireRows;
  Result := FQuery.FieldCount;
end;

function TFireDACQueryResult.GetColumnName(Index: Integer): string;
begin
  CheckIndex(Index);
  Result := FQuery.Fields[Index].FieldName;
end;

function TFireDACQueryResult.GetColumnIndex(const Name: string): Integer;
var
  I: Integer;
begin
  RequireRows;
  Result := -1;
  for I := 0 to FQuery.FieldCount - 1 do
    if SameText(FQuery.Fields[I].FieldName, Name) then
    begin
      if Result >= 0 then
        raise EQueryException.CreateFmt
          ('Ambiguous column name: %s; use its index', [Name]);
      Result := I;
    end;
  if Result < 0 then
    raise EQueryException.CreateFmt('Column not found: %s', [Name]);
end;

function TFireDACQueryResult.IsNull(Index: Integer): Boolean;
begin
  Result := Field(Index).IsNull;
end;

function TFireDACQueryResult.GetValue(const Name: string): TValue;
begin
  Result := GetValue(GetColumnIndex(Name));
end;

function TFireDACQueryResult.GetColumnType(Index: Integer): TQueryValueType;
begin
  CheckIndex(Index);
  Result := TFireDACFieldReader.ValueType(FQuery.Fields[Index]);
end;

function TFireDACQueryResult.GetValue(Index: Integer): TValue;
begin
  Result := TFireDACFieldReader.ReadValue(Field(Index));
end;

end.
