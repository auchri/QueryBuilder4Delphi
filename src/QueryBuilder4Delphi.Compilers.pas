unit QueryBuilder4Delphi.Compilers;

interface

uses
  QueryBuilder4Delphi.Compilers.Compiler,
  QueryBuilder4Delphi.Compilers.SqlServerCompiler,
  QueryBuilder4Delphi.Compilers.PostgresCompiler,
  QueryBuilder4Delphi.Compilers.MySqlCompiler,
  QueryBuilder4Delphi.Compilers.SqliteCompiler,
  QueryBuilder4Delphi.Compilers.OracleCompiler,
  QueryBuilder4Delphi.Compilers.FirebirdCompiler;

type
  // Compatibility facade: implementations live in the individual compiler units.
  TEngineCodes = QueryBuilder4Delphi.Compilers.Compiler.TEngineCodes;
  ICompiler = QueryBuilder4Delphi.Compilers.Compiler.ICompiler;
  ISqlResult = QueryBuilder4Delphi.Compilers.Compiler.ISqlResult;
  TSqlResult = QueryBuilder4Delphi.Compilers.Compiler.TSqlResult;
  TCompileContext = QueryBuilder4Delphi.Compilers.Compiler.TCompileContext;
  TCompiler = QueryBuilder4Delphi.Compilers.Compiler.TCompiler;
  TCompilerObject = QueryBuilder4Delphi.Compilers.Compiler.TCompilerObject;
  TSqlServerCompiler = QueryBuilder4Delphi.Compilers.SqlServerCompiler.TSqlServerCompiler;
  TSqlServerCompilerObject = TSqlServerCompiler;
  TPostgresCompiler = QueryBuilder4Delphi.Compilers.PostgresCompiler.TPostgresCompiler;
  TPostgresCompilerObject = TPostgresCompiler;
  TMySqlCompiler = QueryBuilder4Delphi.Compilers.MySqlCompiler.TMySqlCompiler;
  TMySqlCompilerObject = TMySqlCompiler;
  TSqliteCompiler = QueryBuilder4Delphi.Compilers.SqliteCompiler.TSqliteCompiler;
  TSqliteCompilerObject = TSqliteCompiler;
  TOracleCompiler = QueryBuilder4Delphi.Compilers.OracleCompiler.TOracleCompiler;
  TOracleCompilerObject = TOracleCompiler;
  TFirebirdCompiler = QueryBuilder4Delphi.Compilers.FirebirdCompiler.TFirebirdCompiler;
  TFirebirdCompilerObject = TFirebirdCompiler;

implementation

end.
