unit QueryBuilder4Delphi.Compilers.Factory;

interface

uses QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Compilers.Compiler;

type
  /// <summary>
  /// Creates dialect-specific SQL compilers independently of execution providers and connections.
  /// </summary>
  TQueryCompilerFactory = class
  public
    /// <summary>Creates a compiler for the requested SQL dialect.</summary>
    /// <param name="Dialect">
    /// SQL syntax target, independent of the database provider. Defaults to Microsoft SQL Server.
    /// </param>
    /// <returns>A new reference-counted dialect compiler with its default settings.</returns>
    /// <remarks>
    /// The factory selects SQL syntax only; it does not select or create a provider or connection.
    /// </remarks>
    /// <exception cref="EQueryException">Dialect is not a supported enumeration value.</exception>
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
