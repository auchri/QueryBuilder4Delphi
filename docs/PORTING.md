# Porting plan

Source: SqlKata, local commit df4a2377750d34fc057c81886b481e7309ef975e.
Target: Delphi 12 or later, Windows Win32/Win64. No execution layer.
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
