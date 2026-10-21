# Validation results: October 21, 2026

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
| Win32 | 603 | 603 | 0 | 0 | 0 |
| Win64 | 603 | 603 | 0 | 0 | 0 |

DUnitX reported `Tests Leaked: 0` in both runs.
`ReportMemoryLeaksOnShutdown` is also enabled in the test program.
The executables' PE headers were verified as x86 (`0x14c`) and x64 (`0x8664`).
The machine-readable summary, including SHA-256 hashes, is available in
[validation-results.json](validation-results.json).
`tools/record_validation.py` can regenerate this summary from new successful
test runs; update the validation date in the script for a new validation run.

## Optional FireDAC suite

The separate `test/QueryBuilder.FireDAC.Tests.dproj` project requires FireDAC.
It was fully built for Win32 and Win64 using Delphi 12, with zero errors and
warnings. All 26 tests passed on each platform with no reported test leaks.
The core project does not import FireDAC.

The export cases verify `ToSql`, `GetParameters`, and the combined `Compile`
result for all six dialects with FireDAC automatic parameter creation enabled.
They also cover empty parameter arrays, nil arguments, Variant types, typed
and untyped NULLs, UInt64 decimal precision, binary byte arrays, and direct
`TFDQuery.Open`/`ExecSQL` execution of exported commands using SQLite.
Two option-preservation cases exercise binding by name and by position, all
five preprocessing flags enabled and disabled, and reuse with no parameters.
SQLite CRUD also executes with caller-selected positional binding. The test
fixture explicitly configures preprocessing; the adapter preserves it.

Six cases verify parameterized SQL and binding order for every dialect,
including Firebird's pagination bindings. Further cases cover string, integer,
unsigned integer, Boolean, date/time, Currency, float, GUID, BCD, binary and
Variant bindings; typed and untyped NULL; replacing parameters on reuse;
nil arguments; and rejecting unsupported values before changing the target.
SQLite in-memory tests actually execute INSERT, SELECT, UPDATE and DELETE,
verify affected row counts, roll back a caller-owned transaction, and preserve
literal macro/escape characters. SQLite is statically linked for these tests;
no database server or external SQLite DLL is required.

The suite also exposed an empty-value bug in the core parameter compiler.
`TValue.Empty` now creates a bound NULL rather than an empty unsafe literal.
The core SQL preview regression and FireDAC NULL case cover this correction.

Results and executable architectures/hashes are recorded in
[firedac-validation-results.json](firedac-validation-results.json). Run
`tools/build.ps1 -Suite FireDAC -TestsOnly` after rebuilding the optional
project, then `python tools/record_validation.py --suite FireDAC`.

## Source formatting

All 22 versioned `.pas` and `.dpr` files in `src` and `test` were formatted
with Delphi 12 `Formatter.exe` and the installed `Formatter_Default.config`.
A second formatter pass produced identical file hashes. A token comparison
against the pre-format sources confirmed unchanged Pascal tokens apart from
case-insensitive identifier spelling; string literals, comments, and compiler
directives remained identical. `tools/format.ps1` repeats the formatting.

Generator comparisons now ignore layout outside strings/comments/directives
and preserve matching formatted files instead of rewriting them. Both generator
checks pass, and all eight Python regression tests pass, including preservation
of formatted files and rejection of changes inside literals/comments or at
token boundaries. Both Delphi suites were fully rebuilt and rerun on Win32
and Win64: 603 core and 26 FireDAC tests per platform, with zero build errors,
warnings, hints, or reported test leaks.

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

Eight query-model tests cover direct imports and the concrete query factory,
subclass cloning with independent state, engine-scoped fallback and removal,
callback return validation and scope restoration, snapshots of subqueries,
independent JOIN condition groups, Int64 pagination and negative limits,
and value helper copying and type preservation. Both the write and query-model
fixtures are included after rebasing onto the merged PR #2.

Nine additional query compilation cases check the SQL Server default,
selection of all six dialects with engine-scoped projections and pagination,
repeat compilation without query mutation, propagation of compiler errors,
quoted inline values, and INSERT previews. The shortcut is compared with
the existing compiler API's `ToString` output.
The dialect cases also verify the enum's engine-code mapping against the
established string codes and each compiler's `EngineCode`. The custom MySQL
compiler test checks that string-scoped conditions still work with a custom
engine name. The built-in scope helpers use the same central mapping.

The suite now builds without any include files. The 69 reference scenario
queries are implemented in `Oracle.Scenarios.pas`; their DUnitX case attributes
remain in the main fixture. Both generators pass `--check`, and eight Python
tests verify replacement boundaries, invalid marker rejection, idempotence,
read-only checking, UTF-8 BOM preservation, and CRLF output. The generated
method bodies, declarations, scenarios, and case attributes were also compared
with the previous include contents to verify that this extraction preserves
the tested behavior and reference coverage.

## Limitations

Validation covers SQL generation, library runtime behavior, and the optional
FireDAC adapter with Delphi 12 on Win32/Win64. Only SQLite was used for actual
database execution; other dialects were checked for SQL and parameter mapping.
No database servers were contacted, and the SqlKata.Execution layer was not
ported. Newer Delphi versions were not run locally. The suite
does not prove the validity of every possible SQL fragment or every
combination of fluent overloads.

The original temporary model smoke-test projects were replaced by the DUnitX
project. Build outputs and detailed NUnit logs remain in `build/Win32` and
`build/Win64` and are not checked in.

The compatibility facade units and legacy type aliases are removed. Compilers,
examples, generated scenarios, RTTI attributes, and all tests import the defining
QueryBuilder4Delphi units directly. The factory regression checks concrete query
creation, shared interface lifetime, and independent empty queries. Upstream
SqlKata references remain only for attribution, history, and the C# oracle.
