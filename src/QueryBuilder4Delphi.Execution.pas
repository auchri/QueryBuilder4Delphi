unit QueryBuilder4Delphi.Execution;

interface

uses
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Compilers.Compiler;

type
  TQueryExecutor = class abstract(TInterfacedObject, IQueryExecutor)
  private
    FDialect: TSqlDialect;
  protected
    function ExecuteCompiled(const Statement: ISqlResult;
      Mode: TQueryExecutionMode): IQueryResult; virtual; abstract;
  public
    constructor Create(Dialect: TSqlDialect);
    function Execute(const Query: IQuery; Mode: TQueryExecutionMode = emAuto)
      : IQueryResult;
    property Dialect: TSqlDialect read FDialect;
  end;

implementation

uses
  System.SysUtils, QueryBuilder4Delphi.Compilers.Factory;

constructor TQueryExecutor.Create(Dialect: TSqlDialect);
begin
  inherited Create;
  FDialect := Dialect;
end;

function TQueryExecutor.Execute(const Query: IQuery; Mode: TQueryExecutionMode)
  : IQueryResult;
var
  Snapshot: IQuery;
  Compiler: ICompiler;
  Clause: TClause;
begin
  if Query = nil then
    raise EArgumentNilException.Create('Query');
  if not(Mode in [emAuto, emRows, emCommand]) then
    raise EQueryException.Create('Invalid execution mode');
  Snapshot := Query.Clone;
  // Identity retrieval may append a second statement. Never discard it silently.
  for Clause in Snapshot.GetComponents('insert', FDialect.EngineCode) do
    if Clause.ReturnId then
      raise EQueryException.Create
        ('ReturnId batches are not supported by execution');
  if Mode = emAuto then
  begin
    if (Snapshot.Method = 'select') or (Snapshot.Method = 'aggregate') then
      Mode := emRows
    else if (Snapshot.Method = 'insert') or (Snapshot.Method = 'update') or
      (Snapshot.Method = 'delete') then
      Mode := emCommand
    else
      raise EQueryException.Create
        ('Unknown query method; specify an execution mode');
  end;
  Compiler := CreateCompiler(FDialect);
  Compiler.ParameterPrefix := ':p';
  Result := ExecuteCompiled(Compiler.Compile(Snapshot), Mode);
end;

end.
