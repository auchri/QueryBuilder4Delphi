unit QueryBuilder4Delphi.Query;

interface

uses
  System.SysUtils, System.Rtti, System.Generics.Collections,
  QueryBuilder4Delphi.Query.Core;

type
  /// <summary>
  /// Reference-counted implementation of the mutable IQuery fluent model. Prefer TQuery.Create to obtain an
  /// interface and automatic lifetime management. Fluent methods modify this instance; Clone and NewQuery
  /// create independent models.
  /// </summary>
  TQueryObject = class(TInterfacedObject, IQuery)
  private
    FClauses: TObjectList<TClause>;
    FVariables: TDictionary<string, TValue>;
    FOrFlag, FNot: Boolean;
    FComment, FEngineScope, FQueryAlias, FMethod, FJoinType: string;
    FIsDistinct: Boolean;
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

    function Condition(const Component: string; IsOr, IsNot: Boolean;
      Kind: TClauseKind): TClause;
    function CallbackQuery(const Callback: TQueryCallback): IQuery;
    function DataPairs(Data: TObject; ConsiderKeys: Boolean)
      : TArray<TPair<string, TValue>>;
  public
    /// <summary>Creates a mutable SELECT query with optional table and comment.</summary>
    /// <param name="Table">
    /// Table identifier with optional qualified name and explicit AS alias; empty means no initial source in
    /// constructors.
    /// </param>
    /// <param name="Comment">
    /// Optional initial stored comment; built-in compilers do not emit it in SQL.
    /// </param>
    constructor Create(const Table: string = ''; const Comment: string = '');
    /// <summary>Releases owned clauses and variables when the query is destroyed.</summary>
    /// <remarks>
    /// For interface-managed instances, release interface references instead of calling Destroy directly.
    /// </remarks>
    destructor Destroy; override;
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
    /// <summary>Creates an independent query model with cloned clauses and nested queries.</summary>
    /// <returns>
    /// A new query retaining copied variable values; TValue object references remain shared.
    /// </returns>
    /// <remarks>
    /// Copies alias, method, join type, distinct flag, comment, variables, and engine scope. Pending
    /// AND/OR/NOT flags are not copied.
    /// </remarks>
    function Clone: IQuery; virtual;
    /// <summary>Creates a new empty query using the default query factory.</summary>
    /// <returns>A new SELECT query with default settings.</returns>
    /// <remarks>Does not copy this query configuration; subclasses can override this factory.</remarks>
    function NewQuery: IQuery; virtual;
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
  /// Factory for reference-counted fluent queries; construction does not access a database.
  /// </summary>
  TQuery = record
    /// <summary>Creates a reference-counted SELECT query with optional table and comment.</summary>
    /// <param name="Table">
    /// Table identifier with optional qualified name and explicit AS alias; empty means no initial source in
    /// constructors.
    /// </param>
    /// <param name="Comment">
    /// Optional initial stored comment; built-in compilers do not emit it in SQL.
    /// </param>
    /// <returns>
    /// A new reference-counted interface; releasing the last reference destroys the instance.
    /// </returns>
    class function Create(const Table: string = ''; const Comment: string = '')
      : IQuery; static;
  end;

implementation

uses
  System.StrUtils, QueryBuilder4Delphi.Query.Writes,
  QueryBuilder4Delphi.Query.DataMapper,
  QueryBuilder4Delphi.Compilers.Compiler,
  QueryBuilder4Delphi.Compilers.Factory;

class function TQuery.Create(const Table, Comment: string): IQuery;
begin
  Result := TQueryObject.Create(Table, Comment);
end;

function TQueryObject.Compile(Dialect: TSqlDialect): ISqlResult;
var
  Compiler: ICompiler;
begin
  Compiler := TQueryCompilerFactory.CreateCompiler(Dialect);
  Result := Compiler.Compile(Self);
end;

function TQueryObject.ToDebugSql(Dialect: TSqlDialect): string;
begin
  Result := Compile(Dialect).ToString;
end;

function TQueryObject.GetEngineScope: string;
begin
  Result := FEngineScope;
end;

procedure TQueryObject.PutEngineScope(const Value: string);
begin
  FEngineScope := Value;
end;

function TQueryObject.GetQueryAlias: string;
begin
  Result := FQueryAlias;
end;

procedure TQueryObject.SetQueryAlias(const Value: string);
begin
  FQueryAlias := Value;
end;

function TQueryObject.GetMethod: string;
begin
  Result := FMethod;
end;

procedure TQueryObject.SetMethod(const Value: string);
begin
  FMethod := Value;
end;

function TQueryObject.GetJoinType: string;
begin
  Result := FJoinType;
end;

procedure TQueryObject.SetJoinType(const Value: string);
begin
  FJoinType := Value;
end;

function TQueryObject.GetIsDistinct: Boolean;
begin
  Result := FIsDistinct;
end;

procedure TQueryObject.SetIsDistinct(const Value: Boolean);
begin
  FIsDistinct := Value;
end;

function TQueryObject.GetClauses: TObjectList<TClause>;
begin
  Result := FClauses;
end;

function TQueryObject.GetVariables: TDictionary<string, TValue>;
begin
  Result := FVariables;
end;

constructor TQueryObject.Create(const Table, Comment: string);
begin
  inherited Create;
  FClauses := TObjectList<TClause>.Create(True);
  FVariables := TDictionary<string, TValue>.Create;
  Method := 'select';
  JoinType := 'INNER JOIN';
  FComment := Comment;
  if Table <> '' then
    &From(Table);
end;

destructor TQueryObject.Destroy;
begin
  FVariables.Free;
  FClauses.Free;
  inherited;
end;

function TQueryObject.Clone: IQuery;
var
  Pair: TPair<string, TValue>;
begin
  Result := NewQuery;
  Result.CopyClausesFrom(Self);
  Result.EngineScope := EngineScope;
  Result.QueryAlias := QueryAlias;
  Result.Method := Method;
  Result.JoinType := JoinType;
  Result.IsDistinct := IsDistinct;
  Result.Comment(FComment);
  for Pair in FVariables do
    Result.Variables.Add(Pair.Key, Pair.Value);
end;

function TQueryObject.CopyClausesFrom(Source: IQuery): IQuery;
var
  C: TClause;
begin
  if Source = (Self as IQuery) then
    Exit(Self);
  FClauses.Clear;
  for C in Source.Clauses do
    FClauses.Add(C.Clone);
  Result := Self;
end;

function TQueryObject.Execute(const Executor: IQueryExecutor;
  Mode: TQueryExecutionMode): TQueryResult;
var
  Query: IQuery;
begin
  Query := Self;
  if Executor = nil then
    raise EArgumentNilException.Create('Executor');
  Result := TQueryResult.Create(Executor.Execute(Query, Mode));
end;

function TQueryObject.NewQuery: IQuery;
begin
  Result := TQuery.Create;
end;

function TQueryObject.Add(const Component: string; Kind: TClauseKind): TClause;
begin
  Result := TClause.Create;
  Result.Component := Component;
  Result.Kind := Kind;
  Result.Engine := EngineScope;
  FClauses.Add(Result);
end;

procedure TQueryObject.Remove(const Component, Engine: string);
var
  I: Integer;
begin
  for I := FClauses.Count - 1 downto 0 do
    if (FClauses[I].Component = Component) and (FClauses[I].Engine = Engine)
    then
      FClauses.Delete(I);
end;

function TQueryObject.GetOne(const Component, Engine: string): TClause;
var
  C: TClause;
begin
  Result := nil;
  for C in FClauses do
    if C.Component = Component then
    begin
      if C.Engine = Engine then
        Exit(C);
      if (C.Engine = '') and (Result = nil) then
        Result := C;
    end;
end;

function TQueryObject.GetComponents(const Component, Engine: string)
  : TArray<TClause>;
var
  C: TClause;
  List: TList<TClause>;
begin
  List := TList<TClause>.Create;
  try
    for C in FClauses do
      if (C.Component = Component) and
        ((C.Engine = '') or (C.Engine = Engine) or (Engine = '')) then
        List.Add(C);
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TQueryObject.HasComponent(const Component, Engine: string): Boolean;
begin
  Result := Length(GetComponents(Component, Engine)) > 0;
end;

function TQueryObject.ClearComponent(const Component, Engine: string): IQuery;
var
  I: Integer;
  E: string;
begin
  E := Engine;
  if E = '' then
    E := EngineScope;
  for I := FClauses.Count - 1 downto 0 do
    if (FClauses[I].Component = Component) and
      ((E = '') or (FClauses[I].Engine = '') or (FClauses[I].Engine = E)) then
      FClauses.Delete(I);
  Result := Self;
end;

function TQueryObject.HasConditions(const Engine: string): Boolean;
begin
  Result := HasComponent('where', Engine);
end;

function TQueryObject.Condition(const Component: string; IsOr, IsNot: Boolean;
  Kind: TClauseKind): TClause;
begin
  Result := Add(Component, Kind);
  Result.IsOr := IsOr or FOrFlag;
  Result.IsNot := IsNot or FNot;
  FOrFlag := False;
  FNot := False;
end;

function TQueryObject.CallbackQuery(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  if not Assigned(Callback) then
    raise EArgumentNilException.Create('Callback');
  Q := NewQuery;
  Q.EngineScope := EngineScope;
  if Callback(Q) <> Q then
    raise EQueryException.Create('Callback must return its supplied query');
  Result := Q;
end;

function TQueryObject.SetEngineScope(const Engine: string): IQuery;
begin
  EngineScope := Engine;
  Result := Self;
end;

function TQueryObject.&Or: IQuery;
begin
  FOrFlag := True;
  Result := Self;
end;

function TQueryObject.&And: IQuery;
begin
  FOrFlag := False;
  Result := Self;
end;

function TQueryObject.&Not(Flag: Boolean): IQuery;
begin
  FNot := Flag;
  Result := Self;
end;

function TQueryObject.&As(const Alias: string): IQuery;
begin
  QueryAlias := Alias;
  Result := Self;
end;

function TQueryObject.Comment(const Text: string): IQuery;
begin
  FComment := Text;
  Result := Self;
end;

function TQueryObject.GetComment: string;
begin
  Result := FComment;
end;

function TQueryObject.&For(const Engine: string;
  const Callback: TQueryCallback): IQuery;
var
  Previous: string;
begin
  Previous := EngineScope;
  EngineScope := Engine;
  try
    Result := Callback(Self);
    if Result <> (Self as IQuery) then
      raise EQueryException.Create('Callback must return its supplied query');
  finally
    EngineScope := Previous;
  end;
end;

function TQueryObject.When(Condition: Boolean;
  const WhenTrue, WhenFalse: TQueryCallback): IQuery;
begin
  Result := Self;
  if Condition and Assigned(WhenTrue) then
    Result := WhenTrue(Self)
  else if not Condition and Assigned(WhenFalse) then
    Result := WhenFalse(Self);
  if Result <> (Self as IQuery) then
    raise EQueryException.Create('Callback must return its supplied query');
end;

function TQueryObject.WhenNot(Condition: Boolean;
  const Callback: TQueryCallback): IQuery;
begin
  Result := When(not Condition, Callback);
end;

function TQueryObject.Define(const Name: string; const Value: TValue): IQuery;
begin
  FVariables.Add(Name, Value);
  Result := Self;
end;

function TQueryObject.FindVariable(const Name: string): TValue;
begin
  if not FVariables.TryGetValue(Name, Result) then
    raise EQueryException.CreateFmt('Variable ''%s'' not found', [Name]);
end;

function TQueryObject.&From(const Table: string): IQuery;
begin
  Remove('from', EngineScope);
  Add('from', ckIdentifier).Name := Table;
  Result := Self;
end;

function TQueryObject.&From(Query: IQuery; const Alias: string): IQuery;
var
  C: TClause;
begin
  Remove('from', EngineScope);
  C := Add('from', ckQuery);
  C.Query := Query.Clone;
  if Alias <> '' then
    C.Query.&As(Alias);
  Result := Self;
end;

function TQueryObject.&From(const Callback: TQueryCallback;
  const Alias: string): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := &From(Q, Alias);
end;

function TQueryObject.Select(Query: IQuery; const Alias: string): IQuery;
var
  C: TClause;
begin
  C := Add('select', ckQuery);
  C.Query := Query.Clone.&As(Alias);
  Method := 'select';
  Result := Self;
end;

function TQueryObject.Select(const Callback: TQueryCallback;
  const Alias: string): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := Select(Q, Alias);
end;

function TQueryObject.SelectAggregate(const Aggregate, Column: string;
  const Filter: TQueryCallback): IQuery;
var
  C: TClause;
begin
  C := Add('select', ckAggregate);
  C.Op := Aggregate;
  C.Name := Column;
  if Assigned(Filter) then
    C.Query := CallbackQuery(Filter);
  Method := 'select';
  Result := Self;
end;

function TQueryObject.SelectAggregate(const Aggregate, Column: string;
  Filter: IQuery): IQuery;
var
  C: TClause;
begin
  C := Add('select', ckAggregate);
  C.Op := Aggregate;
  C.Name := Column;
  if Filter <> nil then
    C.Query := Filter.Clone;
  Method := 'select';
  Result := Self;
end;

function TQueryObject.&With(const Alias: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  if Trim(Alias) = '' then
    raise EQueryException.Create('No alias found for CTE');
  C := Add('cte', ckQuery);
  C.Alias := Trim(Alias);
  C.Query := Query.Clone;
  C.Query.QueryAlias := '';
  Result := Self;
end;

function TQueryObject.&With(Query: IQuery): IQuery;
begin
  Result := &With(Query.QueryAlias, Query);
end;

function TQueryObject.&With(const Alias: string;
  const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := &With(Alias, Q);
end;

function TQueryObject.&With(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := &With(Q);
end;

function TQueryObject.&With(const Alias: string; const Columns: array of string;
  const Rows: TRows): IQuery;
var
  C: TClause;
  Row: TValues;
  V: TValue;
  List: TList<TValue>;
begin
  if (Length(Columns) = 0) or (Length(Rows) = 0) then
    raise EQueryException.Create('Columns and rows cannot be empty');
  for Row in Rows do
    if Length(Row) <> Length(Columns) then
      raise EQueryException.Create('Column/value count mismatch');
  C := Add('cte', ckAdHoc);
  C.Alias := Alias;
  C.Columns := CopyStrings(Columns);
  List := TList<TValue>.Create;
  try
    for Row in Rows do
      for V in Row do
        List.Add(V);
    C.Values := List.ToArray;
  finally
    List.Free;
  end;
  Result := Self;
end;

function TQueryObject.WithRaw(const Alias, Sql: string;
  const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Add('cte', ckRaw);
  C.Alias := Alias;
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.WithRaw(const Alias, Sql: string): IQuery;
begin
  Result := WithRaw(Alias, Sql, []);
end;

function TQueryObject.Join(const Table, First, Second, Op,
  JoinType: string): IQuery;
var
  C: TClause;
begin
  C := Add('join', ckJoin);
  C.Query := NewQuery;
  C.Query.&From(Table).WhereColumns(First, Op, Second).AsType(JoinType);
  Result := Self;
end;

function TQueryObject.Join(const Table: string; const Callback: TQueryCallback;
  const JoinType: string): IQuery;
var
  C: TClause;
  Q, Group: IQuery;
begin
  Q := CallbackQuery(Callback);
  Group := Q.Clone;
  Q.ClearComponent('where');
  C := Q.Add('where', ckNested);
  C.Query := Group;
  Q.&From(Table).AsType(JoinType);
  C := Add('join', ckJoin);
  C.Query := Q;

  Result := Self;
end;

function TQueryObject.Join(Query: IQuery; const Callback: TQueryCallback;
  const JoinType: string): IQuery;
var
  C: TClause;
  Q, Group: IQuery;
begin
  Q := CallbackQuery(Callback);
  Group := Q.Clone;
  Q.ClearComponent('where');
  C := Q.Add('where', ckNested);
  C.Query := Group;
  Q.&From(Query).AsType(JoinType);
  C := Add('join', ckJoin);
  C.Query := Q;

  Result := Self;
end;

function TQueryObject.LeftJoin(const Table, First, Second, Op: string): IQuery;
begin
  Result := Join(Table, First, Second, Op, 'left join');
end;

function TQueryObject.LeftJoin(const Table: string;
  const Callback: TQueryCallback): IQuery;
begin
  Result := Join(Table, Callback, 'left join');
end;

function TQueryObject.LeftJoin(Query: IQuery;
  const Callback: TQueryCallback): IQuery;
begin
  Result := Join(Query, Callback, 'left join');
end;

function TQueryObject.RightJoin(const Table, First, Second, Op: string): IQuery;
begin
  Result := Join(Table, First, Second, Op, 'right join');
end;

function TQueryObject.RightJoin(const Table: string;
  const Callback: TQueryCallback): IQuery;
begin
  Result := Join(Table, Callback, 'right join');
end;

function TQueryObject.RightJoin(Query: IQuery;
  const Callback: TQueryCallback): IQuery;
begin
  Result := Join(Query, Callback, 'right join');
end;

function TQueryObject.CrossJoin(const Table: string): IQuery;
var
  C: TClause;
begin
  C := Add('join', ckJoin);
  C.Query := NewQuery.&From(Table).AsCross;
  Result := Self;
end;

function TQueryObject.On(const First, Second, Op: string): IQuery;
begin
  Result := WhereColumns(First, Op, Second);
end;

function TQueryObject.OrOn(const First, Second, Op: string): IQuery;
begin
  Result := OrWhereColumns(First, Op, Second);
end;

function TQueryObject.JoinWith(const Table: string): IQuery;
begin
  Result := &From(Table);
end;

function TQueryObject.JoinWith(Query: IQuery; const Alias: string): IQuery;
begin
  Result := &From(Query, Alias);
end;

function TQueryObject.JoinWith(const Callback: TQueryCallback;
  const Alias: string): IQuery;
begin
  Result := &From(Callback, Alias);
end;

function TQueryObject.JoinWithRaw(const Sql: string;
  const Bindings: array of TValue): IQuery;
begin
  Result := FromRaw(Sql, Bindings);
end;

function TQueryObject.AsType(const Value: string): IQuery;
begin
  JoinType := UpperCase(Value);
  Result := Self;
end;

function TQueryObject.AsInner: IQuery;
begin
  Result := AsType('inner join');
end;

function TQueryObject.AsOuter: IQuery;
begin
  Result := AsType('outer join');
end;

function TQueryObject.AsLeft: IQuery;
begin
  Result := AsType('left join');
end;

function TQueryObject.AsRight: IQuery;
begin
  Result := AsType('right join');
end;

function TQueryObject.AsCross: IQuery;
begin
  Result := AsType('cross join');
end;

function TQueryObject.Limit(Value: Integer): IQuery;
begin
  Remove('limit', EngineScope);
  Add('limit', ckLimit).Value := Value;
  Result := Self;
end;

function TQueryObject.Offset(Value: Int64): IQuery;
begin
  Remove('offset', EngineScope);
  Add('offset', ckOffset).Value := Value;
  Result := Self;
end;

function TQueryObject.Take(Value: Integer): IQuery;
begin
  Result := Limit(Value);
end;

function TQueryObject.Skip(Value: Int64): IQuery;
begin
  Result := Offset(Value);
end;

function TQueryObject.ForPage(Page, PerPage: Integer): IQuery;
begin
  Result := Offset(Int64(Page - 1) * PerPage).Limit(PerPage);
end;

function TQueryObject.GetLimit(const Engine: string): Integer;
var
  C: TClause;
begin
  C := GetOne('limit', Engine);
  Result := 0;
  if C <> nil then
    Result := C.Value.AsInteger;
  if Result < 0 then
    Result := 0;
end;

function TQueryObject.GetOffset(const Engine: string): Int64;
var
  C: TClause;
begin
  C := GetOne('offset', Engine);
  Result := 0;
  if C <> nil then
    Result := C.Value.AsInt64;
  if Result < 0 then
    Result := 0;
end;

function TQueryObject.HasLimit(const Engine: string): Boolean;
begin
  Result := GetLimit(Engine) > 0;
end;

function TQueryObject.HasOffset(const Engine: string): Boolean;
begin
  Result := GetOffset(Engine) > 0;
end;

function TQueryObject.Distinct: IQuery;
begin
  IsDistinct := True;
  Result := Self;
end;

function TQueryObject.OrderByRandom: IQuery;
begin
  Add('order', ckRandom);
  Result := Self;
end;

function TQueryObject.OrderByRandom(Seed: Integer): IQuery;
begin
  Add('order', ckRandom).Value := Seed;
  Result := Self;
end;

function TQueryObject.Combine(const Operation: string; All: Boolean;
  Query: IQuery): IQuery;
var
  C: TClause;
begin
  if (Method <> 'select') or (Query.Method <> 'select') then
    raise EQueryException.Create('Only select queries can be combined');
  if not MatchText(Operation, ['union', 'except', 'intersect']) then
    raise EQueryException.Create('Invalid combine operation');
  C := Add('combine', ckCombine);
  C.Op := Operation;
  C.IsNot := All;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.AsAggregate(const Aggregate: string;
  const Columns: array of string): IQuery;
begin
  Result := TQueryWrites.AsAggregate(Self, Aggregate, Columns);
end;

function TQueryObject.AsInsert(const Columns: array of string;
  const Values: array of TValue): IQuery;
begin
  Result := TQueryWrites.AsInsert(Self, Columns, Values);
end;

function TQueryObject.AsInsert(const Columns: array of string;
  const Rows: TRows): IQuery;
begin
  Result := TQueryWrites.AsInsert(Self, Columns, Rows);
end;

function TQueryObject.AsInsert(const Columns: array of string;
  Query: IQuery): IQuery;
begin
  Result := TQueryWrites.AsInsert(Self, Columns, Query);
end;

function TQueryObject.AsInsert(const Values: array of TPair<string, TValue>;
  ReturnId: Boolean): IQuery;
begin
  Result := TQueryWrites.AsInsert(Self, Values, ReturnId);
end;

function TQueryObject.AsUpdate(const Columns: array of string;
  const Values: array of TValue): IQuery;
begin
  Result := TQueryWrites.AsUpdate(Self, Columns, Values);
end;

function TQueryObject.AsUpdate(const Values
  : array of TPair<string, TValue>): IQuery;
begin
  Result := TQueryWrites.AsUpdate(Self, Values);
end;

function TQueryObject.AsDelete: IQuery;
begin
  Result := TQueryWrites.AsDelete(Self);
end;

function TQueryObject.AsIncrement(const Column: string; Value: Integer): IQuery;
begin
  Result := TQueryWrites.AsIncrement(Self, Column, Value);
end;

function TQueryObject.AsDecrement(const Column: string; Value: Integer): IQuery;
begin
  Result := TQueryWrites.AsDecrement(Self, Column, Value);
end;

function TQueryObject.DataPairs(Data: TObject; ConsiderKeys: Boolean)
  : TArray<TPair<string, TValue>>;
begin
  if ConsiderKeys then
    Result := TQueryDataMapper.GetPairs(Data,
      procedure(Name: string; Value: TValue)
      begin
        Where(Name, Value);
      end)
  else
    Result := TQueryDataMapper.GetPairs(Data);
end;

function TQueryObject.AsInsert(Data: TObject; ReturnId: Boolean): IQuery;
begin
  Result := AsInsert(DataPairs(Data, False), ReturnId);
end;

function TQueryObject.AsUpdate(Data: TObject): IQuery;
begin
  Result := AsUpdate(DataPairs(Data, True));
end;

function TQueryObject.Where(const Values: array of TPair<string,
  TValue>): IQuery;
var
  Pair: TPair<string, TValue>;
  OrFlag, NotFlag: Boolean;
begin
  OrFlag := FOrFlag;
  NotFlag := FNot;
  for Pair in Values do
  begin
    FOrFlag := OrFlag;
    FNot := NotFlag;
    Where(Pair.Key, Pair.Value);
  end;
  Result := Self;
end;

function TQueryObject.Where(Data: TObject): IQuery;
begin
  Result := Where(DataPairs(Data, False));
end;

function TQueryObject.Having(const Values
  : array of TPair<string, TValue>): IQuery;
var
  Pair: TPair<string, TValue>;
  OrFlag, NotFlag: Boolean;
begin
  OrFlag := FOrFlag;
  NotFlag := FNot;
  for Pair in Values do
  begin
    FOrFlag := OrFlag;
    FNot := NotFlag;
    Having(Pair.Key, Pair.Value);
  end;
  Result := Self;
end;

function TQueryObject.Having(Data: TObject): IQuery;
begin
  Result := Having(DataPairs(Data, False));
end;

function TQueryObject.AsInsert(Data: TDictionary<string, TValue>;
ReturnId: Boolean): IQuery;
begin
  if Data = nil then
    raise EArgumentNilException.Create('Data');
  Result := AsInsert(Data.ToArray, ReturnId);
end;

function TQueryObject.AsUpdate(Data: TDictionary<string, TValue>): IQuery;
begin
  if Data = nil then
    raise EArgumentNilException.Create('Data');
  Result := AsUpdate(Data.ToArray);
end;

function TQueryObject.Where(Data: TDictionary<string, TValue>): IQuery;
begin
  if Data = nil then
    raise EArgumentNilException.Create('Data');
  Result := Where(Data.ToArray);
end;

function TQueryObject.Having(Data: TDictionary<string, TValue>): IQuery;
begin
  if Data = nil then
    raise EArgumentNilException.Create('Data');
  Result := Having(Data.ToArray);
end;

// BEGIN GENERATED: fluent implementation
function TQueryObject.Where(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckBasic);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.Where(const Column: string; const Value: TValue): IQuery;

begin
  Result := Where(Column, '=', Value);
end;

function TQueryObject.Where(Group: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.Where(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := Where(Q);
end;

function TQueryObject.Where(const Column, Op: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckQuery);
  C.Name := Column;
  C.Op := Op;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.Where(const Column, Op: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := Where(Column, Op, Q);
end;

function TQueryObject.WhereNull(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.WhereTrue(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckBoolean);
  C.Name := Column;
  C.Value := True;
  Result := Self;
end;

function TQueryObject.WhereFalse(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckBoolean);
  C.Name := Column;
  C.Value := False;
  Result := Self;
end;

function TQueryObject.WhereBetween(const Column: string;
const Lower, Higher: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckBetween);
  C.Name := Column;
  C.Value := Lower;
  C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.WhereIn(const Column: string;
const Values: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckIn);
  C.Name := Column;
  C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.WhereIn(const Column: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckInQuery);
  C.Name := Column;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.WhereIn(const Column: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := WhereIn(Column, Q);
end;

function TQueryObject.WhereExists(Query: IQuery): IQuery;
var
  C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then
    raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('where', False, False, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.WhereExists(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := WhereExists(Q);
end;

function TQueryObject.WhereLike(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'like';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereStarts(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'starts';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereEnds(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'ends';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereContains(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'contains';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereDate(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.WhereDate(const Column: string;
const Value: TValue): IQuery;

begin
  Result := WhereDate(Column, '=', Value);
end;

function TQueryObject.WhereTime(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.WhereTime(const Column: string;
const Value: TValue): IQuery;

begin
  Result := WhereTime(Column, '=', Value);
end;

function TQueryObject.WhereDatePart(const Part, Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := Part;
  Result := Self;
end;

function TQueryObject.WhereDatePart(const Part, Column: string;
const Value: TValue): IQuery;

begin
  Result := WhereDatePart(Part, Column, '=', Value);
end;

function TQueryObject.WhereNot(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckBasic);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.WhereNot(const Column: string;
const Value: TValue): IQuery;

begin
  Result := WhereNot(Column, '=', Value);
end;

function TQueryObject.WhereNot(Group: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.WhereNot(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := WhereNot(Q);
end;

function TQueryObject.WhereNot(const Column, Op: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckQuery);
  C.Name := Column;
  C.Op := Op;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.WhereNot(const Column, Op: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := WhereNot(Column, Op, Q);
end;

function TQueryObject.WhereNotNull(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.WhereNotBetween(const Column: string;
const Lower, Higher: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckBetween);
  C.Name := Column;
  C.Value := Lower;
  C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.WhereNotIn(const Column: string;
const Values: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckIn);
  C.Name := Column;
  C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.WhereNotIn(const Column: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckInQuery);
  C.Name := Column;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.WhereNotIn(const Column: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := WhereNotIn(Column, Q);
end;

function TQueryObject.WhereNotExists(Query: IQuery): IQuery;
var
  C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then
    raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('where', False, True, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.WhereNotExists(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := WhereNotExists(Q);
end;

function TQueryObject.WhereNotLike(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'like';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereNotStarts(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'starts';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereNotEnds(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'ends';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereNotContains(const Column: string;
const Value: TValue; const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'contains';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereNotDate(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.WhereNotDate(const Column: string;
const Value: TValue): IQuery;

begin
  Result := WhereNotDate(Column, '=', Value);
end;

function TQueryObject.WhereNotTime(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.WhereNotTime(const Column: string;
const Value: TValue): IQuery;

begin
  Result := WhereNotTime(Column, '=', Value);
end;

function TQueryObject.WhereNotDatePart(const Part, Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := Part;
  Result := Self;
end;

function TQueryObject.WhereNotDatePart(const Part, Column: string;
const Value: TValue): IQuery;

begin
  Result := WhereNotDatePart(Part, Column, '=', Value);
end;

function TQueryObject.WhereRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.WhereRaw(const Sql: string): IQuery;

begin
  Result := WhereRaw(Sql, []);
end;

function TQueryObject.WhereColumns(const First, Op, Second: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckColumns);
  C.Name := First;
  C.Op := Op;
  C.Extra := Second;
  Result := Self;
end;

function TQueryObject.WhereSub(Query: IQuery; const Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckSubQuery);
  C.Query := Query.Clone;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.WhereSub(Query: IQuery; const Value: TValue): IQuery;

begin
  Result := WhereSub(Query, '=', Value);
end;

function TQueryObject.OrWhere(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckBasic);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.OrWhere(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrWhere(Column, '=', Value);
end;

function TQueryObject.OrWhere(Group: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.OrWhere(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhere(Q);
end;

function TQueryObject.OrWhere(const Column, Op: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckQuery);
  C.Name := Column;
  C.Op := Op;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrWhere(const Column, Op: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhere(Column, Op, Q);
end;

function TQueryObject.OrWhereNull(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.OrWhereTrue(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckBoolean);
  C.Name := Column;
  C.Value := True;
  Result := Self;
end;

function TQueryObject.OrWhereFalse(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckBoolean);
  C.Name := Column;
  C.Value := False;
  Result := Self;
end;

function TQueryObject.OrWhereBetween(const Column: string;
const Lower, Higher: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckBetween);
  C.Name := Column;
  C.Value := Lower;
  C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.OrWhereIn(const Column: string;
const Values: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckIn);
  C.Name := Column;
  C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.OrWhereIn(const Column: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckInQuery);
  C.Name := Column;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrWhereIn(const Column: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhereIn(Column, Q);
end;

function TQueryObject.OrWhereExists(Query: IQuery): IQuery;
var
  C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then
    raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('where', True, False, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrWhereExists(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhereExists(Q);
end;

function TQueryObject.OrWhereLike(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'like';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereStarts(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'starts';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereEnds(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'ends';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereContains(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'contains';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereDate(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.OrWhereDate(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrWhereDate(Column, '=', Value);
end;

function TQueryObject.OrWhereTime(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.OrWhereTime(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrWhereTime(Column, '=', Value);
end;

function TQueryObject.OrWhereDatePart(const Part, Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := Part;
  Result := Self;
end;

function TQueryObject.OrWhereDatePart(const Part, Column: string;
const Value: TValue): IQuery;

begin
  Result := OrWhereDatePart(Part, Column, '=', Value);
end;

function TQueryObject.OrWhereNot(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckBasic);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.OrWhereNot(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrWhereNot(Column, '=', Value);
end;

function TQueryObject.OrWhereNot(Group: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.OrWhereNot(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhereNot(Q);
end;

function TQueryObject.OrWhereNot(const Column, Op: string;
Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckQuery);
  C.Name := Column;
  C.Op := Op;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrWhereNot(const Column, Op: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhereNot(Column, Op, Q);
end;

function TQueryObject.OrWhereNotNull(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.OrWhereNotBetween(const Column: string;
const Lower, Higher: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckBetween);
  C.Name := Column;
  C.Value := Lower;
  C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.OrWhereNotIn(const Column: string;
const Values: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckIn);
  C.Name := Column;
  C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.OrWhereNotIn(const Column: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckInQuery);
  C.Name := Column;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrWhereNotIn(const Column: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhereNotIn(Column, Q);
end;

function TQueryObject.OrWhereNotExists(Query: IQuery): IQuery;
var
  C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then
    raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('where', True, True, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrWhereNotExists(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhereNotExists(Q);
end;

function TQueryObject.OrWhereNotLike(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'like';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereNotStarts(const Column: string;
const Value: TValue; const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'starts';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereNotEnds(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'ends';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereNotContains(const Column: string;
const Value: TValue; const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'contains';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereNotDate(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.OrWhereNotDate(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrWhereNotDate(Column, '=', Value);
end;

function TQueryObject.OrWhereNotTime(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.OrWhereNotTime(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrWhereNotTime(Column, '=', Value);
end;

function TQueryObject.OrWhereNotDatePart(const Part, Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := Part;
  Result := Self;
end;

function TQueryObject.OrWhereNotDatePart(const Part, Column: string;
const Value: TValue): IQuery;

begin
  Result := OrWhereNotDatePart(Part, Column, '=', Value);
end;

function TQueryObject.OrWhereRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.OrWhereRaw(const Sql: string): IQuery;

begin
  Result := OrWhereRaw(Sql, []);
end;

function TQueryObject.OrWhereColumns(const First, Op, Second: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckColumns);
  C.Name := First;
  C.Op := Op;
  C.Extra := Second;
  Result := Self;
end;

function TQueryObject.OrWhereSub(Query: IQuery; const Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckSubQuery);
  C.Query := Query.Clone;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.OrWhereSub(Query: IQuery; const Value: TValue): IQuery;

begin
  Result := OrWhereSub(Query, '=', Value);
end;

function TQueryObject.Having(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckBasic);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.Having(const Column: string; const Value: TValue): IQuery;

begin
  Result := Having(Column, '=', Value);
end;

function TQueryObject.Having(Group: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.Having(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := Having(Q);
end;

function TQueryObject.Having(const Column, Op: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckQuery);
  C.Name := Column;
  C.Op := Op;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.Having(const Column, Op: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := Having(Column, Op, Q);
end;

function TQueryObject.HavingNull(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.HavingTrue(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckBoolean);
  C.Name := Column;
  C.Value := True;
  Result := Self;
end;

function TQueryObject.HavingFalse(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckBoolean);
  C.Name := Column;
  C.Value := False;
  Result := Self;
end;

function TQueryObject.HavingBetween(const Column: string;
const Lower, Higher: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckBetween);
  C.Name := Column;
  C.Value := Lower;
  C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.HavingIn(const Column: string;
const Values: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckIn);
  C.Name := Column;
  C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.HavingIn(const Column: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckInQuery);
  C.Name := Column;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.HavingIn(const Column: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := HavingIn(Column, Q);
end;

function TQueryObject.HavingExists(Query: IQuery): IQuery;
var
  C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then
    raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('having', False, False, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.HavingExists(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := HavingExists(Q);
end;

function TQueryObject.HavingLike(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'like';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingStarts(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'starts';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingEnds(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'ends';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingContains(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'contains';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingDate(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.HavingDate(const Column: string;
const Value: TValue): IQuery;

begin
  Result := HavingDate(Column, '=', Value);
end;

function TQueryObject.HavingTime(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.HavingTime(const Column: string;
const Value: TValue): IQuery;

begin
  Result := HavingTime(Column, '=', Value);
end;

function TQueryObject.HavingDatePart(const Part, Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := Part;
  Result := Self;
end;

function TQueryObject.HavingDatePart(const Part, Column: string;
const Value: TValue): IQuery;

begin
  Result := HavingDatePart(Part, Column, '=', Value);
end;

function TQueryObject.HavingNot(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckBasic);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.HavingNot(const Column: string;
const Value: TValue): IQuery;

begin
  Result := HavingNot(Column, '=', Value);
end;

function TQueryObject.HavingNot(Group: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.HavingNot(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := HavingNot(Q);
end;

function TQueryObject.HavingNot(const Column, Op: string;
Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckQuery);
  C.Name := Column;
  C.Op := Op;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.HavingNot(const Column, Op: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := HavingNot(Column, Op, Q);
end;

function TQueryObject.HavingNotNull(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.HavingNotBetween(const Column: string;
const Lower, Higher: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckBetween);
  C.Name := Column;
  C.Value := Lower;
  C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.HavingNotIn(const Column: string;
const Values: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckIn);
  C.Name := Column;
  C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.HavingNotIn(const Column: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckInQuery);
  C.Name := Column;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.HavingNotIn(const Column: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := HavingNotIn(Column, Q);
end;

function TQueryObject.HavingNotExists(Query: IQuery): IQuery;
var
  C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then
    raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('having', False, True, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.HavingNotExists(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := HavingNotExists(Q);
end;

function TQueryObject.HavingNotLike(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'like';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingNotStarts(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'starts';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingNotEnds(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'ends';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingNotContains(const Column: string;
const Value: TValue; const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'contains';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingNotDate(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.HavingNotDate(const Column: string;
const Value: TValue): IQuery;

begin
  Result := HavingNotDate(Column, '=', Value);
end;

function TQueryObject.HavingNotTime(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.HavingNotTime(const Column: string;
const Value: TValue): IQuery;

begin
  Result := HavingNotTime(Column, '=', Value);
end;

function TQueryObject.HavingNotDatePart(const Part, Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := Part;
  Result := Self;
end;

function TQueryObject.HavingNotDatePart(const Part, Column: string;
const Value: TValue): IQuery;

begin
  Result := HavingNotDatePart(Part, Column, '=', Value);
end;

function TQueryObject.HavingRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.HavingRaw(const Sql: string): IQuery;

begin
  Result := HavingRaw(Sql, []);
end;

function TQueryObject.HavingColumns(const First, Op, Second: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckColumns);
  C.Name := First;
  C.Op := Op;
  C.Extra := Second;
  Result := Self;
end;

function TQueryObject.HavingSub(Query: IQuery; const Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckSubQuery);
  C.Query := Query.Clone;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.HavingSub(Query: IQuery; const Value: TValue): IQuery;

begin
  Result := HavingSub(Query, '=', Value);
end;

function TQueryObject.OrHaving(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckBasic);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.OrHaving(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrHaving(Column, '=', Value);
end;

function TQueryObject.OrHaving(Group: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.OrHaving(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHaving(Q);
end;

function TQueryObject.OrHaving(const Column, Op: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckQuery);
  C.Name := Column;
  C.Op := Op;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrHaving(const Column, Op: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHaving(Column, Op, Q);
end;

function TQueryObject.OrHavingNull(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.OrHavingTrue(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckBoolean);
  C.Name := Column;
  C.Value := True;
  Result := Self;
end;

function TQueryObject.OrHavingFalse(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckBoolean);
  C.Name := Column;
  C.Value := False;
  Result := Self;
end;

function TQueryObject.OrHavingBetween(const Column: string;
const Lower, Higher: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckBetween);
  C.Name := Column;
  C.Value := Lower;
  C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.OrHavingIn(const Column: string;
const Values: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckIn);
  C.Name := Column;
  C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.OrHavingIn(const Column: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckInQuery);
  C.Name := Column;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrHavingIn(const Column: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHavingIn(Column, Q);
end;

function TQueryObject.OrHavingExists(Query: IQuery): IQuery;
var
  C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then
    raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('having', True, False, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrHavingExists(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHavingExists(Q);
end;

function TQueryObject.OrHavingLike(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'like';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingStarts(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'starts';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingEnds(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'ends';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingContains(const Column: string;
const Value: TValue; const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'contains';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingDate(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.OrHavingDate(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrHavingDate(Column, '=', Value);
end;

function TQueryObject.OrHavingTime(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.OrHavingTime(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrHavingTime(Column, '=', Value);
end;

function TQueryObject.OrHavingDatePart(const Part, Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := Part;
  Result := Self;
end;

function TQueryObject.OrHavingDatePart(const Part, Column: string;
const Value: TValue): IQuery;

begin
  Result := OrHavingDatePart(Part, Column, '=', Value);
end;

function TQueryObject.OrHavingNot(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckBasic);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.OrHavingNot(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrHavingNot(Column, '=', Value);
end;

function TQueryObject.OrHavingNot(Group: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.OrHavingNot(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHavingNot(Q);
end;

function TQueryObject.OrHavingNot(const Column, Op: string;
Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckQuery);
  C.Name := Column;
  C.Op := Op;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrHavingNot(const Column, Op: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHavingNot(Column, Op, Q);
end;

function TQueryObject.OrHavingNotNull(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.OrHavingNotBetween(const Column: string;
const Lower, Higher: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckBetween);
  C.Name := Column;
  C.Value := Lower;
  C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.OrHavingNotIn(const Column: string;
const Values: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckIn);
  C.Name := Column;
  C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.OrHavingNotIn(const Column: string;
Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckInQuery);
  C.Name := Column;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrHavingNotIn(const Column: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHavingNotIn(Column, Q);
end;

function TQueryObject.OrHavingNotExists(Query: IQuery): IQuery;
var
  C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then
    raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('having', True, True, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrHavingNotExists(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHavingNotExists(Q);
end;

function TQueryObject.OrHavingNotLike(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'like';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingNotStarts(const Column: string;
const Value: TValue; const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'starts';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingNotEnds(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'ends';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingNotContains(const Column: string;
const Value: TValue; const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'contains';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingNotDate(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.OrHavingNotDate(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrHavingNotDate(Column, '=', Value);
end;

function TQueryObject.OrHavingNotTime(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.OrHavingNotTime(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrHavingNotTime(Column, '=', Value);
end;

function TQueryObject.OrHavingNotDatePart(const Part, Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := Part;
  Result := Self;
end;

function TQueryObject.OrHavingNotDatePart(const Part, Column: string;
const Value: TValue): IQuery;

begin
  Result := OrHavingNotDatePart(Part, Column, '=', Value);
end;

function TQueryObject.OrHavingRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.OrHavingRaw(const Sql: string): IQuery;

begin
  Result := OrHavingRaw(Sql, []);
end;

function TQueryObject.OrHavingColumns(const First, Op, Second: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckColumns);
  C.Name := First;
  C.Op := Op;
  C.Extra := Second;
  Result := Self;
end;

function TQueryObject.OrHavingSub(Query: IQuery; const Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckSubQuery);
  C.Query := Query.Clone;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.OrHavingSub(Query: IQuery; const Value: TValue): IQuery;

begin
  Result := OrHavingSub(Query, '=', Value);
end;

function TQueryObject.Select(const Columns: array of string): IQuery;
var
  S, E: string;
  C: TClause;
begin
  for S in Columns do
    for E in ExpandExpression(S) do
    begin
      C := Add('select', ckIdentifier);
      C.Name := E;
      C.IsNot := False;
    end;
  Method := 'select';
  Result := Self;
end;

function TQueryObject.Select(const Column: string): IQuery;

begin
  Result := Select([Column]);
end;

function TQueryObject.GroupBy(const Columns: array of string): IQuery;
var
  S, E: string;
  C: TClause;
begin
  for S in Columns do
    for E in ExpandExpression(S) do
    begin
      C := Add('group', ckIdentifier);
      C.Name := E;
      C.IsNot := False;
    end;
  Result := Self;
end;

function TQueryObject.GroupBy(const Column: string): IQuery;

begin
  Result := GroupBy([Column]);
end;

function TQueryObject.OrderBy(const Columns: array of string): IQuery;
var
  S, E: string;
  C: TClause;
begin
  for S in Columns do
    for E in ExpandExpression(S) do
    begin
      C := Add('order', ckIdentifier);
      C.Name := E;
      C.IsNot := False;
    end;
  Result := Self;
end;

function TQueryObject.OrderBy(const Column: string): IQuery;

begin
  Result := OrderBy([Column]);
end;

function TQueryObject.OrderByDesc(const Columns: array of string): IQuery;
var
  S, E: string;
  C: TClause;
begin
  for S in Columns do
    for E in ExpandExpression(S) do
    begin
      C := Add('order', ckIdentifier);
      C.Name := E;
      C.IsNot := True;
    end;
  Result := Self;
end;

function TQueryObject.OrderByDesc(const Column: string): IQuery;

begin
  Result := OrderByDesc([Column]);
end;

function TQueryObject.SelectRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  Method := 'select';
  C := Add('select', ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.SelectRaw(const Sql: string): IQuery;

begin
  Result := SelectRaw(Sql, []);
end;

function TQueryObject.FromRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  Remove('from', EngineScope);
  C := Add('from', ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.FromRaw(const Sql: string): IQuery;

begin
  Result := FromRaw(Sql, []);
end;

function TQueryObject.OrderByRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Add('order', ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.OrderByRaw(const Sql: string): IQuery;

begin
  Result := OrderByRaw(Sql, []);
end;

function TQueryObject.GroupByRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Add('group', ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.GroupByRaw(const Sql: string): IQuery;

begin
  Result := GroupByRaw(Sql, []);
end;

function TQueryObject.CombineRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  if Method <> 'select' then
    raise EQueryException.Create('Only select queries can be combined');
  C := Add('combine', ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.CombineRaw(const Sql: string): IQuery;

begin
  Result := CombineRaw(Sql, []);
end;

function TQueryObject.UnionRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  if Method <> 'select' then
    raise EQueryException.Create('Only select queries can be combined');
  C := Add('combine', ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.UnionRaw(const Sql: string): IQuery;

begin
  Result := UnionRaw(Sql, []);
end;

function TQueryObject.ExceptRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  if Method <> 'select' then
    raise EQueryException.Create('Only select queries can be combined');
  C := Add('combine', ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.ExceptRaw(const Sql: string): IQuery;

begin
  Result := ExceptRaw(Sql, []);
end;

function TQueryObject.IntersectRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  if Method <> 'select' then
    raise EQueryException.Create('Only select queries can be combined');
  C := Add('combine', ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.IntersectRaw(const Sql: string): IQuery;

begin
  Result := IntersectRaw(Sql, []);
end;

function TQueryObject.AsCount(const Columns: array of string): IQuery;

begin
  if Length(Columns) = 0 then
    Result := AsAggregate('count', ['*'])
  else
    Result := AsAggregate('count', Columns);
end;

function TQueryObject.AsCount(): IQuery;

begin
  Result := AsCount([]);
end;

function TQueryObject.AsSum(const Column: string): IQuery;

begin
  Result := AsAggregate('sum', [Column]);
end;

function TQueryObject.AsAvg(const Column: string): IQuery;

begin
  Result := AsAggregate('avg', [Column]);
end;

function TQueryObject.AsAverage(const Column: string): IQuery;

begin
  Result := AsAggregate('avg', [Column]);
end;

function TQueryObject.AsMin(const Column: string): IQuery;

begin
  Result := AsAggregate('min', [Column]);
end;

function TQueryObject.AsMax(const Column: string): IQuery;

begin
  Result := AsAggregate('max', [Column]);
end;

function TQueryObject.SelectSum(const Column: string;
const Filter: TQueryCallback): IQuery;

begin
  Result := SelectAggregate('sum', Column, Filter);
end;

function TQueryObject.SelectCount(const Column: string;
const Filter: TQueryCallback): IQuery;

begin
  Result := SelectAggregate('count', Column, Filter);
end;

function TQueryObject.SelectAvg(const Column: string;
const Filter: TQueryCallback): IQuery;

begin
  Result := SelectAggregate('avg', Column, Filter);
end;

function TQueryObject.SelectMin(const Column: string;
const Filter: TQueryCallback): IQuery;

begin
  Result := SelectAggregate('min', Column, Filter);
end;

function TQueryObject.SelectMax(const Column: string;
const Filter: TQueryCallback): IQuery;

begin
  Result := SelectAggregate('max', Column, Filter);
end;

function TQueryObject.Union(Query: IQuery; All: Boolean): IQuery;

begin
  Result := Combine('union', All, Query);
end;

function TQueryObject.Union(const Callback: TQueryCallback;
All: Boolean): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := Union(Q, All);
end;

function TQueryObject.UnionAll(Query: IQuery): IQuery;

begin
  Result := Union(Query, True);
end;

function TQueryObject.UnionAll(const Callback: TQueryCallback): IQuery;

begin
  Result := Union(Callback, True);
end;

function TQueryObject.&Except(Query: IQuery; All: Boolean): IQuery;

begin
  Result := Combine('except', All, Query);
end;

function TQueryObject.&Except(const Callback: TQueryCallback;
All: Boolean): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := &Except(Q, All);
end;

function TQueryObject.ExceptAll(Query: IQuery): IQuery;

begin
  Result := &Except(Query, True);
end;

function TQueryObject.ExceptAll(const Callback: TQueryCallback): IQuery;

begin
  Result := &Except(Callback, True);
end;

function TQueryObject.Intersect(Query: IQuery; All: Boolean): IQuery;

begin
  Result := Combine('intersect', All, Query);
end;

function TQueryObject.Intersect(const Callback: TQueryCallback;
All: Boolean): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := Intersect(Q, All);
end;

function TQueryObject.IntersectAll(Query: IQuery): IQuery;

begin
  Result := Intersect(Query, True);
end;

function TQueryObject.IntersectAll(const Callback: TQueryCallback): IQuery;

begin
  Result := Intersect(Callback, True);
end;

function TQueryObject.ForSqlServer(const Callback: TQueryCallback): IQuery;

begin
  Result := &For(TSqlDialect.MSSql.EngineCode, Callback);
end;

function TQueryObject.ForPostgreSql(const Callback: TQueryCallback): IQuery;

begin
  Result := &For(TSqlDialect.PostgreSql.EngineCode, Callback);
end;

function TQueryObject.ForMySql(const Callback: TQueryCallback): IQuery;

begin
  Result := &For(TSqlDialect.MySql.EngineCode, Callback);
end;

function TQueryObject.ForSqlite(const Callback: TQueryCallback): IQuery;

begin
  Result := &For(TSqlDialect.Sqlite.EngineCode, Callback);
end;

function TQueryObject.ForOracle(const Callback: TQueryCallback): IQuery;

begin
  Result := &For(TSqlDialect.Oracle.EngineCode, Callback);
end;

function TQueryObject.ForFirebird(const Callback: TQueryCallback): IQuery;

begin
  Result := &For(TSqlDialect.Firebird.EngineCode, Callback);
end;
// END GENERATED: fluent implementation

end.
