# Changelog

All notable changes to QueryBuilder4Delphi are documented in this file.
Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
- Checked signed/unsigned integer and exact integer/float conversions; native
  BCD, SQL timestamp/offset, GUID and byte-array mapping; exact Currency/BCD
  conversion with precision and overflow checks.

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

[1.0.0]: https://github.com/auchri/QueryBuilder4Delphi/releases/tag/v1.0.0
