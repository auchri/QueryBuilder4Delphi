# Object mapper performance

Measured 2026-10-24 at commit `279b0da`, before the fluent helper extension,
with Delphi 12 Community Edition (RAD Studio 23.0), native
Win32 and Win64 optimized Base builds, default RTL memory manager, AMD Ryzen 5
7600X, Windows NT 10.0 build 26300 on x64. Executables run from PowerShell outside
the debugger. No database, connection or driver participates in these timings.

Build [MappingBenchmarks.dproj](../benchmarks/MappingBenchmarks.dproj) for each
platform using Project / Build in Delphi 12+. This Community Edition installation
rejects command-line compiling; an IDE build is required. Then run:

```powershell
./tools/benchmark.ps1 -Platform Win32 -Output docs/mapping-benchmark-win32.csv
./tools/benchmark.ps1 -Platform Win64 -Output docs/mapping-benchmark-win64.csv
```

The default is three fresh processes per row-count/API pair. Each process measures
one cold call and five warm calls. `-Processes` changes the repetition count.
The first call discovers metadata for a previously unseen class. No production
cache-clearing API is introduced. Unit initialization (including built-in nullable
registration), process startup and fixture creation are outside the stopwatch.

The fixture is the provider-free `TMockQueryResult`. It supplies four columns:
Integer Id, Unicode string Title, Currency Price (mapped into `TNullable<Currency>`)
and Boolean Active. Input rows and their copy into the mock are prepared before
both timing and heap measurements. Every run checks the processed row count,
Id checksum and that all DTOs have been destroyed. All Ids are summed for both
APIs; callback/constructor/destructor instrumentation is included in the timings.

`mapping_ms` ends at the mapper return. For `ToList` it excludes list traversal
and destruction; `ForEach` necessarily includes the callback and per-row object
destruction. `total_ms` includes all mapping, checksum traversal/callback and DTO
cleanup for both APIs, allowing a comparison of equivalent complete work.

Heap values use `GetMemoryManagerState`: allocated medium/large block sizes plus
small-block allocated counts times usable block sizes (including block rounding).
They are **samples of live allocated Delphi heap bytes above the baseline**,
not allocation counts, OS working set, total allocation traffic or measured heap
peaks. `ToList` samples after return with its list still alive. `ForEach` samples
inside its first callback while the plan and one DTO are alive. Cold deltas also
include metadata retained in the cache. The mock's input rows are excluded by the
baseline; its own memory remains proportional to input size. Thus this measures
the mapper's output memory, not end-to-end database streaming. The separate peak
live DTO count is exact for every row, with 100/10,000/100,000 live DTOs for lists
and one for streaming. Strings in this fixture share the same constant value;
real payloads and driver buffering change memory use.

## Results

The table reports medians: three cold samples and fifteen warm samples per pair.
Raw observations (including both mapping-only and total times) are preserved in
[mapping-benchmark-win32.csv](mapping-benchmark-win32.csv) and
[mapping-benchmark-win64.csv](mapping-benchmark-win64.csv).
The [environment manifest](mapping-benchmark-environment.json) records source,
executable and CSV SHA-256 hashes and verifies each executable's architecture.

| Platform | Rows | API | Cold map ms | Warm map ms | Cold total ms | Warm total ms | Warm heap sample bytes | Peak DTOs |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Win32 | 100 | ToList | 0.171 | 0.090 | 0.176 | 0.092 | 4,928 | 100 |
| Win32 | 100 | ForEach | 0.136 | 0.087 | 0.138 | 0.087 | 120 | 1 |
| Win32 | 10,000 | ToList | 8.763 | 8.468 | 8.999 | 8.683 | 499,232 | 10,000 |
| Win32 | 10,000 | ForEach | 8.802 | 8.492 | 8.806 | 8.492 | 120 | 1 |
| Win32 | 100,000 | ToList | 85.731 | 86.440 | 88.342 | 89.364 | 4,848,404 | 100,000 |
| Win32 | 100,000 | ForEach | 84.378 | 85.856 | 84.385 | 85.856 | 120 | 1 |
| Win64 | 100 | ToList | 0.214 | 0.110 | 0.218 | 0.112 | 7,200 | 100 |
| Win64 | 100 | ForEach | 0.208 | 0.130 | 0.210 | 0.130 | 208 | 1 |
| Win64 | 10,000 | ToList | 11.261 | 11.201 | 11.573 | 11.438 | 678,416 | 10,000 |
| Win64 | 10,000 | ForEach | 11.172 | 11.029 | 11.177 | 11.029 | 208 | 1 |
| Win64 | 100,000 | ToList | 114.206 | 111.227 | 117.227 | 114.423 | 6,496,808 | 100,000 |
| Win64 | 100,000 | ForEach | 110.504 | 110.760 | 110.510 | 110.760 | 208 | 1 |

Warm timing ranges for 100,000 rows (all fifteen samples):

| Platform | API | Warm total min ms | Warm total max ms |
| --- | --- | ---: | ---: |
| Win32 | ToList | 87.395 | 112.947 |
| Win32 | ForEach | 83.732 | 88.330 |
| Win64 | ToList | 113.068 | 125.396 |
| Win64 | ForEach | 109.241 | 116.206 |

These are local observations, not throughput guarantees. Cold and warm calls also
differ in allocator, RTTI-invocation and instruction/data cache state. The class
metadata cache cost is most visible at 100 rows; large runs are dominated by
property assignment and value conversion. The benchmark does not isolate a
before/after speedup for the diagnostic-string optimization.

## Implementation and trade-offs

All public entry points call `BuildPlan` and/or the same `CreateMapped` / `MapObject`
engine. `Single` checks at most two rows; `First` reads only one; `ForEach` allocates
and frees one DTO at a time. The metadata cache stores only immutable class/property
RTTI, column names and target type information. A retained RTTI context keeps
cached properties alive. Its critical section protects both discovery and cache
publication, once per mapping call, never once per row. Concurrent cold mappings
of different DTOs are covered by the tests. There is no global plan, resultset,
cursor, connection or options cache.

A local mapping plan resolves indices and checks ambiguous/unmatched columns before
iteration. Each call rebuilds the plan so changed projections, column order and
provider schemas cannot poison later mappings. The property/column scan is linear
in each dimension (O(properties * columns)); for typical small DTO projections this
keeps validation simple without another dictionary or global schema cache.
`MapCurrent` rebuilds a plan each call: use `ForEach` for a large row loop.

Source-type names used only for failure diagnostics are now constructed only on
exceptions. Source type identity is saved before conversion, preserving the source
name even if a setter fails after conversion. Existing exact-type TValue paths,
nullable handling and validated conversions are reused. No unsafe field writes,
manual reference counting, object pooling, conversion shortcuts or per-row RTTI
discovery were added. Streaming still performs one allocation per mapped object;
its benefit is bounded simultaneously live output, not zero allocations or an
assumed speed advantage. Callback cost depends on the application.

The fluent helper now exposes all terminal operations and delegates to the static
mapper measured above. Its follow-up adds ownership-transfer wrappers only; the
static mapping/conversion engine and benchmark measurements are unchanged.
Interfaces, query execution and provider contracts were not changed to add syntax. Borrowing and cursor ownership
are documented in [the mapping examples](EXAMPLES.md#object-mapping).
