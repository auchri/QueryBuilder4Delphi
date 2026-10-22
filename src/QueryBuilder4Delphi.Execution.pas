unit QueryBuilder4Delphi.Execution;

interface

uses
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Compilers.Compiler;

type
  TQueryExecutor = class abstract(TInterfacedObject, IQueryExecutor)
  private
    FDialect: TSqlDialect;
    FParameterPrefix: string;
  protected
    function CreateCompiler: ICompiler; virtual;
    function ExecuteCompiled(const Statement: ISqlResult;
      Mode: TQueryExecutionMode): IQueryResult; virtual; abstract;
  public
    constructor Create(Dialect: TSqlDialect;
      const ParameterPrefix: string = ':p');
    function Execute(const Query: IQuery; Mode: TQueryExecutionMode = emAuto)
      : IQueryResult;
    property ParameterPrefix: string read FParameterPrefix;
    property Dialect: TSqlDialect read FDialect;
  end;

implementation

uses
  System.SysUtils, QueryBuilder4Delphi.Compilers.Factory,
  QueryBuilder4Delphi.Sql.Lexer;

constructor TQueryExecutor.Create(Dialect: TSqlDialect;
  const ParameterPrefix: string);
begin
  inherited Create;
  FDialect := Dialect;
  if ParameterPrefix = '' then
    raise EQueryException.Create('A named parameter prefix is required');
  FParameterPrefix := ParameterPrefix;
end;

function TQueryExecutor.CreateCompiler: ICompiler;
begin
  Result := QueryBuilder4Delphi.Compilers.Factory.CreateCompiler(FDialect);
  Result.ParameterPrefix := FParameterPrefix;
end;

function TQueryExecutor.Execute(const Query: IQuery; Mode: TQueryExecutionMode)
  : IQueryResult;
var
  Snapshot: IQuery;
  Compiler: ICompiler;
  Clause: TClause;
  Statement: ISqlResult;
begin
  if Query = nil then
    raise EArgumentNilException.Create('Query');
  if not(Mode in [emAuto, emRows, emCommand]) then
    raise EQueryException.Create('Invalid execution mode');
  Compiler := CreateCompiler;
  if Compiler = nil then
    raise EQueryException.Create('The compiler factory returned nil');
  Snapshot := Query.Clone;
  // Identity retrieval may append a second statement. Never discard it silently.
  for Clause in Snapshot.GetComponents('insert', Compiler.EngineCode) do
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
  Statement := Compiler.Compile(Snapshot);
  if Statement = nil then
    raise EQueryException.Create('The compiler returned nil SQL');
  ValidateSingleStatement(Statement.Sql, Compiler.EngineCode = 'mysql');
  Result := ExecuteCompiled(Statement, Mode);
end;

end.
