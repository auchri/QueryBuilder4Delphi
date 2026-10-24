# Object Mapping

`QueryBuilder4Delphi.Mapping` maps `IQueryResult` rows through Delphi RTTI.
It requires only RTL and the query core; it works with any executor/provider.
Classes need a public parameterless constructor and writable public/published
properties with RTTI. No base class, interface, table attribute or key is needed.
For classes compiled with restricted RTTI, enable property RTTI explicitly.

Prefer `Execute(Executor).ToList<T>()` and
`Execute(Executor).FirstOrDefault<T>()` for new code. The methods below are
record helper methods and require `QueryBuilder4Delphi.Mapping` in the calling
unit's `uses` clause.

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

## Result facade and compatibility

`IQuery.Execute` returns `TQueryResult`, a record in
`QueryBuilder4Delphi.Query.Core` containing one `IQueryResult`. It delegates
every reader operation and never advances the cursor on construction. Core
does not depend on Mapping. Delphi interfaces cannot declare generic methods
(E2535), so `TQueryResultMappingHelper` in Mapping supplies the generic methods
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

Fluent `ToList` and `FirstOrDefault` consume the receiving facade, including a
named variable: `TakeRaw` transfers its interface reference to a local and clears
the facade before calling the existing mapper. A `finally` releases the local
on success or exception. This avoids waiting for Delphi's managed expression
temporaries to finalize. With no other references, the underlying result is
destroyed before the mapping call returns or propagates an exception.
`FirstOrDefault` also releases an incompletely read cursor. The facade is empty
after either call; use `TQueryMapper.FirstOrDefault<TBook>(Rows.AsRaw)` when a
named facade must remain available for subsequent reads. The static mapper
remains non-owning. `AsRaw` and implicit conversion retain rather than consume;
their compiler-generated temporaries may live until the enclosing routine exits.

Copied facades and separately retained interfaces remain valid and share cursor
position. Their references can legitimately delay destruction until the final
owner releases them. Mapping never closes or invalidates another owner's result.
Mapped objects and owning lists are independent of the live resultset and remain
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
nonpublic properties and all fields are excluded. Inherited writable properties
follow the same mapping rules. Extra columns are ignored, even when NULL or
unsupported. Missing columns leave constructor values intact.
Duplicate result names raise `EQueryMappingException` when a mapped property
would be ambiguous; use distinct aliases to resolve them. Classes without any
eligible properties raise a descriptive exception, including on empty results.
At least one result column must match an eligible property. A schema with no
matches raises `EQueryMappingException` naming the class and available columns,
even if the result has no rows. Validation happens before advancing the cursor
or constructing objects in both mapper methods.

Effective mapping names must be unique across eligible properties, ignoring
case. Two `[Column]` names, or an explicit name and another property's implicit
name, cannot refer to the same column. Such class metadata is rejected even if
the current projection omits the conflicting column. `[Ignore]` properties do
not participate in these checks. A property may have at most one column mapping
attribute (`[Column]` or its subclass `[Key]`); multiple attributes are rejected
instead of selecting one arbitrarily. Errors identify the class and conflicting
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
  .Select(['Rating', 'Title', 'Payload']).OrderBy('Id')
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
inner RTTI identities also match. There is no generic-name parsing, record-layout
assumption, unsafe pointer construction or provider dependency.

Both fluent and static methods still accept optional `TQueryMappingOptions`.
Configure options before mapping and keep them alive and unchanged until the
call returns. They may be reused for later calls. Custom registrations and
converters affect only operations receiving that instance.

The mapper tests `IQueryResult.IsNull` before reading a value. NULL writes a
supported nullable's Null record; NULL to a non-nullable or unregistered target
raises `EQueryMappingException`. `TQueryNull` is still only a SQL input-parameter
type hint, not a nullable DTO value or result sentinel. If the provider has
already normalized an empty value to SQL NULL, the mapper cannot recover it.

Set `Options.SkipNullAssignment := True` to leave **all** matched NULL
properties unchanged, including nullable properties initialized by a
constructor. This is an explicit opt-in; its default is False. Omitted columns
continue to preserve constructor values independently of this setting.

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
lazy loading or CRUD. Existing object-to-INSERT/UPDATE mapping through
`TQueryDataMapper` is unchanged.
