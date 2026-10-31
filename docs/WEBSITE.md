# Documentation website and SQL converter

The website is a static GitHub Pages application. **Documentation stays in
`README.md`, `CHANGELOG.md`, and `docs/*.md`.** The build reads these files
directly; do not copy their contents into website templates. Every Markdown
file immediately inside `docs/` becomes a page. Add navigation entries in
`website/build.mjs` when introducing a new guide.

Markdown links between documentation pages become relative HTML links,
including heading anchors. Links to source files and other repository artifacts
point back to GitHub. The generated pages include syntax highlighting, an
on-page contents list, and a link to their original Markdown source.
The generated `website/dist/` directory is ignored by Git.

The footer on every page links to the current GitHub release. Its version is
read from the `Current release` declaration in `README.md`, so updating that
declaration also updates the website. The changelog and
[v2 migration guide](MIGRATION.md) are available through the Advanced menu.

## Local development

Requires Node.js 24 and npm. From the repository root:

```sh
cd website
npm ci
npm test
npm run build
npm run test:site
npm run preview
```

Open `http://127.0.0.1:4173/` for documentation or
`http://127.0.0.1:4173/converter.html` for the converter. Rebuild after editing
Markdown or website sources, then refresh the browser. Stop preview with Ctrl+C.

The build bundles all browser dependencies locally; no CDN, backend, database,
AI API, or analytics service is required. Only the selected dialect's parser is
loaded. SQL input is processed in memory and is neither uploaded nor persisted.

The converter uses CodeMirror 6, with dialect-specific SQL highlighting and a
small Delphi lexical highlighter (`website/delphi-tokens.mjs`). The generic
legacy Pascal mode was evaluated; it does not distinguish Delphi types and
calls, and treats line-leading `#` character codes as preprocessor text.
The Delphi highlighter handles generated code, doubled-quote strings, character
codes and multiline comments; it is not a complete Delphi parser or validator.
The output editor is read-only and supports selection and copying. Ctrl+Enter
(or ⌘Enter) converts; Tab indents SQL, and Escape followed by Tab leaves the
editor. Input remains limited to 50,000 characters.

Primary documentation links stay visible. Secondary pages live in a native
**Advanced** details group that opens automatically for its active page. On
mobile, this remains a single horizontally scrolling row; a right-edge fade
indicates hidden links and disappears at the end. The current page scrolls into
view on load without moving the document vertically.

Browser interaction and responsive checks run with:

```sh
npm run build
npx playwright install chromium  # Linux/macOS; Windows uses installed Edge
npm run test:browser
```

These tests start a separate local server at port 4174 and mount the site at
`/QueryBuilder4Delphi/`. They cover editing, read-only output, copy/fallback,
conversion shortcuts, invalidation/errors, navigation groups, mobile overflow,
focus and reduced motion at 1920, 1366, 768, 320, 375 and 390 pixels. CI uses
Chromium. Browser tooling is development-only; it is not shipped to visitors.

## GitHub Pages deployment

1. Merge the website files and `.github/workflows/pages.yml` into `main`.
2. In the repository's **Settings → Pages → Build and deployment**, select
   **GitHub Actions** as the source.
3. Run **Documentation & SQL converter** from the Actions tab, or push a change
   to the website, documentation or library sources on `main`.

The workflow tests the converter, builds the documentation, checks generated
links and anchors, and uploads a Pages artifact. Pull requests run these checks
without deploying. The deployment job runs only on `main` and uses the
`github-pages` environment, with write permissions scoped to that job.
If environment protection requires approval, approve the deployment in GitHub.

The default project URL is `https://auchri.github.io/QueryBuilder4Delphi/`.
All local asset and page links are relative, so the project subpath is supported.
If the repository or default branch changes, update the workflow branch filters
and repository links in `website/build.mjs`.

## SELECT conversion

`website/converter.mjs` parses SQL with `node-sql-parser` and translates a
deliberately bounded subset into the library's actual fluent API. The result is
a `BuildQuery: IQuery` function and its required imports. The browser never
compiles Delphi or executes SQL. Use the correct output dialect with
`BuildQuery.Compile(TSqlDialect.MySql)` or another matching dialect in Delphi.

Supported input dialects: MySQL, PostgreSQL, SQL Server and SQLite.

- Column selection, wildcards, DISTINCT, table and column aliases.
- INNER, LEFT and RIGHT JOIN with one column comparison; CROSS JOIN.
- Nested AND/OR conditions, scalar and column comparisons, LIKE/NOT LIKE,
  IN/NOT IN, BETWEEN/NOT BETWEEN, IS NULL/IS NOT NULL.
- GROUP BY columns and HAVING using the same supported conditions.
- ORDER BY columns, ascending or descending.
- Literal LIMIT/OFFSET, MySQL-style LIMIT offset,count, and SQL Server
  TOP and OFFSET/FETCH.

String values retain doubled apostrophes and control characters correctly in
Delphi syntax. PostgreSQL unquoted names are folded to lowercase; double-quoted
names retain their case. Values become library bindings when the generated query
is compiled. Comments are omitted from generated code.

Simple LIKE patterns use the corresponding fluent helper: `foo%` becomes
`WhereStarts('a', 'foo')`, `%foo` becomes `WhereEnds`, and `%foo%` becomes
`WhereContains`. Other patterns use `WhereLike` with the complete pattern.
NOT LIKE, OR conditions and HAVING use their corresponding method variants.

Unsupported syntax produces an error and clears any earlier output. There is no
partial conversion or raw SQL fallback. This includes writes, multiple
statements, CTEs, unions, subqueries, aggregate/function expressions, complex
JOIN predicates, placeholders, unusual identifiers, window clauses, locking
clauses, DISTINCT ON and TOP PERCENT/WITH TIES. MySQL backslash string escapes
are rejected because they depend on SQL mode. Use SQL-standard doubled quotes.
Identifiers currently use ASCII letters, digits, underscore and dollar signs,
and cannot begin with a digit. Zero row limits are rejected because the library's `Limit(0)` means
unlimited. SQL dialects and database collations can still affect comparisons;
review generated code against your application's schema and dialect.

### Numeric values and SQL types

The converter saves numeric tokens as original text before parsing SQL. Only
small placeholder integers enter the JavaScript SQL parser; user values never
pass through JavaScript floating point.

- Integer literals use exact `BigInt` range checks. Delphi `Integer` is used
  within its signed 32-bit range, and explicit `Int64(...)` outside it, up to
  `9223372036854775807`. Negative type boundaries use `Low(Integer)` and
  `Low(Int64)` so their Delphi types are explicit. Integers
  outside signed 64-bit range are rejected, including unsigned-only values.
- Ordinary decimals generate natural Delphi literals: `19.99` stays `19.99`,
  `.125` becomes `0.125`, `0001.2300` becomes `1.23`, and `1.` or `1.000`
  becomes `1.0`. The decimal point retains floating-point intent for
  integer-valued decimals. No BCD machinery, wrappers or extra imports are
  generated. The compiler resolves the natural literal through TValue's
  standard Double/Extended conversions; binding type can vary by platform.
- The default decimal policy accepts at most 15 significant digits, ignoring
  leading and insignificant trailing zeros, and excludes overflow and
  subnormal values outside the normal IEEE Double range. Range checks compare
  the original decimal against the exact bounds using integer arithmetic;
  JavaScript does not parse or round the decimal. These deliberately
  conservative limits apply even if Win32 Extended could hold more digits.
  High-precision/out-of-range values are rejected with a manual-type-selection
  hint, rather than truncating the input. Scientific notation remains unsupported.
- Paging requires integer tokens: counts fit signed 32-bit `Integer`, and
  offsets fit non-negative signed `Int64`. Fractional or scientific paging
  literals are rejected even when their mathematical value is an integer.

The converter prioritizes readable Delphi code while avoiding known unsafe
conversions. **Binary floating point is approximate and does not guarantee
exact SQL DECIMAL semantics.** Original decimal digits reach the Delphi
compiler without JavaScript reformatting; the compiler then applies ordinary
floating-point rounding. Insignificant trailing zeros and SQL decimal scale
are not preserved. Exact parameter types cannot be inferred without schema
and server information. Choose an appropriate Delphi type manually when
needed, such as Currency or TBcd for exact decimal parameters, or explicit
`TValue.From<Double>(...)` when a stable Double binding type is required.
There is no automatic BCD mode. Database/provider coercions and limits still
apply; inspect parameterized `Compile.Sql` and its bindings for your application.

## Validation

`npm test` checks conversion across all four dialects, aliases and JOIN argument
order, condition grouping, string escaping, NULL handling, paging, rejected
constructs, emitted method names against the Delphi interface, exact numeric
boundaries, generated smoke fixtures and overlapping asynchronous conversions.
`npm run test:site`, after building, checks local links, heading anchors, assets
and compatibility with a project URL subpath. Delphi compilation is a separate
check and requires an available Delphi compiler.

### Generated Delphi compilation smoke tests

From the repository root, run:

```powershell
./tools/test_converter_smoke.ps1 -Platform Both
```

This regenerates four console projects under `build/converter-smoke/` through
the production converter, then compiles and executes them using Delphi's
`dcc32` and `dcc64`. Supply `-BdsRoot` if the compiler is not on PATH. It covers
basic SELECT/WHERE, joins and aliases, nested anonymous callbacks, IN/BETWEEN/
LIKE/NULL, GROUP BY/HAVING, ordering, paging, integer boundaries and ordinary floating-point
bindings for every input dialect. Runtime assertions check SQL generation,
binding counts, Integer/Int64 types and values, and Double/Extended binding
types and approximate values. The floating-point check prints the actual
binding type and uses a relative tolerance of 1E-14; it does not assert exact
decimal arithmetic or a specific platform-dependent real-literal overload.
No database connection or FireDAC is needed for these checks.

The fixtures are generated from `website/smoke-cases.mjs`, not copied examples.
To generate them without compiling, run `npm run smoke:generate` in `website/`.
The generated files are ignored build artifacts. JavaScript tests exercise the
generation on CI; the GitHub Pages workflow does not require Delphi and does
not claim to validate Delphi compilation.

With Community Edition, open each generated `.dproj` in the Delphi IDE and
build for Windows 32-bit and Windows 64-bit.

The executables are written to the `Win32/` and `Win64/` subdirectories of
`build/converter-smoke/`. Project files derive from the repository's working
`test/QueryBuilder.Tests.dproj`, retaining its Base configuration groups,
sanitized project name, IDE metadata and target/UserTools imports. Only project
identity, relative paths and test-specific unit references are adapted. Compiler
options (`DCC_*`) are placed in the conditional Base property group: Delphi's
IDE needs this configuration scope to resolve the executable when pressing F9,
even though MSBuild also accepts unconditional compiler options. Generated
sources and project files use Windows CRLF line endings. No
debugger host-application override is used for these console executables.
Reload the project in the IDE after regenerating it. Then run:

```powershell
./tools/test_converter_smoke.ps1 -Platform Both -TestsOnly
```

This verifies that the fixture sources still match current converter output
and refuses executables older than their source or the library units. A missing
executable, rejected compilation, or failed runtime assertion fails the command.
When the installed license rejects command-line compilation, generating fixtures
and passing JavaScript checks alone is **not** proof of Delphi compilation.
