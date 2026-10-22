unit Execution.ProviderExample;

interface

uses
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Execution,
  QueryBuilder4Delphi.Compilers.Compiler;

type
  // Implement this bridge in the application using its existing adapter.
  ICommandAdapter = interface
    ['{6C14C9C2-BAAB-42CE-B5A2-441789327568}']
    function ExecuteParameterized(const Sql: string; const Values: TValues;
      Mode: TQueryExecutionMode): IQueryResult;
  end;

  TAdapterQueryExecutor = class(TQueryExecutor)
  private
    FAdapter: ICommandAdapter;
  protected
    function ExecuteCompiled(const Statement: ISqlResult;
      Mode: TQueryExecutionMode): IQueryResult; override;
  public
    constructor Create(const Adapter: ICommandAdapter; Dialect: TSqlDialect);
  end;

implementation

uses System.SysUtils;

constructor TAdapterQueryExecutor.Create(const Adapter: ICommandAdapter;
  Dialect: TSqlDialect);
begin
  // This adapter's named convention is :Parameter0, :Parameter1, ...
  inherited Create(Dialect, ':Parameter');
  if Adapter = nil then
    raise EArgumentNilException.Create('Adapter');
  FAdapter := Adapter;
end;

function TAdapterQueryExecutor.ExecuteCompiled(const Statement: ISqlResult;
  Mode: TQueryExecutionMode): IQueryResult;
begin
  // The bridge binds Values[I] to :Parameter<I>, interpreting TQueryNull hints.
  // It returns its own cursor implementation and defines connection ownership.
  Result := FAdapter.ExecuteParameterized(Statement.Sql,
    Statement.Bindings.ToArray, Mode);
end;

end.
