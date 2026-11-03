# Contributing

QueryBuilder4Delphi is a Delphi port of [SqlKata](https://github.com/sqlkata/querybuilder),
ported from SqlKata commit `df4a2377750d34fc057c81886b481e7309ef975e`. The
query model and SQL compilers follow SqlKata; execution, object mapping and
`TNullable<T>` are Delphi additions. Intentional differences from SqlKata are
listed in the [API reference](docs/API.md#additional-behavior-and-limitations).

## Build and test

Requirements: Delphi 12 or later for Win32 and Win64, Python 3 for the
generators and checks, and Node.js 24 for the website.

1. Open `QueryBuilder4Delphi.Tests.groupproj` and use **Project > Build All
   Projects** for Win32 and Win64. It contains the core DUnitX tests and the
   FireDAC/SQLite integration tests.
2. Run both suites on both platforms:

   ```powershell
   ./tools/build.ps1 -Suite Core -Platform Both -TestsOnly
   ./tools/build.ps1 -Suite FireDAC -Platform Both -TestsOnly
   ```

   Without `-TestsOnly`, the script also compiles. That needs an edition with
   command-line compilation; Community Edition builds only in the IDE.
3. Run the generator and documentation checks from the repository root:

   ```text
   python tools/generate_query.py --check
   python tools/generate_oracle.py --check
   python tools/check_xml_documentation.py
   python -m unittest discover -s tools -p "test_*.py"
   ```

Website and converter changes are described in
[Website maintenance](docs/WEBSITE.md), including the generated Delphi smoke
projects (`build/converter-smoke/ConverterSmoke.groupproj`).

Optional: [tools/format.ps1](tools/format.ps1) runs the Delphi formatter on
`src` and `test`, and [Mapping performance](docs/MAPPING_PERFORMANCE.md)
explains how to rerun the benchmarks.

## Generated code

Do not edit generated sections by hand; change the generator and rerun it.

- **Fluent wrappers.** [tools/generate_query.py](tools/generate_query.py)
  writes the repetitive fluent declarations and implementations between
  `BEGIN GENERATED` and `END GENERATED` markers in
  `QueryBuilder4Delphi.Query.Core.pas` and `QueryBuilder4Delphi.Query.pas`.
  Their XML documentation comes from
  [tools/query_documentation.py](tools/query_documentation.py). Code outside
  the markers is never touched.
- **Reference tests.** [tools/generate_oracle.py](tools/generate_oracle.py)
  defines paired C# and Delphi scenarios. It writes `test/Oracle.Scenarios.pas`,
  the DUnitX test cases and the C# program in `tools/oracle`.

`--check` compares tokens, including comments, without writing files.

## Reference results from SqlKata

`test/golden.json` holds SQL, raw SQL and bindings that the original C#
SqlKata produces for every scenario and dialect. The Delphi tests compare
against it, so the port stays faithful to SqlKata.

To add a scenario or refresh the results, clone SqlKata next to this
repository (as `../querybuilder`), then:

```text
python tools/generate_oracle.py ../querybuilder
dotnet run --project tools/oracle -- test/golden.json
```

Twelve combinations intentionally differ from SqlKata: HAVING callbacks and
Oracle aggregate aliases. They keep the unmodified C# output in
`golden.json`, are excluded from the direct comparison, and have dedicated
tests for the corrected behavior.

## XML documentation

Every exported declaration in `src` has Delphi XML documentation:

- `///` comments directly before the declaration, using `summary`, named
  `param`, `returns` and, where useful, `remarks` and `exception cref`.
- Escape XML characters, including generic angle brackets; wrap at 110 columns.
- No C#-only tags such as `typeparam` or `inheritdoc`, and no Markdown.
- Each enum value has its own summary; the enum's summary also describes all
  values.
- Describe behavior callers rely on: fluent mutation versus cloning,
  parameterized output versus diagnostic previews, NULL handling, ownership.

`tools/check_xml_documentation.py` checks coverage, XML validity, the tag set
and that parameter names match each signature. It reads the declaration forms
used in this repository; it is not a full Delphi parser.

## Pull requests

- Add or update tests with every behavior change, and run the checks above.
- Note user-visible changes in [CHANGELOG.md](CHANGELOG.md) under
  **Unreleased**.
- Keep `README.md` examples compiling: they are checked by
  `test/DocumentationExamples.pas`.
