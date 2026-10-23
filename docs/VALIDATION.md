# Validation: October 23, 2026

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
