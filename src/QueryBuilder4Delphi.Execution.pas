unit QueryBuilder4Delphi.Execution;

interface

uses
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Compilers.Compiler;

type
  /// <summary>
  /// Provider base class that clones the query, chooses execution mode, compiles with its dialect and
  /// parameter prefix, then delegates to the provider. ReturnId batches are rejected. It does not own
  /// application connections or manage transaction boundaries.
  /// </summary>
  TQueryExecutor = class abstract(TInterfacedObject, IQueryExecutor)
  private
    FDialect: TSqlDialect;
    FParameterPrefix: string;
  protected
    function CreateCompiler: ICompiler; virtual;
    function ExecuteCompiled(const Statement: ISqlResult;
      Mode: TQueryExecutionMode): IQueryResult; virtual; abstract;
  public
    /// <summary>Initializes compilation syntax and named parameter convention.</summary>
    /// <param name="Dialect">SQL syntax target, independent of the database provider.</param>
    /// <param name="ParameterPrefix">
    /// Nonempty prefix followed by zero-based parameter ordinals; must match the provider convention.
    /// </param>
    /// <exception cref="EQueryException">ParameterPrefix is empty.</exception>
    constructor Create(Dialect: TSqlDialect;
      const ParameterPrefix: string = ':p');
    /// <summary>Executes the query through a provider and returns its result.</summary>
    /// <param name="Query">Non-nil query to execute. The base executor compiles a clone of its state.</param>
    /// <param name="Mode">Automatic, row-result, or command execution intent; defaults to emAuto.</param>
    /// <returns>
    /// A reference-counted result cursor; retain it until iteration is complete. The application still owns
    /// the connection and transaction.
    /// </returns>
    /// <remarks>
    /// The base executor chooses rows for SELECT/aggregate and commands for writes in emAuto. ReturnId
    /// batches are rejected. Driver/runtime behavior depends on the provider; execution exceptions propagate.
    /// </remarks>
    /// <exception cref="EArgumentNilException">Query is nil.</exception>
    function Execute(const Query: IQuery; Mode: TQueryExecutionMode = emAuto)
      : IQueryResult;
    /// <summary>
    /// Named parameter prefix followed by a zero-based ordinal. Compilers default to @p; executor defaults to
    /// :p. The selected provider must accept the convention.
    /// </summary>
    property ParameterPrefix: string read FParameterPrefix;
    /// <summary>
    /// SQL syntax selected for compilation; independent of connection and database driver selection.
    /// </summary>
    property Dialect: TSqlDialect read FDialect;
  end;

implementation

uses
  System.SysUtils, QueryBuilder4Delphi.Compilers.Factory;

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
  Result := TQueryCompilerFactory.CreateCompiler(FDialect);
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
  Result := ExecuteCompiled(Statement, Mode);
end;

end.
