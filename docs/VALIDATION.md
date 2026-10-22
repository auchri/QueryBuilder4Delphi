# Validation: October 22, 2026

The execution layer replaces the previous FireDAC integration. Earlier test
counts and binary hashes are superseded by this validation run.

Delphi 12 Community Edition (RAD Studio 23.0), Windows. Command-line compilation
was attempted with tools/build.ps1 and rejected by the installed Community
Edition license. Full builds were therefore performed with IDE Project > Build
(Base configuration). Test executables were run with tools/build.ps1 -TestsOnly.

| Suite | Platform | Tests | Passed | Failed/errors/ignored | Test leaks |
| --- | --- | ---: | ---: | --- | ---: |
| Core | Win32 | 622 | 622 | 0 | 0 |
| Core | Win64 | 622 | 622 | 0 | 0 |
| FireDAC | Win32 | 38 | 38 | 0 | 0 |
| FireDAC | Win64 | 38 | 38 | 0 | 0 |

All four full builds reported zero errors, warnings and hints.
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

The 38 optional cases use statically linked SQLite :memory: or native field
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

Both generator checks pass (including 69 paired Oracle scenario definitions).
All eight Python generator regression tests pass. The first Python run failed
during temporary-directory cleanup under the sandbox's system temp path;
rerunning with TMP/TEMP set to build/python-temp passed all eight.
Delphi Formatter.exe was applied to source/test Pascal files. Execute is outside
the generated sections and both generator checks retain it unchanged. A second
formatter pass was byte-for-byte idempotent across all 30 immediate Pascal
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
python tools/record_validation.py --suite Core --date 2026-10-22
python tools/record_validation.py --suite FireDAC --date 2026-10-22
```

Python commands used the bundled Python runtime because the system python.exe
is an unavailable Windows Store alias.

The reference golden SQL remains unchanged: local SqlKata source commit
`df4a2377750d34fc057c81886b481e7309ef975e`, 552 reference results, 540 direct
comparisons and 12 corrected behavior cases. The C# oracle was not regenerated
in this execution-layer task.
