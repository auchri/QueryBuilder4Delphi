# API mapping and limitations

## Optional FireDAC execution

`QueryBuilder4Delphi.FireDAC` contains `TFireDACAdapter.Apply`, `Open`, and
`ExecSQL`. They accept a caller-owned `TFDQuery`, an `IQuery`, and a dialect
(SQL Server by default). `Apply` transfers SQL and typed parameters without
preparing or executing; `Open` opens a result set; `ExecSQL` returns
`RowsAffected`. The caller configures the connection and database driver and
controls transactions and component lifetime. This is an optional adapter,
not a port of `SqlKata.Execution` or an object result mapper.

The adapter uses a fresh compiler with `ParameterPrefix = ':p'`. It builds
and validates parameters before closing/unpreparing the target, then replaces
SQL and parameters, binds by name, enables automatic parameter creation and
parameter expansion, and disables macro/escape expansion. These resource
settings remain on the target after the call. Compilation/binding errors
leave the target intact; connection/execution errors propagate from FireDAC.

`TFireDACAdapter.Compile(Query, Dialect)` returns a `TFireDACCommand` record:
`Sql: string`, `Parameters: TArray<Variant>`, and
`DataTypes: TArray<TFieldType>`. All arrays follow the compiler's binding
order, including dialect-specific pagination parameters. Pass them to
`TFDQuery.Open(Sql, Parameters, DataTypes)` or the corresponding `ExecSQL`
overload, with `ParamCreate`/`ParamExpand` enabled and macro/escape expansion
disabled. Compilation requires no target component or connection and does not
execute SQL. Byte bindings become byte Variant arrays; the data-type array
preserves typed NULLs and FireDAC-specific parameter types. Untyped NULLs use
`ftWideString` because no target formatting options are available.

`ToSql(Query, Dialect): string` and
`GetParameters(Query, Dialect): TArray<Variant>` expose each part separately.
They also default to SQL Server. Each call compiles independently; prefer
`Compile` for a matching snapshot of SQL, values, and types. `ToSql` only
generates SQL, whereas `Compile`/`GetParameters` also validate binding types.
No macro placeholders are generated; user-supplied raw SQL remains unchanged.

Bindings preserve strings, characters, integer values, Boolean, floats,
Currency, `TDateTime`, `TGUID`, `TBcd`, binary `TBytes`, and supported scalar
Variants. UInt64 above High(Int64) uses FMTBCD to avoid overflow. Other records,
objects, interfaces, and unsupported arrays are rejected instead of being
silently converted to text. Raw query array expansion still occurs in the
compiler before binding.

`TFireDACNull.Create(TFieldType)` represents a typed NULL; `ftUnknown` is
rejected by its constructor. Untyped NULL (`TValue.Empty`, Variant Null/Empty)
uses the target's `DefaultParamDataType` or `ftWideString` if it is unknown.
The adapter cannot infer a column type without database metadata. Prefer a
typed NULL when the target column needs a particular data type.
`TFireDACNull` is interpreted by the adapter; generic `Query.Compile` previews
do not interpret this FireDAC-specific record.

The parameter compiler also treats `TValue.Empty` as a bound NULL for writes
and raw bindings. Previously, `TValue.IsType<TUnsafeLiteral>` accepted an empty
value and emitted an empty literal; the new regression prevents that loss.

## Public fluent API

The upstream public `Query` method names are available on `IQuery`, except for
`Include` and `IncludeMany`, which belong to the explicitly excluded execution
and relation-loading layer.

`Query` maps to `IQuery`, `Compiler` to `ICompiler`, and `SqlResult` to
`ISqlResult`. `TQuery.Create` is a record factory. `TCompiler` and the six
dialect compilers are classes; their inherited `Create` class function returns
`ICompiler` immediately. Temporary fluent chains do not require manual cleanup.
Each compiler has its own `QueryBuilder4Delphi.Compilers.<ClassName>` unit,
with the Delphi `T` prefix omitted from the unit name.
`IQuery.Compile(Dialect: TSqlDialect = TSqlDialect.MSSql): string` is a
Delphi convenience method for SQL previews. `TSqlDialect` is a scoped enum in
`QueryBuilder4Delphi.Query.Core` with `MSSql`, `MySql`, `PostgreSql`, `Sqlite`,
`Oracle`, and `Firebird`. The method creates the selected compiler with its
default settings and returns `Compiler.Compile(Query).ToString`, including
substituted values. It preserves the query, propagates compiler errors, and
requires no compiler unit imports in calling code. Use `ICompiler.Compile`
when you need SQL and bindings separately or custom compiler settings.

`CreateCompiler(Dialect)` in `QueryBuilder4Delphi.Compilers.Factory` creates
the corresponding reference-counted compiler. `ICompiler.ParameterPrefix`
configures generated named markers (for example, `':p'` produces `:p0`).
The default compiler prefixes remain unchanged.

`TQueryObject` and the `TQuery` factory live in `QueryBuilder4Delphi.Query`.
`IQuery`, `TClause`, callbacks, attributes, and value types live in
`QueryBuilder4Delphi.Query.Core`. Import both units to use the model directly.
The `SqlKata` and `QueryBuilder4Delphi.Compilers` facade units are no longer
provided. Import the defining units directly; rebuild dependent units and
packages after updating the library. The fluent method signatures remain the
same, but old imports and compatibility type names are intentionally removed.
All include files have been removed. Generated fluent declarations and methods
are regular Pascal source in marked sections of the two query units.
`tools/generate_query.py` updates those sections without replacing handwritten
code; `--check` verifies that the checked-in source matches the generator.
The upstream `EngineCodes` constants are represented by
`TSqlDialect.EngineCode`: for example, `TSqlDialect.MSSql.EngineCode` returns
`'sqlsrv'`. Dialect compilers and the `ForSqlServer`/`ForMySql`/etc. methods use
this central mapping. The former `TEngineCodes` record has been removed;
replace `TEngineCodes.SqlServer` with `TSqlDialect.MSSql.EngineCode` and use
the corresponding enum member for each other dialect. `IQuery.For` and
`SetEngineScope` continue to accept strings for custom compiler engine names.
The base `TCompiler` uses the string code `'generic'`.

Write operations delegate to the stateless `TQueryWrites` class in
`QueryBuilder4Delphi.Query.Writes`. RTTI property mapping delegates to
`TQueryDataMapper` in `QueryBuilder4Delphi.Query.DataMapper`. These are
implementation helpers; applications continue to call `IQuery.AsInsert`,
`AsUpdate`, `AsDelete`, `AsIncrement`, `AsDecrement`, and `AsAggregate`.
The former `SqlKata.Writes.inc` is no longer used or provided.

`object` parameters become `TValue`; `params` and `IEnumerable` parameters
become open arrays or `TArray`. For IN values from typed arrays,
`TSqlValues.&Of<T>` converts to `TValues`. Multiple rows use `TRows`, with
`TValues` for each row. Dictionaries use `TDictionary<string,TValue>` or arrays
of `TPair<string,TValue>`. Delphi has no C# anonymous data types; object data
uses RTTI-accessible Delphi properties.

`TUnsafeLiteral` and `TVariable` are value records with implicit conversion to
`TValue`; they do not need `Free`. `TUnsafeLiteral.Create(SQL, False)` leaves
the SQL text unchanged. These record constructors replace the `Expressions`
helper class.

Condition and join callbacks use `IQuery` directly. The former
`IConditionGroup`, `TConditionGroup`, `IJoin`, and `TJoin` aliases have been
removed. The C# internal clause subclasses,
interfaces, separate `Wheres`/`Havings`/clause properties, and visitor and
CompileContext extension interfaces are not reproduced with binary or type
compatibility. Instead, the port exposes `TClause`, `Clauses`, `GetComponents`,
`GetOne`, and `ClearComponent`. Components are `where`, `having`, `select`,
`from`, `group`, `order`, `join`, `cte`, `combine`, `limit`, `offset`,
`aggregate`, `insert`, and `update`. These internal lists belong to the query.
Custom query implementations can derive from `TQueryObject` and override
`NewQuery`/`Clone`. Always hold implementation instances through interfaces.

## Compiler classes and extensions

`TCompiler` in `QueryBuilder4Delphi.Compilers.Compiler` contains shared SQL generation.
`TSqlServerCompiler`, `TPostgresCompiler`, `TMySqlCompiler`, `TSqliteCompiler`,
`TOracleCompiler`, and `TFirebirdCompiler` derive from it in individual Pascal
units. Dialect-specific behavior is implemented through virtual overrides,
including pagination, date expressions, random and Boolean expressions,
identifier wrapping, ad hoc tables, multirow inserts, and joined updates.
The compiler sources contain no include directives or engine-name dispatch.

Derive custom compilers from `TCompiler` or a dialect class and override the
relevant virtual methods. Override the protected `CreateInstance` constructor
for initialization, calling `inherited` first. The inherited `Create` class
function uses the receiving class and its virtual constructor, so
`TCustomCompiler.Create` returns an `ICompiler` for the custom descendant.
Do not replace it with an object-returning constructor or call `CreateInstance`
from application code. Derive from `TCompiler` or the named dialect class;
the former `TCompilerObject` and `T...CompilerObject` aliases have been removed.

[CompilerClasses.Tests.pas](../test/CompilerClasses.Tests.pas) demonstrates
custom MySQL and SQL Server descendants. It checks that inherited dialect
behavior survives a custom `EngineCode`, and that custom overrides are called
through `ICompiler`.

## Memory and lifetime

- `IQuery`, `ICompiler`, and `ISqlResult` use reference counting through
  `TInterfacedObject`. Assignments share the same instance; `Clone` creates an
  independent query. Leaving scope or assigning `Q := nil` releases a reference.
  Never call `Free`/`FreeAndNil` on the implementation objects.
- For single-query `Compile` calls, `ISqlResult.Query` keeps the original query
  alive. For batch results, `Query` remains `nil`, as before.
- `Clauses`, `Variables`, `Bindings`, and `NamedBindings` are borrowed RTL
  collections. They belong to their query or result and must not be freed
  separately. Keep the owning interface alive while using them.
- Supplied query objects are copied. The caller may modify or release the
  original after the method returns.
- Callback helper queries are created and copied internally; their lifetimes
  are also reference-counted. A retained callback query interface remains valid
  after the callback returns. Callbacks are not stored in the query. Callbacks
  must return the query they receive; returning another query or `nil` raises
  an exception. `When` and `For` operate directly on the original query and
  likewise require that query to be returned.
- `TValue` holds scalar values, records, and reference-counted data according
  to RTL rules. Arbitrary `TObject` instances wrapped as parameters are not owned.
- Query clones own independent clauses and subqueries. Reference objects
  embedded in custom `TValue` data are not deeply cloned.
- As with all reference-counted interfaces, custom extensions must avoid strong
  reference cycles. Built-in query trees have no back references; subqueries
  are cloned.
- Query instances and configurable compilers do not synchronize shared mutable
  state. Use separate instances per thread.

## Intentionally corrected upstream bugs

The following corrections were explicitly approved:

1. `Having(function(Q: IQuery): IQuery begin Result := Q.Where(...); end)`
   produces a HAVING group. The C# overload checks only `query.Havings` and
   discards conditions from `query.Wheres`. A callback using `Q.Having(...)`
   also works. For both components, Delphi prefers the Where group and falls
   back to the Having group when no Where group exists.
2. `TOracleCompiler.Create.Compile(TQuery.Create.SelectCount('Id as Total'))`
   produces `COUNT("Id") "Total"`. The C# implementation loses the AS keyword
   while splitting the alias and places the alias inside the aggregate:
   `COUNT("Id" "Total")`. The Delphi correction also applies to filtered
   aggregates and Oracle legacy mode.

The unmodified C# reference outputs for these cases remain in `test/golden.json`.
The twelve affected engine/scenario combinations have explicit correction tests;
the reference data is not silently changed to match the corrected output.

## Other differences due to Delphi and lifetime management

- `For` restores the previous EngineScope even when an exception occurs.
- `Clone` preserves the comment. The current C# implementation does not copy it.
- Batch compilation of an empty array returns an empty result.
- Raw binding counts must match unescaped `?` placeholders; mismatches raise
  `EQueryException` early.
- Operators are checked against a whitelist. Aggregate names and date parts
  must be simple SQL function or part names. Dialect-specific names such as
  `quarter` are allowed; raw expressions support arbitrary SQL fragments.
- The compact model does not guarantee RTTI property or dictionary entry order.
  Use explicit column/value arrays when order matters.
- Whitespace formatting in compiled SQL may differ. Parity comparisons
  normalize only these whitespace differences. No database servers are contacted.

As in the local C# compiler implementation, `Comment`/`GetComment` manage model
metadata; comments are not inserted into SQL.
