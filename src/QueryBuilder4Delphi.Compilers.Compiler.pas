unit QueryBuilder4Delphi.Compilers.Compiler;

interface

uses System.SysUtils, System.Rtti, System.Generics.Collections,
  QueryBuilder4Delphi.Query.Core;

type
  // Preserve existing qualified references to the shared contract.
  /// <summary>
  /// Parameterized compilation result. RawSql uses ? placeholders; Sql uses named placeholders. Bindings are
  /// ordered and NamedBindings maps full parameter tokens to values. The result owns both collections and
  /// retains Query. ToString is a diagnostic preview only.
  /// </summary>
  ISqlResult = QueryBuilder4Delphi.Query.Core.ISqlResult;

  /// <summary>
  /// Reference-counted implementation of ISqlResult, owning its binding collections and retaining the
  /// compiled query. Keep an interface reference while using borrowed collections.
  /// </summary>
  TSqlResult = class(TInterfacedObject, ISqlResult)
  public
    /// <summary>Returns RawSql for this instance.</summary>
    /// <returns>
    /// SQL with positional ? placeholders before named substitution; used with Bindings for diagnostic
    /// previews.
    /// </returns>
    function GetRawSql: string;
    /// <summary>Replaces RawSql for this instance.</summary>
    /// <param name="Value">
    /// SQL with positional ? placeholders before named substitution; used with Bindings for diagnostic
    /// previews.
    /// </param>
    procedure SetRawSql(const Value: string);
    /// <summary>Returns Sql for this instance.</summary>
    /// <returns>
    /// Parameterized SQL text with named placeholders. Execute with the associated bindings, never with
    /// substituted debug values.
    /// </returns>
    function GetSql: string;
    /// <summary>Replaces Sql for this instance.</summary>
    /// <param name="Value">
    /// Parameterized SQL text with named placeholders. Execute with the associated bindings, never with
    /// substituted debug values.
    /// </param>
    procedure SetSql(const Value: string);
    /// <summary>Returns Bindings for this instance.</summary>
    /// <returns>
    /// Borrowed ordered binding list owned by this result; entries correspond to RawSql placeholders. Do not
    /// free the list.
    /// </returns>
    function GetBindings: TList<TValue>;
    /// <summary>Returns NamedBindings for this instance.</summary>
    /// <returns>
    /// Borrowed dictionary owned by the result, keyed by full named parameter tokens including the prefix.
    /// Keep it consistent with Bindings.
    /// </returns>
    function GetNamedBindings: TDictionary<string, TValue>;
    /// <summary>Returns Query for this instance.</summary>
    /// <returns>The retained source query, or nil for batch compilation.</returns>
    function GetQuery: IQuery;
    /// <summary>Replaces Query for this instance.</summary>
    /// <param name="Value">
    /// Retained query interface associated with compilation; the result keeps the query alive.
    /// </param>
    procedure SetQuery(const Value: IQuery);
  public
    /// <summary>
    /// RawSql contains positional ? placeholders; Sql contains executable named placeholders. Keep both texts
    /// consistent with the binding collections.
    /// </summary>
    RawSql, Sql: string;
    /// <summary>
    /// Borrowed ordered binding list owned by this result; entries correspond to RawSql placeholders. Do not
    /// free the list.
    /// </summary>
    Bindings: TList<TValue>;
    /// <summary>
    /// Borrowed dictionary owned by the result, keyed by full named parameter tokens including the prefix.
    /// Keep it consistent with Bindings.
    /// </summary>
    NamedBindings: TDictionary<string, TValue>;
    /// <summary>Retained source query for single-query compilation; nil for batch compilation.</summary>
    Query: IQuery; // retained by the result
    /// <summary>Creates empty binding collections owned by this result.</summary>
    constructor Create;
    /// <summary>
    /// Frees both binding collections; retained query references are released during destruction.
    /// </summary>
    /// <remarks>
    /// For interface-managed instances, release interface references instead of calling Destroy directly.
    /// </remarks>
    destructor Destroy; override;
    /// <summary>Formats a diagnostic SQL preview with parameter values substituted.</summary>
    /// <returns>Debug text that may contain sensitive parameter values; never execute it as SQL.</returns>
    /// <remarks>
    /// Preview formatting is not a complete driver/dialect literal serializer. Use parameterized Sql and
    /// bindings for execution.
    /// </remarks>
    function ToString: string; override;
  end;

  /// <summary>
  /// Low-level per-compilation binding accumulator and active query stack used by compiler extensions. The
  /// context owns its lists and retains stacked queries; callers own directly created contexts.
  /// </summary>
  TCompileContext = class
  public
    /// <summary>Owned binding accumulator in SQL placeholder order; do not free independently.</summary>
    Bindings: TList<TValue>;
    /// <summary>
    /// Owned active-query stack retaining interfaces; variable lookup searches from the last entry backward.
    /// </summary>
    Queries: TList<IQuery>;
    /// <summary>Creates an empty binding accumulator and active-query stack.</summary>
    constructor Create;
    /// <summary>Frees the binding list and retained-query stack.</summary>
    destructor Destroy; override;
    /// <summary>Resolves a variable from the active query stack, innermost first.</summary>
    /// <param name="Name">Variable name, matched by the query dictionary.</param>
    /// <returns>The first matching TValue; referenced objects remain application-owned.</returns>
    /// <exception cref="EQueryException">No active query defines Name.</exception>
    function FindVariable(const Name: string): TValue;
  end;

  /// <summary>
  /// SQL dialect compiler producing parameterized SQL and ordered/named bindings without execution. Compiler
  /// settings control syntax, not the database provider. Configure before use; driver capabilities and SQL
  /// support still vary by target database.
  /// </summary>
  ICompiler = interface
    ['{B86643F2-4FE8-465C-BD67-8F8D635EF4CD}']
    function GetEngineCode: string;
    function GetParameterPrefix: string;
    procedure SetParameterPrefix(const Value: string);
    function GetSupportsFilterClause: Boolean;
    procedure SetSupportsFilterClause(const Value: Boolean);
    function GetOmitSelectInsideExists: Boolean;
    procedure SetOmitSelectInsideExists(const Value: Boolean);
    function GetUseLegacyPagination: Boolean;
    procedure SetUseLegacyPagination(const Value: Boolean);
    /// <summary>Compiles the query into parameterized SQL and ordered/named bindings.</summary>
    /// <param name="Query">Non-nil query model to compile without executing it.</param>
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
    function Compile(Query: IQuery): ISqlResult; overload;
    /// <summary>Compiles a statement batch into parameterized SQL and ordered/named bindings.</summary>
    /// <param name="Queries">Statements to compile in order with one shared binding sequence.</param>
    /// <returns>
    /// A reference-counted SQL result owning its binding collections; no query is executed.
    /// </returns>
    /// <remarks>
    /// Dialect selection controls SQL syntax separately from provider selection. Bind values through the
    /// provider; use ToDebugSql or result ToString only for diagnostics. Batch statements share parameter
    /// ordinals and are separated by semicolons; the batch result does not retain a Query reference.
    /// </remarks>
    /// <exception cref="EQueryException">
    /// Query state, operator, SQL feature, or placeholder/binding counts cannot be compiled.
    /// </exception>
    function Compile(const Queries: array of IQuery): ISqlResult; overload;
    /// <summary>Quotes a qualified identifier and its optional AS alias for this dialect.</summary>
    /// <param name="Value">Identifier text to quote.</param>
    /// <returns>Quoted identifier SQL, preserving asterisk components.</returns>
    /// <remarks>Splits qualified names on dots; this is not an arbitrary SQL expression parser.</remarks>
    function Wrap(const Value: string): string;
    /// <summary>Quotes one identifier component and escapes its closing quote characters.</summary>
    /// <param name="Value">Identifier text to quote.</param>
    /// <returns>Quoted identifier text, or an unchanged asterisk.</returns>
    /// <remarks>
    /// Firebird uppercases the entire quoted identifier, including explicitly supplied quote characters;
    /// mixed-case identifier preservation is not provided.
    /// </remarks>
    function WrapValue(const Value: string): string;
    /// <summary>Replaces raw SQL identifier markers with dialect quote characters.</summary>
    /// <param name="Value">Trusted SQL containing {identifier} or [identifier] markers.</param>
    /// <returns>
    /// SQL with { } and [ ] markers translated; backslash-escaped markers become literal characters.
    /// </returns>
    /// <remarks>
    /// Performs character replacement rather than SQL syntax validation; raw text must be trusted.
    /// </remarks>
    function WrapIdentifiers(const Value: string): string;
    /// <summary>Splits an identifier at its final case-insensitive AS separator.</summary>
    /// <param name="Value">Identifier expression with an optional explicit AS alias.</param>
    /// <param name="Expression">
    /// Receives the identifier expression before its final case-insensitive AS separator.
    /// </param>
    /// <param name="Alias">Receives the final AS alias, or an empty string if absent.</param>
    /// <remarks>
    /// Does not parse SQL expressions; without a separator Alias is empty and Expression equals Value.
    /// </remarks>
    procedure SplitAlias(const Value: string; out Expression, Alias: string);
    /// <summary>Adds trusted custom comparison operators to this compiler.</summary>
    /// <param name="Operators">
    /// Trusted additional operator strings. Stored lowercase and emitted without SQL syntax validation.
    /// </param>
    /// <returns>This compiler instance for further configuration.</returns>
    /// <remarks>Values are lowercased and emitted as SQL; never whitelist untrusted input.</remarks>
    function Whitelist(const Operators: array of string): ICompiler;
    /// <summary>Produces the dialect Boolean true literal.</summary>
    /// <returns>SQL text representing true.</returns>
    function CompileTrue: string;
    /// <summary>Produces the dialect Boolean false literal.</summary>
    /// <returns>SQL text representing false.</returns>
    function CompileFalse: string;
    /// <summary>Produces the dialect random-order SQL expression.</summary>
    /// <param name="Seed">Optional random seed; some dialects ignore it.</param>
    /// <returns>Random function SQL; seed support varies by compiler.</returns>
    /// <remarks>
    /// MySQL uses a supplied seed, SQL Server ignores it for NEWID(), and base/Oracle/Firebird
    /// implementations ignore it.
    /// </remarks>
    function CompileRandom(const Seed: TValue): string;
    /// <summary>Wraps an existing SQL expression with LOWER.</summary>
    /// <param name="Value">Trusted SQL expression, already quoted or parameterized as needed.</param>
    /// <returns>LOWER(Value) SQL text.</returns>
    /// <remarks>Value is already SQL; no identifier quoting or parameterization is performed.</remarks>
    function CompileLower(const Value: string): string;
    /// <summary>Wraps an existing SQL expression with UPPER.</summary>
    /// <param name="Value">Trusted SQL expression, already quoted or parameterized as needed.</param>
    /// <returns>UPPER(Value) SQL text.</returns>
    /// <remarks>Value is already SQL; no identifier quoting or parameterization is performed.</remarks>
    function CompileUpper(const Value: string): string;
    /// <summary>
    /// Engine identifier used to select dialect-scoped clauses (sqlsrv, mysql, postgres, sqlite, oracle,
    /// firebird; generic for the base compiler).
    /// </summary>
    property EngineCode: string read GetEngineCode;
    /// <summary>
    /// Named parameter prefix followed by a zero-based ordinal. Compilers default to @p; executor defaults to
    /// :p. The selected provider must accept the convention.
    /// </summary>
    property ParameterPrefix: string read GetParameterPrefix
      write SetParameterPrefix;
    /// <summary>Whether filtered aggregates use SQL FILTER instead of a CASE expression fallback.</summary>
    property SupportsFilterClause: Boolean read GetSupportsFilterClause
      write SetSupportsFilterClause;
    /// <summary>
    /// Whether EXISTS compilation replaces the cloned subquery select list with the literal 1.
    /// </summary>
    property OmitSelectInsideExists: Boolean read GetOmitSelectInsideExists
      write SetOmitSelectInsideExists;
    /// <summary>
    /// Enables legacy pagination in SQL Server and Oracle compilers; other compilers may ignore this setting.
    /// </summary>
    property UseLegacyPagination: Boolean read GetUseLegacyPagination
      write SetUseLegacyPagination;
  end;

  /// <summary>
  /// Extensible, reference-counted SQL compiler. Create returns an ICompiler for the receiver class using its
  /// virtual instance constructor. Protected methods implement compilation internals; prefer ICompiler for
  /// ordinary use.
  /// </summary>
  TCompiler = class(TInterfacedObject, ICompiler)
  protected
    FEngineCode, FOpening, FClosing, FParameterPrefix, FLastId,
      FDummyTable: string;
    FColumnAs, FTableAs: string;
    FUserOperators: TList<string>;
    FSupportsJoinWrites: Boolean;
    constructor CreateInstance; virtual;
    function CheckDatePart(const Part: string): string;
    function DatePart(const Column, Part: string): string; virtual;
    function CompileAdHocTable(Context: TCompileContext; Clause: TClause)
      : string; virtual;
    function CompileOffsetFetch(Context: TCompileContext; Query: IQuery;
      const DefaultOrder: string): string;
    function CompileInsertRows(Context: TCompileContext;
      const TableSql, Columns: string; const Inserts: TArray<TClause>)
      : string; virtual;
    function CompileUpdateAssignments(Context: TCompileContext;
      Clause: TClause): string;
    function CompileJoinedUpdate(Context: TCompileContext; Query: IQuery;
      FromClause, UpdateClause: TClause): string; virtual;
    function CheckOperator(const Op: string): string;
    function Parameter(Context: TCompileContext; const Value: TValue)
      : string; virtual;
    function Parameterize(Context: TCompileContext;
      const Values: array of TValue): string;
    function Raw(Context: TCompileContext; const Sql: string;
      const Values: array of TValue): string;
    function Resolve(Context: TCompileContext; const Value: TValue): TValue;
    function Column(Context: TCompileContext; Clause: TClause): string; virtual;
    function Table(Context: TCompileContext; Clause: TClause): string; virtual;
    function Conditions(Context: TCompileContext; Query: IQuery;
      const Component: string): string;
    function Condition(Context: TCompileContext; Clause: TClause)
      : string; virtual;
    function DateCondition(Context: TCompileContext; Clause: TClause)
      : string; virtual;
    function CompileQuery(Context: TCompileContext; Query: IQuery;
      WithCtes: Boolean = True): string;
    function CompileSelect(Context: TCompileContext; Query: IQuery)
      : string; virtual;
    function CompileSelectCore(Context: TCompileContext; Query: IQuery): string;
    function CompileWrite(Context: TCompileContext; Query: IQuery)
      : string; virtual;
    function CompileCtes(Context: TCompileContext; Query: IQuery): string;
    function CompileJoins(Context: TCompileContext; Query: IQuery): string;
    function CompileOrders(Context: TCompileContext; Query: IQuery): string;
    function SelectPrefix(Context: TCompileContext; Query: IQuery)
      : string; virtual;
    function CompileLimit(Context: TCompileContext; Query: IQuery)
      : string; virtual;
    function AggregateQuery(Query: IQuery): IQuery;
    function WrapList(const Values: array of string): string;
    function JoinTarget(Clause: TClause): string;
  public
    /// <summary>Returns EngineCode for this instance.</summary>
    /// <returns>
    /// Engine identifier used to select dialect-scoped clauses (sqlsrv, mysql, postgres, sqlite, oracle,
    /// firebird; generic for the base compiler).
    /// </returns>
    function GetEngineCode: string;
    function GetParameterPrefix: string;
    procedure SetParameterPrefix(const Value: string);
    /// <summary>Returns SupportsFilterClause for this instance.</summary>
    /// <returns>Whether filtered aggregates use SQL FILTER instead of a CASE expression fallback.</returns>
    function GetSupportsFilterClause: Boolean;
    /// <summary>Replaces SupportsFilterClause for this instance.</summary>
    /// <param name="Value">
    /// Whether filtered aggregates use SQL FILTER instead of a CASE expression fallback.
    /// </param>
    procedure SetSupportsFilterClause(const Value: Boolean);
    /// <summary>Returns OmitSelectInsideExists for this instance.</summary>
    /// <returns>
    /// Whether EXISTS compilation replaces the cloned subquery select list with the literal 1.
    /// </returns>
    function GetOmitSelectInsideExists: Boolean;
    /// <summary>Replaces OmitSelectInsideExists for this instance.</summary>
    /// <param name="Value">
    /// Whether EXISTS compilation replaces the cloned subquery select list with the literal 1.
    /// </param>
    procedure SetOmitSelectInsideExists(const Value: Boolean);
    /// <summary>Returns UseLegacyPagination for this instance.</summary>
    /// <returns>
    /// Enables legacy pagination in SQL Server and Oracle compilers; other compilers may ignore this setting.
    /// </returns>
    function GetUseLegacyPagination: Boolean;
    /// <summary>Replaces UseLegacyPagination for this instance.</summary>
    /// <param name="Value">
    /// Enables legacy pagination in SQL Server and Oracle compilers; other compilers may ignore this setting.
    /// </param>
    procedure SetUseLegacyPagination(const Value: Boolean);
  public
    /// <summary>
    /// Mutable compiler flags: FILTER versus CASE for aggregates, replacing EXISTS select lists with 1, and
    /// legacy SQL Server/Oracle pagination. Configure before compilation.
    /// </summary>
    SupportsFilterClause, OmitSelectInsideExists, UseLegacyPagination: Boolean;
    // The class receiver selects the virtual instance constructor.
    /// <summary>Creates a reference-counted compiler for the receiver class.</summary>
    /// <returns>
    /// A new reference-counted interface; releasing the last reference destroys the instance.
    /// </returns>
    class function Create: ICompiler;
    /// <summary>Releases compiler operator configuration.</summary>
    /// <remarks>
    /// For interface-managed instances, release interface references instead of calling Destroy directly.
    /// </remarks>
    destructor Destroy; override;
    /// <summary>Compiles the query into parameterized SQL and ordered/named bindings.</summary>
    /// <param name="Query">Non-nil query model to compile without executing it.</param>
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
    function Compile(Query: IQuery): ISqlResult; overload; virtual;
    /// <summary>Compiles a statement batch into parameterized SQL and ordered/named bindings.</summary>
    /// <param name="Queries">Statements to compile in order with one shared binding sequence.</param>
    /// <returns>
    /// A reference-counted SQL result owning its binding collections; no query is executed.
    /// </returns>
    /// <remarks>
    /// Dialect selection controls SQL syntax separately from provider selection. Bind values through the
    /// provider; use ToDebugSql or result ToString only for diagnostics. Batch statements share parameter
    /// ordinals and are separated by semicolons; the batch result does not retain a Query reference.
    /// </remarks>
    /// <exception cref="EQueryException">
    /// Query state, operator, SQL feature, or placeholder/binding counts cannot be compiled.
    /// </exception>
    function Compile(const Queries: array of IQuery): ISqlResult;
      overload; virtual;
    /// <summary>Quotes a qualified identifier and its optional AS alias for this dialect.</summary>
    /// <param name="Value">Identifier text to quote.</param>
    /// <returns>Quoted identifier SQL, preserving asterisk components.</returns>
    /// <remarks>Splits qualified names on dots; this is not an arbitrary SQL expression parser.</remarks>
    function Wrap(const Value: string): string; virtual;
    /// <summary>Quotes one identifier component and escapes its closing quote characters.</summary>
    /// <param name="Value">Identifier text to quote.</param>
    /// <returns>Quoted identifier text, or an unchanged asterisk.</returns>
    /// <remarks>
    /// Firebird uppercases the entire quoted identifier, including explicitly supplied quote characters;
    /// mixed-case identifier preservation is not provided.
    /// </remarks>
    function WrapValue(const Value: string): string; virtual;
    /// <summary>Replaces raw SQL identifier markers with dialect quote characters.</summary>
    /// <param name="Value">Trusted SQL containing {identifier} or [identifier] markers.</param>
    /// <returns>
    /// SQL with { } and [ ] markers translated; backslash-escaped markers become literal characters.
    /// </returns>
    /// <remarks>
    /// Performs character replacement rather than SQL syntax validation; raw text must be trusted.
    /// </remarks>
    function WrapIdentifiers(const Value: string): string; virtual;
    /// <summary>Splits an identifier at its final case-insensitive AS separator.</summary>
    /// <param name="Value">Identifier expression with an optional explicit AS alias.</param>
    /// <param name="Expression">
    /// Receives the identifier expression before its final case-insensitive AS separator.
    /// </param>
    /// <param name="Alias">Receives the final AS alias, or an empty string if absent.</param>
    /// <remarks>
    /// Does not parse SQL expressions; without a separator Alias is empty and Expression equals Value.
    /// </remarks>
    procedure SplitAlias(const Value: string; out Expression, Alias: string);
    /// <summary>Adds trusted custom comparison operators to this compiler.</summary>
    /// <param name="Operators">
    /// Trusted additional operator strings. Stored lowercase and emitted without SQL syntax validation.
    /// </param>
    /// <returns>This compiler instance for further configuration.</returns>
    /// <remarks>Values are lowercased and emitted as SQL; never whitelist untrusted input.</remarks>
    function Whitelist(const Operators: array of string): ICompiler;
    /// <summary>Produces the dialect Boolean true literal.</summary>
    /// <returns>SQL text representing true.</returns>
    function CompileTrue: string; virtual;
    /// <summary>Produces the dialect Boolean false literal.</summary>
    /// <returns>SQL text representing false.</returns>
    function CompileFalse: string; virtual;
    /// <summary>Produces the dialect random-order SQL expression.</summary>
    /// <param name="Seed">Ignored by the base compiler.</param>
    /// <returns>RANDOM() SQL.</returns>
    /// <remarks>Dialect subclasses can override the expression and seed support.</remarks>
    function CompileRandom(const Seed: TValue): string; virtual;
    /// <summary>Wraps an existing SQL expression with LOWER.</summary>
    /// <param name="Value">Trusted SQL expression, already quoted or parameterized as needed.</param>
    /// <returns>LOWER(Value) SQL text.</returns>
    /// <remarks>Value is already SQL; no identifier quoting or parameterization is performed.</remarks>
    function CompileLower(const Value: string): string;
    /// <summary>Wraps an existing SQL expression with UPPER.</summary>
    /// <param name="Value">Trusted SQL expression, already quoted or parameterized as needed.</param>
    /// <returns>UPPER(Value) SQL text.</returns>
    /// <remarks>Value is already SQL; no identifier quoting or parameterization is performed.</remarks>
    function CompileUpper(const Value: string): string;
    /// <summary>
    /// Engine identifier used to select dialect-scoped clauses (sqlsrv, mysql, postgres, sqlite, oracle,
    /// firebird; generic for the base compiler).
    /// </summary>
    property EngineCode: string read FEngineCode;
    /// <summary>
    /// Named parameter prefix followed by a zero-based ordinal. Compilers default to @p; executor defaults to
    /// :p. The selected provider must accept the convention.
    /// </summary>
    property ParameterPrefix: string read GetParameterPrefix
      write SetParameterPrefix;
  end;

implementation

uses System.StrUtils, System.TypInfo, System.Variants,
  System.RegularExpressions,
  QueryBuilder4Delphi.Query, QueryBuilder4Delphi.Sql.Lexer;

function TCompiler.GetParameterPrefix: string;
begin
  Result := FParameterPrefix;
end;

procedure TCompiler.SetParameterPrefix(const Value: string);
begin
  FParameterPrefix := Value;
end;

function TSqlResult.GetRawSql: string;
begin
  Result := RawSql;
end;

procedure TSqlResult.SetRawSql(const Value: string);
begin
  RawSql := Value;
end;

function TSqlResult.GetSql: string;
begin
  Result := Sql;
end;

procedure TSqlResult.SetSql(const Value: string);
begin
  Sql := Value;
end;

function TSqlResult.GetBindings: TList<TValue>;
begin
  Result := Bindings;
end;

function TSqlResult.GetNamedBindings: TDictionary<string, TValue>;
begin
  Result := NamedBindings;
end;

function TSqlResult.GetQuery: IQuery;
begin
  Result := Query;
end;

procedure TSqlResult.SetQuery(const Value: IQuery);
begin
  Query := Value;
end;

function TCompiler.GetEngineCode: string;
begin
  Result := FEngineCode;
end;

function TCompiler.GetSupportsFilterClause: Boolean;
begin
  Result := SupportsFilterClause;
end;

procedure TCompiler.SetSupportsFilterClause(const Value: Boolean);
begin
  SupportsFilterClause := Value;
end;

function TCompiler.GetOmitSelectInsideExists: Boolean;
begin
  Result := OmitSelectInsideExists;
end;

procedure TCompiler.SetOmitSelectInsideExists(const Value: Boolean);
begin
  OmitSelectInsideExists := Value;
end;

function TCompiler.GetUseLegacyPagination: Boolean;
begin
  Result := UseLegacyPagination;
end;

procedure TCompiler.SetUseLegacyPagination(const Value: Boolean);
begin
  UseLegacyPagination := Value;
end;

class function TCompiler.Create: ICompiler;
begin
  Result := Self.CreateInstance;
end;

function SqlValue(const Value: TValue): string;
var
  V: Variant;
  D: TDateTime;
begin
  if Value.IsEmpty or Value.IsType<TQueryNull>(False) then
    Exit('NULL');
  if Value.TypeInfo = TypeInfo(TDateTime) then
  begin
    D := Value.AsType<TDateTime>;
    if Frac(D) = 0 then
      Exit(QuotedStr(FormatDateTime('yyyy-mm-dd', D)))
    else
      Exit(QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss', D)));
  end;
  if Value.TypeInfo = TypeInfo(Boolean) then
    if Value.AsBoolean then
      Exit('true')
    else
      Exit('false');
  case Value.Kind of
    tkInteger, tkInt64:
      Exit(Value.ToString);
    tkFloat:
      Exit(FloatToStr(Value.AsExtended, TFormatSettings.Invariant));
    tkVariant:
      begin
        V := Value.AsVariant;
        if VarIsNull(V) or VarIsEmpty(V) then
          Exit('NULL');
        if VarIsNumeric(V) then
          Exit(FloatToStr(V, TFormatSettings.Invariant));
      end;
  end;
  Result := QuotedStr(Value.ToString);
end;

// Preserve escaped question marks exactly as in the C# Helper.ReplaceAll.
function ReplaceParameters(const Sql: string; const Bindings: TList<TValue>;
  const Prefix: string; InlineValues: Boolean;
  BackslashEscapes: Boolean = False): string;
var
  I, N: Integer;
  Mask: TArray<Boolean>;
begin
  Mask := SqlCodeMask(Sql, BackslashEscapes);
  Result := '';
  I := 1;
  N := 0;
  while I <= Length(Sql) do
  begin
    if Mask[I - 1] and (Sql[I] = '?') and ((I = 1) or (Sql[I - 1] <> '\')) then
    begin
      if N >= Bindings.Count then
        raise EQueryException.Create('Not enough bindings');
      if InlineValues then
        Result := Result + SqlValue(Bindings[N])
      else
        Result := Result + Prefix + IntToStr(N);
      Inc(N);
    end
    else
      Result := Result + Sql[I];
    Inc(I);
  end;
  if N <> Bindings.Count then
    raise EQueryException.Create('Binding/placeholder count mismatch');
  if InlineValues then
    Result := StringReplace(Result, '\?', '?', [rfReplaceAll]);
end;

constructor TSqlResult.Create;
begin
  inherited;
  Bindings := TList<TValue>.Create;
  NamedBindings := TDictionary<string, TValue>.Create;
end;

destructor TSqlResult.Destroy;
begin
  NamedBindings.Free;
  Bindings.Free;
  inherited;
end;

function TSqlResult.ToString: string;
begin
  Result := ReplaceParameters(RawSql, Bindings, '', True);
end;

constructor TCompileContext.Create;
begin
  inherited;
  Bindings := TList<TValue>.Create;
  Queries := TList<IQuery>.Create;
end;

destructor TCompileContext.Destroy;
begin
  Queries.Free;
  Bindings.Free;
  inherited;
end;

function TCompileContext.FindVariable(const Name: string): TValue;
var
  I: Integer;
begin
  for I := Queries.Count - 1 downto 0 do
    if Queries[I].Variables.TryGetValue(Name, Result) then
      Exit;
  raise EQueryException.CreateFmt('Variable ''%s'' not found', [Name]);
end;

constructor TCompiler.CreateInstance;
begin
  inherited;
  FUserOperators := TList<string>.Create;
  FEngineCode := 'generic';
  FOpening := '"';
  FClosing := '"';
  FParameterPrefix := '@p';
  FColumnAs := 'AS ';
  FTableAs := 'AS ';
  OmitSelectInsideExists := True;
  FSupportsJoinWrites := True;
end;

destructor TCompiler.Destroy;
begin
  FUserOperators.Free;
  inherited;
end;

function TCompiler.Whitelist(const Operators: array of string): ICompiler;
var
  Op: string;
begin
  for Op in Operators do
    FUserOperators.Add(LowerCase(Op));
  Result := Self;
end;

function TCompiler.CheckOperator(const Op: string): string;
begin
  Result := LowerCase(Op);
  if not MatchStr(Result, ['=', '<', '>', '<=', '>=', '<>', '!=', '<=>', 'like',
    'not like', 'ilike', 'not ilike', 'like binary', 'not like binary', 'rlike',
    'not rlike', 'regexp', 'not regexp', 'similar to', 'not similar to']) and
    not FUserOperators.Contains(Result) then
    raise EQueryException.CreateFmt('Operator ''%s'' is not whitelisted', [Op]);
end;

procedure TCompiler.SplitAlias(const Value: string;
  out Expression, Alias: string);
var
  P: Integer;
begin
  P := LowerCase(Value).LastIndexOf(' as ') + 1;
  if P = 0 then
  begin
    Expression := Value;
    Alias := '';
  end
  else
  begin
    Expression := Copy(Value, 1, P - 1);
    Alias := Copy(Value, P + 4, MaxInt);
  end;
end;

function TCompiler.WrapValue(const Value: string): string;
begin
  if Value = '*' then
    Exit('*');
  Result := FOpening + StringReplace(Value, FClosing, FClosing + FClosing,
    [rfReplaceAll]) + FClosing;
end;

function TCompiler.Wrap(const Value: string): string;
var
  Expr, Alias, Part: string;
begin
  SplitAlias(Value, Expr, Alias);
  Result := '';
  for Part in Expr.Split(['.']) do
  begin
    if Result <> '' then
      Result := Result + '.';
    Result := Result + WrapValue(Part);
  end;
  if Alias <> '' then
    Result := Result + ' ' + FColumnAs + WrapValue(Alias);
end;

function TCompiler.WrapList(const Values: array of string): string;
var
  S: string;
begin
  Result := '';
  for S in Values do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + Wrap(S);
  end;
end;

function TCompiler.WrapIdentifiers(const Value: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  I := 1;
  while I <= Length(Value) do
  begin
    C := Value[I];
    if (C = '\') and (I < Length(Value)) and
      CharInSet(Value[I + 1], ['{', '}', '[', ']']) then
    begin
      Inc(I);
      Result := Result + Value[I];
    end
    else
      case C of
        '{', '[':
          Result := Result + FOpening;
        '}', ']':
          Result := Result + FClosing;
      else
        Result := Result + C;
      end;
    Inc(I);
  end;
end;

function TCompiler.Resolve(Context: TCompileContext;
  const Value: TValue): TValue;
begin
  Result := Value;
  if Value.IsEmpty then
    Exit;
  if Value.IsType<TVariable> then
    Result := Context.FindVariable(Value.AsType<TVariable>.Name)
  else if Value.IsType<TUnsafeLiteral> then
    Result := Value.AsType<TUnsafeLiteral>.Value;
end;

function TCompiler.Parameter(Context: TCompileContext;
  const Value: TValue): string;
begin
  if not Value.IsEmpty and Value.IsType<TUnsafeLiteral> then
    Exit(Value.AsType<TUnsafeLiteral>.Value);
  Context.Bindings.Add(Resolve(Context, Value));
  Result := '?';
end;

function TCompiler.Parameterize(Context: TCompileContext;
  const Values: array of TValue): string;
var
  V: TValue;
begin
  Result := '';
  for V in Values do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + Parameter(Context, V);
  end;
end;

function TCompiler.Raw(Context: TCompileContext; const Sql: string;
  const Values: array of TValue): string;
var
  I, N, J: Integer;
  V: TValue;
  S: string;
  Mask: TArray<Boolean>;
begin
  Result := '';
  N := 0;
  S := WrapIdentifiers(Sql);
  Mask := SqlCodeMask(S, FEngineCode = 'mysql');
  for I := 1 to Length(S) do
  begin
    if Mask[I - 1] and (S[I] = '?') and ((I = 1) or (S[I - 1] <> '\')) then
    begin
      if N >= Length(Values) then
        raise EQueryException.Create('Not enough raw bindings');
      V := Values[N];
      Inc(N);
      if (V.Kind in [tkArray, tkDynArray]) and (V.TypeInfo <> TypeInfo(TBytes))
      then
      begin
        for J := 0 to V.GetArrayLength - 1 do
        begin
          if J > 0 then
            Result := Result + ',';
          Result := Result + Parameter(Context, V.GetArrayElement(J));
        end;
      end
      else
        Result := Result + Parameter(Context, V);
    end
    else
      Result := Result + S[I];
  end;
  if N <> Length(Values) then
    raise EQueryException.Create('Too many raw bindings');
end;

function TCompiler.Compile(Query: IQuery): ISqlResult;
begin
  Result := Compile([Query]);
  Result.Query := Query;
end;

function TCompiler.Compile(const Queries: array of IQuery): ISqlResult;
var
  Context: TCompileContext;
  Q: IQuery;
  N: Integer;
begin
  Context := TCompileContext.Create;
  try
    Result := TSqlResult.Create;
    for Q in Queries do
    begin
      if Q = nil then
        raise EArgumentNilException.Create('Query');
      if Result.RawSql <> '' then
        Result.RawSql := Result.RawSql + ';' + #10;
      Result.RawSql := Result.RawSql + CompileQuery(Context, Q);
    end;
    Result.Bindings.AddRange(Context.Bindings);
    Result.Sql := ReplaceParameters(Result.RawSql, Result.Bindings,
      FParameterPrefix, False, FEngineCode = 'mysql');
    for N := 0 to Result.Bindings.Count - 1 do
      Result.NamedBindings.Add(FParameterPrefix + IntToStr(N),
        Result.Bindings[N]);
  finally
    Context.Free;
  end;
end;

function TCompiler.CompileQuery(Context: TCompileContext; Query: IQuery;
  WithCtes: Boolean): string;
var
  Q: IQuery;
begin
  Q := Query;
  if WithCtes and (Query.Method = 'aggregate') then
    Q := AggregateQuery(Query);
  Context.Queries.Add(Query);
  try
    Result := '';
    if WithCtes then
      Result := CompileCtes(Context, Q);
    if MatchStr(Q.Method, ['insert', 'update', 'delete']) then
      Result := Result + CompileWrite(Context, Q)
    else
      Result := Result + CompileSelect(Context, Q);
  finally
    Context.Queries.Delete(Context.Queries.Count - 1);
  end;
end;

function TCompiler.Column(Context: TCompileContext; Clause: TClause): string;
var
  Expr, Alias, Filter: string;
begin
  case Clause.Kind of
    ckRaw:
      Result := Raw(Context, Clause.Name, Clause.Values);
    ckQuery:
      begin
        Result := '(' + CompileQuery(Context, Clause.Query, False) + ')';
        if Clause.Query.QueryAlias <> '' then
          Result := Result + ' ' + FColumnAs +
            WrapValue(Clause.Query.QueryAlias);
      end;
    ckAggregate:
      begin
        SplitAlias(Clause.Name, Expr, Alias);
        Expr := Wrap(Expr);
        Filter := '';
        if Clause.Query <> nil then
          Filter := Conditions(Context, Clause.Query, 'where');
        if Filter = '' then
          Result := UpperCase(Clause.Op) + '(' + Expr + ')'
        else if SupportsFilterClause then
          Result := UpperCase(Clause.Op) + '(' + Expr + ') FILTER (WHERE ' +
            Filter + ')'
        else
          Result := UpperCase(Clause.Op) + '(CASE WHEN ' + Filter + ' THEN ' +
            Expr + ' END)';
        if Alias <> '' then
          Result := Result + ' ' + FColumnAs + WrapValue(Alias);
      end;
  else
    Result := Wrap(Clause.Name);
  end;
end;

function TCompiler.Table(Context: TCompileContext; Clause: TClause): string;
begin
  if Clause = nil then
    raise EQueryException.Create('No table set');
  case Clause.Kind of
    ckIdentifier:
      Result := Wrap(Clause.Name);
    ckRaw:
      Result := Raw(Context, Clause.Name, Clause.Values);
    ckQuery:
      begin
        Result := '(' + CompileQuery(Context, Clause.Query, False) + ')';
        if Clause.Query.QueryAlias <> '' then
          Result := Result + ' ' + FTableAs +
            WrapValue(Clause.Query.QueryAlias);
      end;
    ckAdHoc:
      Result := CompileAdHocTable(Context, Clause);
  else
    raise EQueryException.Create('Invalid table expression');
  end;
end;

function TCompiler.CompileAdHocTable(Context: TCompileContext;
  Clause: TClause): string;
var
  I, J: Integer;
  Row: string;
begin
  Result := '';
  for I := 0 to Length(Clause.Values) div Length(Clause.Columns) - 1 do
  begin
    Row := 'SELECT ';
    for J := 0 to High(Clause.Columns) do
    begin
      if J > 0 then
        Row := Row + ', ';
      Row := Row + Parameter(Context,
        Clause.Values[I * Length(Clause.Columns) + J]) + ' AS ' +
        Wrap(Clause.Columns[J]);
    end;
    if FDummyTable <> '' then
      Row := Row + ' FROM ' + FDummyTable;
    if Result <> '' then
      Result := Result + ' UNION ALL ';
    Result := Result + Row;
  end;
end;

function TCompiler.Conditions(Context: TCompileContext; Query: IQuery;
  const Component: string): string;
var
  C: TClause;
  S: string;
begin
  Result := '';
  for C in Query.GetComponents(Component, EngineCode) do
  begin
    S := Condition(Context, C);
    if S = '' then
      Continue;
    if Result <> '' then
      if C.IsOr then
        Result := Result + ' OR '
      else
        Result := Result + ' AND ';
    Result := Result + S;
  end;
end;

function TCompiler.Condition(Context: TCompileContext; Clause: TClause): string;
var
  C: TClause;
  V: TValue;
  S, Op: string;
  Neg: Boolean;
  Q: IQuery;
begin
  C := Clause;
  Neg := C.IsNot;
  case C.Kind of
    ckRaw:
      Exit(Raw(Context, C.Name, C.Values));
    ckNested:
      begin
        S := Conditions(Context, C.Query, 'where');
        if S = '' then
          S := Conditions(Context, C.Query, 'having');
        if S = '' then
          Exit('');
        Result := '(' + S + ')';
        if Neg then
          Result := 'NOT ' + Result;
        Exit;
      end;
    ckNull:
      begin
        Result := Wrap(C.Name) + ' IS ';
        if Neg then
          Result := Result + 'NOT ';
        Result := Result + 'NULL';
        Exit;
      end;
    ckBoolean:
      begin
        if C.Value.AsBoolean then
          S := CompileTrue
        else
          S := CompileFalse;
        if Neg then
          Op := ' != '
        else
          Op := ' = ';
        Result := Wrap(C.Name) + Op + S;
        Exit;
      end;
    ckBasic:
      begin
        V := C.Value;
        if V.IsType<TQueryNull>(False) or
          (V.IsEmpty and (V.TypeInfo <> TypeInfo(TBytes))) or
          ((V.Kind = tkVariant) and VarIsNull(V.AsVariant)) then
        begin
          Result := Wrap(C.Name) + ' IS ';
          if Neg or (C.Op <> '=') then
            Result := Result + 'NOT ';
          Exit(Result + 'NULL');
        end;
        if V.TypeInfo = TypeInfo(Boolean) then
        begin
          if V.AsBoolean then
            S := CompileTrue
          else
            S := CompileFalse;
          if Neg or (C.Op <> '=') then
            Op := ' != '
          else
            Op := ' = ';
          Exit(Wrap(C.Name) + Op + S);
        end;
        Result := Wrap(C.Name) + ' ' + CheckOperator(C.Op) + ' ' +
          Parameter(Context, V);
      end;
    ckColumns:
      begin
        Result := Wrap(C.Name) + ' ' + CheckOperator(C.Op) + ' ' +
          Wrap(C.Extra);
        if Neg then
          Result := 'NOT ' + Result;
        Exit;
      end;
    ckString:
      begin
        V := Resolve(Context, C.Value);
        if not(V.Kind in [tkString, tkLString, tkWString, tkUString]) then
          raise EQueryException.Create('Expecting a non-null string');
        S := V.AsString;
        Op := 'like';
        if C.Op = 'starts' then
          S := S + '%'
        else if C.Op = 'ends' then
          S := '%' + S
        else if C.Op = 'contains' then
          S := '%' + S + '%';
        if C.Value.IsType<TUnsafeLiteral> then
          Result := Wrap(C.Name) + ' ' + Op + ' ' + S
        else
          Result := Wrap(C.Name) + ' ' + Op + ' ' + Parameter(Context, S);
        if C.Extra <> '' then
          Result := Result + ' ESCAPE ' + QuotedStr(C.Extra);
      end;
    ckDate:
      Result := DateCondition(Context, C);
    ckBetween:
      begin
        Result := Wrap(C.Name) + ' ';
        if Neg then
          Result := Result + 'NOT ';
        Result := Result + 'BETWEEN ' + Parameter(Context, C.Value) + ' AND ' +
          Parameter(Context, C.Value2);
        Exit;
      end;
    ckIn, ckInQuery:
      begin
        if (C.Kind = ckIn) and (Length(C.Values) = 0) then
          if Neg then
            Exit('1 = 1 /* NOT IN [empty list] */')
          else
            Exit('1 = 0 /* IN [empty list] */');
        Result := Wrap(C.Name) + ' ';
        if Neg then
          Result := Result + 'NOT ';
        Result := Result + 'IN (';
        if C.Kind = ckIn then
          Result := Result + Parameterize(Context, C.Values)
        else
          Result := Result + CompileQuery(Context, C.Query, False);
        Exit(Result + ')');
      end;
    ckExists:
      begin
        Q := C.Query.Clone;
        if OmitSelectInsideExists then
          Q.ClearComponent('select').SelectRaw('1');
        Result := 'EXISTS (' + CompileQuery(Context, Q, False) + ')';
        if Neg then
          Result := 'NOT ' + Result;
        Exit;
      end;
    ckQuery:
      Result := Wrap(C.Name) + ' ' + CheckOperator(C.Op) + ' (' +
        CompileQuery(Context, C.Query, False) + ')';
    ckSubQuery:
      Result := '(' + CompileQuery(Context, C.Query, False) + ') ' +
        CheckOperator(C.Op) + ' ' + Parameter(Context, C.Value);
  else
    raise EQueryException.Create('Unsupported condition');
  end;
  if Neg then
    Result := 'NOT (' + Result + ')';
end;

function TCompiler.CompileCtes(Context: TCompileContext; Query: IQuery): string;
var
  Seen: TList<string>;
  procedure Visit(Q: IQuery);
  var
    C: TClause;
    S: string;
  begin
    for C in Q.GetComponents('cte', EngineCode) do
    begin
      if Seen.Contains(C.Alias) then
        Continue;
      Seen.Add(C.Alias);
      if C.Query <> nil then
        Visit(C.Query);
      if Result <> '' then
        Result := Result + ',' + #10;
      if C.Kind = ckQuery then
        S := CompileQuery(Context, C.Query, False)
      else if C.Kind = ckRaw then
        S := Raw(Context, C.Name, C.Values)
      else
        S := Table(Context, C);
      Result := Result + WrapValue(C.Alias) + ' AS (' + S + ')';
    end;
  end;

begin
  Result := '';
  Seen := TList<string>.Create;
  try
    Visit(Query);
  finally
    Seen.Free;
  end;
  if Result <> '' then
    Result := 'WITH ' + Result + #10;
end;

function TCompiler.CompileJoins(Context: TCompileContext;
  Query: IQuery): string;
var
  C: TClause;
  S: string;
begin
  Result := '';
  for C in Query.GetComponents('join', EngineCode) do
  begin
    Result := Result + ' ' + #10 + C.Query.JoinType + ' ' +
      Table(Context, C.Query.GetOne('from', EngineCode));
    S := Conditions(Context, C.Query, 'where');
    if S <> '' then
      Result := Result + ' ON ' + S;
  end;
end;

function TCompiler.CompileOrders(Context: TCompileContext;
  Query: IQuery): string;
var
  C: TClause;
  S: string;
begin
  Result := '';
  for C in Query.GetComponents('order', EngineCode) do
  begin
    if C.Kind = ckRandom then
      S := CompileRandom(C.Value)
    else
    begin
      S := Column(Context, C);
      if C.IsNot then
        S := S + ' DESC';
    end;
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + S;
  end;
  if Result <> '' then
    Result := 'ORDER BY ' + Result;
end;

function TCompiler.CompileSelectCore(Context: TCompileContext;
  Query: IQuery): string;
var
  C, A: TClause;
  S, Columns: string;
begin
  Result := SelectPrefix(Context, Query);
  Columns := '';
  A := Query.GetOne('aggregate', EngineCode);
  if A <> nil then
  begin
    if Length(A.Columns) = 1 then
      Columns := UpperCase(A.Op) + '(' + Wrap(A.Columns[0]) + ') ' + FColumnAs +
        WrapValue(A.Op)
    else
      Columns := '1';
  end
  else
    for C in Query.GetComponents('select', EngineCode) do
    begin
      if Columns <> '' then
        Columns := Columns + ', ';
      Columns := Columns + Column(Context, C);
    end;
  if Columns = '' then
    Columns := '*';
  Result := Result + Columns;
  C := Query.GetOne('from', EngineCode);
  if C <> nil then
    Result := Result + ' FROM ' + Table(Context, C);
  Result := Result + CompileJoins(Context, Query);
  S := Conditions(Context, Query, 'where');
  if S <> '' then
    Result := Result + ' WHERE ' + S;
  S := '';
  for C in Query.GetComponents('group', EngineCode) do
  begin
    if S <> '' then
      S := S + ', ';
    S := S + Column(Context, C);
  end;
  if S <> '' then
    Result := Result + ' GROUP BY ' + S;
  S := Conditions(Context, Query, 'having');
  if S <> '' then
    Result := Result + ' HAVING ' + S;
  S := CompileOrders(Context, Query);
  if S <> '' then
    Result := Result + ' ' + S;
  S := CompileLimit(Context, Query);
  if S <> '' then
    Result := Result + ' ' + S;
  for C in Query.GetComponents('combine', EngineCode) do
  begin
    if C.Kind = ckRaw then
      S := Raw(Context, C.Name, C.Values)
    else
    begin
      S := UpperCase(C.Op) + ' ';
      if C.IsNot then
        S := S + 'ALL ';
      S := S + CompileQuery(Context, C.Query, False);
    end;
    Result := Result + ' ' + S;
  end;
end;

function TCompiler.AggregateQuery(Query: IQuery): IQuery;
var
  A, Outer: TClause;
  Inner: IQuery;
  S: string;
begin
  A := Query.GetOne('aggregate', EngineCode);
  if A = nil then
    raise EQueryException.Create('Missing aggregate');
  Inner := Query.Clone;
  Inner.ClearComponent('limit').ClearComponent('order').ClearComponent('group');
  if (Length(A.Columns) = 1) and not Query.IsDistinct then
  begin
    Result := Inner;
    Inner := nil;
    Exit;
  end;
  if Query.IsDistinct then
  begin
    Inner.ClearComponent('aggregate').ClearComponent('select')
      .Select(A.Columns);
    Inner.Method := 'select';
  end
  else
    for S in A.Columns do
      Inner.WhereNotNull(S);
  Result := TQuery.Create;
  Result.&From(Inner, A.Op + 'Query');
  Outer := Result.Add('aggregate', ckAggregate);
  Outer.Op := A.Op;
  Outer.Columns := TArray<string>.Create('*');
end;

function TCompiler.JoinTarget(Clause: TClause): string;
var
  Expr, Alias: string;
begin
  SplitAlias(Clause.Name, Expr, Alias);
  if Alias <> '' then
    Exit(WrapValue(Alias.Trim(['[', ']', '"', '`'])));
  if Clause.Kind = ckRaw then
    Exit(WrapIdentifiers(Clause.Name));
  Result := WrapValue(Copy(Expr, LastDelimiter('.', Expr) + 1, MaxInt));
end;

function TCompiler.CompileTrue: string;
begin
  Result := 'true';
end;

function TCompiler.CompileFalse: string;
begin
  Result := 'false';
end;

function TCompiler.CompileRandom(const Seed: TValue): string;
begin
  Result := 'RANDOM()';
end;

function TCompiler.SelectPrefix(Context: TCompileContext;
  Query: IQuery): string;
begin
  Result := 'SELECT ';
  if (Query.GetOne('aggregate', EngineCode) = nil) and Query.IsDistinct then
    Result := Result + 'DISTINCT ';
end;

function TCompiler.CompileSelect(Context: TCompileContext;
  Query: IQuery): string;
begin
  Result := CompileSelectCore(Context, Query);
end;

function TCompiler.CompileLimit(Context: TCompileContext;
  Query: IQuery): string;
var
  L: Integer;
  O: Int64;
begin
  Result := '';
  L := Query.GetLimit(EngineCode);
  O := Query.GetOffset(EngineCode);
  if L > 0 then
    Result := 'LIMIT ' + Parameter(Context, L);
  if O > 0 then
  begin
    if Result <> '' then
      Result := Result + ' ';
    Result := Result + 'OFFSET ' + Parameter(Context, O);
  end;
end;

function TCompiler.CompileOffsetFetch(Context: TCompileContext; Query: IQuery;
  const DefaultOrder: string): string;
var
  L: Integer;
  O: Int64;
begin
  Result := '';
  L := Query.GetLimit(EngineCode);
  O := Query.GetOffset(EngineCode);
  if (L = 0) and (O = 0) then
    Exit;
  if not Query.HasComponent('order', EngineCode) then
    Result := DefaultOrder + ' ';
  Result := Result + 'OFFSET ' + Parameter(Context, O) + ' ROWS';
  if L > 0 then
    Result := Result + ' FETCH NEXT ' + Parameter(Context, L) + ' ROWS ONLY';
end;

function TCompiler.CheckDatePart(const Part: string): string;
begin
  Result := LowerCase(Part);
  if not TRegEx.IsMatch(Result, '^[a-z_]+$') then
    raise EQueryException.Create('Unsupported date part: ' + Part);
end;

function TCompiler.DatePart(const Column, Part: string): string;
begin
  Result := UpperCase(Part) + '(' + Column + ')';
end;

function TCompiler.DateCondition(Context: TCompileContext;
  Clause: TClause): string;
var
  Col, Part, Op, V: string;
begin
  Col := Wrap(Clause.Name);
  Part := CheckDatePart(Clause.Extra);
  Op := CheckOperator(Clause.Op);
  V := Parameter(Context, Clause.Value);
  Result := DatePart(Col, Part) + ' ' + Op + ' ' + V;
end;

function TCompiler.CompileInsertRows(Context: TCompileContext;
  const TableSql, Columns: string; const Inserts: TArray<TClause>): string;
var
  I: Integer;
begin
  Result := 'INSERT INTO ' + TableSql + Columns + ' VALUES ';
  for I := 0 to High(Inserts) do
  begin
    if I > 0 then
      Result := Result + ', ';
    Result := Result + '(' + Parameterize(Context, Inserts[I].Values) + ')';
  end;
end;

function TCompiler.CompileUpdateAssignments(Context: TCompileContext;
  Clause: TClause): string;
var
  J: Integer;
  Sign: string;
begin
  Result := '';
  if Clause.Kind = ckIncrement then
  begin
    if Clause.Value.AsInteger < 0 then
      Sign := '-'
    else
      Sign := '+';
    Exit(Wrap(Clause.Name) + ' = ' + Wrap(Clause.Name) + ' ' + Sign + ' ' +
      Parameter(Context, Int64(Abs(Int64(Clause.Value.AsInteger)))));
  end;
  for J := 0 to High(Clause.Columns) do
  begin
    if J > 0 then
      Result := Result + ', ';
    Result := Result + Wrap(Clause.Columns[J]) + ' = ' +
      Parameter(Context, Clause.Values[J]);
  end;
end;

function TCompiler.CompileJoinedUpdate(Context: TCompileContext; Query: IQuery;
  FromClause, UpdateClause: TClause): string;
var
  Target, Sets: string;
begin
  Target := JoinTarget(FromClause);
  // SET bindings precede the raw FROM/JOIN bindings in this form.
  Sets := CompileUpdateAssignments(Context, UpdateClause);
  Result := 'UPDATE ' + Target + ' SET ' + Sets + ' FROM ' +
    Table(Context, FromClause) + CompileJoins(Context, Query);
end;

function TCompiler.CompileWrite(Context: TCompileContext;
  Query: IQuery): string;
var
  F, C: TClause;
  Inserts: TArray<TClause>;
  TableSql, Columns, S: string;
  HasJoins: Boolean;
begin
  F := Query.GetOne('from', EngineCode);
  if (F = nil) or not(F.Kind in [ckIdentifier, ckRaw]) then
    raise EQueryException.Create('No valid table set for write');
  HasJoins := Query.HasComponent('join', EngineCode);
  if HasJoins and not FSupportsJoinWrites then
    raise EQueryException.Create
      (EngineCode + ' does not support writes with JOIN clauses');
  if Query.Method = 'insert' then
  begin
    TableSql := Table(Context, F);
    Inserts := Query.GetComponents('insert', EngineCode);
    if Length(Inserts) = 0 then
      raise EQueryException.Create('No insert data');
    C := Inserts[0];
    Columns := '';
    if Length(C.Columns) > 0 then
      Columns := ' (' + WrapList(C.Columns) + ')';
    if C.Kind = ckQuery then
      Exit('INSERT INTO ' + TableSql + Columns + ' ' + CompileQuery(Context,
        C.Query, False));
    Result := CompileInsertRows(Context, TableSql, Columns, Inserts);
    if (Length(Inserts) = 1) and C.ReturnId and (FLastId <> '') then
      Result := Result + ';' + FLastId;
    Exit;
  end;
  if Query.Method = 'delete' then
  begin
    TableSql := Table(Context, F);
    if HasJoins then
      Result := 'DELETE ' + JoinTarget(F) + ' FROM ' + TableSql +
        CompileJoins(Context, Query)
    else
      Result := 'DELETE FROM ' + TableSql;
  end
  else
  begin
    C := Query.GetOne('update', EngineCode);
    if C = nil then
      raise EQueryException.Create('No update data');
    if HasJoins then
      Result := CompileJoinedUpdate(Context, Query, F, C)
    else
    begin
      TableSql := Table(Context, F);
      Result := 'UPDATE ' + TableSql + ' SET ' + CompileUpdateAssignments
        (Context, C);
    end;
  end;
  S := Conditions(Context, Query, 'where');
  if S <> '' then
    Result := Result + ' WHERE ' + S;
end;

function TCompiler.CompileLower(const Value: string): string;
begin
  Result := 'LOWER(' + Value + ')';
end;

function TCompiler.CompileUpper(const Value: string): string;
begin
  Result := 'UPPER(' + Value + ')';
end;

end.
