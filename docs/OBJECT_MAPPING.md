# Object Mapping

## Shared read/write attributes

Both `TQueryMapper` and `TQueryDataMapper` use the same property name and
attribute resolver. For example, `TBookData` in
[MappingExamples.pas](../test/MappingExamples.pas) works in both directions:

```delphi
{$RTTI EXPLICIT METHODS([vcPublic]) PROPERTIES([vcPublic]) FIELDS([])}
TBookData = class
private
  FId: Integer;
  FTitle, FNote: string;
public
  [Key('book_id')]
  property Id: Integer read FId write FId;
  [Column('book_title')]
  property Title: string read FTitle write FTitle;
  [Ignore]
  property InternalNote: string read FNote write FNote;
end;
{$RTTI INHERIT}

Book := TQuery.Create('MappedBooks')
  .Select(['book_id AS BOOK_ID', 'book_title AS BOOK_TITLE'])
  .Where('book_id', 7).Execute(Executor).Single<TBookData>();
try
  Book.Title := 'Updated';
  TQuery.Create('MappedBooks').AsUpdate(Book).Execute(Executor);
finally
  Book.Free;
end;
```

Without an attribute the property name is the column name. `[Column]` replaces
that name; reading matches **result aliases**, case-insensitively, while writing
emits the configured name unchanged. `[Key]` also supplies a column name. Only
`GetPairs` with an `OnKey` callback and object `AsUpdate` use its key semantics:
updates add key predicates and retain the key in the update columns, as before.
Object `AsInsert`, `Where` and `Having` use all eligible non-ignored properties
without special key handling. `[Ignore]` always wins, including over conflicting
or empty attributes on that property, and prevents getter/callback invocation.

Both directions reject case-insensitive duplicate effective column names,
multiple `[Column]`/`[Key]` attributes (even with identical names), and empty or
whitespace-only column names with `EQueryMappingException` (an `EQueryException`).
The exception remains available from `QueryBuilder4Delphi.Mapping`; the shared
declaration is in `QueryBuilder4Delphi.Mapping.Metadata`. Validation covers the
whole eligible property set before reading rows, getters or key callbacks.
Other getter and callback exceptions retain their original class.

Reading requires writable public/published properties; writing requires readable
properties. Inherited properties follow the same rules. For compatibility,
writing continues to include nonpublic properties if their RTTI was explicitly
emitted; reading continues to exclude them. Prefer public/published properties
for DTOs used in both directions. A read-only and a write-only property may use
the same column because only one is eligible in each direction. An empty write
property set still returns an empty pair array; reading requires a matching
writable property even for empty results.

Fields are excluded in both directions, even when public field RTTI and mapping
attributes are present. Private backing fields are never inspected implicitly.
Field support is deferred: enabling it automatically would add columns for
existing DTOs and requires a separate compatibility policy for property/field
collisions. Use a property wrapper today. `FIELDS([])` is sufficient for the
examples; enable `PROPERTIES([vcPublic, vcPublished])` as appropriate. Published
properties also require the usual Delphi published RTTI support (`{$M+}` or an
appropriate base class).

## Reading objects

`QueryBuilder4Delphi.Mapping` maps `IQueryResult` rows through Delphi RTTI.
It requires only RTL and the query core; it works with any executor/provider.
Classes need a public parameterless constructor and writable public/published
properties with RTTI. No base class, interface, table attribute or key is needed.
For classes compiled with restricted RTTI, enable property RTTI explicitly.

Prefer `Query.Execute(Executor).ToList<T>()`, `.First<T>()`,
`.FirstOrDefault<T>()`, `.Single<T>()`, `.SingleOrDefault<T>()` and
`.ForEach<T>(Callback)` for terminal mapping. Lazy `.FirstOrElse<T>(Fallback)`
and `.SingleOrElse<T>(Fallback)` accept a `TFunc<T>`. All accept optional
`TQueryMappingOptions`; for `ForEach` and both `OrElse` methods pass options after the callback.
These record helper methods require `QueryBuilder4Delphi.Mapping` in the calling
unit's `uses` clause. They delegate to `TQueryMapper` without changing mapping,
conversion or cursor semantics. `Single` variants inspect at most two rows and
never add SQL LIMIT/TOP clauses.

Use the static mapper for advanced cursor control. In particular,
`TQueryMapper.MapCurrent<T>(Rows)` requires an explicitly positioned cursor and
has no fluent terminal counterpart. See [examples and cursor semantics](EXAMPLES.md#object-mapping)
and [performance measurements](MAPPING_PERFORMANCE.md).

The following example is compiled in [MappingExamples.pas](../test/MappingExamples.pas)
and exercised against SQLite through the execution API:

```delphi
unit MappingExamples;

interface

uses
  System.Generics.Collections, QueryBuilder4Delphi.Query.Core;

type
  {$RTTI EXPLICIT METHODS([vcPublic]) PROPERTIES([vcPublic]) FIELDS([])}
  TBook = class
  private
    FId: Integer;
    FTitle: string;
  public
    property Id: Integer read FId write FId;
    [Column('BookTitle')]
    property Title: string read FTitle write FTitle;
  end;
  {$RTTI INHERIT}

function LoadBooks(const Executor: IQueryExecutor): TObjectList<TBook>;
function FindBook(const Executor: IQueryExecutor; Id: Integer): TBook;

implementation

uses
  QueryBuilder4Delphi.Query, QueryBuilder4Delphi.Mapping;

function LoadBooks(const Executor: IQueryExecutor): TObjectList<TBook>;
begin
  Result := TQuery.Create('Books')
    .Select(['Id', 'Title AS BookTitle']).OrderBy('Id').Execute(Executor)
    .ToList<TBook>();
end;

function FindBook(const Executor: IQueryExecutor; Id: Integer): TBook;
begin
  Result := TQuery.Create('Books')
    .Select(['Title AS BookTitle', 'Id']).Where('Id', Id).Execute(Executor)
    .FirstOrDefault<TBook>();
end;

end.
```

## Lazy fallback and ownership

`First` requires at least one remaining row; `Single` requires exactly one.
`FirstOrDefault` and `SingleOrDefault` return nil for zero rows. `Single` variants
raise `EQueryMappingException` for multiple rows, inspecting at most two rows.
`FirstOrElse` and `SingleOrElse` have the same row/cardinality behavior as the
corresponding `OrDefault` method, but invoke the callback exactly once for zero
rows. They never invoke it for mapping, conversion, provider or cardinality errors.
Schema validation still happens on empty resultsets. No method rewinds or adds
a SQL row limit. First variants call `Next` at most once.

A nil fallback raises `EArgumentNilException` **before schema validation or
cursor movement**, even if a row exists. Fluent calls still consume and release
their receiving facade on this error. A callback may return nil.

The mapper returns the **exact reference** supplied by the callback: it never
clones, modifies or frees a fallback, and never infers ownership. Database-mapped
objects are newly allocated and caller-owned. Fallback ownership stays as arranged
by the application: a newly allocated fallback normally needs caller cleanup;
an existing cache/list/component-owned object remains borrowed. **Do not free
an externally owned fallback unless ownership was explicitly transferred.**
The callback is responsible for its own allocations if it raises before returning.

The fluent helper releases its transferred result reference before invoking an
empty-result fallback, so that callback can query the same connection. Copied
facades and independently retained interfaces may legitimately keep the shared
result alive. Static methods never release the caller's result reference; release
it explicitly when a static fallback needs an exclusive connection resource.
See [tested lazy examples](EXAMPLES.md#lazy-fallbacks).

## Result facade and compatibility

`IQuery.Execute` returns `TQueryResult`, a record in
`QueryBuilder4Delphi.Query.Core` containing one `IQueryResult`. It delegates
every reader operation and never advances the cursor on construction. Core
does not depend on Mapping. Delphi interfaces cannot declare generic methods
(E2535), so `TQueryResultMappingHelper` in Mapping supplies the eight generic terminal methods
and calls the existing `TQueryMapper` directly. Only the helper must be in scope;
executors still return `IQueryResult` and need no mapping implementation.

Delphi selects one helper for a type at a call site. If an application defines
another helper for `TQueryResult`, ensure this mapping helper is selected by
unit scope/order, or use the static API explicitly.

Existing static mapping remains supported:

```delphi
Books := TQueryMapper.ToList<TBook>(Rows);
Book := TQueryMapper.FirstOrDefault<TBook>(Rows);
```

Direct reader assignments still compile through a one-way implicit conversion:

```delphi
Rows := TQuery.Create('Books').Execute(Executor);
while Rows.Next do
  Writeln(Rows.GetValue('Title').AsString);
```

Here `Rows` is an `IQueryResult`. To select the interface explicitly use
`Rows := TQuery.Create('Books').Execute(Executor).AsRaw`. Facades themselves
expose `Next`, both `GetValue`/`IsNull` overloads, column metadata,
`HasResultSet` and `RowsAffected`, without requiring the Mapping unit.

Rebuild dependent units/packages because `IQuery.Execute` has changed return
type. Custom implementations of `IQuery` must return `TQueryResult`; custom
`IQueryExecutor` and `IQueryResult` implementations remain unchanged. An
inferred local variable from `Execute` is now a record: use
`Default(TQueryResult)` to clear it, or declare an `IQueryResult` variable/use
`AsRaw` when interface operations or a nil comparison are needed. A `var`/`out`
`IQueryResult` parameter requires a real interface variable; implicit conversion
is intended for assignments, returned values and value/const arguments.

Record assignments share the underlying cursor and its current position.
Normal interface reference counting keeps temporaries, copied records and
independently retained `AsRaw` interfaces alive. Releasing one facade does not
invalidate another reference. No manual reference counting or custom managed
record operators are used. `AsRaw` on a default/empty facade returns nil;
reader operations on it raise `EQueryException`, and mapping preserves the
static mapper's `EArgumentNilException`. Command results without a resultset
raise `EQueryMappingException` before constructing any object.

All eight fluent terminal methods consume the receiving facade, including a
named variable: `TakeRaw` transfers its interface reference to a local and clears
the facade before calling the existing mapper. A `finally` releases the local
on success or exception. This avoids waiting for Delphi's managed expression
temporaries to finalize. With no other references, the underlying result is
destroyed before the mapping call returns or propagates an exception.
`First`/`FirstOrDefault` also release an incompletely read cursor. The facade is empty
after any terminal call; use `TQueryMapper.FirstOrDefault<TBook>(Rows.AsRaw)` when a
named facade must remain available for subsequent reads. The static mapper
remains non-owning. `AsRaw` and implicit conversion retain rather than consume;
their compiler-generated temporaries may live until the enclosing routine exits.

Copied facades and separately retained interfaces remain valid and share cursor
position. Their references can legitimately delay destruction until the final
owner releases them. Mapping never closes or invalidates another owner's result.
Database-mapped objects and owning lists are independent of the live resultset and remain
valid after its destruction. The facade owns no connection; application-owned
connections must outlive all retained live results. Mapping errors preserve the
mapper's exception class, message context and object cleanup.

The FireDAC executor sets `FetchOptions.AutoClose := True`: after all rows are
fetched it releases the underlying command while keeping the dataset's cached
rows and metadata readable. This API exposes only the first resultset, so
discarding subsequent command resultsets is intentional. Partially fetched
results remain readable; destruction of the owning result also frees its
`TFDQuery`, so early termination does not depend on AutoClose. See
[FireDAC fetching semantics](https://docwiki.embarcadero.com/RADStudio/Athens/en/Fetching_Rows_(FireDAC)).

Free the owning `TObjectList<TBook>` returned by `LoadBooks` in a `finally` block.
Free the single object returned by `FindBook` similarly (`nil.Free` is safe).
For an empty result with a compatible column schema, `ToList` returns an empty
owning list and `FirstOrDefault` returns `nil`. Both call `Next` before mapping:
a row already selected by the caller is skipped. `ToList` consumes all remaining
rows; `FirstOrDefault` consumes at most one, leaving later rows available to any
retained owner. Neither rewinds the cursor. The static API does not release the
caller's result interface.
Do not share one cursor between concurrent calls.

Names are matched case-insensitively against result column names, including
aliases. `[Column('BookTitle')]` replaces the default property-name match.
`[Ignore]` excludes a property. `[Key('BookId')]` retains its inherited column
mapping behavior without identity or persistence semantics. Read-only and
nonpublic properties and all fields are excluded when reading. Inherited writable
properties follow the same mapping rules. Extra columns are ignored, even when NULL or
unsupported. Missing columns leave constructor values intact.
Duplicate result names raise `EQueryMappingException` when a mapped property
would be ambiguous; use distinct aliases to resolve them. Classes without any
eligible properties raise a descriptive exception, including on empty results.
At least one result column must match an eligible property. A schema with no
matches raises `EQueryMappingException` naming the class and available columns,
even if the result has no rows. Validation happens before advancing the cursor
or constructing objects in every mapper operation.

Effective mapping names must be unique across eligible properties, ignoring
case. Two `[Column]` names, or an explicit name and another property's implicit
name, cannot refer to the same column. Such class metadata is rejected even if
the current projection omits the conflicting column. `[Ignore]` properties do
not participate in these checks. A property may have at most one column mapping
attribute (`[Column]` or its subclass `[Key]`); empty or whitespace-only names
and multiple attributes are rejected. Errors identify the class and conflicting
properties or attributes.

| Destination | Accepted source |
| --- | --- |
| Integer, Cardinal, Int64, UInt64, ShortInt, SmallInt, Byte, Word | Any of these integer types, within destination range; negative to unsigned is rejected |
| Boolean | Boolean |
| string (UnicodeString) | string (UnicodeString) |
| Single, Double, Extended | Same type, or another of these types when the finite value is represented exactly |
| Integers to/from Single, Double, Extended | Exact representations only; fractional, nonfinite, out-of-range and rounded values are rejected |
| Currency | Currency; TBcd only when an exact BCD round trip confirms no rounding or overflow |
| TBcd | TBcd unchanged (including precision/scale); Currency through CurrToBcd without floating point |
| TDateTime | TDateTime |
| TSQLTimeStamp | TSQLTimeStamp, retaining all fractional digits |
| TSQLTimeStampOffset | TSQLTimeStampOffset, retaining all fractional digits and timezone fields |
| TGUID | TGUID |
| TBytes | TBytes, including zero-length/nil arrays as non-NULL values |

There is no string parsing or formatting, numeric-to-Boolean conversion,
binary-float/decimal conversion, integer/decimal conversion, or implicit
conversion between timestamp records and TDateTime. Timestamp conversion could
lose fractional precision or introduce/drop a timezone; select the matching
native property type. These unsupported pairs raise a descriptive mapping
exception even when a particular value could fit; applications may register an
explicit converter for their own policy. Distinct custom types also require a
converter. TGUID text is not parsed automatically.
Extended follows Delphi's platform representation (Win64 uses Double precision).
Nonfinite floating-point values are accepted only for same-type assignment.
Conversions use `GetValue`'s actual `TValue.TypeInfo`; `GetColumnType` metadata
does not override concrete data. Native decimal/timestamp records use the
standard `Data.FmtBcd`/`Data.SqlTimSt` types; the mapper does not use `TDataSet`,
FireDAC, or provider-specific null values. Arbitrary records, objects, enums and
variants remain unsupported unless explicitly converted.

## Nullable properties and scoped options

Add `QueryBuilder4Delphi.Nullable` for `TNullable<T>`. `Default(TNullable<T>)`
and `TNullable<T>.Null` represent NULL. `Create(Value)` represents a value,
including zero, False, empty string and empty bytes. Check `HasValue` before
reading `Value`; reading NULL raises `EQueryNullValue`. Initialize local records
with `Default` or `Null` as usual in Delphi. Object fields are zero-initialized.
Managed strings and arrays use ordinary compiler-managed record copies and
finalization. Nullable object references, like ordinary object references, do
not acquire ownership of the referenced object.

Built-in nullable properties work automatically, without options or registration.
For `TRatedBook` and its nullable Rating, Title and Payload properties in
[the compiled SQLite example](../test/NullableMappingExamples.pas):

```delphi
Books := TQuery.Create('NullableBooks')
  .Select(['Id', 'Rating', 'Title', 'Payload']).OrderBy('Id')
  .Execute(Executor).ToList<TRatedBook>();
try
  for Book in Books do
    if Book.Rating.HasValue then
      Writeln(Book.Rating.Value);
finally
  Books.Free;
end;
```

`FirstOrDefault<TRatedBook>()` and the static `TQueryMapper` methods also work
without options. Supported inner types are `ShortInt`, `SmallInt`, `Integer`,
`Int64`, `Byte`, `Word`, `Cardinal`, `UInt64`, `Boolean`, `string`, `Single`,
`Double`, `Extended`, `Currency`, `TDateTime`, `TBcd`, `TSQLTimeStamp`,
`TSQLTimeStampOffset`, `TGUID` and `TBytes`. Nullable values use the same strict
conversion rules as ordinary properties, including precision and overflow checks.

The built-in registry is initialized once during unit initialization and is
immutable during mapping, allowing concurrent lookups without per-row setup.
It uses compile-time typed callbacks shared with `RegisterNullable<T>` and
ordinary `TValue.From<TNullable<T>>` construction and RTTI property assignment.
Compiler aliases sharing a closed specialization are accepted only when their
inner RTTI identities also match. Conversion never infers a generic record layout or reinterprets memory;
closed generic RTTI names are used only to reject unregistered specializations.

Both fluent and static methods still accept optional `TQueryMappingOptions`.
Configure options before mapping and keep them alive and unchanged until the
call returns. They may be reused for later calls. Custom registrations and
converters affect only operations receiving that instance.

The mapper tests `IQueryResult.IsNull` before reading a value. A supported
`TNullable<T>` always receives `TNullable<T>.Null` for SQL NULL, under every
policy, overwriting constructor values. Non-NULL zero, False and empty strings
remain present values (`HasValue = True`). This includes explicitly registered
nullable specializations. `TQueryNull` remains an input-parameter type hint.
If a provider normalizes empty values to SQL NULL, the mapper cannot recover them.

For non-nullable properties, `TQueryMappingOptions.NullBehavior` selects:

| Policy | SQL NULL assignment |
| --- | --- |
| `nmbDefault` (default, also with omitted/nil options) | Assign the actual Delphi type default, overwriting constructor values |
| `nmbThrow` | Raise `EQueryMappingException`, preserving the previous strict behavior |
| `nmbSkip` | Do not call the setter; preserve the existing property value |

Defaults are limited to the ordinary types supported by the conversion table:
numeric types and TDateTime become zero, Boolean becomes False, string becomes
empty, TGUID/TBcd/timestamp records become their zero-initialized records, and
TBytes becomes nil. The RTL constructs typed defaults through `TValue.Make`;
arbitrary records/classes do not gain automatic default mapping. Custom
converters do not enable default construction of otherwise unsupported types.
`nmbSkip` can leave an unsupported non-nullable target untouched on SQL NULL.
Missing columns always preserve constructor values. Conversion, setter and
provider errors remain errors under every policy.

**Migration:** SQL NULL previously raised by default. Select `nmbThrow` to keep
that behavior. `nmbDefault` loses the distinction between SQL NULL and a stored
type default; use `TNullable<T>` when that distinction matters.
`NullBehavior` is the only configuration property for this policy. An explicit
`nmbThrow` exception says SQL NULL was rejected by that policy. With the default
policy, unsupported targets instead report that the type does not support
default-value mapping. Both errors retain the property, row, column, source and
target context. Supported nullable targets are handled before either error.

```delphi
Options := TQueryMappingOptions.Create;
try
  Options.NullBehavior := nmbThrow; // Or nmbSkip to retain constructor values.
  Books := Query.Execute(Executor).ToList<TBook>(Options);
  try
    // Use Books; nullable properties preserve SQL NULL under either policy.
  finally
    Books.Free;
  end;
finally
  Options.Free;
end;
```

### Custom nullable types and precedence

`Options.RegisterNullable<TApplicationCode>` is an advanced extension point for
custom application types. Public RTTI identifies closed generic specializations
but cannot construct arbitrary specializations at runtime; this method supplies
the typed construction at compile time. Custom inner types also need an exact
application converter when ordinary conversion does not support them.

Conversion first checks operation-scoped nullable registrations, then built-in
nullable registrations, then the existing non-nullable rules. Within either
nullable callback, an exact application source/inner-target converter takes
precedence over built-in scalar conversion. Built-in callbacks receive the
current operation's options and retain no reference to caller-owned options.

For non-NULL values, an exact converter returning the complete destination
record also remains supported before default built-in nullable construction.
An explicit scoped nullable registration still takes precedence over such a
whole-record converter. SQL NULL never reaches ordinary converters.

Explicit `RegisterNullable<Integer>` and other built-in registrations remain
supported and override the built-in entry for that operation. They do not mutate
the global registry. Duplicate registration within one options instance still
raises an error; a separate options instance retains its own conversion policy.

### Application converters

`Options.RegisterConverter<TSource, TTarget>(TFunc<TSource, TTarget>)` registers
one exact actual source/target pair. For example, this callback can fill an
application record containing a string field:

```delphi
Options.RegisterConverter<string, TApplicationCode>(
  function(Text: string): TApplicationCode
  begin
    Result.Text := 'code:' + Text;
  end);
Options.RegisterNullable<TApplicationCode>;
```

See [the executable custom record test](../test/Mapping.Values.Tests.pas) for
the record definition and complete calls. Registered pairs take precedence over
built-ins only in calls using those options; otherwise built-ins remain the
default. Nullable registrations wrap conversion of their inner type, so the
same converter also fills `TNullable<TApplicationCode>`. Ordinary converters
never receive SQL NULL. Duplicate nullable types/pairs and nil callbacks are
rejected; there is no converter chain or implicit source coercion.
Applications own their conversion policy and referenced objects. Converter
exceptions retain their class and receive the same row/column/property/type
context as provider and setter failures.

SQLite integration tests cover nullable integers/strings and binary values.
FireDAC memory-field tests pass exact BCD, timestamp fractions and offsets
through the existing field reader into the mapper. Neither those field tests
nor SQLite establish SQL Server/Oracle driver or server behavior. Those servers
were not available for integration testing.

Errors identify the class, property, row within this call, column/index and
source/target types. Provider and setter exceptions keep their original class
and are re-raised with mapping context. On failure the current object, partial
list and all objects already added to it are freed. Constructors/destructors
should follow normal Delphi exception-safety conventions.

Class properties, types, attributes and mapping names are cached per class
under a lock; a retained RTTI context keeps references valid until unit
finalization. Immutable metadata is shared between calls. Each result gets a
new column plan, so reordered columns and different projections are safe.
Rows are read directly with no intermediate result array. Classes from runtime
packages must remain loaded while cached metadata is in use.

This API is an object mapper only: it adds no change tracking, identity map,
lazy loading or implicit CRUD.

## Writing nullable properties

All built-in specializations listed above work automatically with `AsInsert(Data)`,
`AsUpdate(Data)`, `Where(Data)` and `Having(Data)`. They share the read mapper's
immutable registrations and the attribute metadata resolver. No extra unit or
configuration is required by the write calls. `Create(Value)` extracts exactly
`TValue.From<T>(Value)`, preserving unsigned ranges, Extended/Currency/BCD precision,
timestamps, GUIDs and managed-value ownership. `Null` emits `TQueryNull` with an
inner-type hint; NULL never invokes an outbound custom converter.

NULL is an explicit value, not an omitted property. To omit a column, use a partial
DTO or `[Ignore]`. `Create(0)`, `Create(False)`, `Create('')` and
`TNullable<TBytes>.Create(nil)` remain non-NULL. Database rules still apply;
Oracle, for example, treats an empty character string as NULL.

`Where(Data)` and `Having(Data)` use `IS NULL` for absent nullable properties,
with no parameter for that predicate. Negation uses `IS NOT NULL`. Other values
retain existing predicate behavior, including Boolean SQL literals. INSERT/UPDATE
values remain parameterized; SET bindings precede key WHERE bindings in existing
property order. `[Column]`, `[Key]`, inherited and readable-only properties and
`[Ignore]` keep the shared mapping behavior.

Every `[Key]` supplied to an UPDATE must be non-NULL. A NULL key raises
`EQueryMappingException` before any key predicate or SET clause is changed,
including when another composite-key member was already read. All getters and
conversions complete before key callbacks run. Custom callbacks retain their own
side effects if they throw; the mapper cannot roll back external callback actions.
DTOs without keys retain existing behavior: callers must provide an appropriate
WHERE condition for a restricted UPDATE.

The same `TRatedBook` DTO is used throughout this example (see
[`NullableMappingExamples.pas`](../test/NullableMappingExamples.pas) for the class
and executable example):

```delphi
Book := TRatedBook.Create;
try
  Book.Id := 10; // [Key('Id')]
  Book.Title := TNullable<string>.Create('');
  Book.Rating := TNullable<Integer>.Create(0);
  TQuery.Create('NullableBooks').AsInsert(Book).Execute(Executor).GetRowsAffected;
finally
  Book.Free;
end;
Book := TQuery.Create('NullableBooks').Where('Id', 10)
  .Execute(Executor).Single<TRatedBook>();
try
  Book.Rating := TNullable<Integer>.Null;
  TQuery.Create('NullableBooks').AsUpdate(Book).Execute(Executor).GetRowsAffected;
finally
  Book.Free;
end;
```

Custom inner records opt in using scoped `TQueryMappingOptions.RegisterNullable<T>`
and `RegisterConverter<TCustom, TSqlScalar>`. Use
`TQueryDataMapper.GetPairs(Data, nil, Options)` and pass the returned pairs to
`AsInsert`, `AsUpdate`, `Where` or `Having`. For pair-based updates add your key
WHERE condition explicitly, or supply an `OnKey` callback to `GetPairs` (NULL keys
are rejected when that callback is present). Register a reverse converter when
reading a custom inner type. Options never alter global built-ins or read-side
`NullBehavior`. The first registered custom-to-supported-scalar converter is used;
register a single outbound representation per custom inner type. Unsupported
unregistered nullable specializations fail before provider execution.
