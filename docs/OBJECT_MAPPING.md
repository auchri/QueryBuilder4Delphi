# Object Mapping

`QueryBuilder4Delphi.Mapping` maps `IQueryResult` rows through Delphi RTTI.
It requires only RTL and the query core; it works with any executor/provider.
Classes need a public parameterless constructor and writable public/published
properties with RTTI. No base class, interface, table attribute or key is needed.
For classes compiled with restricted RTTI, enable property RTTI explicitly.

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
  Result := TQueryMapper.ToList<TBook>(
    TQuery.Create('Books').Select(['Id', 'Title as BookTitle'])
      .OrderBy('Id').Execute(Executor));
end;

function FindBook(const Executor: IQueryExecutor; Id: Integer): TBook;
begin
  Result := TQueryMapper.FirstOrDefault<TBook>(
    TQuery.Create('Books').Select(['Title as BookTitle', 'Id'])
      .Where('Id', Id).Execute(Executor));
end;

end.
```

Free the owning `TObjectList<TBook>` returned by `LoadBooks` in a `finally` block.
Free the single object returned by `FindBook` similarly (`nil.Free` is safe).
For an empty result with a compatible column schema, `ToList` returns an empty
owning list and `FirstOrDefault` returns `nil`. Both call `Next` before mapping:
a row already selected by the caller is skipped. `ToList` consumes all remaining
rows; `FirstOrDefault` consumes at most one, leaving later rows available.
Neither rewinds the cursor or explicitly frees the caller's result interface.
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
| Integer | Integer/Int64 and signed 8/16-bit or unsigned 8/16/32-bit integers, within Integer range |
| Int64 | The same integer sources, without narrowing |
| Boolean | Boolean |
| string (UnicodeString) | string (UnicodeString) |
| Single, Double, Extended | Same type, or another of these types when the finite value is represented exactly |
| Currency | Currency |
| TDateTime | TDateTime |

There is no string parsing or formatting, numeric-to-Boolean conversion,
integer-to-float conversion, float-to-integer conversion or decimal-record
conversion. Distinct custom types are not part of the supported contract.
Extended follows Delphi's platform representation (Win64 uses Double precision).
Nonfinite floating-point values are accepted only for same-type assignment.
SQL NULL is checked with `IsNull`, independently of `TValue.IsEmpty`, and raises
`EQueryMappingException` for every mapped property in this version. Nullable
types, binary arrays, records (including BCD, GUID and native timestamp records),
variants, objects and enums are unsupported. Check or transform NULLs in the
query, or use the result reader API when nullable values are needed.

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
