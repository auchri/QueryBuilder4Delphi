# Upgrade from v1.0.0 to v2.0.0

Version 2 adds object mapping, nullable DTO reads and writes, and a
[documentation website and SQL converter](WEBSITE.md). Two public return types
changed. Rebuild all dependent units and packages after updating `src`.
The minimum target remains Delphi 12 on Windows, Win32 or Win64.

## Compile returns SQL and bindings

In v1, `Query.Compile(Dialect)` returned a string with values substituted.
In v2 it returns `ISqlResult`, declared in `QueryBuilder4Delphi.Query.Core`:

```delphi
var
  Statement: ISqlResult;
begin
  Statement := TQuery.Create('Books').Where('Id', 42)
    .Compile(TSqlDialect.MSSql);
  // Pass Statement.Sql AND Statement.Bindings to your database adapter.
end;
```

For the previous diagnostic string behavior, replace
`Preview := Query.Compile(Dialect)` with
`Preview := Query.ToDebugSql(Dialect)`. `Statement.ToString` also produces a
substituted preview. Previews are intended for diagnostics; execute the
parameterized SQL with its ordered bindings. The default dialect remains MSSql.
`ICompiler.Compile` is unchanged. The compiler unit retains an `ISqlResult`
type alias with the original interface GUID.

## Execute returns a record facade

`IQuery.Execute` now returns `TQueryResult`, which wraps an `IQueryResult` and
delegates its reader methods. Existing assignments to an explicitly declared
`IQueryResult` continue to work through implicit conversion:

```delphi
var
  Rows: IQueryResult;
begin
  Rows := TQuery.Create('Books').Execute(Executor);
  while Rows.Next do
    Writeln(Rows.GetValue('Title').AsString);
end;
```

Use `.Execute(Executor).AsRaw` to request the interface explicitly. Inferred
variables now hold a record; clear them with `Default(TQueryResult)` rather
than `nil`. A `var` or `out` interface argument needs an actual `IQueryResult`
variable. Custom `IQuery` implementations must update both `Compile` and
`Execute` signatures; custom executors still return `IQueryResult` unchanged.

## Mapping methods and ownership

Import `QueryBuilder4Delphi.Mapping` to use `ToList<T>`, `First<T>`,
`FirstOrDefault<T>`, `Single<T>`, `SingleOrDefault<T>`, `FirstOrElse<T>`,
`SingleOrElse<T>` and `ForEach<T>` directly after `Execute`.

- `ToList<T>` returns an owning `TObjectList<T>`; free the list after use.
- Single-object results belong to the caller. Lazy fallback references retain
  their existing ownership and run only when the result is empty.
- `ForEach<T>` lends each mapped object only during its callback.
- Fluent terminal methods consume their receiving facade and release its
  result reference before returning, including on errors. Copies and retained
  raw interfaces share the cursor and keep their own references alive.
- Static `TQueryMapper` methods remain available, including `MapCurrent<T>`
  for a cursor already positioned on a row.

See [mapping compatibility](OBJECT_MAPPING.md#result-facade-and-compatibility)
for helper selection, retained references and error behavior.

## SQL NULL and shared DTO attributes

The new mapper defaults to `nmbDefault`: SQL NULL overwrites constructor values
with the supported Delphi type's default. Configure `TQueryMappingOptions` with
`nmbThrow` for strict errors or `nmbSkip` to preserve constructor values.
Use `TNullable<T>` from `QueryBuilder4Delphi.Nullable` to distinguish SQL NULL
from zero, False or empty values. Nullable properties receive `.Null` under
all three policies and can also be used in object INSERT, UPDATE, WHERE and
HAVING. NULL UPDATE keys are rejected.

Read and write mapping share `[Column]`, `[Key]` and `[Ignore]` resolution.
Blank names, case-insensitive column collisions and conflicting attributes
are rejected before object-write getters or key callbacks run. Review DTOs
that previously relied on ambiguous names. See the
[shared attribute rules](OBJECT_MAPPING.md#shared-readwrite-attributes) and
[nullable write examples](OBJECT_MAPPING.md#writing-nullable-properties).
