# Changelog

All notable changes to QueryBuilder4Delphi are documented in this file.
Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [2.0.0] - 2026-10-31

Object mapping, nullable DTO round trips, parameterized fluent compilation and
a documentation website with a browser-local SQL-to-Delphi converter.

### Breaking changes and migration

- `IQuery.Compile` returns `ISqlResult` instead of a substituted SQL string.
  Use `.Compile(Dialect).Sql` together with `.Bindings` for execution, or
  `.ToDebugSql(Dialect)` for the previous diagnostic preview behavior.
- `IQuery.Execute` returns the `TQueryResult` record facade instead of
  `IQueryResult`. Direct interface assignments still work; use `.AsRaw` when
  an explicit interface is needed. Custom `IQuery` implementations must adopt
  both return types. Rebuild dependent units and packages.
- See the [v1 migration guide](docs/MIGRATION.md) for examples and ownership rules.

### Changed

- `IQuery.Compile` now returns `ISqlResult` with parameterized SQL and bindings.
  Use `ToDebugSql` for the previous substituted preview behavior. Both default
  to MSSql and use the existing compiler pipeline. The `ISqlResult` contract
  now lives in Query.Core with its original GUID; the compiler unit retains
  a type alias for existing consumers. `ICompiler.Compile` is unchanged.

### Fixed

- Unified read/write property attribute resolution. Object writes now reject
  case-insensitive column collisions and conflicting Column/Key attributes
  before getters or key callbacks run; both directions reject blank names.
  Existing property visibility, key operation and Ignore behavior is preserved.

### Added

- Provider-neutral `TNullable<T>` with automatic mapping for built-in types,
  operation-scoped registrations for custom types, optional NULL assignment
  skipping and exact-pair converters.
- Provider-independent RTTI object mapping with shared `[Column]`, `[Key]` and
  `[Ignore]` attributes, schema validation and contextual mapping errors.
- Fluent `ToList`, `First`, `FirstOrDefault`, `Single`, `SingleOrDefault`,
  `FirstOrElse`, `SingleOrElse` and `ForEach` mapping methods, plus static
  `MapCurrent` for caller-positioned cursors. Terminal calls release their
  consumed result reference deterministically; lazy fallbacks run only for
  empty results and streaming callbacks borrow one object at a time.
- Explicit SQL NULL policies: type defaults (`nmbDefault`), strict errors
  (`nmbThrow`) or preservation of constructor values (`nmbSkip`). Nullable
  properties retain the distinction between NULL and zero/False/empty values.
- Nullable DTO values in object INSERT, UPDATE, WHERE and HAVING, including
  typed SQL NULL bindings, `IS NULL` predicates and rejection of NULL UPDATE
  keys. FireDAC supports native SQL timestamp/offset parameter values.
- Checked signed/unsigned integer and exact integer/float conversions; native
  BCD, SQL timestamp/offset, GUID and byte-array mapping; exact Currency/BCD
  conversion with precision and overflow checks.
- Mapping benchmarks for Win32/Win64, expanded DUnitX regressions and compiled
  examples for mapping, nullable round trips and fluent search.
- XML documentation throughout the public API and generated declarations,
  with a repeatable coverage audit and behavior-specific generator tests.
- GitHub Pages documentation generated directly from repository Markdown,
  with syntax highlighting, heading links, responsive navigation and search
  examples. Browser interaction tests cover desktop and mobile layouts.
- Browser-local SELECT-to-Delphi conversion for MySQL, PostgreSQL, SQL Server
  and SQLite, with highlighted SQL/Delphi editors, exact numeric range checks,
  unsupported-syntax errors, copy support and generated Delphi smoke projects.
  The converter processes input in memory without uploading or persisting it.

### Validation

- Release checks and their scope are recorded in
  [validation details](docs/VALIDATION.md#v200-release-validation-2026-10-31).
- Existing Delphi executables rerun: 940 Core and 94 FireDAC tests passed on
  each of Win32 and Win64, with zero failures, errors, ignored tests or leaks.
  These are reruns of the October 25 IDE builds, not fresh release builds.
- All 67 JavaScript tests, 10 browser tests, website build/link checks, 15
  Python tests, generator checks and the XML documentation audit passed.
- Database integration coverage uses SQLite in memory; other dialects have SQL
  compilation/binding coverage rather than live server validation.

## [1.0.0] - 2026-10-23

First public release of QueryBuilder4Delphi, a fluent SQL query builder for
Delphi 12 and later on Windows (Win32 and Win64).

### Added

- Interface-based fluent query API with automatic resource management, query
  cloning, filters, joins, subqueries, common table expressions, aggregation,
  ordering and pagination.
- SELECT, INSERT, UPDATE and DELETE query compilation, including RTTI-based
  mapping of write values.
- SQL Server, MySQL, PostgreSQL, SQLite, Oracle and Firebird compiler classes,
  selected through `TQueryCompilerFactory.CreateCompiler`.
- Parameterized SQL with ordered bindings and configurable parameter prefixes;
  inline SQL previews for diagnostics through `Query.Compile` and
  `ISqlResult.ToString`.
- Provider-independent execution through `IQueryExecutor` and `IQueryResult`,
  with explicit or automatic execution modes, column metadata, typed values,
  NULL checks by index or name, and affected-row counts.
- Optional FireDAC provider using caller-owned connections and transactions,
  typed parameter binding and independent result cursors.
- Getting-started instructions, verified examples, API documentation, provider
  extension guidance and build/validation tools.
- DUnitX regression suites for all six SQL compilers, query ownership,
  execution contracts and SQLite integration through FireDAC.

### Requirements and scope

- Add `src` to the Delphi search path. The core library requires only the RTL;
  FireDAC is required only for the optional provider.
- Execution exposes one resultset. Output parameters, multiple resultsets and
  identity batches requested with `ReturnId` are unsupported.
- Applications manage connections and transactions. SQL previews are intended
  for diagnostics; execute parameterized SQL together with its bindings.

### Validation

- Core: 632 tests passed on each of Win32 and Win64.
- Optional FireDAC provider: 39 tests passed on each of Win32 and Win64.
- All four suites reported zero failures, errors, ignored tests or test leaks.
- Database integration was verified with SQLite in memory. Other dialects were
  covered by SQL compilation and binding tests; server-specific execution was
  not tested. See [validation details](docs/VALIDATION.md).

[Unreleased]: https://github.com/auchri/QueryBuilder4Delphi/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/auchri/QueryBuilder4Delphi/releases/tag/v2.0.0
[1.0.0]: https://github.com/auchri/QueryBuilder4Delphi/releases/tag/v1.0.0
