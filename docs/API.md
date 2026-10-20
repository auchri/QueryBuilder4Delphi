# API mapping and limitations

## Public fluent API

The upstream public `Query` method names are available on `IQuery`, except for
`Include` and `IncludeMany`, which belong to the explicitly excluded execution
and relation-loading layer.

`Query` maps to `IQuery`, `Compiler` to `ICompiler`, and `SqlResult` to
`ISqlResult`. `TQuery.Create` and `T...Compiler.Create` are record factories
that return an interface immediately. Temporary fluent chains do not require
manual cleanup. All compilers are in `SqlKata.Compilers`; the model is in
`SqlKata`. The six compiler factories use the Delphi `T` prefix.
`EngineCodes` is named `TEngineCodes`.

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

`TConditionGroup` and `TJoin` are aliases of the shared fluent model `IQuery`,
also named `IConditionGroup` and `IJoin`. The C# internal clause subclasses,
interfaces, separate `Wheres`/`Havings`/clause properties, and visitor and
CompileContext extension interfaces are not reproduced with binary or type
compatibility. Instead, the port exposes `TClause`, `Clauses`, `GetComponents`,
`GetOne`, and `ClearComponent`. Components are `where`, `having`, `select`,
`from`, `group`, `order`, `join`, `cte`, `combine`, `limit`, `offset`,
`aggregate`, `insert`, and `update`. These internal lists belong to the query.
Custom compilers can override protected virtual methods on `TCompilerObject`
or the dialect-specific `T...CompilerObject` classes. Custom query
implementations can derive from `TQueryObject` and override `NewQuery`/`Clone`.
Always hold instances of these implementation classes through interfaces;
the factories are the normal entry points.

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
