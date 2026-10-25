unit QueryBuilder4Delphi.Compilers.MySqlCompiler;

interface

uses System.SysUtils, System.Rtti, QueryBuilder4Delphi.Query.Core,
  QueryBuilder4Delphi.Compilers.Compiler;

type
  /// <summary>
  /// MySQL SQL syntax compiler. Inherited Create returns a reference-counted ICompiler for this dialect.
  /// Compilation does not select a provider, connect, or execute SQL; server and driver capabilities still
  /// apply.
  /// </summary>
  TMySqlCompiler = class(TCompiler)
  protected
    constructor CreateInstance; override;
    function CompileLimit(Context: TCompileContext; Query: IQuery)
      : string; override;
    function CompileJoinedUpdate(Context: TCompileContext; Query: IQuery;
      FromClause, UpdateClause: TClause): string; override;
  public
    /// <summary>Produces the dialect random-order SQL expression.</summary>
    /// <param name="Seed">Optional random seed; some dialects ignore it.</param>
    /// <returns>Random function SQL; seed support varies by compiler.</returns>
    /// <remarks>
    /// MySQL uses a supplied seed, SQL Server ignores it for NEWID(), and base/Oracle/Firebird
    /// implementations ignore it.
    /// </remarks>
    function CompileRandom(const Seed: TValue): string; override;
  end;

implementation

uses System.StrUtils;

constructor TMySqlCompiler.CreateInstance;
begin
  inherited;
  FEngineCode := TSqlDialect.MySql.EngineCode;
  FOpening := '`';
  FClosing := '`';
  FLastId := 'SELECT last_insert_id() as Id';
end;

function TMySqlCompiler.CompileRandom(const Seed: TValue): string;
begin
  if Seed.IsEmpty then
    Result := 'RAND()'
  else
    Result := 'RAND(' + IntToStr(Seed.AsInteger) + ')';
end;

function TMySqlCompiler.CompileLimit(Context: TCompileContext;
  Query: IQuery): string;
begin
  if (Query.GetLimit(EngineCode) = 0) and (Query.GetOffset(EngineCode) > 0) then
    Exit('LIMIT 18446744073709551615 OFFSET ' + Parameter(Context,
      Query.GetOffset(EngineCode)));
  Result := inherited CompileLimit(Context, Query);
end;

function TMySqlCompiler.CompileJoinedUpdate(Context: TCompileContext;
  Query: IQuery; FromClause, UpdateClause: TClause): string;
var
  TableSql: string;
begin
  TableSql := Table(Context, FromClause) + CompileJoins(Context, Query);
  Result := 'UPDATE ' + TableSql + ' SET ' + CompileUpdateAssignments(Context,
    UpdateClause);
end;

end.
