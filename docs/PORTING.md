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
