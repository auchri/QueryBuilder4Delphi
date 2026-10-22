# Porting plan

Source: SqlKata, local commit df4a2377750d34fc057c81886b481e7309ef975e.
Target: Delphi 12 or later, Windows Win32/Win64. No SqlKata.Execution port.
An optional FireDAC adapter was subsequently added at the user's request.
Queries, compilers, and SQL results use reference-counted interfaces.
The initial class-based API was migrated at the user's explicit request.
Supplied subqueries are copied. Callback queries are released internally.

Completed work packages:

1. Project structure, license, and porting plan (`5eac4fa`).
2. Query model and fluent API with conditions and ownership management (`802ed35`).
3. SQL compilers for SELECT, joins, subqueries, CTEs, set operations, writes,
   and aggregates across all six dialects (`3955bc5`).
4. DUnitX project, C# reference data, and build script; 563 passing tests per
   platform on Win32 and Win64, with no build warnings.
5. README with tested examples, API mapping, and validation documentation.

Language-specific API differences and limitations are documented in
[API.md](API.md). Actual validation results are recorded in
[VALIDATION.md](VALIDATION.md). The approved corrections to HAVING callbacks
and Oracle aggregate aliases are documented separately from C# parity.

Completed work packages for the interface migration:

6. `IQuery`, `ICompiler`, `ISqlResult`, and interface factories with the same
   fluent method names; automatic lifetime management for temporary chains
   (`9d62252`).
7. Tests migrated to interfaces, plus seven lifetime regression tests using
   destructor counters; 570 tests passed on each of Win32 and Win64, with no
   build warnings (`d65686d`).
8. Updated README examples, API mapping, and validation records (`ff425ed`).

Completed work packages for compiler classes:

9. Replace compiler include files and record factories with a `TCompiler`
   base class and six dialect subclasses in individual Pascal units. Move
   dialect behavior into virtual overrides and retain the reference-counted
   `Create` API and the interim `SqlKata.Compilers` compatibility facade
   (`883f4a2`), subsequently renamed in step 11.
10. Add eight tests for class factories, direct unit imports, and custom
    descendants; update the test project, API documentation, and validation
    records for Win32 and Win64. The class and inheritance tests are recorded
    in `91e6a9f`; all 578 tests pass on each platform.

11. Rename the compiler units and facade from `SqlKata.Compilers` to
    `QueryBuilder4Delphi.Compilers`, updating project references, tests, and
    API documentation. At this stage, imports used the renamed facade or
    individual compiler units. Step 19 subsequently removes the renamed
    facade too; current applications must import individual compiler units.

Completed work packages for query writes:

12. Start `codex/refactor-query-writes` from the freshly fetched `origin/main`
    at `1a39f8d`, before modifying any files. Replace `SqlKata.Writes.inc` with
    the stateless `TQueryWrites` class in `QueryBuilder4Delphi.Query.Writes`
    and `TQueryDataMapper` in `QueryBuilder4Delphi.Query.DataMapper`.
    Keep the public fluent API and reference-counted return values unchanged.
13. Add eight write and RTTI mapping regression cases; rebuild and run all
    586 tests on both Win32 and Win64. Update the API and validation records.

Completed work packages for the query unit:

14. Start `codex/refactor-query-unit` independently from `origin/main` at
    `1a39f8d`, then rebase onto `58dca75` after PR #2 was merged. Move the
    write forwarding methods into the extracted query class. Remove
    `SqlKata.Query.inc` and move
    `TQueryObject` and the `TQuery` factory into `QueryBuilder4Delphi.Query`.
    Move shared interfaces, clauses, attributes, and value helpers into
    `QueryBuilder4Delphi.Query.Core`. Retain `SqlKata` as a compatibility facade
    at this stage; step 19 subsequently removes it.
15. Add eight query-model regression tests for direct imports, facade type
    identity, subclass cloning, scopes, callbacks, subqueries, joins,
    pagination, and value helpers. Update project references and documentation.
    All 594 tests pass on both Win32 and Win64 after full Delphi 12 builds
    with zero errors and warnings.

Completed work packages for the remaining includes:

16. Start `codex/remove-remaining-includes` from `origin/main` at `6341bba`,
    after PR #3 was merged. Replace fluent declaration and implementation
    includes with generated sections in the existing query units, preserving
    the public API. Update the generator to check markers before writing and
    support a read-only `--check` mode.
17. Replace the test includes with `Oracle.Scenarios.pas` and generated case
    attributes in the regular DUnitX fixture. Preserve the reference scenarios
    and case attributes; add six Python tests for generator safeguards.
18. Rebuild and run the Delphi suite for Win32 and Win64, verify generated
    source consistency, and update the README and validation records.
    All 594 DUnitX tests pass on both platforms with zero build errors and
    warnings; all six Python generator tests and both `--check` commands pass.

Completed work packages for removing compatibility layers:

19. Start `codex/remove-compatibility` from `origin/main` at `ced5018`.
    Remove `SqlKata.pas`, the compiler facade unit, compiler object aliases,
    and condition/join aliases. Import defining units throughout the library.
20. Migrate tests, RTTI attributes, examples, and the scenario generator to
    direct imports. Replace facade checks with a concrete query factory test.
21. Document the required import/type migration and rerun Win32/Win64 DUnitX
    validation and generator consistency checks. Preserve upstream attribution
    and the C# reference program.
    All 594 DUnitX tests pass on each platform after full builds with zero
    errors and warnings. Both generator checks and all six Python tests pass.

Completed work packages for query compilation:

22. Start `codex/query-compile` from `origin/main` at `5a59ecc`, after PR #5
    was merged. Add the scoped `TSqlDialect` enum and `IQuery.Compile`, with
    SQL Server as its default. Reuse the dialect compilers and their `ToString`
    rendering to return a SQL preview with substituted values. Keep compiler
    dependencies in implementation sections to avoid an interface cycle.
23. Add nine regression cases for defaults, all dialects, scoped projections,
    pagination, repeated compilation, exceptions, inline quoting, and writes.
    Document the shortcut and the separate parameterized compiler API.
    All 603 DUnitX tests pass on Win32 and Win64, with no build errors or
    warnings and no reported test leaks. Both generator checks pass.
24. Replace `TEngineCodes` with the central `TSqlDialect.EngineCode` mapping.
    Use it in dialect constructors and generated scope helpers. Retain custom
    string engine scopes and cover the mapping and custom-scoped conditions
    in the existing regression cases. Update API migration guidance.
    All 603 tests pass on each of Win32 and Win64 after full builds with zero
    errors and warnings; both generator checks and six Python tests pass.

Execution replaces the former optional adapter API. See README and API.md for
provider units, migration, cursor semantics, ownership and provider extension.
The previous adapter facade and command export helpers have been removed.
Parameterized compilation remains available through ICompiler/ISqlResult.

The execution contracts are colocated with IQuery to avoid circular units.
The Fluent Execute member is outside generated sections and survives both
query generator regeneration and formatting. No generator change is needed.
The generic executor compiles a clone with a configured dialect; FireDAC
execution, binding and resource ownership are isolated in optional units.

PR #9 review follow-up keeps this architecture. TQueryExecutor now offers a
protected virtual CreateCompiler and an optional parameter prefix; FireDAC
retains :pN and validates the compiled named/ordered binding convention.
TQueryNull/TQueryValueType carry small provider-neutral NULL hints and column
categories, including for all-NULL columns. IQueryResult has a new interface
GUID for GetColumnType. Optional TFireDACNull remains for exact driver types.
No compiler-factory hierarchy, mapper or database-specific external bridge was
introduced. Execution.ProviderExample.pas compiles without Data.DB/FireDAC.

Decimal reads use AsBCD with FMTBcd storage preferred over Currency-backed
fields; standard timestamp records preserve fractions and timezone offsets.
Opaque Oracle timestamp/interval formats still fail explicitly. A shared
lexical mask protects raw bindings in literals/comments and guards single
query execution, including common SQL Server batches without semicolons.
This is a conservative query-builder guard, not a general SQL parser.
See VALIDATION.md for the 622 core / 38 FireDAC cases on each platform and the
limits of native field fixtures versus live server integration.
