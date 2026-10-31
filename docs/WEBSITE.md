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
and cannot begin with a digit. Numeric literals are limited to 15 significant
digits and JavaScript's safe integer range. Paging counts must fit a Delphi
Integer. Zero row limits are rejected because the library's `Limit(0)` means
unlimited. SQL dialects and database collations can still affect comparisons;
review generated code against your application's schema and dialect.

## Validation

`npm test` checks conversion across all four dialects, aliases and JOIN argument
order, condition grouping, string escaping, NULL handling, paging, rejected
constructs, and emitted method names against the Delphi interface.
`npm run test:site`, after building, checks local links, heading anchors, assets
and compatibility with a project URL subpath. Delphi compilation is a separate
check and requires an available Delphi compiler.
