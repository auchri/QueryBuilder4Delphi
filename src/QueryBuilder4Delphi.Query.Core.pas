unit QueryBuilder4Delphi.Query.Core;

interface

uses
  System.SysUtils, System.Rtti, System.TypInfo, System.Generics.Collections;

type
  /// <summary>Base exception for query construction, SQL compilation, and provider contract errors.</summary>
  EQueryException = class(Exception);
{$SCOPEDENUMS ON}
  /// <summary>
  /// SQL syntax target. MSSql: Microsoft SQL Server; MySql: MySQL; PostgreSql: PostgreSQL; Sqlite: SQLite;
  /// Oracle: Oracle Database; Firebird: Firebird. Selecting syntax does not select a database connection or
  /// provider.
  /// </summary>
  TSqlDialect = (
    /// <summary>Microsoft SQL Server syntax (engine code sqlsrv).</summary>
    MSSql,
    /// <summary>MySQL syntax (mysql).</summary>
    MySql,
    /// <summary>PostgreSQL syntax (postgres).</summary>
    PostgreSql,
    /// <summary>SQLite syntax (sqlite).</summary>
    Sqlite,
    /// <summary>Oracle Database syntax (oracle).</summary>
    Oracle,
    /// <summary>Firebird syntax (firebird).</summary>
    Firebird
  );
{$SCOPEDENUMS OFF}

  /// <summary>Provides the engine code used to scope clauses to a SQL dialect.</summary>
  TSqlDialectHelper = record helper for TSqlDialect
    /// <summary>Returns the stable dialect code for clause scoping.</summary>
    /// <returns>sqlsrv, mysql, postgres, sqlite, oracle, or firebird for the receiver dialect.</returns>
    function EngineCode: string;
  end;

  // Broad value categories, shared by typed NULLs and result metadata.
  // qtUnknown is valid metadata, but not a typed NULL hint.
  /// <summary>
  /// Provider-neutral SQL value categories for metadata and typed NULL hints. qtUnknown: unknown metadata
  /// (invalid as a typed NULL); qtString: text; qtInteger: 32-bit integer category; qtInt64: 64-bit integer
  /// category; qtBoolean: Boolean; qtFloat: floating point; qtCurrency: Delphi Currency; qtDecimal: BCD
  /// decimal; qtDateTime: date/time; qtTimestamp: SQL timestamp; qtTimestampOffset: timestamp with offset;
  /// qtGuid: GUID; qtBinary: bytes. Provider storage and conversion depend on the driver.
  /// </summary>
  TQueryValueType = (
    /// <summary>Unknown result metadata; not a valid typed SQL NULL hint.</summary>
    qtUnknown,
    /// <summary>Text value category.</summary>
    qtString,
    /// <summary>Integer category, including provider unsigned 32-bit fields.</summary>
    qtInteger,
    /// <summary>64-bit integer category.</summary>
    qtInt64,
    /// <summary>Boolean value category.</summary>
    qtBoolean,
    /// <summary>Floating-point category; precision depends on platform and driver.</summary>
    qtFloat,
    /// <summary>Delphi fixed-scale Currency category.</summary>
    qtCurrency,
    /// <summary>BCD decimal category; precision and scale depend on the provider.</summary>
    qtDecimal,
    /// <summary>Delphi TDateTime date/time category.</summary>
    qtDateTime,
    /// <summary>SQL timestamp category preserving timestamp fractions.</summary>
    qtTimestamp,
    /// <summary>SQL timestamp category with timezone offset.</summary>
    qtTimestampOffset,
    /// <summary>GUID category.</summary>
    qtGuid,
    /// <summary>Binary byte-array category; empty data can be non-null.</summary>
    qtBinary
  );

  /// <summary>
  /// SQL NULL carrying a provider-neutral type hint. Use this in bindings when the provider needs a type even
  /// though the value is NULL; qtUnknown is rejected.
  /// </summary>
  TQueryNull = record
  private
    FValueType: TQueryValueType;
  public
    /// <summary>Creates a typed SQL NULL for a supported value category.</summary>
    /// <param name="ValueType">
    /// Supported category from qtString through qtBinary; qtUnknown is rejected.
    /// </param>
    /// <exception cref="EQueryException">
    /// ValueType is qtUnknown or outside the supported category range.
    /// </exception>
    constructor Create(ValueType: TQueryValueType);
    /// <summary>Boxes this record as a TValue while preserving its distinct type.</summary>
    /// <param name="Value">Typed NULL record to box.</param>
    /// <returns>A TValue containing the record, not a string conversion.</returns>
    class operator Implicit(const Value: TQueryNull): TValue;
    /// <summary>Type hint carried by this SQL NULL; qtUnknown is not a valid constructor argument.</summary>
    property ValueType: TQueryValueType read FValueType;
  end;

  IQuery = interface;

  /// <summary>
  /// Parameterized compilation result. RawSql uses ? placeholders; Sql uses named placeholders. Bindings are
  /// ordered and NamedBindings maps full parameter tokens to values. The result owns both collections and
  /// retains Query. ToString is a diagnostic preview only.
  /// </summary>
  ISqlResult = interface
    ['{451A0775-C8EC-455D-B66A-7480EF77C28C}']
    function GetRawSql: string;
    procedure SetRawSql(const Value: string);
    function GetSql: string;
    procedure SetSql(const Value: string);
    function GetBindings: TList<TValue>;
    function GetNamedBindings: TDictionary<string, TValue>;
    function GetQuery: IQuery;
    procedure SetQuery(const Value: IQuery);
    /// <summary>Formats a diagnostic SQL preview with parameter values substituted.</summary>
    /// <returns>Debug text that may contain sensitive parameter values; never execute it as SQL.</returns>
    /// <remarks>
    /// Preview formatting is not a complete driver/dialect literal serializer. Use parameterized Sql and
    /// bindings for execution.
    /// </remarks>
    function ToString: string;
    /// <summary>
    /// SQL with positional ? placeholders before named substitution; used with Bindings for diagnostic
    /// previews.
    /// </summary>
    property RawSql: string read GetRawSql write SetRawSql;
    /// <summary>
    /// Parameterized SQL text with named placeholders. Execute with the associated bindings, never with
    /// substituted debug values.
    /// </summary>
    property Sql: string read GetSql write SetSql;
    /// <summary>
    /// Borrowed ordered binding list owned by this result; entries correspond to RawSql placeholders. Do not
    /// free the list.
    /// </summary>
    property Bindings: TList<TValue> read GetBindings;
    /// <summary>
    /// Borrowed dictionary owned by the result, keyed by full named parameter tokens including the prefix.
    /// Keep it consistent with Bindings.
    /// </summary>
    property NamedBindings: TDictionary<string, TValue> read GetNamedBindings;
    /// <summary>Retained source query for single-query compilation; nil for batch compilation.</summary>
    property Query: IQuery read GetQuery write SetQuery;
  end;

  /// <summary>
  /// Execution intent. emAuto: SELECT/aggregate opens rows and INSERT/UPDATE/DELETE executes a command;
  /// emRows: explicitly request a result set; emCommand: explicitly execute without exposing rows. Automatic
  /// mode does not inspect SQL text.
  /// </summary>
  TQueryExecutionMode = (
    /// <summary>
    /// Infer rows for SELECT/aggregate and commands for INSERT/UPDATE/DELETE from Method; unknown methods
    /// require an explicit mode.
    /// </summary>
    emAuto,
    /// <summary>
    /// Explicitly request a row result; the provider/database must support returning rows for the statement.
    /// </summary>
    emRows,
    /// <summary>Explicitly execute a command without exposing returned rows.</summary>
    emCommand
  );

  // Cursor starts before the first row; indices are zero based.
  // NULL is TValue.Empty. RowsAffected = -1 means unknown.
  /// <summary>
  /// Reference-counted provider cursor, initially before the first row. Call Next before row access. Column
  /// indices are zero-based; SQL NULL is TValue.Empty. Retain the interface while using the result.
  /// Connections and transactions belong to application code; provider results may hold commands and require
  /// their connection to remain alive.
  /// </summary>
  IQueryResult = interface
    ['{33A2DB10-1BA7-4089-95D1-78A86D2D88DC}']
    /// <summary>Advances the shared cursor to the next row.</summary>
    /// <returns>True if positioned on a row, False at end of rows.</returns>
    /// <remarks>
    /// Initially positioned before the first row. Do not access row values after False. Command-only results
    /// can reject iteration; FireDAC raises EQueryException.
    /// </remarks>
    function Next: Boolean;
    function GetHasResultSet: Boolean;
    function GetRowsAffected: Int64;
    function GetColumnCount: Integer;
    function GetColumnName(Index: Integer): string;
    /// <summary>Reads a provider-neutral column type category.</summary>
    /// <param name="Index">Zero-based column index, from zero through ColumnCount - 1.</param>
    /// <returns>Metadata category, or qtUnknown when the provider cannot classify it.</returns>
    function GetColumnType(Index: Integer): TQueryValueType;
    /// <summary>Resolves a result column name to an index.</summary>
    /// <param name="Name">Result column name; provider-specific comparison and ambiguity rules apply.</param>
    /// <returns>The zero-based index; provider rules govern missing or duplicate names.</returns>
    /// <remarks>
    /// FireDAC uses case-insensitive matching and raises EQueryException for missing or ambiguous names;
    /// other providers define their own lookup policy.
    /// </remarks>
    function GetColumnIndex(const Name: string): Integer;
    /// <summary>Reads a column value from the current row.</summary>
    /// <param name="Index">Zero-based column index, from zero through ColumnCount - 1.</param>
    /// <returns>
    /// The provider native TValue, or TValue.Empty for SQL NULL. Empty binary data is a typed TBytes value,
    /// not SQL NULL.
    /// </returns>
    /// <remarks>Call Next successfully before access.</remarks>
    function GetValue(Index: Integer): TValue; overload;
    /// <summary>Reads a column value from the current row.</summary>
    /// <param name="Name">Result column name; provider-specific comparison and ambiguity rules apply.</param>
    /// <returns>
    /// The provider native TValue, or TValue.Empty for SQL NULL. Empty binary data is a typed TBytes value,
    /// not SQL NULL.
    /// </returns>
    /// <remarks>
    /// Call Next successfully before access. Names follow provider lookup rules; FireDAC ignores case and
    /// rejects missing or ambiguous names.
    /// </remarks>
    function GetValue(const Name: string): TValue; overload;
    /// <summary>Tests a column in the current row for SQL NULL.</summary>
    /// <param name="Index">Zero-based column index, from zero through ColumnCount - 1.</param>
    /// <returns>True for SQL NULL; empty strings and empty byte arrays can be non-null.</returns>
    /// <remarks>Call Next successfully before access.</remarks>
    function IsNull(Index: Integer): Boolean; overload;
    /// <summary>Tests a column in the current row for SQL NULL.</summary>
    /// <param name="Name">Result column name; provider-specific comparison and ambiguity rules apply.</param>
    /// <returns>True for SQL NULL; empty strings and empty byte arrays can be non-null.</returns>
    /// <remarks>
    /// Call Next successfully before access. Names follow provider lookup rules; FireDAC ignores case and
    /// rejects missing or ambiguous names.
    /// </remarks>
    function IsNull(const Name: string): Boolean; overload;
    /// <summary>Whether the result exposes rows; this does not indicate whether any rows exist.</summary>
    property HasResultSet: Boolean read GetHasResultSet;
    /// <summary>
    /// Provider-reported affected row count, or -1 when unknown. SELECT counts and driver behavior vary.
    /// </summary>
    property RowsAffected: Int64 read GetRowsAffected;
    /// <summary>
    /// Number of columns in a row result; does not require a current row. Command-only results may reject
    /// metadata access.
    /// </summary>
    property ColumnCount: Integer read GetColumnCount;
    /// <summary>Column name at a zero-based index. Keep the result alive while inspecting metadata.</summary>
    property ColumnNames[Index: Integer]: string read GetColumnName;
  end;

  // A reference-counted view of one cursor. Copies share its position.
  // Object mapping is supplied by the helper in QueryBuilder4Delphi.Mapping.
  /// <summary>
  /// Value facade retaining one IQueryResult reference. Copies share the same cursor and position; releasing
  /// the last interface releases provider resources. A default or consumed facade has no result, and
  /// cursor/metadata operations then raise EQueryException.
  /// </summary>
  TQueryResult = record
  private
    FResult: IQueryResult;
    function RequireResult: IQueryResult;
  public
    /// <summary>Retains a provider cursor in a result facade.</summary>
    /// <param name="AResult">Underlying cursor interface to retain; copies share its position.</param>
    constructor Create(const AResult: IQueryResult);
    /// <summary>Returns another reference to the underlying cursor without clearing this facade.</summary>
    /// <returns>A retained reference to the shared cursor, or nil for an empty facade.</returns>
    function AsRaw: IQueryResult;
    // Transfer this facade's reference; independently retained copies survive.
    /// <summary>Transfers this facade reference to the caller and clears the facade.</summary>
    /// <returns>
    /// The underlying interface, possibly nil; independently retained facade copies remain valid.
    /// </returns>
    function TakeRaw: IQueryResult;
    /// <summary>Retains the underlying cursor interface.</summary>
    /// <param name="Value">Facade whose cursor reference is retained; the facade is not cleared.</param>
    /// <returns>The shared cursor interface, possibly nil.</returns>
    class operator Implicit(const Value: TQueryResult): IQueryResult;
    /// <summary>Advances the shared cursor to the next row.</summary>
    /// <returns>True if positioned on a row, False at end of rows.</returns>
    /// <remarks>
    /// Initially positioned before the first row. Do not access row values after False. Command-only results
    /// can reject iteration; FireDAC raises EQueryException.
    /// </remarks>
    function Next: Boolean;
    function GetHasResultSet: Boolean;
    function GetRowsAffected: Int64;
    function GetColumnCount: Integer;
    function GetColumnName(Index: Integer): string;
    /// <summary>Reads a provider-neutral column type category.</summary>
    /// <param name="Index">Zero-based column index, from zero through ColumnCount - 1.</param>
    /// <returns>Metadata category, or qtUnknown when the provider cannot classify it.</returns>
    function GetColumnType(Index: Integer): TQueryValueType;
    /// <summary>Resolves a result column name to an index.</summary>
    /// <param name="Name">Result column name; provider-specific comparison and ambiguity rules apply.</param>
    /// <returns>The zero-based index; provider rules govern missing or duplicate names.</returns>
    /// <remarks>
    /// FireDAC uses case-insensitive matching and raises EQueryException for missing or ambiguous names;
    /// other providers define their own lookup policy.
    /// </remarks>
    function GetColumnIndex(const Name: string): Integer;
    /// <summary>Reads a column value from the current row.</summary>
    /// <param name="Index">Zero-based column index, from zero through ColumnCount - 1.</param>
    /// <returns>
    /// The provider native TValue, or TValue.Empty for SQL NULL. Empty binary data is a typed TBytes value,
    /// not SQL NULL.
    /// </returns>
    /// <remarks>Call Next successfully before access.</remarks>
    function GetValue(Index: Integer): TValue; overload;
    /// <summary>Reads a column value from the current row.</summary>
    /// <param name="Name">Result column name; provider-specific comparison and ambiguity rules apply.</param>
    /// <returns>
    /// The provider native TValue, or TValue.Empty for SQL NULL. Empty binary data is a typed TBytes value,
    /// not SQL NULL.
    /// </returns>
    /// <remarks>
    /// Call Next successfully before access. Names follow provider lookup rules; FireDAC ignores case and
    /// rejects missing or ambiguous names.
    /// </remarks>
    function GetValue(const Name: string): TValue; overload;
    /// <summary>Tests a column in the current row for SQL NULL.</summary>
    /// <param name="Index">Zero-based column index, from zero through ColumnCount - 1.</param>
    /// <returns>True for SQL NULL; empty strings and empty byte arrays can be non-null.</returns>
    /// <remarks>Call Next successfully before access.</remarks>
    function IsNull(Index: Integer): Boolean; overload;
    /// <summary>Tests a column in the current row for SQL NULL.</summary>
    /// <param name="Name">Result column name; provider-specific comparison and ambiguity rules apply.</param>
    /// <returns>True for SQL NULL; empty strings and empty byte arrays can be non-null.</returns>
    /// <remarks>
    /// Call Next successfully before access. Names follow provider lookup rules; FireDAC ignores case and
    /// rejects missing or ambiguous names.
    /// </remarks>
    function IsNull(const Name: string): Boolean; overload;
    /// <summary>Whether the result exposes rows; this does not indicate whether any rows exist.</summary>
    property HasResultSet: Boolean read GetHasResultSet;
    /// <summary>
    /// Provider-reported affected row count, or -1 when unknown. SELECT counts and driver behavior vary.
    /// </summary>
    property RowsAffected: Int64 read GetRowsAffected;
    /// <summary>
    /// Number of columns in a row result; does not require a current row. Command-only results may reject
    /// metadata access.
    /// </summary>
    property ColumnCount: Integer read GetColumnCount;
    /// <summary>Column name at a zero-based index. Keep the result alive while inspecting metadata.</summary>
    property ColumnNames[Index: Integer]: string read GetColumnName;
  end;

  /// <summary>
  /// Provider contract for compiling and executing queries. Applications own connections and transaction
  /// boundaries; provider implementations define supported runtime types and result lifetimes independently
  /// of SQL dialect selection.
  /// </summary>
  IQueryExecutor = interface
    ['{6793FB16-8CA0-4785-AB75-63C8DE7BC09A}']
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
  end;

  /// <summary>
  /// Immediate fluent callback receiving a query and required to return that same instance.
  /// Predicate/subquery callbacks receive a new scoped query; When and For callbacks receive the current
  /// query. Mutations are not rolled back if the callback raises.
  /// </summary>
  TQueryCallback = reference to function(Query: IQuery): IQuery;
  /// <summary>
  /// Ordered TValue array for SQL bindings; object values retain ordinary Delphi non-owning reference
  /// semantics.
  /// </summary>
  TValues = TArray<TValue>;
  /// <summary>Row-major array of binding arrays. Each row must match its associated column count.</summary>
  TRows = TArray<TValues>;

  // Value records avoid ownership surprises in parameter lists.
  /// <summary>
  /// Trusted SQL inserted directly in place of a binding. This bypasses parameterization; never construct it
  /// from untrusted input. Quote replacement alone does not make arbitrary SQL safe.
  /// </summary>
  TUnsafeLiteral = record
    /// <summary>
    /// Trusted SQL text emitted directly without binding; do not place untrusted input here.
    /// </summary>
    Value: string;
    /// <summary>Stores trusted SQL, optionally doubling single quotes.</summary>
    /// <param name="AValue">Trusted literal SQL text; never use untrusted input.</param>
    /// <param name="ReplaceQuotes">
    /// True doubles single quote characters; no surrounding quotes are added and parameter safety is not
    /// provided.
    /// </param>
    constructor Create(const AValue: string; ReplaceQuotes: Boolean = True);
    /// <summary>Boxes this record as a TValue while preserving its distinct type.</summary>
    /// <param name="Literal">Literal SQL record to box without converting it to a bound string.</param>
    /// <returns>A TValue containing the record, not a string conversion.</returns>
    class operator Implicit(const Literal: TUnsafeLiteral): TValue;
  end;

  /// <summary>
  /// Deferred binding reference resolved by name during compilation, searching the innermost query before its
  /// enclosing queries.
  /// </summary>
  TVariable = record
    /// <summary>Variable name looked up during compilation; names use dictionary comparison rules.</summary>
    Name: string;
    /// <summary>Stores the deferred variable name without resolving it.</summary>
    /// <param name="AName">Name stored by this value or attribute.</param>
    constructor Create(const AName: string);
    /// <summary>Boxes this record as a TValue while preserving its distinct type.</summary>
    /// <param name="Variable">Deferred variable reference to box for compilation-time resolution.</param>
    /// <returns>A TValue containing the record, not a string conversion.</returns>
    class operator Implicit(const Variable: TVariable): TValue;
  end;

  /// <summary>
  /// Maps an RTTI property to a database column name. Applied to properties, not backing fields. Names must
  /// be nonblank and unique ignoring case among eligible properties.
  /// </summary>
  ColumnAttribute = class(TCustomAttribute)
  public
    /// <summary>
    /// Mapped column name. Must be nonblank and unique ignoring case among eligible properties.
    /// </summary>
    Name: string;
    /// <summary>Associates a property with a database column name.</summary>
    /// <param name="AName">Name stored by this value or attribute.</param>
    constructor Create(const AName: string);
  end;

  /// <summary>
  /// Column mapping attribute also marking an object UPDATE key. Its value adds a WHERE equality and is still
  /// included in assignments. A typed SQL NULL key (TQueryNull, including an empty nullable) is rejected
  /// before key callbacks modify the query. This is not a general NULL check for arbitrary Variant keys.
  /// </summary>
  KeyAttribute = class(ColumnAttribute);
  /// <summary>
  /// Excludes a property from reading and object writes. Ignore takes precedence over other mapping
  /// attributes.
  /// </summary>
  IgnoreAttribute = class(TCustomAttribute);

  /// <summary>
  /// Low-level query/compiler clause discriminator. ckIdentifier: quoted identifier; ckRaw: trusted SQL;
  /// ckBasic: value comparison; ckNull: NULL test; ckBoolean: Boolean test; ckColumns: column comparison;
  /// ckString: pattern comparison; ckDate: date comparison; ckBetween: range; ckIn: value membership;
  /// ckInQuery: query membership; ckQuery: subquery; ckSubQuery: scalar query/value comparison; ckNested:
  /// predicate group; ckExists: existence test; ckJoin: join; ckCombine: set operation; ckLimit: row limit;
  /// ckOffset: skipped rows; ckAggregate: aggregate; ckInsert: write values; ckIncrement: arithmetic update;
  /// ckRandom: random order; ckAdHoc: value-table CTE. Prefer fluent methods for ordinary use.
  /// </summary>
  TClauseKind = (
    /// <summary>Quoted identifier.</summary>
    ckIdentifier,
    /// <summary>Trusted SQL fragment and bindings.</summary>
    ckRaw,
    /// <summary>Column/value comparison.</summary>
    ckBasic,
    /// <summary>SQL NULL test.</summary>
    ckNull,
    /// <summary>Dialect Boolean literal comparison.</summary>
    ckBoolean,
    /// <summary>Column/column comparison.</summary>
    ckColumns,
    /// <summary>LIKE pattern comparison.</summary>
    ckString,
    /// <summary>Date/time part comparison.</summary>
    ckDate,
    /// <summary>Inclusive range comparison.</summary>
    ckBetween,
    /// <summary>Value-list membership.</summary>
    ckIn,
    /// <summary>Subquery membership.</summary>
    ckInQuery,
    /// <summary>Embedded query.</summary>
    ckQuery,
    /// <summary>Scalar query on the left of a value comparison.</summary>
    ckSubQuery,
    /// <summary>Parenthesized predicate group.</summary>
    ckNested,
    /// <summary>Subquery existence test.</summary>
    ckExists,
    /// <summary>Join model.</summary>
    ckJoin,
    /// <summary>Set operation; IsNot represents ALL for this kind.</summary>
    ckCombine,
    /// <summary>Row limit.</summary>
    ckLimit,
    /// <summary>Skipped row count.</summary>
    ckOffset,
    /// <summary>Aggregate expression or standalone aggregate.</summary>
    ckAggregate,
    /// <summary>INSERT/UPDATE column-value payload.</summary>
    ckInsert,
    /// <summary>Arithmetic UPDATE expression.</summary>
    ckIncrement,
    /// <summary>Random sort expression.</summary>
    ckRandom,
    /// <summary>Value-table CTE.</summary>
    ckAdHoc
  );

  /// <summary>
  /// Low-level mutable query/compiler node owned by its query clause list. Value arrays are managed values;
  /// nested queries are retained interfaces. Do not free nodes borrowed from a query.
  /// </summary>
  TClause = class
  public
    /// <summary>
    /// Mutable clause payload: component key, dialect scope (empty for shared), identifier/raw text,
    /// operator, kind-specific extra text, and alias. Interpretation depends on Kind.
    /// </summary>
    Component, Engine, Name, Op, Extra, Alias: string;
    /// <summary>Discriminator defining how the compiler interprets this node payload.</summary>
    Kind: TClauseKind;
    /// <summary>
    /// Kind-specific flags: OR connection, predicate negation (ALL for set operations), and optional INSERT
    /// identity retrieval.
    /// </summary>
    IsOr, IsNot, ReturnId: Boolean;
    /// <summary>
    /// Primary and secondary values for comparisons, ranges, pagination, or increments; ordinary object
    /// references are not owned.
    /// </summary>
    Value, Value2: TValue;
    /// <summary>Managed ordered values for raw bindings, IN lists, inserts, or flattened CTE rows.</summary>
    Values: TValues;
    /// <summary>Managed column identifiers for aggregates, writes, and value-table CTEs.</summary>
    Columns: TArray<string>;
    /// <summary>Retained nested query for subqueries, joins, groups, CTEs, or set operations.</summary>
    Query: IQuery;
    /// <summary>Copies this low-level clause and recursively clones its nested query.</summary>
    /// <returns>A caller-owned TClause; transfer it to an owning clause list or free it.</returns>
    /// <remarks>Arrays are copied; TValue object references remain shared and non-owning.</remarks>
    function Clone: TClause;
  end;

  /// <summary>
  /// Mutable fluent SQL query model. Configuration methods return this same instance except Clone and
  /// NewQuery, which return independent queries. Construction and compilation do not execute SQL. Nested
  /// queries are cloned when added; ordinary TValue object references are not deep-copied. Clauses can be
  /// engine-scoped; other state such as Method is shared. Predicates use AND by default; Or/Not set flags
  /// consumed by the next condition.
  /// </summary>
  IQuery = interface
    ['{408F2E7B-CA64-4B3A-B88D-972214A15CAA}']
    /// <summary>Executes the query through a provider and returns its result.</summary>
    /// <param name="Executor">Non-nil provider executor borrowing an application-owned connection.</param>
    /// <param name="Mode">Automatic, row-result, or command execution intent; defaults to emAuto.</param>
    /// <returns>
    /// A reference-counted result facade; retain it until iteration is complete. The application still owns
    /// the connection and transaction.
    /// </returns>
    /// <remarks>
    /// The base executor chooses rows for SELECT/aggregate and commands for writes in emAuto. ReturnId
    /// batches are rejected. Driver/runtime behavior depends on the provider; execution exceptions propagate.
    /// </remarks>
    /// <exception cref="EArgumentNilException">Executor is nil.</exception>
    function Execute(const Executor: IQueryExecutor;
      Mode: TQueryExecutionMode = emAuto): TQueryResult;
    function GetEngineScope: string;
    procedure PutEngineScope(const Value: string);
    function GetQueryAlias: string;
    procedure SetQueryAlias(const Value: string);
    function GetMethod: string;
    procedure SetMethod(const Value: string);
    function GetJoinType: string;
    procedure SetJoinType(const Value: string);
    function GetIsDistinct: Boolean;
    procedure SetIsDistinct(const Value: Boolean);
    function GetClauses: TObjectList<TClause>;
    function GetVariables: TDictionary<string, TValue>;
    /// <summary>Creates an independent query model with cloned clauses and nested queries.</summary>
    /// <returns>
    /// A new query retaining copied variable values; TValue object references remain shared.
    /// </returns>
    /// <remarks>
    /// Copies alias, method, join type, distinct flag, comment, variables, and engine scope. Pending
    /// AND/OR/NOT flags are not copied.
    /// </remarks>
    function Clone: IQuery;
    /// <summary>Creates a new empty query using the default query factory.</summary>
    /// <returns>A new SELECT query with default settings.</returns>
    /// <remarks>Does not copy this query configuration; subclasses can override this factory.</remarks>
    function NewQuery: IQuery;
    // Parameterized SQL and bindings, suitable for execution.
    /// <summary>Compiles the query into parameterized SQL and ordered/named bindings.</summary>
    /// <param name="Dialect">
    /// SQL syntax target, independent of the database provider. Defaults to Microsoft SQL Server.
    /// </param>
    /// <returns>
    /// A reference-counted SQL result owning its binding collections; no query is executed.
    /// </returns>
    /// <remarks>
    /// Dialect selection controls SQL syntax separately from provider selection. Bind values through the
    /// provider; use ToDebugSql or result ToString only for diagnostics.
    /// </remarks>
    /// <exception cref="EQueryException">
    /// Query state, operator, SQL feature, or placeholder/binding counts cannot be compiled.
    /// </exception>
    function Compile(Dialect: TSqlDialect = TSqlDialect.MSSql): ISqlResult;
    // Substituted values for debugging/logging only; not for SQL execution.
    /// <summary>Formats a diagnostic SQL preview with parameter values substituted.</summary>
    /// <param name="Dialect">
    /// SQL syntax target, independent of the database provider. Defaults to Microsoft SQL Server.
    /// </param>
    /// <returns>Debug text that may contain sensitive parameter values; never execute it as SQL.</returns>
    /// <remarks>
    /// Preview formatting is not a complete driver/dialect literal serializer. Use parameterized Sql and
    /// bindings for execution.
    /// </remarks>
    function ToDebugSql(Dialect: TSqlDialect = TSqlDialect.MSSql): string;
    /// <summary>Replaces this query clause list with clones of Source clauses.</summary>
    /// <param name="Source">Non-nil query whose clauses are cloned.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Other query state and variables are unchanged. Copying from this same instance is a no-op.
    /// </remarks>
    function CopyClausesFrom(Source: IQuery): IQuery;
    /// <summary>Adds a low-level clause in the current engine scope.</summary>
    /// <param name="Component">
    /// Internal component key such as select, from, where, having, order, or update.
    /// </param>
    /// <param name="Kind">Clause discriminator determining the payload interpreted by the compiler.</param>
    /// <returns>A borrowed node owned by this query; do not free it.</returns>
    /// <remarks>Configure the returned payload consistently with Kind.</remarks>
    function Add(const Component: string; Kind: TClauseKind): TClause;
    /// <summary>Deletes clauses matching both component and engine exactly.</summary>
    /// <param name="Component">
    /// Internal component key such as select, from, where, having, order, or update.
    /// </param>
    /// <param name="Engine">Engine scope to match exactly; empty matches shared clauses only.</param>
    /// <remarks>
    /// An empty engine matches only shared clauses. Removed nodes are freed and borrowed references become
    /// invalid.
    /// </remarks>
    procedure Remove(const Component, Engine: string);
    /// <summary>Finds the first exact-engine clause, falling back to the first shared clause.</summary>
    /// <param name="Component">
    /// Internal component key such as select, from, where, having, order, or update.
    /// </param>
    /// <param name="Engine">
    /// Preferred engine scope, with shared-clause fallback; empty selects shared clauses only.
    /// </param>
    /// <returns>A borrowed query-owned node, or nil if no matching clause exists.</returns>
    function GetOne(const Component, Engine: string): TClause;
    /// <summary>Collects matching clauses in insertion order.</summary>
    /// <param name="Component">
    /// Internal component key such as select, from, where, having, order, or update.
    /// </param>
    /// <param name="Engine">
    /// Engine scope to include alongside shared clauses; empty searches all scopes.
    /// </param>
    /// <returns>An array of borrowed query-owned nodes; the array does not own them.</returns>
    /// <remarks>
    /// For a nonempty engine, includes shared and matching scoped clauses. Empty engine includes all scopes.
    /// </remarks>
    function GetComponents(const Component: string; const Engine: string = '')
      : TArray<TClause>;
    /// <summary>Tests whether GetComponents finds any matching clause.</summary>
    /// <param name="Component">
    /// Internal component key such as select, from, where, having, order, or update.
    /// </param>
    /// <param name="Engine">
    /// Engine scope to include alongside shared clauses; empty searches all scopes.
    /// </param>
    /// <returns>True when at least one matching shared or scoped clause exists.</returns>
    function HasComponent(const Component: string;
      const Engine: string = ''): Boolean;
    /// <summary>Deletes component clauses visible to the selected engine.</summary>
    /// <param name="Component">
    /// Internal component key such as select, from, where, having, order, or update.
    /// </param>
    /// <param name="Engine">
    /// Engine scope to clear; empty uses EngineScope, and an empty effective scope clears all scopes.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Empty Engine uses the current EngineScope. If the effective scope is empty, removes every scope;
    /// otherwise removes shared and matching scoped nodes.
    /// </remarks>
    function ClearComponent(const Component: string;
      const Engine: string = ''): IQuery;
    /// <summary>Tests whether this query contains WHERE clauses visible to the engine.</summary>
    /// <param name="Engine">
    /// Engine scope to include alongside shared clauses; empty searches all scopes.
    /// </param>
    /// <returns>True when WHERE clauses exist; HAVING is not inspected.</returns>
    /// <remarks>An empty engine searches all scopes.</remarks>
    function HasConditions(const Engine: string = ''): Boolean;
    /// <summary>Sets the engine code for clauses added subsequently.</summary>
    /// <param name="Engine">
    /// Engine code assigned to new clauses; empty adds clauses shared by all dialects.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Use the dialect EngineCode; empty scope adds shared clauses.</remarks>
    function SetEngineScope(const Engine: string): IQuery;
    /// <summary>Connects the next condition with OR.</summary>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// The flag resets after the next condition is created; pair/object predicate overloads apply it to every
    /// pair.
    /// </remarks>
    function &Or: IQuery;
    /// <summary>Connects the next condition with AND by clearing the pending OR flag.</summary>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Explicit OrWhere/OrHaving methods still request OR.</remarks>
    function &And: IQuery;
    /// <summary>Sets whether the next condition is negated.</summary>
    /// <param name="Flag">True to negate the next condition; False clears pending negation.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// The flag resets after condition creation; pair/object predicate overloads apply it to every pair. Raw
    /// predicates ignore this flag; include NOT in their SQL text.
    /// </remarks>
    function &Not(Flag: Boolean = True): IQuery;
    /// <summary>Assigns the alias used when this query is embedded.</summary>
    /// <param name="Alias">Alias for the embedded query or CTE; CTE aliases must be nonblank.</param>
    /// <returns>This query instance, modified in place.</returns>
    function &As(const Alias: string): IQuery;
    /// <summary>Replaces the query comment stored in this model.</summary>
    /// <param name="Text">
    /// Comment text to store unchanged; built-in compilers currently do not emit it in SQL.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// The stored comment is copied by Clone and returned by GetComment. Built-in compilers currently do not
    /// emit it in SQL.
    /// </remarks>
    function Comment(const Text: string): IQuery;
    /// <summary>Reads the stored query comment.</summary>
    /// <returns>The stored comment text, unchanged; built-in compilers do not emit it in SQL.</returns>
    function GetComment: string;
    /// <summary>Invokes a callback on this query with a temporary engine scope.</summary>
    /// <param name="Engine">
    /// Temporary engine scope for added clauses; shared query state is still global.
    /// </param>
    /// <param name="Callback">
    /// Callback receiving this current query and required to return the same instance.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Always invokes the callback immediately, even when compilation later targets another engine. The
    /// callback must return this same query. The previous scope is restored even on failure; mutations
    /// persist and shared state is not engine-scoped.
    /// </remarks>
    function &For(const Engine: string; const Callback: TQueryCallback): IQuery;
    /// <summary>Invokes the assigned true or false callback according to Condition.</summary>
    /// <param name="Condition">Boolean evaluated now to choose whether the callback runs.</param>
    /// <param name="WhenTrue">
    /// Optional callback invoked immediately on this query when Condition is True; must return this query.
    /// </param>
    /// <param name="WhenFalse">
    /// Optional callback invoked immediately on this query when Condition is False; must return this query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Only the selected assigned callback runs, immediately on this query; an unassigned branch is a no-op.
    /// The callback must return the supplied instance, otherwise EQueryException is raised. Changes are made
    /// to this query and are not rolled back on failure.
    /// </remarks>
    function When(Condition: Boolean; const WhenTrue: TQueryCallback;
      const WhenFalse: TQueryCallback = nil): IQuery;
    /// <summary>Invokes Callback on this query only when Condition is False.</summary>
    /// <param name="Condition">Boolean evaluated now to choose whether the callback runs.</param>
    /// <param name="Callback">
    /// Callback receiving this current query and required to return the same instance.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// An unassigned callback is a no-op. The callback must return the supplied query; changes persist on
    /// this instance.
    /// </remarks>
    function WhenNot(Condition: Boolean;
      const Callback: TQueryCallback): IQuery;
    /// <summary>Adds a named variable for deferred compilation-time lookup.</summary>
    /// <param name="Name">Variable name, matched by the query dictionary.</param>
    /// <param name="Value">
    /// Value stored for deferred lookup; referenced objects remain application-owned.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Duplicate names raise the underlying dictionary duplicate-key exception; this method does not replace
    /// existing variables.
    /// </remarks>
    function Define(const Name: string; const Value: TValue): IQuery;
    /// <summary>Looks up a variable defined directly on this query.</summary>
    /// <param name="Name">Variable name, matched by the query dictionary.</param>
    /// <returns>The stored TValue; referenced objects remain application-owned.</returns>
    /// <remarks>
    /// Raises EQueryException if the name is missing. Compiler lookup additionally searches enclosing query
    /// scopes.
    /// </remarks>
    function FindVariable(const Name: string): TValue;
    /// <summary>Replaces the FROM source in this engine scope with a table identifier.</summary>
    /// <param name="Table">Table name, optionally qualified and with an explicit AS alias.</param>
    /// <returns>This query instance, modified in place.</returns>
    function &From(const Table: string): IQuery; overload;
    /// <summary>Replaces the FROM source in this engine scope with a cloned subquery.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; subsequent changes to the source do not change this clause.
    /// </param>
    /// <param name="Alias">Alias for the embedded query.</param>
    /// <returns>This query instance, modified in place.</returns>
    function &From(Query: IQuery; const Alias: string = ''): IQuery; overload;
    /// <summary>
    /// Builds a subquery immediately through Callback and uses it as the FROM source in this engine scope.
    /// </summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that same query.
    /// </param>
    /// <param name="Alias">Alias for the embedded query.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns another query or nil.</exception>
    function &From(const Callback: TQueryCallback; const Alias: string = '')
      : IQuery; overload;
    /// <summary>Appends a scalar subquery select expression and switches to SELECT.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; subsequent changes to the source do not change this clause.
    /// </param>
    /// <param name="Alias">Alias for the embedded query.</param>
    /// <returns>This query instance, modified in place.</returns>
    function Select(Query: IQuery; const Alias: string): IQuery; overload;
    /// <summary>Appends a scalar subquery select expression and switches to SELECT.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that same query.
    /// </param>
    /// <param name="Alias">Alias for the embedded query.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns another query or nil.</exception>
    function Select(const Callback: TQueryCallback; const Alias: string)
      : IQuery; overload;
    /// <summary>Appends an aggregate select expression with an optional predicate filter.</summary>
    /// <param name="Aggregate">
    /// Trusted SQL function name, emitted as supplied apart from uppercasing; not validated or parameterized.
    /// </param>
    /// <param name="Column">
    /// Aggregated column name; accepts an explicit AS alias. Column shorthand is not expanded.
    /// </param>
    /// <param name="Filter">
    /// Optional callback configuring a new scoped query whose WHERE predicates filter the aggregate; runs
    /// immediately and must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Uses FILTER where supported, otherwise CASE; SQL support depends on the database.</remarks>
    function SelectAggregate(const Aggregate, Column: string;
      const Filter: TQueryCallback = nil): IQuery; overload;
    /// <summary>Appends an aggregate select expression with an optional predicate filter.</summary>
    /// <param name="Aggregate">
    /// Trusted SQL function name, emitted as supplied apart from uppercasing; not validated or parameterized.
    /// </param>
    /// <param name="Column">
    /// Aggregated column name; accepts an explicit AS alias. Column shorthand is not expanded.
    /// </param>
    /// <param name="Filter">
    /// Optional query whose WHERE predicates are cloned to filter the aggregate; nil means no filter.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Uses FILTER where supported, otherwise CASE; SQL support depends on the database.</remarks>
    function SelectAggregate(const Aggregate, Column: string; Filter: IQuery)
      : IQuery; overload;
    /// <summary>Appends a common table expression (CTE).</summary>
    /// <param name="Alias">Nonblank CTE name; surrounding whitespace is trimmed.</param>
    /// <param name="Query">
    /// Non-nil query to clone; subsequent changes to the source do not change this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Uses the supplied Alias. The stored query alias is cleared.</remarks>
    /// <exception cref="EQueryException">The CTE name is blank.</exception>
    function &With(const Alias: string; Query: IQuery): IQuery; overload;
    /// <summary>Appends a common table expression (CTE).</summary>
    /// <param name="Query">
    /// Non-nil query to clone; subsequent changes to the source do not change this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses the nested query QueryAlias, which must be nonblank. The stored query alias is cleared.
    /// </remarks>
    /// <exception cref="EQueryException">The CTE name is blank.</exception>
    function &With(Query: IQuery): IQuery; overload;
    /// <summary>Appends a common table expression (CTE).</summary>
    /// <param name="Alias">Nonblank CTE name; surrounding whitespace is trimmed.</param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that same query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Uses the supplied Alias. The stored query alias is cleared.</remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">
    /// The CTE name is blank. Callback returns another query or nil.
    /// </exception>
    function &With(const Alias: string; const Callback: TQueryCallback)
      : IQuery; overload;
    /// <summary>Appends a common table expression (CTE).</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that same query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses the nested query QueryAlias, which must be nonblank. The stored query alias is cleared.
    /// </remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">
    /// The CTE name is blank. Callback returns another query or nil.
    /// </exception>
    function &With(const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Appends a common table expression (CTE).</summary>
    /// <param name="Alias">Nonblank CTE name; surrounding whitespace is trimmed.</param>
    /// <param name="Columns">
    /// Column identifiers in value/projection order; each row must have a matching value for every column.
    /// </param>
    /// <param name="Rows">Nonempty row-major values matching the column count in each row.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Defines a value-table CTE with nonempty columns and rows of matching width.</remarks>
    function &With(const Alias: string; const Columns: array of string;
      const Rows: TRows): IQuery; overload;
    /// <summary>Appends a CTE defined by trusted SQL.</summary>
    /// <param name="Alias">Nonblank CTE name; surrounding whitespace is trimmed.</param>
    /// <param name="Sql">
    /// Trusted CTE body; ? placeholders outside quotes and comments consume bindings. Identifier markers
    /// request dialect quoting.
    /// </param>
    /// <param name="Bindings">
    /// Values for unquoted ? placeholders in order. Arrays expand into parameter lists, except TBytes.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Never interpolate untrusted data. Bindings supply placeholder values in order. A literal \? escape
    /// remains in executable SQL.
    /// </remarks>
    function WithRaw(const Alias, Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    /// <summary>Appends a CTE defined by trusted SQL.</summary>
    /// <param name="Alias">Nonblank CTE name; surrounding whitespace is trimmed.</param>
    /// <param name="Sql">
    /// Trusted CTE body; ? placeholders outside quotes and comments consume bindings. Identifier markers
    /// request dialect quoting.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Never interpolate untrusted data. This overload supplies no bindings. A literal \? escape remains in
    /// executable SQL.
    /// </remarks>
    function WithRaw(const Alias, Sql: string): IQuery; overload;
    /// <summary>Appends a JOIN comparing two columns.</summary>
    /// <param name="Table">Table name, optionally qualified and with an explicit AS alias.</param>
    /// <param name="First">Left column identifier, quoted by the compiler.</param>
    /// <param name="Second">
    /// Right column identifier, quoted by the compiler rather than bound as a value.
    /// </param>
    /// <param name="Op">Comparison operator accepted by the compiler whitelist.</param>
    /// <param name="JoinType">Join SQL keyword sequence, such as inner join or left join.</param>
    /// <returns>This query instance, modified in place.</returns>
    function Join(const Table, First, Second: string; const Op: string = '=';
      const JoinType: string = 'inner join'): IQuery; overload;
    /// <summary>Appends a JOIN with callback-defined ON predicates.</summary>
    /// <param name="Table">Table name, optionally qualified and with an explicit AS alias.</param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that same query.
    /// </param>
    /// <param name="JoinType">Join SQL keyword sequence, such as inner join or left join.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Callback predicates become a parenthesized ON group; configure column comparisons with On/OrOn.
    /// </remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns another query or nil.</exception>
    function Join(const Table: string; const Callback: TQueryCallback;
      const JoinType: string = 'inner join'): IQuery; overload;
    /// <summary>Appends a JOIN to a cloned subquery with callback-defined ON predicates.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; subsequent changes to the source do not change this clause.
    /// </param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that same query.
    /// </param>
    /// <param name="JoinType">Join SQL keyword sequence, such as inner join or left join.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Callback predicates become a parenthesized ON group; configure column comparisons with On/OrOn.
    /// </remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns another query or nil.</exception>
    function Join(Query: IQuery; const Callback: TQueryCallback;
      const JoinType: string = 'inner join'): IQuery; overload;
    /// <summary>Appends a LEFT JOIN comparing two columns.</summary>
    /// <param name="Table">Table name, optionally qualified and with an explicit AS alias.</param>
    /// <param name="First">Left column identifier, quoted by the compiler.</param>
    /// <param name="Second">
    /// Right column identifier, quoted by the compiler rather than bound as a value.
    /// </param>
    /// <param name="Op">Comparison operator accepted by the compiler whitelist.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Unmatched left source rows are retained.</remarks>
    function LeftJoin(const Table, First, Second: string;
      const Op: string = '='): IQuery; overload;
    /// <summary>Appends a LEFT JOIN with callback-defined ON predicates.</summary>
    /// <param name="Table">Table name, optionally qualified and with an explicit AS alias.</param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that same query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Callback predicates become a parenthesized ON group; configure column comparisons with On/OrOn.
    /// Unmatched left source rows are retained.
    /// </remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns another query or nil.</exception>
    function LeftJoin(const Table: string; const Callback: TQueryCallback)
      : IQuery; overload;
    /// <summary>Appends a LEFT JOIN to a cloned subquery with callback-defined ON predicates.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; subsequent changes to the source do not change this clause.
    /// </param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that same query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Callback predicates become a parenthesized ON group; configure column comparisons with On/OrOn.
    /// Unmatched left source rows are retained.
    /// </remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns another query or nil.</exception>
    function LeftJoin(Query: IQuery; const Callback: TQueryCallback)
      : IQuery; overload;
    /// <summary>Appends a RIGHT JOIN comparing two columns.</summary>
    /// <param name="Table">Table name, optionally qualified and with an explicit AS alias.</param>
    /// <param name="First">Left column identifier, quoted by the compiler.</param>
    /// <param name="Second">
    /// Right column identifier, quoted by the compiler rather than bound as a value.
    /// </param>
    /// <param name="Op">Comparison operator accepted by the compiler whitelist.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Database support depends on the selected dialect/server. Unmatched right source rows are retained.
    /// </remarks>
    function RightJoin(const Table, First, Second: string;
      const Op: string = '='): IQuery; overload;
    /// <summary>Appends a RIGHT JOIN with callback-defined ON predicates.</summary>
    /// <param name="Table">Table name, optionally qualified and with an explicit AS alias.</param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that same query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Database support depends on the selected dialect/server. Callback predicates become a parenthesized ON
    /// group; configure column comparisons with On/OrOn. Unmatched right source rows are retained.
    /// </remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns another query or nil.</exception>
    function RightJoin(const Table: string; const Callback: TQueryCallback)
      : IQuery; overload;
    /// <summary>Appends a RIGHT JOIN to a cloned subquery with callback-defined ON predicates.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; subsequent changes to the source do not change this clause.
    /// </param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that same query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Database support depends on the selected dialect/server. Callback predicates become a parenthesized ON
    /// group; configure column comparisons with On/OrOn. Unmatched right source rows are retained.
    /// </remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns another query or nil.</exception>
    function RightJoin(Query: IQuery; const Callback: TQueryCallback)
      : IQuery; overload;
    /// <summary>Appends a CROSS JOIN without ON predicates.</summary>
    /// <param name="Table">Table name, optionally qualified and with an explicit AS alias.</param>
    /// <returns>This query instance, modified in place.</returns>
    function CrossJoin(const Table: string): IQuery;
    /// <summary>Adds an AND-connected column comparison to a join query.</summary>
    /// <param name="First">Left column identifier, quoted by the compiler.</param>
    /// <param name="Second">
    /// Right column identifier, quoted by the compiler rather than bound as a value.
    /// </param>
    /// <param name="Op">Comparison operator accepted by the compiler whitelist.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Equivalent to WhereColumns on the query supplied to a JOIN callback.</remarks>
    function On(const First, Second: string; const Op: string = '='): IQuery;
    /// <summary>Adds an OR-connected column comparison to a join query.</summary>
    /// <param name="First">Left column identifier, quoted by the compiler.</param>
    /// <param name="Second">
    /// Right column identifier, quoted by the compiler rather than bound as a value.
    /// </param>
    /// <param name="Op">Comparison operator accepted by the compiler whitelist.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Equivalent to OrWhereColumns on the query supplied to a JOIN callback.</remarks>
    function OrOn(const First, Second: string; const Op: string = '='): IQuery;
    /// <summary>Replaces the join source with a table identifier.</summary>
    /// <param name="Table">
    /// Table identifier, optionally qualified or followed by an explicit AS alias.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Alias of From; use inside a join-model callback.</remarks>
    function JoinWith(const Table: string): IQuery; overload;
    /// <summary>Replaces the join source with a cloned subquery.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; subsequent changes to the source do not change this clause.
    /// </param>
    /// <param name="Alias">Alias for the embedded query or CTE; CTE aliases must be nonblank.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Alias of From; use inside a join-model callback.</remarks>
    function JoinWith(Query: IQuery; const Alias: string = ''): IQuery;
      overload;
    /// <summary>Builds a subquery immediately through Callback and uses it as the join source.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that same query.
    /// </param>
    /// <param name="Alias">Alias for the embedded query or CTE; CTE aliases must be nonblank.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Alias of From; use inside a join-model callback.</remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns another query or nil.</exception>
    function JoinWith(const Callback: TQueryCallback; const Alias: string = '')
      : IQuery; overload;
    /// <summary>Replaces the source of a join query with trusted SQL.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. Use ? for values and {identifier} or [identifier] for dialect quoting. Escape a
    /// literal ? as \?.
    /// </param>
    /// <param name="Bindings">
    /// Values for unquoted ? placeholders in order. Arrays expand into parameter lists, except TBytes.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Only trusted SQL belongs in Sql; use Bindings for data. No-binding overloads supply an empty binding
    /// list.
    /// </remarks>
    function JoinWithRaw(const Sql: string;
      const Bindings: array of TValue): IQuery;
    /// <summary>Sets the join keyword text after converting it to uppercase.</summary>
    /// <param name="Value">Join keyword text; converted to uppercase without validating SQL grammar.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Used on join models; the database must support the supplied join syntax.</remarks>
    function AsType(const Value: string): IQuery;
    /// <summary>Sets this join model to INNER JOIN.</summary>
    /// <returns>This query instance, modified in place.</returns>
    function AsInner: IQuery;
    /// <summary>Sets this join model to OUTER JOIN.</summary>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// The emitted OUTER JOIN keyword sequence must be accepted by the target database; no FULL keyword is
    /// added.
    /// </remarks>
    function AsOuter: IQuery;
    /// <summary>Sets this join model to LEFT JOIN.</summary>
    /// <returns>This query instance, modified in place.</returns>
    function AsLeft: IQuery;
    /// <summary>Sets this join model to RIGHT JOIN.</summary>
    /// <returns>This query instance, modified in place.</returns>
    function AsRight: IQuery;
    /// <summary>Sets this join model to CROSS JOIN.</summary>
    /// <returns>This query instance, modified in place.</returns>
    function AsCross: IQuery;
    /// <summary>Replaces the maximum row count in the current engine scope.</summary>
    /// <param name="Value">Maximum rows to return; nonpositive values do not impose a positive limit.</param>
    /// <returns>This query instance, modified in place.</returns>
    function Limit(Value: Integer): IQuery;
    /// <summary>Replaces the number of rows to skip in the current engine scope.</summary>
    /// <param name="Value">Rows to skip; negative values are read as zero.</param>
    /// <returns>This query instance, modified in place.</returns>
    function Offset(Value: Int64): IQuery;
    /// <summary>Sets the maximum row count using Limit.</summary>
    /// <param name="Value">Maximum rows to return; nonpositive values do not impose a positive limit.</param>
    /// <returns>This query instance, modified in place.</returns>
    function Take(Value: Integer): IQuery;
    /// <summary>Sets the skipped row count using Offset.</summary>
    /// <param name="Value">Rows to skip; negative values are read as zero.</param>
    /// <returns>This query instance, modified in place.</returns>
    function Skip(Value: Int64): IQuery;
    /// <summary>Configures pagination from a one-based page number and page size.</summary>
    /// <param name="Page">One-based page number; not validated.</param>
    /// <param name="PerPage">Maximum rows per page; defaults to 15 and is not validated.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Sets Offset to (Page - 1) * PerPage and Limit to PerPage. Inputs are not validated; nonpositive
    /// limits/offsets follow the usual clamping rules. Use explicit ordering for stable pages.
    /// </remarks>
    function ForPage(Page: Integer; PerPage: Integer = 15): IQuery;
    /// <summary>Reads the selected row limit with shared-clause fallback.</summary>
    /// <param name="Engine">
    /// Engine scope, with shared-clause fallback; empty reads shared clauses only.
    /// </param>
    /// <returns>A nonnegative row limit, or zero when missing or negative.</returns>
    function GetLimit(const Engine: string = ''): Integer;
    /// <summary>Reads the selected offset with shared-clause fallback.</summary>
    /// <param name="Engine">
    /// Engine scope, with shared-clause fallback; empty reads shared clauses only.
    /// </param>
    /// <returns>A nonnegative skipped row count, or zero when missing or negative.</returns>
    function GetOffset(const Engine: string = ''): Int64;
    /// <summary>Tests whether the selected row limit is positive.</summary>
    /// <param name="Engine">
    /// Engine scope, with shared-clause fallback; empty reads shared clauses only.
    /// </param>
    /// <returns>True only when GetLimit is greater than zero.</returns>
    function HasLimit(const Engine: string = ''): Boolean;
    /// <summary>Tests whether the selected offset is positive.</summary>
    /// <param name="Engine">
    /// Engine scope, with shared-clause fallback; empty reads shared clauses only.
    /// </param>
    /// <returns>True only when GetOffset is greater than zero.</returns>
    function HasOffset(const Engine: string = ''): Boolean;
    /// <summary>Enables DISTINCT for SELECT or aggregate compilation.</summary>
    /// <returns>This query instance, modified in place.</returns>
    function Distinct: IQuery;
    /// <summary>Appends dialect-specific random ordering.</summary>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Seed use and repeatability depend on the compiler; several dialects ignore seeds.</remarks>
    function OrderByRandom: IQuery; overload;
    /// <summary>Appends dialect-specific random ordering.</summary>
    /// <param name="Seed">Optional random seed; some dialects ignore it.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Seed use and repeatability depend on the compiler; several dialects ignore seeds.</remarks>
    function OrderByRandom(Seed: Integer): IQuery; overload;
    /// <summary>Appends a cloned SELECT using a set operation.</summary>
    /// <param name="Operation">Set operator: union, except, or intersect (case-insensitive).</param>
    /// <param name="All">
    /// True to retain duplicates using the ALL form; database support depends on dialect.
    /// </param>
    /// <param name="Query">
    /// Non-nil query to clone; subsequent changes to the source do not change this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Operation must be union, except, or intersect. Both queries must have Method select. Database support
    /// for operations and ALL varies.
    /// </remarks>
    function Combine(const Operation: string; All: Boolean;
      Query: IQuery): IQuery;
    /// <summary>Switches to a standalone aggregate query.</summary>
    /// <param name="Aggregate">SQL aggregate function identifier, for example count or sum.</param>
    /// <param name="Columns">
    /// Column names stored as supplied, in order; AsCount handles an empty column array specially.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Validates the function identifier. Compilation removes LIMIT, ORDER BY and GROUP BY from a clone,
    /// retains OFFSET, and may wrap DISTINCT or multiple-column queries. Only the DISTINCT rewrite expands
    /// column shorthand through Select.
    /// </remarks>
    function AsAggregate(const Aggregate: string;
      const Columns: array of string): IQuery;
    /// <summary>Configures an INSERT of one row with positional column/value pairs.</summary>
    /// <param name="Columns">Target columns in assignment order; must match Values in length.</param>
    /// <param name="Values">Values copied in column order; duplicate values are preserved.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Column and value counts must be nonzero and equal; every supplied row must match the columns,
    /// otherwise EQueryException is raised.
    /// </remarks>
    function AsInsert(const Columns: array of string;
      const Values: array of TValue): IQuery; overload;
    /// <summary>Configures an INSERT of multiple rows sharing the same columns.</summary>
    /// <param name="Columns">Target columns in row order; each row must have this many values.</param>
    /// <param name="Rows">Nonempty row-major values matching the column count in each row.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Column and value counts must be nonzero and equal; every supplied row must match the columns,
    /// otherwise EQueryException is raised.
    /// </remarks>
    function AsInsert(const Columns: array of string; const Rows: TRows)
      : IQuery; overload;
    /// <summary>Configures INSERT ... SELECT from a cloned source query.</summary>
    /// <param name="Columns">Target columns in projection order; caller must match the SELECT output.</param>
    /// <param name="Query">
    /// Non-nil query to clone; subsequent changes to the source do not change this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Builds INSERT ... SELECT from a clone of the source query; the caller is responsible for matching
    /// projected columns.
    /// </remarks>
    function AsInsert(const Columns: array of string; Query: IQuery)
      : IQuery; overload;
    /// <summary>Configures an INSERT from named column/value pairs.</summary>
    /// <param name="Values">
    /// Named column/value pairs copied in the supplied order; duplicate values are preserved.
    /// </param>
    /// <param name="ReturnId">
    /// Requests dialect-specific identity SQL where available. Built-in execution rejects ReturnId batches;
    /// compilation alone can produce them.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>At least one pair is required, otherwise EQueryException is raised.</remarks>
    function AsInsert(const Values: array of TPair<string, TValue>;
      ReturnId: Boolean = False): IQuery; overload;
    /// <summary>Configures an INSERT from readable object properties and mapping attributes.</summary>
    /// <param name="Data">Non-nil caller-owned object; readable RTTI properties supply the values.</param>
    /// <param name="ReturnId">
    /// Requests dialect-specific identity SQL where available. Built-in execution rejects ReturnId batches;
    /// compilation alone can produce them.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Reads eligible RTTI properties and honors Column/Key/Ignore attributes. Built-in nullable values
    /// become a contained value or typed SQL NULL; custom nullable types requiring options must be extracted
    /// with TQueryDataMapper.GetPairs first.
    /// </remarks>
    function AsInsert(Data: TObject; ReturnId: Boolean = False)
      : IQuery; overload;
    /// <summary>Configures an INSERT from dictionary column/value pairs.</summary>
    /// <param name="Data">
    /// Non-nil caller-owned dictionary; pairs are copied in dictionary enumeration order.
    /// </param>
    /// <param name="ReturnId">
    /// Requests dialect-specific identity SQL where available. Built-in execution rejects ReturnId batches;
    /// compilation alone can produce them.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Copies dictionary pairs in dictionary enumeration order; no stable assignment order is promised.
    /// </remarks>
    function AsInsert(Data: TDictionary<string, TValue>;
      ReturnId: Boolean = False): IQuery; overload;
    /// <summary>Configures an UPDATE with positional column/value assignments.</summary>
    /// <param name="Columns">Target columns in assignment order; must match Values in length.</param>
    /// <param name="Values">Values copied in column order; duplicate values are preserved.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Existing WHERE conditions are retained. Without predicates the statement can affect every row. Column
    /// and value counts must be nonzero and equal; every supplied row must match the columns, otherwise
    /// EQueryException is raised.
    /// </remarks>
    function AsUpdate(const Columns: array of string;
      const Values: array of TValue): IQuery; overload;
    /// <summary>Configures an UPDATE from named column/value pairs.</summary>
    /// <param name="Values">
    /// Named column/value pairs copied in the supplied order; duplicate values are preserved.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Existing WHERE conditions are retained. Without predicates the statement can affect every row. At
    /// least one pair is required, otherwise EQueryException is raised.
    /// </remarks>
    function AsUpdate(const Values: array of TPair<string, TValue>)
      : IQuery; overload;
    /// <summary>Configures an UPDATE from readable object properties and mapping attributes.</summary>
    /// <param name="Data">Non-nil caller-owned object; readable RTTI properties supply the values.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Existing WHERE conditions are retained. Without predicates the statement can affect every row. Reads
    /// eligible RTTI properties and honors Column/Key/Ignore attributes. Built-in nullable values become a
    /// contained value or typed SQL NULL; custom nullable types requiring options must be extracted with
    /// TQueryDataMapper.GetPairs first. Key values add WHERE predicates and remain in assignments. TQueryNull
    /// keys raise EQueryMappingException before key callbacks modify the query; no key attribute means no
    /// automatic key predicate.
    /// </remarks>
    function AsUpdate(Data: TObject): IQuery; overload;
    /// <summary>Configures an UPDATE from dictionary column/value pairs.</summary>
    /// <param name="Data">
    /// Non-nil caller-owned dictionary; pairs are copied in dictionary enumeration order.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Existing WHERE conditions are retained. Without predicates the statement can affect every row. Copies
    /// dictionary pairs in dictionary enumeration order; no stable assignment order is promised.
    /// </remarks>
    function AsUpdate(Data: TDictionary<string, TValue>): IQuery; overload;
    /// <summary>Switches to DELETE while retaining the source and WHERE clauses.</summary>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Without WHERE predicates the statement can delete every row.</remarks>
    function AsDelete: IQuery;
    /// <summary>Replaces update assignments with an arithmetic column increment.</summary>
    /// <param name="Column">Column identifier, optionally qualified by a table name.</param>
    /// <param name="Value">Integer amount to add or subtract; negative amounts reverse the operation.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Retains WHERE predicates; without predicates the statement can affect every row.</remarks>
    function AsIncrement(const Column: string; Value: Integer = 1): IQuery;
    /// <summary>Replaces update assignments with an arithmetic column decrement.</summary>
    /// <param name="Column">Column identifier, optionally qualified by a table name.</param>
    /// <param name="Value">Integer amount to add or subtract; negative amounts reverse the operation.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Retains WHERE predicates; without predicates the statement can affect every row.</remarks>
    function AsDecrement(const Column: string; Value: Integer = 1): IQuery;
    /// <summary>Appends equality WHERE predicates from named values.</summary>
    /// <param name="Values">
    /// Column/value pairs in enumeration order; each becomes an equality predicate.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Pending OR and NOT flags apply to each pair. Empty input adds no conditions.</remarks>
    function Where(const Values: array of TPair<string, TValue>)
      : IQuery; overload;
    /// <summary>Appends equality WHERE predicates from named values.</summary>
    /// <param name="Data">Non-nil caller-owned object; readable RTTI properties supply the values.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Pending OR and NOT flags apply to each pair. Empty input adds no conditions. Reads eligible RTTI
    /// properties and honors Column/Key/Ignore attributes. Built-in nullable values become a contained value
    /// or typed SQL NULL; custom nullable types requiring options must be extracted with
    /// TQueryDataMapper.GetPairs first.
    /// </remarks>
    function Where(Data: TObject): IQuery; overload;
    /// <summary>Appends equality WHERE predicates from named values.</summary>
    /// <param name="Data">
    /// Non-nil caller-owned dictionary; pairs are copied in dictionary enumeration order.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Pending OR and NOT flags apply to each pair. Empty input adds no conditions. Copies dictionary pairs
    /// in dictionary enumeration order; no stable assignment order is promised.
    /// </remarks>
    function Where(Data: TDictionary<string, TValue>): IQuery; overload;
    /// <summary>Appends equality HAVING predicates from named values.</summary>
    /// <param name="Values">
    /// Column/value pairs in enumeration order; each becomes an equality predicate.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Pending OR and NOT flags apply to each pair. Empty input adds no conditions.</remarks>
    function Having(const Values: array of TPair<string, TValue>)
      : IQuery; overload;
    /// <summary>Appends equality HAVING predicates from named values.</summary>
    /// <param name="Data">Non-nil caller-owned object; readable RTTI properties supply the values.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Pending OR and NOT flags apply to each pair. Empty input adds no conditions. Reads eligible RTTI
    /// properties and honors Column/Key/Ignore attributes. Built-in nullable values become a contained value
    /// or typed SQL NULL; custom nullable types requiring options must be extracted with
    /// TQueryDataMapper.GetPairs first.
    /// </remarks>
    function Having(Data: TObject): IQuery; overload;
    /// <summary>Appends equality HAVING predicates from named values.</summary>
    /// <param name="Data">
    /// Non-nil caller-owned dictionary; pairs are copied in dictionary enumeration order.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Pending OR and NOT flags apply to each pair. Empty input adds no conditions. Copies dictionary pairs
    /// in dictionary enumeration order; no stable assignment order is promised.
    /// </remarks>
    function Having(Data: TDictionary<string, TValue>): IQuery; overload;
    // BEGIN GENERATED: fluent declarations
    /// <summary>Appends a column/value comparison to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Direct SQL NULL values compile to IS NULL for equality, or IS NOT NULL for other operators or
    /// negation. Boolean values use dialect literals.
    /// </remarks>
    function Where(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a column/value comparison to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses equality (=). Direct SQL NULL values compile to IS NULL for equality, or IS NOT NULL for other
    /// operators or negation. Boolean values use dialect literals.
    /// </remarks>
    function Where(const Column: string; const Value: TValue): IQuery; overload;
    /// <summary>Appends a parenthesized predicate group to WHERE.</summary>
    /// <param name="Group">Non-nil query whose predicates are cloned into the group.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses WHERE predicates when present, otherwise HAVING predicates; empty groups are omitted.
    /// </remarks>
    function Where(Group: IQuery): IQuery; overload;
    /// <summary>Appends a parenthesized predicate group to WHERE.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses WHERE predicates when present, otherwise HAVING predicates; empty groups are omitted.
    /// </remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function Where(const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Appends a column comparison with a scalar subquery to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function Where(const Column, Op: string; Query: IQuery): IQuery; overload;
    /// <summary>Appends a column comparison with a scalar subquery to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function Where(const Column, Op: string; const Callback: TQueryCallback)
      : IQuery; overload;
    /// <summary>Appends an IS NULL test to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereNull(const Column: string): IQuery;
    /// <summary>Appends a test for the dialect true literal to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereTrue(const Column: string): IQuery;
    /// <summary>Appends a test for the dialect false literal to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereFalse(const Column: string): IQuery;
    /// <summary>Appends an inclusive BETWEEN test to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Lower">Inclusive lower bound.</param>
    /// <param name="Higher">Inclusive upper bound.</param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereBetween(const Column: string;
      const Lower, Higher: TValue): IQuery;
    /// <summary>Appends an IN test against a value list to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Values">Values copied and deduplicated using supported, type-sensitive equality.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>An empty list compiles to false for IN.</remarks>
    function WhereIn(const Column: string; const Values: array of TValue)
      : IQuery; overload;
    /// <summary>Appends an IN test against a subquery to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereIn(const Column: string; Query: IQuery): IQuery; overload;
    /// <summary>Appends an IN test against a subquery to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function WhereIn(const Column: string; const Callback: TQueryCallback)
      : IQuery; overload;
    /// <summary>Appends an EXISTS test to WHERE.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <exception cref="EQueryException">The subquery is nil or has no FROM clause.</exception>
    function WhereExists(Query: IQuery): IQuery; overload;
    /// <summary>Appends an EXISTS test to WHERE.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <exception cref="EQueryException">
    /// The subquery is nil or has no FROM clause. Callback returns a different query or nil.
    /// </exception>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    function WhereExists(const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Appends a LIKE pattern comparison to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereLike(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a LIKE comparison with a trailing % wildcard to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereStarts(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a LIKE comparison with a leading % wildcard to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereEnds(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a LIKE comparison with leading and trailing % wildcards to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereContains(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a comparison of the date portion of a column to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereDate(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the date portion of a column to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Uses equality (=).</remarks>
    function WhereDate(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the time portion of a column to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereTime(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the time portion of a column to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Uses equality (=).</remarks>
    function WhereTime(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of a date part of a column to WHERE.</summary>
    /// <param name="Part">
    /// Date part name containing ASCII letters or underscores; supported names depend on the compiler.
    /// </param>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereDatePart(const Part, Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of a date part of a column to WHERE.</summary>
    /// <param name="Part">
    /// Date part name containing ASCII letters or underscores; supported names depend on the compiler.
    /// </param>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Uses equality (=).</remarks>
    function WhereDatePart(const Part, Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a column/value comparison to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Direct SQL NULL values compile to IS NULL for equality, or IS NOT NULL for other operators or
    /// negation. Boolean values use dialect literals.
    /// </remarks>
    function WhereNot(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a column/value comparison to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses equality (=). Direct SQL NULL values compile to IS NULL for equality, or IS NOT NULL for other
    /// operators or negation. Boolean values use dialect literals.
    /// </remarks>
    function WhereNot(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a parenthesized predicate group to WHERE and negates it.</summary>
    /// <param name="Group">Non-nil query whose predicates are cloned into the group.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses WHERE predicates when present, otherwise HAVING predicates; empty groups are omitted.
    /// </remarks>
    function WhereNot(Group: IQuery): IQuery; overload;
    /// <summary>Appends a parenthesized predicate group to WHERE and negates it.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses WHERE predicates when present, otherwise HAVING predicates; empty groups are omitted.
    /// </remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function WhereNot(const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Appends a column comparison with a scalar subquery to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereNot(const Column, Op: string; Query: IQuery): IQuery;
      overload;
    /// <summary>Appends a column comparison with a scalar subquery to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function WhereNot(const Column, Op: string; const Callback: TQueryCallback)
      : IQuery; overload;
    /// <summary>Appends an IS NULL test to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereNotNull(const Column: string): IQuery;
    /// <summary>Appends an inclusive BETWEEN test to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Lower">Inclusive lower bound.</param>
    /// <param name="Higher">Inclusive upper bound.</param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereNotBetween(const Column: string;
      const Lower, Higher: TValue): IQuery;
    /// <summary>Appends an IN test against a value list to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Values">Values copied and deduplicated using supported, type-sensitive equality.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>An empty list compiles to true for NOT IN.</remarks>
    function WhereNotIn(const Column: string; const Values: array of TValue)
      : IQuery; overload;
    /// <summary>Appends an IN test against a subquery to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereNotIn(const Column: string; Query: IQuery): IQuery; overload;
    /// <summary>Appends an IN test against a subquery to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function WhereNotIn(const Column: string; const Callback: TQueryCallback)
      : IQuery; overload;
    /// <summary>Appends an EXISTS test to WHERE and negates it.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <exception cref="EQueryException">The subquery is nil or has no FROM clause.</exception>
    function WhereNotExists(Query: IQuery): IQuery; overload;
    /// <summary>Appends an EXISTS test to WHERE and negates it.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <exception cref="EQueryException">
    /// The subquery is nil or has no FROM clause. Callback returns a different query or nil.
    /// </exception>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    function WhereNotExists(const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Appends a LIKE pattern comparison to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereNotLike(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a LIKE comparison with a trailing % wildcard to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereNotStarts(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a LIKE comparison with a leading % wildcard to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereNotEnds(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>
    /// Appends a LIKE comparison with leading and trailing % wildcards to WHERE and negates it.
    /// </summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereNotContains(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a comparison of the date portion of a column to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereNotDate(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the date portion of a column to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Uses equality (=).</remarks>
    function WhereNotDate(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the time portion of a column to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereNotTime(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the time portion of a column to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Uses equality (=).</remarks>
    function WhereNotTime(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of a date part of a column to WHERE and negates it.</summary>
    /// <param name="Part">
    /// Date part name containing ASCII letters or underscores; supported names depend on the compiler.
    /// </param>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereNotDatePart(const Part, Column, Op: string;
      const Value: TValue): IQuery; overload;
    /// <summary>Appends a comparison of a date part of a column to WHERE and negates it.</summary>
    /// <param name="Part">
    /// Date part name containing ASCII letters or underscores; supported names depend on the compiler.
    /// </param>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Uses equality (=).</remarks>
    function WhereNotDatePart(const Part, Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a trusted SQL predicate to WHERE.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <param name="Bindings">
    /// Placeholder values in order. Arrays expand into parameter lists, except TBytes.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Never interpolate untrusted input into Sql. A literal question mark can be marked as \?; the escape
    /// remains in executable SQL. Pending Not does not negate raw predicates; include any required NOT in
    /// Sql.
    /// </remarks>
    function WhereRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    /// <summary>Appends a trusted SQL predicate to WHERE.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Supplies no bindings; unescaped value placeholders require the overload with Bindings. Never
    /// interpolate untrusted input into Sql. A literal question mark can be marked as \?; the escape remains
    /// in executable SQL. Pending Not does not negate raw predicates; include any required NOT in Sql.
    /// </remarks>
    function WhereRaw(const Sql: string): IQuery; overload;
    /// <summary>Appends a comparison between two columns to WHERE.</summary>
    /// <param name="First">Left column name.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Second">Right column name, quoted as an identifier rather than bound as a value.</param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereColumns(const First, Op, Second: string): IQuery;
    /// <summary>Appends a scalar subquery on the left of a value comparison to WHERE.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    function WhereSub(Query: IQuery; const Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a scalar subquery on the left of a value comparison to WHERE.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Uses equality (=).</remarks>
    function WhereSub(Query: IQuery; const Value: TValue): IQuery; overload;
    /// <summary>Appends a column/value comparison to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Joins this predicate with OR. Direct SQL NULL values compile to IS NULL for equality, or IS NOT NULL
    /// for other operators or negation. Boolean values use dialect literals.
    /// </remarks>
    function OrWhere(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a column/value comparison to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Joins this predicate with OR. Uses equality (=). Direct SQL NULL values compile to IS NULL for
    /// equality, or IS NOT NULL for other operators or negation. Boolean values use dialect literals.
    /// </remarks>
    function OrWhere(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a parenthesized predicate group to WHERE.</summary>
    /// <param name="Group">Non-nil query whose predicates are cloned into the group.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses WHERE predicates when present, otherwise HAVING predicates; empty groups are omitted. Joins this
    /// predicate with OR.
    /// </remarks>
    function OrWhere(Group: IQuery): IQuery; overload;
    /// <summary>Appends a parenthesized predicate group to WHERE.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses WHERE predicates when present, otherwise HAVING predicates; empty groups are omitted. Joins this
    /// predicate with OR.
    /// </remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function OrWhere(const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Appends a column comparison with a scalar subquery to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhere(const Column, Op: string; Query: IQuery): IQuery; overload;
    /// <summary>Appends a column comparison with a scalar subquery to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function OrWhere(const Column, Op: string; const Callback: TQueryCallback)
      : IQuery; overload;
    /// <summary>Appends an IS NULL test to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereNull(const Column: string): IQuery;
    /// <summary>Appends a test for the dialect true literal to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereTrue(const Column: string): IQuery;
    /// <summary>Appends a test for the dialect false literal to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereFalse(const Column: string): IQuery;
    /// <summary>Appends an inclusive BETWEEN test to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Lower">Inclusive lower bound.</param>
    /// <param name="Higher">Inclusive upper bound.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereBetween(const Column: string;
      const Lower, Higher: TValue): IQuery;
    /// <summary>Appends an IN test against a value list to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Values">Values copied and deduplicated using supported, type-sensitive equality.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR. An empty list compiles to false for IN.</remarks>
    function OrWhereIn(const Column: string; const Values: array of TValue)
      : IQuery; overload;
    /// <summary>Appends an IN test against a subquery to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereIn(const Column: string; Query: IQuery): IQuery; overload;
    /// <summary>Appends an IN test against a subquery to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function OrWhereIn(const Column: string; const Callback: TQueryCallback)
      : IQuery; overload;
    /// <summary>Appends an EXISTS test to WHERE.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    /// <exception cref="EQueryException">The subquery is nil or has no FROM clause.</exception>
    function OrWhereExists(Query: IQuery): IQuery; overload;
    /// <summary>Appends an EXISTS test to WHERE.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    /// <exception cref="EQueryException">
    /// The subquery is nil or has no FROM clause. Callback returns a different query or nil.
    /// </exception>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    function OrWhereExists(const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Appends a LIKE pattern comparison to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereLike(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a LIKE comparison with a trailing % wildcard to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereStarts(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a LIKE comparison with a leading % wildcard to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereEnds(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a LIKE comparison with leading and trailing % wildcards to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereContains(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a comparison of the date portion of a column to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereDate(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the date portion of a column to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR. Uses equality (=).</remarks>
    function OrWhereDate(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the time portion of a column to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereTime(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the time portion of a column to WHERE.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR. Uses equality (=).</remarks>
    function OrWhereTime(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of a date part of a column to WHERE.</summary>
    /// <param name="Part">
    /// Date part name containing ASCII letters or underscores; supported names depend on the compiler.
    /// </param>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereDatePart(const Part, Column, Op: string;
      const Value: TValue): IQuery; overload;
    /// <summary>Appends a comparison of a date part of a column to WHERE.</summary>
    /// <param name="Part">
    /// Date part name containing ASCII letters or underscores; supported names depend on the compiler.
    /// </param>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR. Uses equality (=).</remarks>
    function OrWhereDatePart(const Part, Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a column/value comparison to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Joins this predicate with OR. Direct SQL NULL values compile to IS NULL for equality, or IS NOT NULL
    /// for other operators or negation. Boolean values use dialect literals.
    /// </remarks>
    function OrWhereNot(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a column/value comparison to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Joins this predicate with OR. Uses equality (=). Direct SQL NULL values compile to IS NULL for
    /// equality, or IS NOT NULL for other operators or negation. Boolean values use dialect literals.
    /// </remarks>
    function OrWhereNot(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a parenthesized predicate group to WHERE and negates it.</summary>
    /// <param name="Group">Non-nil query whose predicates are cloned into the group.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses WHERE predicates when present, otherwise HAVING predicates; empty groups are omitted. Joins this
    /// predicate with OR.
    /// </remarks>
    function OrWhereNot(Group: IQuery): IQuery; overload;
    /// <summary>Appends a parenthesized predicate group to WHERE and negates it.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses WHERE predicates when present, otherwise HAVING predicates; empty groups are omitted. Joins this
    /// predicate with OR.
    /// </remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function OrWhereNot(const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Appends a column comparison with a scalar subquery to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereNot(const Column, Op: string; Query: IQuery)
      : IQuery; overload;
    /// <summary>Appends a column comparison with a scalar subquery to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function OrWhereNot(const Column, Op: string;
      const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Appends an IS NULL test to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereNotNull(const Column: string): IQuery;
    /// <summary>Appends an inclusive BETWEEN test to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Lower">Inclusive lower bound.</param>
    /// <param name="Higher">Inclusive upper bound.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereNotBetween(const Column: string;
      const Lower, Higher: TValue): IQuery;
    /// <summary>Appends an IN test against a value list to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Values">Values copied and deduplicated using supported, type-sensitive equality.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR. An empty list compiles to true for NOT IN.</remarks>
    function OrWhereNotIn(const Column: string; const Values: array of TValue)
      : IQuery; overload;
    /// <summary>Appends an IN test against a subquery to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereNotIn(const Column: string; Query: IQuery): IQuery;
      overload;
    /// <summary>Appends an IN test against a subquery to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function OrWhereNotIn(const Column: string; const Callback: TQueryCallback)
      : IQuery; overload;
    /// <summary>Appends an EXISTS test to WHERE and negates it.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    /// <exception cref="EQueryException">The subquery is nil or has no FROM clause.</exception>
    function OrWhereNotExists(Query: IQuery): IQuery; overload;
    /// <summary>Appends an EXISTS test to WHERE and negates it.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    /// <exception cref="EQueryException">
    /// The subquery is nil or has no FROM clause. Callback returns a different query or nil.
    /// </exception>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    function OrWhereNotExists(const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Appends a LIKE pattern comparison to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereNotLike(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a LIKE comparison with a trailing % wildcard to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereNotStarts(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a LIKE comparison with a leading % wildcard to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereNotEnds(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>
    /// Appends a LIKE comparison with leading and trailing % wildcards to WHERE and negates it.
    /// </summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereNotContains(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a comparison of the date portion of a column to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereNotDate(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the date portion of a column to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR. Uses equality (=).</remarks>
    function OrWhereNotDate(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the time portion of a column to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereNotTime(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the time portion of a column to WHERE and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR. Uses equality (=).</remarks>
    function OrWhereNotTime(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of a date part of a column to WHERE and negates it.</summary>
    /// <param name="Part">
    /// Date part name containing ASCII letters or underscores; supported names depend on the compiler.
    /// </param>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereNotDatePart(const Part, Column, Op: string;
      const Value: TValue): IQuery; overload;
    /// <summary>Appends a comparison of a date part of a column to WHERE and negates it.</summary>
    /// <param name="Part">
    /// Date part name containing ASCII letters or underscores; supported names depend on the compiler.
    /// </param>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR. Uses equality (=).</remarks>
    function OrWhereNotDatePart(const Part, Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a trusted SQL predicate to WHERE.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <param name="Bindings">
    /// Placeholder values in order. Arrays expand into parameter lists, except TBytes.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Joins this predicate with OR. Never interpolate untrusted input into Sql. A literal question mark can
    /// be marked as \?; the escape remains in executable SQL. Pending Not does not negate raw predicates;
    /// include any required NOT in Sql.
    /// </remarks>
    function OrWhereRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    /// <summary>Appends a trusted SQL predicate to WHERE.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Joins this predicate with OR. Supplies no bindings; unescaped value placeholders require the overload
    /// with Bindings. Never interpolate untrusted input into Sql. A literal question mark can be marked as
    /// \?; the escape remains in executable SQL. Pending Not does not negate raw predicates; include any
    /// required NOT in Sql.
    /// </remarks>
    function OrWhereRaw(const Sql: string): IQuery; overload;
    /// <summary>Appends a comparison between two columns to WHERE.</summary>
    /// <param name="First">Left column name.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Second">Right column name, quoted as an identifier rather than bound as a value.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereColumns(const First, Op, Second: string): IQuery;
    /// <summary>Appends a scalar subquery on the left of a value comparison to WHERE.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrWhereSub(Query: IQuery; const Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a scalar subquery on the left of a value comparison to WHERE.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR. Uses equality (=).</remarks>
    function OrWhereSub(Query: IQuery; const Value: TValue): IQuery; overload;
    /// <summary>Appends a column/value comparison to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Direct SQL NULL values compile to IS NULL for equality, or IS NOT NULL for other operators or
    /// negation. Boolean values use dialect literals.
    /// </remarks>
    function Having(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a column/value comparison to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses equality (=). Direct SQL NULL values compile to IS NULL for equality, or IS NOT NULL for other
    /// operators or negation. Boolean values use dialect literals.
    /// </remarks>
    function Having(const Column: string; const Value: TValue): IQuery;
      overload;
    /// <summary>Appends a parenthesized predicate group to HAVING.</summary>
    /// <param name="Group">Non-nil query whose predicates are cloned into the group.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses WHERE predicates when present, otherwise HAVING predicates; empty groups are omitted.
    /// </remarks>
    function Having(Group: IQuery): IQuery; overload;
    /// <summary>Appends a parenthesized predicate group to HAVING.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses WHERE predicates when present, otherwise HAVING predicates; empty groups are omitted.
    /// </remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function Having(const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Appends a column comparison with a scalar subquery to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function Having(const Column, Op: string; Query: IQuery): IQuery; overload;
    /// <summary>Appends a column comparison with a scalar subquery to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function Having(const Column, Op: string; const Callback: TQueryCallback)
      : IQuery; overload;
    /// <summary>Appends an IS NULL test to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingNull(const Column: string): IQuery;
    /// <summary>Appends a test for the dialect true literal to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingTrue(const Column: string): IQuery;
    /// <summary>Appends a test for the dialect false literal to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingFalse(const Column: string): IQuery;
    /// <summary>Appends an inclusive BETWEEN test to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Lower">Inclusive lower bound.</param>
    /// <param name="Higher">Inclusive upper bound.</param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingBetween(const Column: string;
      const Lower, Higher: TValue): IQuery;
    /// <summary>Appends an IN test against a value list to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Values">Values copied and deduplicated using supported, type-sensitive equality.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>An empty list compiles to false for IN.</remarks>
    function HavingIn(const Column: string; const Values: array of TValue)
      : IQuery; overload;
    /// <summary>Appends an IN test against a subquery to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingIn(const Column: string; Query: IQuery): IQuery; overload;
    /// <summary>Appends an IN test against a subquery to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function HavingIn(const Column: string; const Callback: TQueryCallback)
      : IQuery; overload;
    /// <summary>Appends an EXISTS test to HAVING.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <exception cref="EQueryException">The subquery is nil or has no FROM clause.</exception>
    function HavingExists(Query: IQuery): IQuery; overload;
    /// <summary>Appends an EXISTS test to HAVING.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <exception cref="EQueryException">
    /// The subquery is nil or has no FROM clause. Callback returns a different query or nil.
    /// </exception>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    function HavingExists(const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Appends a LIKE pattern comparison to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingLike(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a LIKE comparison with a trailing % wildcard to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingStarts(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a LIKE comparison with a leading % wildcard to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingEnds(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a LIKE comparison with leading and trailing % wildcards to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingContains(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a comparison of the date portion of a column to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingDate(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the date portion of a column to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Uses equality (=).</remarks>
    function HavingDate(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the time portion of a column to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingTime(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the time portion of a column to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Uses equality (=).</remarks>
    function HavingTime(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of a date part of a column to HAVING.</summary>
    /// <param name="Part">
    /// Date part name containing ASCII letters or underscores; supported names depend on the compiler.
    /// </param>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingDatePart(const Part, Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of a date part of a column to HAVING.</summary>
    /// <param name="Part">
    /// Date part name containing ASCII letters or underscores; supported names depend on the compiler.
    /// </param>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Uses equality (=).</remarks>
    function HavingDatePart(const Part, Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a column/value comparison to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Direct SQL NULL values compile to IS NULL for equality, or IS NOT NULL for other operators or
    /// negation. Boolean values use dialect literals.
    /// </remarks>
    function HavingNot(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a column/value comparison to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses equality (=). Direct SQL NULL values compile to IS NULL for equality, or IS NOT NULL for other
    /// operators or negation. Boolean values use dialect literals.
    /// </remarks>
    function HavingNot(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a parenthesized predicate group to HAVING and negates it.</summary>
    /// <param name="Group">Non-nil query whose predicates are cloned into the group.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses WHERE predicates when present, otherwise HAVING predicates; empty groups are omitted.
    /// </remarks>
    function HavingNot(Group: IQuery): IQuery; overload;
    /// <summary>Appends a parenthesized predicate group to HAVING and negates it.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses WHERE predicates when present, otherwise HAVING predicates; empty groups are omitted.
    /// </remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function HavingNot(const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Appends a column comparison with a scalar subquery to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingNot(const Column, Op: string; Query: IQuery)
      : IQuery; overload;
    /// <summary>Appends a column comparison with a scalar subquery to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function HavingNot(const Column, Op: string; const Callback: TQueryCallback)
      : IQuery; overload;
    /// <summary>Appends an IS NULL test to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingNotNull(const Column: string): IQuery;
    /// <summary>Appends an inclusive BETWEEN test to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Lower">Inclusive lower bound.</param>
    /// <param name="Higher">Inclusive upper bound.</param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingNotBetween(const Column: string;
      const Lower, Higher: TValue): IQuery;
    /// <summary>Appends an IN test against a value list to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Values">Values copied and deduplicated using supported, type-sensitive equality.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>An empty list compiles to true for NOT IN.</remarks>
    function HavingNotIn(const Column: string; const Values: array of TValue)
      : IQuery; overload;
    /// <summary>Appends an IN test against a subquery to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingNotIn(const Column: string; Query: IQuery): IQuery; overload;
    /// <summary>Appends an IN test against a subquery to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function HavingNotIn(const Column: string; const Callback: TQueryCallback)
      : IQuery; overload;
    /// <summary>Appends an EXISTS test to HAVING and negates it.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <exception cref="EQueryException">The subquery is nil or has no FROM clause.</exception>
    function HavingNotExists(Query: IQuery): IQuery; overload;
    /// <summary>Appends an EXISTS test to HAVING and negates it.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <exception cref="EQueryException">
    /// The subquery is nil or has no FROM clause. Callback returns a different query or nil.
    /// </exception>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    function HavingNotExists(const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Appends a LIKE pattern comparison to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingNotLike(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a LIKE comparison with a trailing % wildcard to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingNotStarts(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a LIKE comparison with a leading % wildcard to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingNotEnds(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>
    /// Appends a LIKE comparison with leading and trailing % wildcards to HAVING and negates it.
    /// </summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingNotContains(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a comparison of the date portion of a column to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingNotDate(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the date portion of a column to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Uses equality (=).</remarks>
    function HavingNotDate(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the time portion of a column to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingNotTime(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the time portion of a column to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Uses equality (=).</remarks>
    function HavingNotTime(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of a date part of a column to HAVING and negates it.</summary>
    /// <param name="Part">
    /// Date part name containing ASCII letters or underscores; supported names depend on the compiler.
    /// </param>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingNotDatePart(const Part, Column, Op: string;
      const Value: TValue): IQuery; overload;
    /// <summary>Appends a comparison of a date part of a column to HAVING and negates it.</summary>
    /// <param name="Part">
    /// Date part name containing ASCII letters or underscores; supported names depend on the compiler.
    /// </param>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Uses equality (=).</remarks>
    function HavingNotDatePart(const Part, Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a trusted SQL predicate to HAVING.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <param name="Bindings">
    /// Placeholder values in order. Arrays expand into parameter lists, except TBytes.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Never interpolate untrusted input into Sql. A literal question mark can be marked as \?; the escape
    /// remains in executable SQL. Pending Not does not negate raw predicates; include any required NOT in
    /// Sql.
    /// </remarks>
    function HavingRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    /// <summary>Appends a trusted SQL predicate to HAVING.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Supplies no bindings; unescaped value placeholders require the overload with Bindings. Never
    /// interpolate untrusted input into Sql. A literal question mark can be marked as \?; the escape remains
    /// in executable SQL. Pending Not does not negate raw predicates; include any required NOT in Sql.
    /// </remarks>
    function HavingRaw(const Sql: string): IQuery; overload;
    /// <summary>Appends a comparison between two columns to HAVING.</summary>
    /// <param name="First">Left column name.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Second">Right column name, quoted as an identifier rather than bound as a value.</param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingColumns(const First, Op, Second: string): IQuery;
    /// <summary>Appends a scalar subquery on the left of a value comparison to HAVING.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    function HavingSub(Query: IQuery; const Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a scalar subquery on the left of a value comparison to HAVING.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Uses equality (=).</remarks>
    function HavingSub(Query: IQuery; const Value: TValue): IQuery; overload;
    /// <summary>Appends a column/value comparison to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Joins this predicate with OR. Direct SQL NULL values compile to IS NULL for equality, or IS NOT NULL
    /// for other operators or negation. Boolean values use dialect literals.
    /// </remarks>
    function OrHaving(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a column/value comparison to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Joins this predicate with OR. Uses equality (=). Direct SQL NULL values compile to IS NULL for
    /// equality, or IS NOT NULL for other operators or negation. Boolean values use dialect literals.
    /// </remarks>
    function OrHaving(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a parenthesized predicate group to HAVING.</summary>
    /// <param name="Group">Non-nil query whose predicates are cloned into the group.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses WHERE predicates when present, otherwise HAVING predicates; empty groups are omitted. Joins this
    /// predicate with OR.
    /// </remarks>
    function OrHaving(Group: IQuery): IQuery; overload;
    /// <summary>Appends a parenthesized predicate group to HAVING.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses WHERE predicates when present, otherwise HAVING predicates; empty groups are omitted. Joins this
    /// predicate with OR.
    /// </remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function OrHaving(const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Appends a column comparison with a scalar subquery to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHaving(const Column, Op: string; Query: IQuery): IQuery;
      overload;
    /// <summary>Appends a column comparison with a scalar subquery to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function OrHaving(const Column, Op: string; const Callback: TQueryCallback)
      : IQuery; overload;
    /// <summary>Appends an IS NULL test to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingNull(const Column: string): IQuery;
    /// <summary>Appends a test for the dialect true literal to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingTrue(const Column: string): IQuery;
    /// <summary>Appends a test for the dialect false literal to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingFalse(const Column: string): IQuery;
    /// <summary>Appends an inclusive BETWEEN test to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Lower">Inclusive lower bound.</param>
    /// <param name="Higher">Inclusive upper bound.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingBetween(const Column: string;
      const Lower, Higher: TValue): IQuery;
    /// <summary>Appends an IN test against a value list to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Values">Values copied and deduplicated using supported, type-sensitive equality.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR. An empty list compiles to false for IN.</remarks>
    function OrHavingIn(const Column: string; const Values: array of TValue)
      : IQuery; overload;
    /// <summary>Appends an IN test against a subquery to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingIn(const Column: string; Query: IQuery): IQuery; overload;
    /// <summary>Appends an IN test against a subquery to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function OrHavingIn(const Column: string; const Callback: TQueryCallback)
      : IQuery; overload;
    /// <summary>Appends an EXISTS test to HAVING.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    /// <exception cref="EQueryException">The subquery is nil or has no FROM clause.</exception>
    function OrHavingExists(Query: IQuery): IQuery; overload;
    /// <summary>Appends an EXISTS test to HAVING.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    /// <exception cref="EQueryException">
    /// The subquery is nil or has no FROM clause. Callback returns a different query or nil.
    /// </exception>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    function OrHavingExists(const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Appends a LIKE pattern comparison to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingLike(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a LIKE comparison with a trailing % wildcard to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingStarts(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a LIKE comparison with a leading % wildcard to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingEnds(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a LIKE comparison with leading and trailing % wildcards to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingContains(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a comparison of the date portion of a column to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingDate(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the date portion of a column to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR. Uses equality (=).</remarks>
    function OrHavingDate(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the time portion of a column to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingTime(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the time portion of a column to HAVING.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR. Uses equality (=).</remarks>
    function OrHavingTime(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of a date part of a column to HAVING.</summary>
    /// <param name="Part">
    /// Date part name containing ASCII letters or underscores; supported names depend on the compiler.
    /// </param>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingDatePart(const Part, Column, Op: string;
      const Value: TValue): IQuery; overload;
    /// <summary>Appends a comparison of a date part of a column to HAVING.</summary>
    /// <param name="Part">
    /// Date part name containing ASCII letters or underscores; supported names depend on the compiler.
    /// </param>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR. Uses equality (=).</remarks>
    function OrHavingDatePart(const Part, Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a column/value comparison to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Joins this predicate with OR. Direct SQL NULL values compile to IS NULL for equality, or IS NOT NULL
    /// for other operators or negation. Boolean values use dialect literals.
    /// </remarks>
    function OrHavingNot(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a column/value comparison to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Joins this predicate with OR. Uses equality (=). Direct SQL NULL values compile to IS NULL for
    /// equality, or IS NOT NULL for other operators or negation. Boolean values use dialect literals.
    /// </remarks>
    function OrHavingNot(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a parenthesized predicate group to HAVING and negates it.</summary>
    /// <param name="Group">Non-nil query whose predicates are cloned into the group.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses WHERE predicates when present, otherwise HAVING predicates; empty groups are omitted. Joins this
    /// predicate with OR.
    /// </remarks>
    function OrHavingNot(Group: IQuery): IQuery; overload;
    /// <summary>Appends a parenthesized predicate group to HAVING and negates it.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Uses WHERE predicates when present, otherwise HAVING predicates; empty groups are omitted. Joins this
    /// predicate with OR.
    /// </remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function OrHavingNot(const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Appends a column comparison with a scalar subquery to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingNot(const Column, Op: string; Query: IQuery)
      : IQuery; overload;
    /// <summary>Appends a column comparison with a scalar subquery to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function OrHavingNot(const Column, Op: string;
      const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Appends an IS NULL test to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingNotNull(const Column: string): IQuery;
    /// <summary>Appends an inclusive BETWEEN test to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Lower">Inclusive lower bound.</param>
    /// <param name="Higher">Inclusive upper bound.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingNotBetween(const Column: string;
      const Lower, Higher: TValue): IQuery;
    /// <summary>Appends an IN test against a value list to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Values">Values copied and deduplicated using supported, type-sensitive equality.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR. An empty list compiles to true for NOT IN.</remarks>
    function OrHavingNotIn(const Column: string; const Values: array of TValue)
      : IQuery; overload;
    /// <summary>Appends an IN test against a subquery to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingNotIn(const Column: string; Query: IQuery)
      : IQuery; overload;
    /// <summary>Appends an IN test against a subquery to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function OrHavingNotIn(const Column: string; const Callback: TQueryCallback)
      : IQuery; overload;
    /// <summary>Appends an EXISTS test to HAVING and negates it.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    /// <exception cref="EQueryException">The subquery is nil or has no FROM clause.</exception>
    function OrHavingNotExists(Query: IQuery): IQuery; overload;
    /// <summary>Appends an EXISTS test to HAVING and negates it.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    /// <exception cref="EQueryException">
    /// The subquery is nil or has no FROM clause. Callback returns a different query or nil.
    /// </exception>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    function OrHavingNotExists(const Callback: TQueryCallback): IQuery;
      overload;
    /// <summary>Appends a LIKE pattern comparison to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingNotLike(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a LIKE comparison with a trailing % wildcard to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingNotStarts(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a LIKE comparison with a leading % wildcard to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingNotEnds(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>
    /// Appends a LIKE comparison with leading and trailing % wildcards to HAVING and negates it.
    /// </summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.
    /// </param>
    /// <param name="EscapeCharacter">
    /// Optional SQL LIKE escape text; Value is not escaped automatically.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingNotContains(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    /// <summary>Appends a comparison of the date portion of a column to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingNotDate(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the date portion of a column to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR. Uses equality (=).</remarks>
    function OrHavingNotDate(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the time portion of a column to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingNotTime(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of the time portion of a column to HAVING and negates it.</summary>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR. Uses equality (=).</remarks>
    function OrHavingNotTime(const Column: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a comparison of a date part of a column to HAVING and negates it.</summary>
    /// <param name="Part">
    /// Date part name containing ASCII letters or underscores; supported names depend on the compiler.
    /// </param>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingNotDatePart(const Part, Column, Op: string;
      const Value: TValue): IQuery; overload;
    /// <summary>Appends a comparison of a date part of a column to HAVING and negates it.</summary>
    /// <param name="Part">
    /// Date part name containing ASCII letters or underscores; supported names depend on the compiler.
    /// </param>
    /// <param name="Column">Column name, optionally qualified by a table.</param>
    /// <param name="Value">
    /// Comparison value, bound as supplied; no date/time conversion is performed by this method.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR. Uses equality (=).</remarks>
    function OrHavingNotDatePart(const Part, Column: string;
      const Value: TValue): IQuery; overload;
    /// <summary>Appends a trusted SQL predicate to HAVING.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <param name="Bindings">
    /// Placeholder values in order. Arrays expand into parameter lists, except TBytes.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Joins this predicate with OR. Never interpolate untrusted input into Sql. A literal question mark can
    /// be marked as \?; the escape remains in executable SQL. Pending Not does not negate raw predicates;
    /// include any required NOT in Sql.
    /// </remarks>
    function OrHavingRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    /// <summary>Appends a trusted SQL predicate to HAVING.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Joins this predicate with OR. Supplies no bindings; unescaped value placeholders require the overload
    /// with Bindings. Never interpolate untrusted input into Sql. A literal question mark can be marked as
    /// \?; the escape remains in executable SQL. Pending Not does not negate raw predicates; include any
    /// required NOT in Sql.
    /// </remarks>
    function OrHavingRaw(const Sql: string): IQuery; overload;
    /// <summary>Appends a comparison between two columns to HAVING.</summary>
    /// <param name="First">Left column name.</param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Second">Right column name, quoted as an identifier rather than bound as a value.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingColumns(const First, Op, Second: string): IQuery;
    /// <summary>Appends a scalar subquery on the left of a value comparison to HAVING.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <param name="Op">Comparison operator accepted by the selected compiler.</param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR.</remarks>
    function OrHavingSub(Query: IQuery; const Op: string; const Value: TValue)
      : IQuery; overload;
    /// <summary>Appends a scalar subquery on the left of a value comparison to HAVING.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <param name="Value">Comparison value, normally bound as a SQL parameter.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>Joins this predicate with OR. Uses equality (=).</remarks>
    function OrHavingSub(Query: IQuery; const Value: TValue): IQuery; overload;
    /// <summary>Appends selected columns and switches to SELECT.</summary>
    /// <param name="Columns">Columns to select, in output order; an explicit AS alias is accepted.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// QueryBuilder4Delphi expands 'Books.{Id, Title}' into 'Books.Id' and 'Books.Title'. This is library
    /// shorthand, not SQL syntax.
    /// </remarks>
    function Select(const Columns: array of string): IQuery; overload;
    /// <summary>Appends selected columns and switches to SELECT.</summary>
    /// <param name="Column">Column to select, in output order; an explicit AS alias is accepted.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// QueryBuilder4Delphi expands 'Books.{Id, Title}' into 'Books.Id' and 'Books.Title'. This is library
    /// shorthand, not SQL syntax.
    /// </remarks>
    function Select(const Column: string): IQuery; overload;
    /// <summary>Appends grouping columns.</summary>
    /// <param name="Columns">Columns used to group rows.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// QueryBuilder4Delphi expands 'Books.{Id, Title}' into 'Books.Id' and 'Books.Title'. This is library
    /// shorthand, not SQL syntax.
    /// </remarks>
    function GroupBy(const Columns: array of string): IQuery; overload;
    /// <summary>Appends grouping columns.</summary>
    /// <param name="Column">Column used to group rows.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// QueryBuilder4Delphi expands 'Books.{Id, Title}' into 'Books.Id' and 'Books.Title'. This is library
    /// shorthand, not SQL syntax.
    /// </remarks>
    function GroupBy(const Column: string): IQuery; overload;
    /// <summary>Appends ascending sort columns.</summary>
    /// <param name="Columns">Sort columns, in priority order.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// QueryBuilder4Delphi expands 'Books.{Id, Title}' into 'Books.Id' and 'Books.Title'. This is library
    /// shorthand, not SQL syntax.
    /// </remarks>
    function OrderBy(const Columns: array of string): IQuery; overload;
    /// <summary>Appends ascending sort columns.</summary>
    /// <param name="Column">Sort column, in priority order.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// QueryBuilder4Delphi expands 'Books.{Id, Title}' into 'Books.Id' and 'Books.Title'. This is library
    /// shorthand, not SQL syntax.
    /// </remarks>
    function OrderBy(const Column: string): IQuery; overload;
    /// <summary>Appends descending sort columns.</summary>
    /// <param name="Columns">Sort columns, in priority order.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// QueryBuilder4Delphi expands 'Books.{Id, Title}' into 'Books.Id' and 'Books.Title'. This is library
    /// shorthand, not SQL syntax.
    /// </remarks>
    function OrderByDesc(const Columns: array of string): IQuery; overload;
    /// <summary>Appends descending sort columns.</summary>
    /// <param name="Column">Sort column, in priority order.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// QueryBuilder4Delphi expands 'Books.{Id, Title}' into 'Books.Id' and 'Books.Title'. This is library
    /// shorthand, not SQL syntax.
    /// </remarks>
    function OrderByDesc(const Column: string): IQuery; overload;
    /// <summary>Appends a trusted SQL select expression and switches to SELECT.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <param name="Bindings">
    /// Placeholder values in order. Arrays expand into parameter lists, except TBytes.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Never interpolate untrusted input into Sql. A literal question mark can be marked as \?; the escape
    /// remains in executable SQL.
    /// </remarks>
    function SelectRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    /// <summary>Appends a trusted SQL select expression and switches to SELECT.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Supplies no bindings; unescaped value placeholders require the overload with Bindings. Never
    /// interpolate untrusted input into Sql. A literal question mark can be marked as \?; the escape remains
    /// in executable SQL.
    /// </remarks>
    function SelectRaw(const Sql: string): IQuery; overload;
    /// <summary>Replaces the FROM clause in the current engine scope with trusted SQL.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <param name="Bindings">
    /// Placeholder values in order. Arrays expand into parameter lists, except TBytes.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Never interpolate untrusted input into Sql. A literal question mark can be marked as \?; the escape
    /// remains in executable SQL.
    /// </remarks>
    function FromRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    /// <summary>Replaces the FROM clause in the current engine scope with trusted SQL.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Supplies no bindings; unescaped value placeholders require the overload with Bindings. Never
    /// interpolate untrusted input into Sql. A literal question mark can be marked as \?; the escape remains
    /// in executable SQL.
    /// </remarks>
    function FromRaw(const Sql: string): IQuery; overload;
    /// <summary>Appends a trusted SQL ordering expression.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <param name="Bindings">
    /// Placeholder values in order. Arrays expand into parameter lists, except TBytes.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Never interpolate untrusted input into Sql. A literal question mark can be marked as \?; the escape
    /// remains in executable SQL.
    /// </remarks>
    function OrderByRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    /// <summary>Appends a trusted SQL ordering expression.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Supplies no bindings; unescaped value placeholders require the overload with Bindings. Never
    /// interpolate untrusted input into Sql. A literal question mark can be marked as \?; the escape remains
    /// in executable SQL.
    /// </remarks>
    function OrderByRaw(const Sql: string): IQuery; overload;
    /// <summary>Appends a trusted SQL grouping expression.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <param name="Bindings">
    /// Placeholder values in order. Arrays expand into parameter lists, except TBytes.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Never interpolate untrusted input into Sql. A literal question mark can be marked as \?; the escape
    /// remains in executable SQL.
    /// </remarks>
    function GroupByRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    /// <summary>Appends a trusted SQL grouping expression.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Supplies no bindings; unescaped value placeholders require the overload with Bindings. Never
    /// interpolate untrusted input into Sql. A literal question mark can be marked as \?; the escape remains
    /// in executable SQL.
    /// </remarks>
    function GroupByRaw(const Sql: string): IQuery; overload;
    /// <summary>Appends a complete SQL set-operation fragment, including its keyword.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <param name="Bindings">
    /// Placeholder values in order. Arrays expand into parameter lists, except TBytes.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Supply the complete fragment, for example UNION SELECT ...; the method adds no operation keyword.
    /// Never interpolate untrusted input into Sql. A literal question mark can be marked as \?; the escape
    /// remains in executable SQL.
    /// </remarks>
    /// <exception cref="EQueryException">This query is not a SELECT query.</exception>
    function CombineRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    /// <summary>Appends a complete SQL set-operation fragment, including its keyword.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Supply the complete fragment, for example UNION SELECT ...; the method adds no operation keyword.
    /// Supplies no bindings; unescaped value placeholders require the overload with Bindings. Never
    /// interpolate untrusted input into Sql. A literal question mark can be marked as \?; the escape remains
    /// in executable SQL.
    /// </remarks>
    /// <exception cref="EQueryException">This query is not a SELECT query.</exception>
    function CombineRaw(const Sql: string): IQuery; overload;
    /// <summary>Appends a complete SQL set-operation fragment, including its keyword.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <param name="Bindings">
    /// Placeholder values in order. Arrays expand into parameter lists, except TBytes.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Supply the complete fragment, for example UNION SELECT ...; the method adds no operation keyword.
    /// Never interpolate untrusted input into Sql. A literal question mark can be marked as \?; the escape
    /// remains in executable SQL.
    /// </remarks>
    /// <exception cref="EQueryException">This query is not a SELECT query.</exception>
    function UnionRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    /// <summary>Appends a complete SQL set-operation fragment, including its keyword.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Supply the complete fragment, for example UNION SELECT ...; the method adds no operation keyword.
    /// Supplies no bindings; unescaped value placeholders require the overload with Bindings. Never
    /// interpolate untrusted input into Sql. A literal question mark can be marked as \?; the escape remains
    /// in executable SQL.
    /// </remarks>
    /// <exception cref="EQueryException">This query is not a SELECT query.</exception>
    function UnionRaw(const Sql: string): IQuery; overload;
    /// <summary>Appends a complete SQL set-operation fragment, including its keyword.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <param name="Bindings">
    /// Placeholder values in order. Arrays expand into parameter lists, except TBytes.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Supply the complete fragment, for example EXCEPT SELECT ...; the method adds no operation keyword.
    /// Never interpolate untrusted input into Sql. A literal question mark can be marked as \?; the escape
    /// remains in executable SQL.
    /// </remarks>
    /// <exception cref="EQueryException">This query is not a SELECT query.</exception>
    function ExceptRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    /// <summary>Appends a complete SQL set-operation fragment, including its keyword.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Supply the complete fragment, for example EXCEPT SELECT ...; the method adds no operation keyword.
    /// Supplies no bindings; unescaped value placeholders require the overload with Bindings. Never
    /// interpolate untrusted input into Sql. A literal question mark can be marked as \?; the escape remains
    /// in executable SQL.
    /// </remarks>
    /// <exception cref="EQueryException">This query is not a SELECT query.</exception>
    function ExceptRaw(const Sql: string): IQuery; overload;
    /// <summary>Appends a complete SQL set-operation fragment, including its keyword.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <param name="Bindings">
    /// Placeholder values in order. Arrays expand into parameter lists, except TBytes.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Supply the complete fragment, for example INTERSECT SELECT ...; the method adds no operation keyword.
    /// Never interpolate untrusted input into Sql. A literal question mark can be marked as \?; the escape
    /// remains in executable SQL.
    /// </remarks>
    /// <exception cref="EQueryException">This query is not a SELECT query.</exception>
    function IntersectRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    /// <summary>Appends a complete SQL set-operation fragment, including its keyword.</summary>
    /// <param name="Sql">
    /// Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; {identifier} and
    /// [identifier] request dialect quoting.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Supply the complete fragment, for example INTERSECT SELECT ...; the method adds no operation keyword.
    /// Supplies no bindings; unescaped value placeholders require the overload with Bindings. Never
    /// interpolate untrusted input into Sql. A literal question mark can be marked as \?; the escape remains
    /// in executable SQL.
    /// </remarks>
    /// <exception cref="EQueryException">This query is not a SELECT query.</exception>
    function IntersectRaw(const Sql: string): IQuery; overload;
    /// <summary>Switches to a standalone COUNT aggregate.</summary>
    /// <param name="Columns">
    /// Counted column names, stored as supplied; an empty array selects COUNT(*).
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Compilation removes LIMIT, ORDER BY and GROUP BY from a clone, retaining OFFSET. Only the DISTINCT
    /// rewrite expands column shorthand through Select.
    /// </remarks>
    function AsCount(const Columns: array of string): IQuery; overload;
    /// <summary>Switches to a standalone COUNT(*).</summary>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Compilation removes LIMIT, ORDER BY and GROUP BY from a clone, retaining OFFSET. Only the DISTINCT
    /// rewrite expands column shorthand through Select.
    /// </remarks>
    function AsCount(): IQuery; overload;
    /// <summary>Switches to a standalone SUM aggregate.</summary>
    /// <param name="Column">Aggregated column name, stored as supplied.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Compilation removes LIMIT, ORDER BY and GROUP BY from a clone, retaining OFFSET. Only the DISTINCT
    /// rewrite expands column shorthand through Select.
    /// </remarks>
    function AsSum(const Column: string): IQuery;
    /// <summary>Switches to a standalone AVG aggregate.</summary>
    /// <param name="Column">Aggregated column name, stored as supplied.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Compilation removes LIMIT, ORDER BY and GROUP BY from a clone, retaining OFFSET. Only the DISTINCT
    /// rewrite expands column shorthand through Select.
    /// </remarks>
    function AsAvg(const Column: string): IQuery;
    /// <summary>Switches to a standalone AVG aggregate.</summary>
    /// <param name="Column">Aggregated column name, stored as supplied.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Compilation removes LIMIT, ORDER BY and GROUP BY from a clone, retaining OFFSET. Only the DISTINCT
    /// rewrite expands column shorthand through Select.
    /// </remarks>
    function AsAverage(const Column: string): IQuery;
    /// <summary>Switches to a standalone MIN aggregate.</summary>
    /// <param name="Column">Aggregated column name, stored as supplied.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Compilation removes LIMIT, ORDER BY and GROUP BY from a clone, retaining OFFSET. Only the DISTINCT
    /// rewrite expands column shorthand through Select.
    /// </remarks>
    function AsMin(const Column: string): IQuery;
    /// <summary>Switches to a standalone MAX aggregate.</summary>
    /// <param name="Column">Aggregated column name, stored as supplied.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Compilation removes LIMIT, ORDER BY and GROUP BY from a clone, retaining OFFSET. Only the DISTINCT
    /// rewrite expands column shorthand through Select.
    /// </remarks>
    function AsMax(const Column: string): IQuery;
    /// <summary>Appends a SUM select expression and switches to SELECT.</summary>
    /// <param name="Column">
    /// Aggregated column name; accepts an explicit AS alias. Column shorthand is not expanded.
    /// </param>
    /// <param name="Filter">
    /// Optional callback configuring a new query whose WHERE predicates filter this aggregate; must return
    /// that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// The filter runs immediately when assigned. Compilation uses FILTER where supported, otherwise CASE;
    /// support depends on the database.
    /// </remarks>
    /// <exception cref="EQueryException">Filter returns a different query or nil.</exception>
    function SelectSum(const Column: string;
      const Filter: TQueryCallback = nil): IQuery;
    /// <summary>Appends a COUNT select expression and switches to SELECT.</summary>
    /// <param name="Column">
    /// Aggregated column name; accepts an explicit AS alias. Column shorthand is not expanded.
    /// </param>
    /// <param name="Filter">
    /// Optional callback configuring a new query whose WHERE predicates filter this aggregate; must return
    /// that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// The filter runs immediately when assigned. Compilation uses FILTER where supported, otherwise CASE;
    /// support depends on the database.
    /// </remarks>
    /// <exception cref="EQueryException">Filter returns a different query or nil.</exception>
    function SelectCount(const Column: string;
      const Filter: TQueryCallback = nil): IQuery;
    /// <summary>Appends a AVG select expression and switches to SELECT.</summary>
    /// <param name="Column">
    /// Aggregated column name; accepts an explicit AS alias. Column shorthand is not expanded.
    /// </param>
    /// <param name="Filter">
    /// Optional callback configuring a new query whose WHERE predicates filter this aggregate; must return
    /// that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// The filter runs immediately when assigned. Compilation uses FILTER where supported, otherwise CASE;
    /// support depends on the database.
    /// </remarks>
    /// <exception cref="EQueryException">Filter returns a different query or nil.</exception>
    function SelectAvg(const Column: string;
      const Filter: TQueryCallback = nil): IQuery;
    /// <summary>Appends a MIN select expression and switches to SELECT.</summary>
    /// <param name="Column">
    /// Aggregated column name; accepts an explicit AS alias. Column shorthand is not expanded.
    /// </param>
    /// <param name="Filter">
    /// Optional callback configuring a new query whose WHERE predicates filter this aggregate; must return
    /// that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// The filter runs immediately when assigned. Compilation uses FILTER where supported, otherwise CASE;
    /// support depends on the database.
    /// </remarks>
    /// <exception cref="EQueryException">Filter returns a different query or nil.</exception>
    function SelectMin(const Column: string;
      const Filter: TQueryCallback = nil): IQuery;
    /// <summary>Appends a MAX select expression and switches to SELECT.</summary>
    /// <param name="Column">
    /// Aggregated column name; accepts an explicit AS alias. Column shorthand is not expanded.
    /// </param>
    /// <param name="Filter">
    /// Optional callback configuring a new query whose WHERE predicates filter this aggregate; must return
    /// that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// The filter runs immediately when assigned. Compilation uses FILTER where supported, otherwise CASE;
    /// support depends on the database.
    /// </remarks>
    /// <exception cref="EQueryException">Filter returns a different query or nil.</exception>
    function SelectMax(const Column: string;
      const Filter: TQueryCallback = nil): IQuery;
    /// <summary>Appends a cloned SELECT using UNION.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <param name="All">True to request the ALL form; False requests the distinct form.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Both queries must be SELECT queries. Operation and ALL support depend on the database.
    /// </remarks>
    /// <exception cref="EQueryException">Either query is not a SELECT query.</exception>
    function Union(Query: IQuery; All: Boolean = False): IQuery; overload;
    /// <summary>Appends a cloned SELECT using UNION.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <param name="All">True to request the ALL form; False requests the distinct form.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Both queries must be SELECT queries. Operation and ALL support depend on the database.
    /// </remarks>
    /// <exception cref="EQueryException">
    /// Either query is not a SELECT query. Callback returns a different query or nil.
    /// </exception>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    function Union(const Callback: TQueryCallback; All: Boolean = False)
      : IQuery; overload;
    /// <summary>Appends a cloned SELECT using UNION ALL.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Both queries must be SELECT queries. Operation and ALL support depend on the database.
    /// </remarks>
    /// <exception cref="EQueryException">Either query is not a SELECT query.</exception>
    function UnionAll(Query: IQuery): IQuery; overload;
    /// <summary>Appends a cloned SELECT using UNION ALL.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Both queries must be SELECT queries. Operation and ALL support depend on the database.
    /// </remarks>
    /// <exception cref="EQueryException">
    /// Either query is not a SELECT query. Callback returns a different query or nil.
    /// </exception>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    function UnionAll(const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Appends a cloned SELECT using EXCEPT.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <param name="All">True to request the ALL form; False requests the distinct form.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Both queries must be SELECT queries. Operation and ALL support depend on the database.
    /// </remarks>
    /// <exception cref="EQueryException">Either query is not a SELECT query.</exception>
    function &Except(Query: IQuery; All: Boolean = False): IQuery; overload;
    /// <summary>Appends a cloned SELECT using EXCEPT.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <param name="All">True to request the ALL form; False requests the distinct form.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Both queries must be SELECT queries. Operation and ALL support depend on the database.
    /// </remarks>
    /// <exception cref="EQueryException">
    /// Either query is not a SELECT query. Callback returns a different query or nil.
    /// </exception>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    function &Except(const Callback: TQueryCallback; All: Boolean = False)
      : IQuery; overload;
    /// <summary>Appends a cloned SELECT using EXCEPT ALL.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Both queries must be SELECT queries. Operation and ALL support depend on the database.
    /// </remarks>
    /// <exception cref="EQueryException">Either query is not a SELECT query.</exception>
    function ExceptAll(Query: IQuery): IQuery; overload;
    /// <summary>Appends a cloned SELECT using EXCEPT ALL.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Both queries must be SELECT queries. Operation and ALL support depend on the database.
    /// </remarks>
    /// <exception cref="EQueryException">
    /// Either query is not a SELECT query. Callback returns a different query or nil.
    /// </exception>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    function ExceptAll(const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Appends a cloned SELECT using INTERSECT.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <param name="All">True to request the ALL form; False requests the distinct form.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Both queries must be SELECT queries. Operation and ALL support depend on the database.
    /// </remarks>
    /// <exception cref="EQueryException">Either query is not a SELECT query.</exception>
    function Intersect(Query: IQuery; All: Boolean = False): IQuery; overload;
    /// <summary>Appends a cloned SELECT using INTERSECT.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <param name="All">True to request the ALL form; False requests the distinct form.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Both queries must be SELECT queries. Operation and ALL support depend on the database.
    /// </remarks>
    /// <exception cref="EQueryException">
    /// Either query is not a SELECT query. Callback returns a different query or nil.
    /// </exception>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    function Intersect(const Callback: TQueryCallback; All: Boolean = False)
      : IQuery; overload;
    /// <summary>Appends a cloned SELECT using INTERSECT ALL.</summary>
    /// <param name="Query">
    /// Non-nil query to clone; later changes to the source do not affect this clause.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Both queries must be SELECT queries. Operation and ALL support depend on the database.
    /// </remarks>
    /// <exception cref="EQueryException">Either query is not a SELECT query.</exception>
    function IntersectAll(Query: IQuery): IQuery; overload;
    /// <summary>Appends a cloned SELECT using INTERSECT ALL.</summary>
    /// <param name="Callback">
    /// Called immediately with a new query in the current engine scope; must return that query.
    /// </param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Both queries must be SELECT queries. Operation and ALL support depend on the database.
    /// </remarks>
    /// <exception cref="EQueryException">
    /// Either query is not a SELECT query. Callback returns a different query or nil.
    /// </exception>
    /// <exception cref="EArgumentNilException">Callback is not assigned.</exception>
    function IntersectAll(const Callback: TQueryCallback): IQuery; overload;
    /// <summary>Invokes the callback on this query with clauses scoped to SqlServer.</summary>
    /// <param name="Callback">Required callback receiving this query; must return the same instance.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Always runs immediately; compilation selects the engine-specific clauses. The previous scope is
    /// restored even on failure. Shared state such as Method is not engine-scoped.
    /// </remarks>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function ForSqlServer(const Callback: TQueryCallback): IQuery;
    /// <summary>Invokes the callback on this query with clauses scoped to PostgreSql.</summary>
    /// <param name="Callback">Required callback receiving this query; must return the same instance.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Always runs immediately; compilation selects the engine-specific clauses. The previous scope is
    /// restored even on failure. Shared state such as Method is not engine-scoped.
    /// </remarks>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function ForPostgreSql(const Callback: TQueryCallback): IQuery;
    /// <summary>Invokes the callback on this query with clauses scoped to MySql.</summary>
    /// <param name="Callback">Required callback receiving this query; must return the same instance.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Always runs immediately; compilation selects the engine-specific clauses. The previous scope is
    /// restored even on failure. Shared state such as Method is not engine-scoped.
    /// </remarks>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function ForMySql(const Callback: TQueryCallback): IQuery;
    /// <summary>Invokes the callback on this query with clauses scoped to Sqlite.</summary>
    /// <param name="Callback">Required callback receiving this query; must return the same instance.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Always runs immediately; compilation selects the engine-specific clauses. The previous scope is
    /// restored even on failure. Shared state such as Method is not engine-scoped.
    /// </remarks>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function ForSqlite(const Callback: TQueryCallback): IQuery;
    /// <summary>Invokes the callback on this query with clauses scoped to Oracle.</summary>
    /// <param name="Callback">Required callback receiving this query; must return the same instance.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Always runs immediately; compilation selects the engine-specific clauses. The previous scope is
    /// restored even on failure. Shared state such as Method is not engine-scoped.
    /// </remarks>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function ForOracle(const Callback: TQueryCallback): IQuery;
    /// <summary>Invokes the callback on this query with clauses scoped to Firebird.</summary>
    /// <param name="Callback">Required callback receiving this query; must return the same instance.</param>
    /// <returns>This query instance, modified in place.</returns>
    /// <remarks>
    /// Always runs immediately; compilation selects the engine-specific clauses. The previous scope is
    /// restored even on failure. Shared state such as Method is not engine-scoped.
    /// </remarks>
    /// <exception cref="EQueryException">Callback returns a different query or nil.</exception>
    function ForFirebird(const Callback: TQueryCallback): IQuery;
    // END GENERATED: fluent declarations
    /// <summary>
    /// Engine code assigned to newly added clauses; empty means shared clauses. Scope changes do not scope
    /// shared state such as Method or variables.
    /// </summary>
    property EngineScope: string read GetEngineScope write PutEngineScope;
    /// <summary>Alias used when this query is embedded as a subquery or CTE.</summary>
    property QueryAlias: string read GetQueryAlias write SetQueryAlias;
    /// <summary>
    /// Statement kind used by compilation and automatic execution: select, aggregate, insert, update, or
    /// delete.
    /// </summary>
    property Method: string read GetMethod write SetMethod;
    /// <summary>
    /// SQL join keyword text for this query when used as a join model. The compiler emits it as stored.
    /// </summary>
    property JoinType: string read GetJoinType write SetJoinType;
    /// <summary>Whether SELECT and aggregate compilation should apply DISTINCT semantics.</summary>
    property IsDistinct: Boolean read GetIsDistinct write SetIsDistinct;
    /// <summary>
    /// Borrowed mutable owning clause list. The query frees the list and its nodes; do not free or retain
    /// nodes beyond the query lifetime.
    /// </summary>
    property Clauses: TObjectList<TClause> read GetClauses;
    /// <summary>
    /// Borrowed mutable name/value dictionary owned by the query. Values are resolved during compilation;
    /// referenced objects remain application-owned.
    /// </summary>
    property Variables: TDictionary<string, TValue> read GetVariables;
  end;

  /// <summary>
  /// Boxes a typed open array into TValue bindings without taking ownership of referenced objects.
  /// </summary>
  TSqlValues = record
    /// <summary>Boxes a typed array into individual TValue bindings.</summary>
    /// <param name="Values">Typed elements to box individually as TValue.From&lt;T&gt;.</param>
    /// <returns>
    /// A new array preserving order and RTTI type T for each element; referenced objects remain caller-owned.
    /// </returns>
    class function &Of<T>(const Values: array of T): TValues; static;
  end;

/// <summary>Copies an open array into a managed TValue array.</summary>
/// <param name="Values">Input elements in source order; referenced objects are not owned.</param>
/// <returns>A new array with copied values; object references remain non-owning and shared.</returns>
function CopyValues(const Values: array of TValue): TValues;
/// <summary>Copies an open string array into a managed array.</summary>
/// <param name="Values">Input elements in source order; referenced objects are not owned.</param>
/// <returns>A new array containing the supplied strings in order.</returns>
function CopyStrings(const Values: array of string): TArray<string>;
/// <summary>
/// Expands library column shorthand such as &#x27;Books.{Id, Title}&#x27; into &#x27;Books.Id&#x27; and
/// &#x27;Books.Title&#x27;.
/// </summary>
/// <param name="Expression">Column expression to expand; this shorthand is not native SQL syntax.</param>
/// <returns>
/// Expanded identifiers, or the original expression as a single element when shorthand does not match.
/// </returns>
/// <remarks>
/// Used by Select, GroupBy, OrderBy and OrderByDesc. Matches the first .{ only when the final character is };
/// trailing whitespace prevents a match. Splits members on commas, trims each member and prepends the
/// unchanged prefix including its dot. Does not validate identifiers or parse nested braces.
/// </remarks>
function ExpandExpression(const Expression: string): TArray<string>;
/// <summary>Removes duplicates using the library type-sensitive equality rules.</summary>
/// <param name="Values">Input elements in source order; referenced objects are not owned.</param>
/// <returns>
/// Values in first-occurrence order; unsupported equality kinds such as records are not deduplicated.
/// </returns>
/// <remarks>
/// Requires matching TValue type identity; compares numeric, string, Variant and object-reference values.
/// This is not SQL collation or NULL equality.
/// </remarks>
function DistinctValues(const Values: array of TValue): TValues;

implementation

uses
  System.Variants;

constructor TQueryResult.Create(const AResult: IQueryResult);
begin
  FResult := AResult;
end;

function TQueryResult.AsRaw: IQueryResult;
begin
  Result := FResult;
end;

function TQueryResult.TakeRaw: IQueryResult;
begin
  Result := FResult;
  FResult := nil;
end;

class operator TQueryResult.Implicit(const Value: TQueryResult): IQueryResult;
begin
  Result := Value.AsRaw;
end;

function TQueryResult.RequireResult: IQueryResult;
begin
  if FResult = nil then
    raise EQueryException.Create('The result facade has no underlying result');
  Result := FResult;
end;

function TQueryResult.Next: Boolean;
begin
  Result := RequireResult.Next;
end;

function TQueryResult.GetHasResultSet: Boolean;
begin
  Result := RequireResult.HasResultSet;
end;

function TQueryResult.GetRowsAffected: Int64;
begin
  Result := RequireResult.RowsAffected;
end;

function TQueryResult.GetColumnCount: Integer;
begin
  Result := RequireResult.ColumnCount;
end;

function TQueryResult.GetColumnName(Index: Integer): string;
begin
  Result := RequireResult.GetColumnName(Index);
end;

function TQueryResult.GetColumnType(Index: Integer): TQueryValueType;
begin
  Result := RequireResult.GetColumnType(Index);
end;

function TQueryResult.GetColumnIndex(const Name: string): Integer;
begin
  Result := RequireResult.GetColumnIndex(Name);
end;

function TQueryResult.GetValue(Index: Integer): TValue;
begin
  Result := RequireResult.GetValue(Index);
end;

function TQueryResult.GetValue(const Name: string): TValue;
begin
  Result := RequireResult.GetValue(Name);
end;

function TQueryResult.IsNull(Index: Integer): Boolean;
begin
  Result := RequireResult.IsNull(Index);
end;

function TQueryResult.IsNull(const Name: string): Boolean;
begin
  Result := RequireResult.IsNull(Name);
end;

constructor TQueryNull.Create(ValueType: TQueryValueType);
begin
  if not(ValueType in [qtString .. qtBinary]) then
    raise EQueryException.Create
      ('A typed NULL requires a supported value type');
  FValueType := ValueType;
end;

class operator TQueryNull.Implicit(const Value: TQueryNull): TValue;
begin
  Result := TValue.From<TQueryNull>(Value);
end;

function TSqlDialectHelper.EngineCode: string;
const
  Codes: array [TSqlDialect] of string = ('sqlsrv', 'mysql', 'postgres',
    'sqlite', 'oracle', 'firebird');
begin
  Result := Codes[Self];
end;

class function TSqlValues.&Of<T>(const Values: array of T): TValues;
var
  I: Integer;
begin
  SetLength(Result, Length(Values));
  for I := 0 to High(Values) do
    Result[I] := TValue.From<T>(Values[I]);
end;

function CopyValues(const Values: array of TValue): TValues;
var
  I: Integer;
begin
  SetLength(Result, Length(Values));
  for I := 0 to High(Values) do
    Result[I] := Values[I];
end;

function EqualValues(const A, B: TValue): Boolean;
begin
  if A.TypeInfo <> B.TypeInfo then
    Exit(False);
  if A.IsEmpty then
    Exit(True);
  case A.Kind of
    tkInteger, tkInt64, tkEnumeration:
      Result := A.AsOrdinal = B.AsOrdinal;
    tkFloat:
      Result := A.AsExtended = B.AsExtended;
    tkString, tkLString, tkWString, tkUString:
      Result := A.AsString = B.AsString;
    tkVariant:
      Result := VarSameValue(A.AsVariant, B.AsVariant);
    tkClass:
      Result := A.AsObject = B.AsObject;
  else
    Result := False;
  end;
end;

function DistinctValues(const Values: array of TValue): TValues;
var
  List: TList<TValue>;
  V, Other: TValue;
  Found: Boolean;
begin
  List := TList<TValue>.Create;
  try
    for V in Values do
    begin
      Found := False;
      for Other in List do
        if EqualValues(V, Other) then
        begin
          Found := True;
          Break;
        end;
      if not Found then
        List.Add(V);
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function CopyStrings(const Values: array of string): TArray<string>;
var
  I: Integer;
begin
  SetLength(Result, Length(Values));
  for I := 0 to High(Values) do
    Result[I] := Values[I];
end;

function ExpandExpression(const Expression: string): TArray<string>;
var
  P, I: Integer;
  Prefix: string;
begin
  P := Pos('.{', Expression);
  if (P = 0) or not Expression.EndsWith('}') then
  begin
    Result := TArray<string>.Create(Expression);
    Exit;
  end;
  Prefix := Copy(Expression, 1, P);
  Result := Copy(Expression, P + 2, Length(Expression) - P - 2).Split([',']);
  for I := 0 to High(Result) do
    Result[I] := Prefix + Trim(Result[I]);
end;

constructor TUnsafeLiteral.Create(const AValue: string; ReplaceQuotes: Boolean);
begin
  Value := AValue;
  if ReplaceQuotes then
    Value := StringReplace(Value, '''', '''''', [rfReplaceAll]);
end;

class operator TUnsafeLiteral.Implicit(const Literal: TUnsafeLiteral): TValue;
begin
  Result := TValue.From<TUnsafeLiteral>(Literal);
end;

constructor TVariable.Create(const AName: string);
begin
  Name := AName;
end;

class operator TVariable.Implicit(const Variable: TVariable): TValue;
begin
  Result := TValue.From<TVariable>(Variable);
end;

constructor ColumnAttribute.Create(const AName: string);
begin
  inherited Create;
  Name := AName;
end;

function TClause.Clone: TClause;
begin
  Result := TClause.Create;
  try
    Result.Component := Component;
    Result.Engine := Engine;
    Result.Kind := Kind;
    Result.Name := Name;
    Result.Op := Op;
    Result.Extra := Extra;
    Result.Alias := Alias;
    Result.IsOr := IsOr;
    Result.IsNot := IsNot;
    Result.ReturnId := ReturnId;
    Result.Value := Value;
    Result.Value2 := Value2;
    Result.Values := Copy(Values);
    Result.Columns := Copy(Columns);
    if Query <> nil then
      Result.Query := Query.Clone;
  except
    Result.Free;
    raise;
  end;
end;

end.
