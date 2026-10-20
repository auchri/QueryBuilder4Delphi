# Validation results: October 20, 2026

## Checks performed

Delphi 12 Community Edition, RAD Studio directory `23.0`, Windows.
The suite was fully rebuilt for each platform using **Project > Build**.
Both final builds reported **0 errors and 0 warnings**.
Command-line compilation is unavailable in the installed Community Edition,
so the builds were performed in the IDE.

Both standalone test executables were then run using
`tools/build.ps1 -TestsOnly`.

| Target | DUnitX tests | Passed | Failed | Errors | Ignored |
| --- | ---: | ---: | ---: | ---: | ---: |
| Win32 | 586 | 586 | 0 | 0 | 0 |
| Win64 | 586 | 586 | 0 | 0 | 0 |

DUnitX reported `Tests Leaked: 0` in both runs.
`ReportMemoryLeaksOnShutdown` is also enabled in the test program.
The executables' PE headers were verified as x86 (`0x14c`) and x64 (`0x8664`).
The machine-readable summary, including SHA-256 hashes, is available in
[validation-results.json](validation-results.json).
`tools/record_validation.py` can regenerate this summary from new successful
test runs; update the validation date in the script for a new validation run.

## Reference comparison

The C# outputs come directly from local source commit
`df4a2377750d34fc057c81886b481e7309ef975e`.
`tools/oracle` references its `QueryBuilder.csproj`; it does not contain a
reimplementation of the C# compiler. It compiles 69 paired queries for six
dialects and the SQL Server and Oracle legacy variants: 552 reference results.
A repeat C# run reproduced `test/golden.json` byte for byte.

540 engine/scenario combinations compare named SQL, RawSql, and binding counts,
values, and order against this C# data. For JOIN write operations rejected by
the C# implementation, the tests verify rejection. SQL whitespace is normalized.

The twelve explicitly approved differences for HAVING callbacks and Oracle
aggregate aliases have separate tests with explicit corrected expectations;
the original C# references are preserved. See [API.md](API.md).

Eleven existing additional tests check ownership when cloning and releasing
subqueries, callback exceptions and EngineScope restoration, data types and
culture-independent diagnostic SQL, operator validation, invalid write data,
batch parameters, nested variables, raw array parameters, typed arrays,
RTTI attributes, and README examples.

Seven further tests use destructor counters to check the reference-counted API:
shared interfaces, automatic release of query trees and clones, temporary
fluent chains during exceptions, retained callback queries, callback failures,
queries retained by SQL results, and compiler and result release when an
exception exits a scope. All README functions use `IQuery`; the complete
example requires no `try..finally`.

Eight compiler class tests import the individual dialect units directly.
Six verify that the inherited factory creates the requested runtime class.
Two check custom MySQL and SQL Server descendants, including virtual overrides,
date expressions, offset-only pagination, joined updates, and legacy TOP
pagination. Their custom engine names ensure that inherited dialect behavior
does not depend on engine-name comparisons in the base compiler.

Eight write and mapping regression cases cover fluent identity, validation
before multirow insert mutation, independent INSERT-SELECT source clones,
engine-scoped write replacement, OR/NOT flags for WHERE/HAVING pairs,
ignored and unreadable RTTI properties, mapper callback failures, and key
predicates for object updates.

## Limitations

Validation covers SQL generation and library runtime behavior with Delphi 12
on Win32/Win64. No database servers were contacted, and no SqlKata.Execution
features were ported. Newer Delphi versions were not run locally. The suite
does not prove the validity of every possible SQL fragment or every
combination of fluent overloads.

The original temporary model smoke-test projects were replaced by the DUnitX
project. Build outputs and detailed NUnit logs remain in `build/Win32` and
`build/Win64` and are not checked in.
