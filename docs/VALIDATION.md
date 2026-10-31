# Validation

## v2.0.0 release validation (2026-10-31)

The release changes documentation and website release metadata on top of
`4b87528` (main, including PR #30). Library and test sources are unchanged.

The existing Delphi 12 Community Edition executables were rerun with
`tools/build.ps1 -Suite Core/FireDAC -Platform Both -TestsOnly`:

| Suite | Win32 passed | Win64 passed | Failed/errors/ignored/leaked |
| --- | ---: | ---: | --- |
| Core without FireDAC | 940 | 940 | 0/0/0/0 |
| FireDAC / SQLite | 94 | 94 | 0/0/0/0 |

These are reruns of the October 25 IDE builds, not fresh release builds.
The existing JSON validation records below describe their original feature
snapshots; they have not been relabeled as release-build evidence.
Database integration uses SQLite in memory and FireDAC memory fields;
no live validation against the other five database servers is claimed.

Additional release checks passed:

- All 67 JavaScript converter, numeric, state, token and smoke-fixture tests.
- Static website build and all generated local links and heading anchors.
- All 10 Playwright browser tests using installed Microsoft Edge, including
  keyboard/copy behavior and layouts from 320 to 1920 pixels.
- Both generator `--check` commands (including 69 paired Oracle scenarios),
  all 15 Python generator tests and the public XML documentation audit
  (zero errors).
- `git diff --check`.

Generated converter smoke projects are covered by JavaScript fixture checks.
Full native compilation/execution
of all four generated projects on both platforms remains unverified; the
local artifacts contain only a MySQL Win32 executable.

## Previous validation: October 25, 2026

## SQL NULL mapping policy (issue #20)

Both projects were built with IDE Project > Build in Delphi 12 Community Edition
(RAD Studio 23.0), Base configuration, for Win32 and Win64. Execution used
`tools/build.ps1 -Suite Core/FireDAC -Platform Win32/Win64 -TestsOnly`.
Command-line compilation is unavailable in this edition.

The policy API uses only `NullBehavior`, with no compatibility configuration.
All previous skip tests now select `nmbSkip`, preserving constructor-value and
nullable coverage. Four diagnostic cases replace the obsolete alias-only test:
omitted/explicit default options with unsupported targets, and explicit strict
policy with supported/unsupported non-nullable targets. They also verify mapping
context and caller-owned result cleanup after errors.

| Suite | Win32 passed | Win64 passed | Failed/errors/ignored/leaked |
| --- | ---: | ---: | --- |
| Core without FireDAC | 919 | 919 | 0/0/0/0 |
| FireDAC/SQLite and memory fields | 92 | 92 | 0/0/0/0 |

The new policy fixture checks all supported ordinary target types through both
ToList and FirstOrDefault, including overwriting constructor values, skipping
setters, strict exceptions, omitted options, fresh options and explicit policies.
It checks automatic and explicitly registered nullable integers/strings/Booleans
against SQL NULL and non-NULL zero/empty/False under every policy, custom nullable
records and inner converters, unsupported targets/conversions, distinct policy
versus unsupported-default diagnostics, and fluent
ToList/FirstOrDefault/First/Single/ForEach object/result cleanup.
Existing strict NULL error/ownership tests now explicitly select nmbThrow; existing
converter precedence, setter/provider failures, partial lists, streaming, fallback,
concurrency and object-writing regressions remain passing.

SQLite integration checks NULL strings/numbers and nullable values with all three
policies, non-NULL empty/zero values and provider dataset cleanup. Final logs have
no shutdown memory leak reports. Delphi formatting and `git diff --check` pass.
The integration coverage uses SQLite and memory fields; it does not establish
behavior for other database servers/drivers. Type defaults remain limited to the
mapper's existing supported ordinary types.

## Shared attribute mapping (issue #19)

Compiled both test projects for Win32 and Win64 in Delphi 12 Community Edition
(RAD Studio 23.0), Base configuration. Command-line compilation is unavailable
in this edition; compilation used the IDE and execution used
`tools/build.ps1 -Suite Core/FireDAC -Platform Win32/Win64 -TestsOnly`.

| Suite | Win32 passed | Win64 passed | Failed/errors/ignored/leaked |
| --- | ---: | ---: | --- |
| Core without FireDAC | 905 | 905 | 0/0/0/0 |
| FireDAC/SQLite and memory fields | 89 | 89 | 0/0/0/0 |

Core regressions cover shared read/write names, case-insensitive aliases,
inherited and ignored properties, key callbacks and object write operations,
duplicate names, conflicting/blank attributes, direction-specific eligibility,
validation before getters/callbacks, explicit nonpublic write property RTTI,
and exclusion of fields even with field RTTI. Existing conversion, nullable,
streaming, concurrency and ownership tests remain passing. The FireDAC suite
includes an attributed DTO insert/read/update/read round trip using differently
named physical columns and result aliases. Final test logs contain no shutdown
memory leak reports. Delphi formatting and `git diff --check` pass.

Field support remains deferred to avoid automatically adding write columns to
existing DTOs; the property-only contract and compatibility behavior are documented
in [Object Mapping](OBJECT_MAPPING.md#shared-readwrite-attributes). SQLite and
memory-field tests do not establish other database server/driver behavior.

## Automatic nullable mapping and result conversions (issue #16, PR #18)

Both suites were rebuilt through IDE Project > Build, Base configuration, using
Delphi 12 Community Edition / RAD Studio 23.0 (bds.exe 29.0.51961.7529).
All four final builds completed with zero compiler warnings/errors. Community
Edition does not support command-line compilation. Tests were then run with
`tools/build.ps1 -TestsOnly`, selecting Core/FireDAC and Win32/Win64:

| Suite | Win32 | Win64 | Failed/errors/ignored/leaked |
| --- | ---: | ---: | --- |
| Core without FireDAC | 727 | 727 | 0/0/0/0 |
| FireDAC/SQLite and memory fields | 46 | 46 | 0/0/0/0 |

The 32 mapping-value tests include actual RTTI property assignment for all 20
built-in nullable inner types without registration, SQL NULL versus zero/False/
empty strings/empty byte arrays, signed/unsigned boundaries, managed lifetime,
exact numeric precision and overflow rejection, BCD/GUID/timestamp records,
custom nullable types, exact converter precedence, explicit built-in registration,
duplicate/nil registration errors, scoped nmbSkip, contextual converter
failures and object cleanup. A compatibility regression first failed with 42
instead of 242 when an exact converter returned a complete nullable record;
the final dispatcher preserves that converter ahead of default construction,
while explicit nullable registrations still take precedence. SQL NULL never
reaches ordinary converters. The minimum Currency regression constructs exactly
-922337203685477.5808 with typed Currency subtraction and verifies the BCD and
Currency round trip on both platforms. No Currency conversion bug was found.

The alias regression compares inner and closed-generic RTTI identities for
Double/Extended and Double/TDateTime on each target, then maps each specialization.
Concurrent mapping runs 128 iterations through automatic integer/string/byte-array
property assignments. The built-in registry is published once by unit initialization,
is read-only during mapping and does not capture caller-owned options.

Fluent tests exercise ToList and FirstOrDefault without options, immediate facade
release, independently retained facade/raw references, managed values after result
destruction and ownership on failure. All existing PR #14 result-lifetime tests pass.
SQLite integration runs both terminal methods on nullable DTOs without registrations;
native BCD/timestamp/offset FireDAC field-reader regressions also pass.

Both generator checks (including 69 paired reference scenarios), eight Python
generator tests, Delphi formatting and `git diff --check` pass. The
[validation record](nullable-mapping-validation.json) contains the final source,
executable and report hashes with verified x86/x64 PE architectures. It replaces
the earlier explicit-registration snapshot. Test logs contain no shutdown memory
leak reports. The initial standalone generic-RTTI probes remain covered by the
permanent `ClosedGenericPropertyRTTI` test.

Limitations: no separate Delphi 12.3+ compiler installation was tested. SQLite
and FireDAC memory fields do not prove SQL Server/Oracle server or driver behavior;
no such servers were available. Public APIs, nullable layout, SQL compilation,
providers and attribute behavior are unchanged by the automatic-registry update.

## Deterministic fluent result lifetime

All four projects were rebuilt using Delphi 12 Community Edition, RAD Studio
23.0, bds.exe 29.0.51961.7529, IDE Project > Build, Base configuration. All
builds had zero warnings/errors. The resulting executables passed:

| Suite | Win32 | Win64 | Failed/errors/ignored/leaked |
| --- | ---: | ---: | --- |
| Core without FireDAC | 695 | 695 | 0/0/0/0 |
| FireDAC/SQLite in-memory | 44 | 44 | 0/0/0/0 |

Before implementation, a separate compiled generic record-helper probe on
both targets verified transferring a facade's interface through `TakeRaw`,
clearing its field, and releasing the local in `finally`. Destructor counts
reached zero immediately after a temporary expression, on success and mapping
failure, in the same routine. Named receivers were emptied, copied records
survived, and the last independently retained interface controlled destruction.
The implementation uses only normal managed interface assignments.

The core regression tests now measure result destruction before the calling
routine exits, including NULL/type failures for both mapping methods, empty
results and anonymous-method calls. Three additional cases check consuming
copies/raw references, shared mapping failure and a single-row first result.
Existing ownership counters also verify independent mapped-object lifetime.
Static mapping, reader operations, implicit conversion and AsRaw remain covered.

Three additional SQLite cases verify consecutive fluent SELECTs, early first
mapping with one/multiple/no rows, deliberately shared results with 120 rows
across fetch boundaries, and cached row/NULL/metadata access after FetchAll
with AutoClose enabled. DataSetCount proves provider query destruction in the
calling scope, including mapping exceptions. The connection remains open.
AutoClose is supplementary: early release still frees the result-owned TFDQuery.

Only the installed Delphi compiler above was available; a separate Delphi 12.3
or newer compiler was not independently tested. Both generator checks, all eight
Python tests and git diff --check pass. The JSON reports record executable
hashes and verified x86/x64 PE headers for these runs.

## Previous validation: October 23, 2026

## Fluent object mapping facade

The facade/helper change was rebuilt through IDE Project > Build in Delphi 12
Community Edition, RAD Studio 23.0 (bds.exe file version 29.0.51961.7529),
Base configuration, for Win32 and Win64. All four builds completed without
warnings/errors. Command-line compilation is disabled by this edition; the
rebuilt executables were run with `tools/build.ps1 -TestsOnly`.

| Suite | Platform | Tests | Passed | Failed/errors/ignored | Test leaks |
| --- | --- | ---: | ---: | --- | ---: |
| Core (no FireDAC) | Win32 | 692 | 692 | 0/0/0 | 0 |
| Core (no FireDAC) | Win64 | 692 | 692 | 0/0/0 | 0 |
| FireDAC/SQLite | Win32 | 41 | 41 | 0/0/0 | 0 |
| FireDAC/SQLite | Win64 | 41 | 41 | 0/0/0 | 0 |

The 17 additional core cases in FluentMapping.Tests check fluent temporary
expressions, lists/single objects and ownership, empty results, multiple rows,
aliases/attributes/ignored fields/partial projections, shared cursor position,
record assignment and clearing, independent AsRaw lifetime, implicit conversion,
static mapper compatibility, reader metadata/values/errors, SQL NULL and invalid
conversion cleanup for both methods, setter exception class preservation,
command rejection, empty facades and anonymous-method calls. Mock result lifetime
and mapped-object constructor/destructor counts verify cleanup.

The existing SQLite mapping example now uses fluent calls. The same acceptance
query (`Id`, `Title AS BookTitle`, OrderBy, Execute, ToList) runs on SQLite and
asserts every mapped value. The compiled README/EXAMPLES LoadPublishedBooks
function verifies the IsPublished filter too. The new integration case checks
record/raw lifetime, empty lists, command/NULL/conversion errors and that no
provider query remains registered after mapping scopes exit. Existing execution,
static mapping, custom provider and compiler regressions remain in the suites.

Compiler verification covers generic methods on a record helper, direct fluent
temporary calls, implicit conversion in assignments/const arguments/returned
values, default records and anonymous methods on both targets. DUnitX's
overloaded WillRaise calls use explicit TTestLocalMethod casts; list Count
assertions use NativeInt for Win64. Expression temporaries may remain alive
until routine exit: cleanup checks deliberately measure after that scope.
Mapped lists/objects remain valid after loading functions return.

Only the installed compiler build above was available. No separate Delphi 12.3
or newer compiler was run; compatibility with those exact compiler versions is
not claimed as independently verified. The source targets Delphi 12+.

Both generator checks and all eight Python generator regression tests pass.
Changed Pascal files were formatted, and git diff --check passes. The current
JSON reports include successful case counts, executable hashes and verified
x86/x64 PE architecture. The core project compiles without FireDAC units.

## Core object mapping

The object mapping change was built in Delphi 12 Community Edition (RAD Studio
23.0), using IDE Project > Build, Base configuration, on Win32 and Win64. All
four builds completed with zero warnings/errors. The command-line build was
attempted and rejected by the Community Edition license; the actual rebuilt
executables were run through `tools/build.ps1 -TestsOnly`.

| Suite | Platform | Tests | Passed | Failed/errors/ignored | Test leaks |
| --- | --- | ---: | ---: | --- | ---: |
| Core | Win32 | 675 | 675 | 0/0/0 | 0 |
| Core | Win64 | 675 | 675 | 0/0/0 | 0 |
| FireDAC/SQLite | Win32 | 40 | 40 | 0/0/0 | 0 |
| FireDAC/SQLite | Win64 | 40 | 40 | 0/0/0 | 0 |

The existing 632 core and 39 integration cases pass. Forty-three provider-free
mapping cases check actual scalar values, public/published RTTI, attributes,
aliases, partial projections, ignored/extra columns, repeated/reordered schemas,
ambiguity, SQL NULL versus typed empty bytes, checked conversions, missing RTTI,
setter exception preservation, first/empty/cursor behavior and object ownership.
Destructor counts verify cleanup after a failure on row three and a failed
FirstOrDefault. A 64-iteration parallel mapping case exercises shared metadata
and different schemas. Instrumented mock counters verify column names are read
once per result and no per-row name lookup occurs. The mock's lifetime counter
uses interlocked updates for the concurrency case. Both executable shutdown
reports were also checked: no unexpected RTL memory leaks were reported.

The PR #13 review adds 23 cases covering incompatible and zero-column schemas,
including empty results for both mapper methods; duplicate explicit/implicit
mapping names; multiple column attributes; inherited writable properties;
ignored collisions; classes with only ignored/read-only properties; alias-only
matching; and successful reuse of cached metadata after schema validation fails.
The prior unmapped-duplicates test now includes one matching column, preserving
its original extra-column check under the new minimum-one-match requirement.
Constructor/destructor counts and result reads verify that validation failures
occur before construction and cursor advancement. Existing row-three failure
and single-object cleanup regressions continue to pass. Metadata errors include
the available schema, and duplicate mapping names are rejected before caching.

The additional SQLite case executes the compiled examples in MappingExamples.pas
through IQueryExecutor and IQuery.Execute, checking list values, aliases,
reordered columns, single/empty results and rejection of SQL NULL. It runs
against SQLite :memory: using the existing optional FireDAC provider.

The JSON reports record current executable hashes and verified x86/x64 PE
headers. Both generator checks and all eight Python generator regression tests
pass. Delphi Formatter was applied to changed Pascal files; git diff --check
passes. Query.Core, Query.DataMapper, Execution, SQL compilers and provider
implementations are unchanged. The mapper has no FireDAC, ADO or Data.DB imports.

SQL NULL, nullable types, binary/record/object mapping and advanced conversions
remain unsupported as documented in [Object Mapping](OBJECT_MAPPING.md).
Allocation failures and runtime package unloading were not exercised; mapped
classes must remain loaded while their cached RTTI is in use.

## Earlier compiler-factory validation

Compiler-factory class update (issue #10), based on merged documentation main. Earlier
test counts and binary hashes are superseded by the object mapping run above.

Delphi 12 Community Edition (RAD Studio 23.0), Windows. Command-line compilation
was attempted with tools/build.ps1 and rejected by the installed Community
Edition license. Full builds were therefore performed with IDE Project > Build
(Base configuration). Test executables were run with tools/build.ps1 -TestsOnly.

| Suite | Platform | Tests | Passed | Failed/errors/ignored | Test leaks |
| --- | --- | ---: | ---: | --- | ---: |
| Core | Win32 | 632 | 632 | 0 | 0 |
| Core | Win64 | 632 | 632 | 0 | 0 |
| FireDAC | Win32 | 39 | 39 | 0 | 0 |
| FireDAC | Win64 | 39 | 39 | 0 | 0 |

All four full builds reported zero errors, warnings and hints.
The six FactoryCreatesRequestedClass cases now exercise
TQueryCompilerFactory.CreateCompiler for each dialect. Two added cases verify
the default SQL Server compiler and EQueryException for an unsupported dialect.
The static class method replaces the free function; all library/test callers
and README/API/examples use it. Executor CreateCompiler overrides remain intact.
Existing SQL, parameter-prefix, ordered-binding and custom-compiler tests pass.
ReportMemoryLeaksOnShutdown is enabled in both projects. Resource tests also
check the connection's dataset count after failed commands and early release.
The JSON reports record executable hashes and verified x86/x64 PE headers.

The 603 existing core tests remain unchanged. Nineteen provider-free execution
tests verify delegation, custom compiler creation and parameter prefixes,
parameter ordering across all six dialects, cloning, method-based modes,
nil arguments and ReturnId rejection. A reusable in-memory mock verifies
sequential cursors, metadata (including entirely NULL columns), index/name
access, duplicate names, NULL versus empty binary values, RowsAffected and
independent executor/result lifetimes. The external-provider example is
compiled in the core project. No FireDAC or Data.DB units are linked into it.

The 39 optional cases use statically linked SQLite :memory: or native field
fixtures and exercise
SELECT (including empty results, WHERE and CTE), INSERT/UPDATE/DELETE and
RowsAffected, repeated queries and simultaneous cursors, metadata/index/name
errors, duplicate column access by index, NULL, Unicode, Boolean, dates,
large integers and binary data. Binding tests cover all six dialects, Currency,
float, UInt64 precision, GUID, BCD, scalar Variant and typed/untyped NULL.
Further tests cover invalid SQL, unsupported values/Variant arrays, explicit
modes, disconnected/nil arguments, early release, executor lifetime and rollback
of a caller-owned transaction. The documented PrintBooks/ChangeBook examples
are compiled in test/ExecutionExamples.pas as part of the optional project.
Review-follow-up regressions cover five exact BCD values (including
123456789.12345678, negatives, very large decimals and leading/trailing zeros),
FMTBcd memory-table storage, rejection of an unsafe Currency-backed BCD schema,
native timestamp/offset fractions, Single/Extended and Oracle CLOB accessors.
Decimal and timestamp precision checks use controlled field accessors and
TFDMemTable, not SQLite numeric storage as a precision oracle. Additional cases
cover portable typed NULL hints, all-NULL field metadata, empty strings/blobs
versus NULL, compiler/provider parameter mismatch, quoted question marks,
CTE/subquery bindings and explicit emRows for DML RETURNING. Failure cases
verify cleanup after binding, SQL execution and mode errors; result creation
ownership was also checked by code inspection. Allocation failures were not
injected.
Actual server-specific execution for MSSql/MySQL/PostgreSQL/Oracle/Firebird
was not tested; their existing compilation regressions and binding cases run.
Multiple resultsets and ReturnId batches are outside this version's contract.

The SQL-scanner simplification removes the core and SQLite batch-rejection
cases. Compiler SQL passthrough (EXEC with an explicit command mode) and raw
parameter regressions replace the former empty-output/statement-boundary
checks. The raw cases verify doubled quotes, quoted identifiers, nested block
and line comments, PostgreSQL dollar/E strings, Oracle q strings, MySQL
backslash quoting, explicitly escaped question-mark operators and exact :pN
SQL/named/ordered bindings. Incomplete text is no longer syntax-validated by
the scanner. The 603 prior core regressions and existing SELECT/DML integration
cases remain. Public contracts and parameter conventions are unchanged;
syntax and statement-count heuristics are deliberately absent from execution.

The IsNull(Name) addition has one new case per suite plus duplicate-name
checks in the existing cases. Both providers compare index/name NULL checks
for NULL and non-NULL Title values, mixed-case names, missing-column exception
messages and cursor access before/after iteration. The mock checks identical
GetValue/IsNull ambiguity errors. FireDAC may disambiguate duplicate aliases into distinct field names; its
integration test checks index/name agreement for resolved names, or matching
ambiguity errors when duplicate names are preserved. The compiled PrintBooks example uses IsNull('Title').
No shared result base class or new dependencies were introduced.

Documentation/example verification adds eight core cases: 31 query variants
compile for each of the six dialects (six cases), and a separate case verifies
the exact SQL Server/Oracle SQL, preview output, configurable parameter prefix
and UPDATE value ordering displayed in EXAMPLES.md. The functions and compiler
walkthrough in test/DocumentationExamples.pas are called by those tests.
The eighth core case reads seven selected MSSQL SQL blocks and their ordered
ordered text binding lists from EXAMPLES.md and compares them directly with current
compiler output using the executor-style :p prefix. Only presentation whitespace
is ignored. It covers both JOIN variants, aggregation/HAVING, IN and EXISTS
subqueries, a CTE and offset pagination. The README retains the direct compiler
default @p convention. The formatting follow-up preserved the original Delphi example tokens. This
factory update changes only factory references in those examples. Core and
FireDAC were both rebuilt and rerun on Win32/Win64 for issue #10.

One additional SQLite case runs PrintBooks, INSERT/UPDATE/DELETE inside a
caller-started transaction, rollback, the transaction-owning wrapper and the
missing-transaction error. It verifies DELETE RowsAffected and leaves the
connection open. The generic external adapter example compiles in core; no
actual external database adapter is implemented or executed.

A Delphi-token comparison verified that all 36 complete function, procedure
and unit blocks in EXAMPLES.md match the compiled example sources.
The README's short quick starts use the same tested query/reader operations;
they were syntax/API-reviewed rather than compiled as separate programs.
All 30 local Markdown links/anchors in the five Markdown documents were
checked. The sole external API reference link was opened successfully.
README/API/examples contain no template-origin comparisons or old adapter API.
LICENSE, reference data, and internal PORTING.md provenance are unchanged.
The source changes for issue #10 are limited to the factory class and its callers.

Both generator checks pass (including 69 paired Oracle scenario definitions).
All eight Python generator regression tests pass with TMP/TEMP set to
build/python-temp. This avoids sandbox cleanup restrictions on the system
temp directory encountered during earlier execution-layer validation.
Delphi Formatter.exe was applied to source/test Pascal files. Execute is outside
the generated sections and both generator checks retain it unchanged. A second
formatter pass was byte-for-byte idempotent across all 31 immediate Pascal
source/test files. git diff --check passed. Source/documentation searches found
no remaining references to the removed adapter symbol; the core source has no
FireDAC or Data.DB dependencies. Untracked IDE history files were excluded.

Commands used after the IDE builds:

```powershell
./tools/build.ps1 -Suite Core -Platform Both -TestsOnly
./tools/build.ps1 -Suite FireDAC -Platform Both -TestsOnly
python tools/generate_query.py --check
python tools/generate_oracle.py --check
python -m unittest discover -s tools -p 'test_*.py'
python tools/record_validation.py --suite Core --date 2026-10-23
python tools/record_validation.py --suite FireDAC --date 2026-10-23
```

Python commands used the bundled Python runtime because the system python.exe
is an unavailable Windows Store alias.

The reference golden SQL remains unchanged: local SqlKata source commit
`df4a2377750d34fc057c81886b481e7309ef975e`, 552 reference results, 540 direct
comparisons and 12 corrected behavior cases. The C# oracle was not regenerated
in this documentation task.

## Mapping API, streaming and performance (issue #17)

On 2026-10-24 the core and FireDAC projects were rebuilt through Delphi 12
Community Edition's Project / Build command, Base configuration, for both Win32
and Win64. Fresh native executables passed 754/754 core cases and 48/48 FireDAC
SQLite cases on each platform, with zero failed, errored, ignored or leaked
cases. The validation JSON files contain the executable hashes and verified PE
architectures. Existing execution, six-dialect compiler, nullable/native-value
and fluent mapper tests remain included.

The new core fixture adds 27 cases: cardinality and exact Next call counts,
MapCurrent before/on/after a row, returned and borrowed ownership, streaming
empty/one/many rows, callback/mapping/Next failures, preservation of callback
exception identity, short-circuiting before invalid later rows, cold concurrent
mappings of two different DTO classes, changing schemas, copied managed values,
nullable BCD/Currency and scoped converters. Existing concurrent metadata/schema
and advanced scalar/nullable suites provide additional regression coverage.
Two integration cases cover the new methods against a real FireDAC cursor and
execute every routine in MappingApiExamples.pas against an in-memory SQLite
schema, including partial projection and a LEFT JOIN with a missing author.

All seven new documentation routines were compared with their compiled source
(whitespace ignored). The two generator checks pass, including 69 paired Oracle
scenarios, and all eight Python generator regression tests pass. Formatter.exe
was applied to Pascal sources; git diff --check passes.

The initial BCD test literal was corrected to use invariant format settings.
The documentation schema declares Price as DECIMAL(18,4), because this SQLite
FireDAC configuration infers bare NUMERIC as Int64. The mapper's supported
conversions and null policies were not relaxed to accommodate driver inference.

[Performance methodology, medians, ranges and limitations](MAPPING_PERFORMANCE.md)
include optimized Win32/Win64 measurements at 100, 10,000 and 100,000 rows,
ToList versus ForEach, cold versus warm metadata, live heap samples and exact
peak DTO counts. Each platform records 108 validated observations in committed
CSV files. Timings are local observations rather than acceptance thresholds;
heap samples do not include the mock input or constitute OS memory peaks.

## Fluent mapper completion (PR #21)

The helper now exposes First, Single, SingleOrDefault and ForEach alongside its
unchanged ToList and FirstOrDefault implementations. Every new method delegates
to the existing static mapper after TakeRaw and clears the transferred interface
in finally. No static mapping/conversion, provider, cursor, Execute or SQL
compiler implementation changed. MapCurrent remains static.

Fresh Delphi 12 Community Edition Base builds and complete DUnitX runs passed:

| Suite | Win32 | Win64 |
| --- | ---: | ---: |
| Core | 822/822 | 822/822 |
| FireDAC / SQLite in memory | 62/62 | 62/62 |

Every run reports zero failed, errored, ignored and leaked cases, with no
shutdown memory-leak report. The validation JSON files record PE architecture
checks and executable SHA-256 hashes. Both builds completed without compiler
warnings. There are 68 new core cases in FluentMapping.Operations.Tests.pas and
14 new FireDAC cases, plus the existing documentation integration case now runs
nine fluent example routines.

Coverage includes temporary results with zero/one/multiple rows; exact Next call
counts; returned objects surviving result destruction; borrowed objects freed
between callbacks and on failure; immediate caller-scope resource release;
schema, NULL, conversion, setter, custom-converter, provider Next and callback
exceptions; consumed named facades; retained raw interfaces and copied facades;
nullable values, nmbSkip and custom mapping options. SQLite checks
DataSetCount immediately after terminal calls, including callback failures, and
confirms that shared readers remain usable. Single variants detect multiple rows
without SQL limits.

Anonymous test callbacks avoid capturing the facade being assigned a query
result: Delphi may otherwise retain a separate managed expression temporary in
the callback's activation record. The nullable test explicitly clears its local
anonymous check procedure to break a test-only reference cycle. Direct terminal
mapping itself releases its transferred result reference deterministically.

All nine example routines in EXAMPLES.md match MappingApiExamples.pas after
ignoring presentation whitespace and execute in the SQLite integration suite.
README, OBJECT_MAPPING, API and EXAMPLES now prefer fluent terminal calls while
retaining the static API for advanced cursor control. Existing benchmark CSVs
remain the historical static-engine measurements at commit 279b0da; this
follow-up does not change that engine or claim new performance measurements.

Both generator checks pass (including 69 paired Oracle scenarios), all eight
Python generator tests pass, local Markdown file links resolve, and
`git diff --check` passes. Formatter.exe was applied to Pascal files.

## Nullable object writing (issue #23, 2026-10-25)

Built from main `1006353` (including merged issue #20) with Delphi 12 Community
Edition, using Project > Build in the IDE and `tools/build.ps1 -TestsOnly` to
run each executable. The Community Edition command-line compiler refuses builds.

| Suite | Win32 | Win64 |
| --- | ---: | ---: |
| Core | 925 passed | 925 passed |
| FireDAC / SQLite | 94 passed | 94 passed |

All four runs report zero failed, errored, ignored and leaked cases. PE machine
headers verify the architectures; executable, report and changed source hashes
are recorded in [nullable-writing-validation.json](nullable-writing-validation.json).

The new Core fixture checks every built-in nullable specialization for exact
inner TValue identity and typed NULL hints through INSERT, UPDATE, WHERE and
HAVING; zero, False, empty strings and empty bytes; key predicate order and
rejection of NULL composite-key members before query mutation; inherited,
column-mapped and ignored properties; retained strings/bytes after DTO destruction;
scoped custom registrations/converter ordering, getter/converter/callback errors;
and NULL predicates and binding order for all six SQL dialects. Existing mapping,
NULL policy, metadata and write regressions also pass.

SQLite integration exercises the same DTO through INSERT, SELECT, UPDATE and
SELECT again, including 0, empty text, empty/populated binary and NULL states.
FireDAC parameter tests check exact BCD, GUID, timestamp fractions, timezone offset,
Boolean and empty-value bindings. Native timestamp binding was added through
FireDAC's existing typed accessors. No live SQL Server/Oracle roundtrip is claimed;
SQLite cannot establish server decimal/timestamp precision or timezone behavior.
Read-side NullBehavior and the shared attribute resolver remain unchanged.
