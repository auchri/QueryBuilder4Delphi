unit SqlKata.Compilers;

interface

uses
  SqlKata.Compilers.Compiler,
  SqlKata.Compilers.SqlServerCompiler,
  SqlKata.Compilers.PostgresCompiler,
  SqlKata.Compilers.MySqlCompiler,
  SqlKata.Compilers.SqliteCompiler,
  SqlKata.Compilers.OracleCompiler,
  SqlKata.Compilers.FirebirdCompiler;

type
  // Compatibility facade: implementations live in the individual compiler units.
  TEngineCodes = SqlKata.Compilers.Compiler.TEngineCodes;
  ICompiler = SqlKata.Compilers.Compiler.ICompiler;
  ISqlResult = SqlKata.Compilers.Compiler.ISqlResult;
  TSqlResult = SqlKata.Compilers.Compiler.TSqlResult;
  TCompileContext = SqlKata.Compilers.Compiler.TCompileContext;
  TCompiler = SqlKata.Compilers.Compiler.TCompiler;
  TCompilerObject = SqlKata.Compilers.Compiler.TCompilerObject;
  TSqlServerCompiler = SqlKata.Compilers.SqlServerCompiler.TSqlServerCompiler;
  TSqlServerCompilerObject = TSqlServerCompiler;
  TPostgresCompiler = SqlKata.Compilers.PostgresCompiler.TPostgresCompiler;
  TPostgresCompilerObject = TPostgresCompiler;
  TMySqlCompiler = SqlKata.Compilers.MySqlCompiler.TMySqlCompiler;
  TMySqlCompilerObject = TMySqlCompiler;
  TSqliteCompiler = SqlKata.Compilers.SqliteCompiler.TSqliteCompiler;
  TSqliteCompilerObject = TSqliteCompiler;
  TOracleCompiler = SqlKata.Compilers.OracleCompiler.TOracleCompiler;
  TOracleCompilerObject = TOracleCompiler;
  TFirebirdCompiler = SqlKata.Compilers.FirebirdCompiler.TFirebirdCompiler;
  TFirebirdCompilerObject = TFirebirdCompiler;

implementation

end.
