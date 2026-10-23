unit QueryBuilder4Delphi.Compilers.Factory;

interface

uses QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Compilers.Compiler;

type
  TQueryCompilerFactory = class
  public
    class function CreateCompiler(Dialect: TSqlDialect = TSqlDialect.MSSql)
      : ICompiler; static;
  end;

implementation

uses
  QueryBuilder4Delphi.Compilers.SqlServerCompiler,
  QueryBuilder4Delphi.Compilers.MySqlCompiler,
  QueryBuilder4Delphi.Compilers.PostgresCompiler,
  QueryBuilder4Delphi.Compilers.SqliteCompiler,
  QueryBuilder4Delphi.Compilers.OracleCompiler,
  QueryBuilder4Delphi.Compilers.FirebirdCompiler;

class function TQueryCompilerFactory.CreateCompiler(Dialect: TSqlDialect)
  : ICompiler;
begin
  case Dialect of
    TSqlDialect.MSSql:
      Result := TSqlServerCompiler.Create;
    TSqlDialect.MySql:
      Result := TMySqlCompiler.Create;
    TSqlDialect.PostgreSql:
      Result := TPostgresCompiler.Create;
    TSqlDialect.Sqlite:
      Result := TSqliteCompiler.Create;
    TSqlDialect.Oracle:
      Result := TOracleCompiler.Create;
    TSqlDialect.Firebird:
      Result := TFirebirdCompiler.Create;
  else
    raise EQueryException.Create('Unsupported SQL dialect');
  end;
end;

end.
