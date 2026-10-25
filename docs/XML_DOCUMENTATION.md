# Public API XML documentation audit

The audit for issue #27 starts at `27b7a45` on `main`, including merged PRs #26
and #28. Every production unit under `src/` was inspected, including the
implementation and relevant existing tests for its exported contracts.

## Coverage checklist

All entries below have XML documentation. Counts include overloaded declarations
separately and include the concrete implementation declarations as well as their
interfaces. Grouped field declarations count as one declaration.

| Production unit (`QueryBuilder4Delphi.` prefix) | Public surface reviewed |
| --- | --- |
| Query.Core | IQuery and every overload; SQL/result/executor interfaces; result facade; 4 enums and all 46 values; typed NULL; literals/variables; attributes; exceptions; aliases; clause model; value helpers and global functions |
| Query | TQuery factory; TQueryObject constructor/destructor, complete fluent implementation declarations, properties, compilation and execution |
| Query.Writes | All 10 exported write/aggregate helpers, including positional, pair, multirow and subquery overloads |
| Query.DataMapper | Object property extraction, key callbacks, nullable conversion and ownership |
| Compilers.Compiler | ICompiler and TCompiler public methods/settings; ISqlResult alias; TSqlResult fields/lifetime; TCompileContext and variable lookup |
| Compilers.Factory | Factory and dialect selection |
| Compilers.SqlServerCompiler | Class, public Boolean/random overrides and inherited factory contract |
| Compilers.MySqlCompiler | Class, public random override and inherited factory contract |
| Compilers.PostgresCompiler | Class and inherited factory/public API contract |
| Compilers.SqliteCompiler | Class, public Boolean overrides and inherited factory contract |
| Compilers.OracleCompiler | Class, public random override and inherited factory contract |
| Compilers.FirebirdCompiler | Class, public Boolean/random/identifier overrides and inherited factory contract |
| Execution | Base executor, constructor, execution mode, dialect and parameter prefix |
| Mapping | Mapper and result helper, every generic terminal, options, converter registration, exception alias, NULL policy and all 3 values |
| Mapping.Metadata | Exception, property metadata fields and global metadata function |
| Nullable | Exception, generic record, construction, Null and properties |
| Providers.FireDAC | Executor, borrowed connection/transaction ownership and first-result limitation |
| Providers.FireDAC.Parameters | Typed NULL fields/conversion and parameter binder, names, supported values and ownership |
| Providers.FireDAC.Values | Field reader, metadata categories, binary copying and decimal limitations |
| Sql.Lexer | Exported parameter mask function, offsets and scanning limits |

Consumer entry points are the query/result interfaces and factories, mapper,
nullable values, attributes, compiler contracts and optional executor. Exported
clause operations, compile contexts, metadata, scanner, write helpers and field/
binding helpers are also documented, but identified as low-level APIs where
appropriate. There are no exported constants or set types in this revision.

Deliberate exclusions are private/protected implementation members and types,
implementation-section declarations, and inherited RTL methods that the library
does not redeclare. Forward interface references are not counted as separate
definitions. Thirty-nine trivial public property accessors use the documented
property as their contract instead of repeating its text. No supported public
operation is deferred.

## Documentation conventions

Comments use `///` immediately before the declaration, with `summary`, named
`param`, `returns`, and selective `remarks`/`exception cref` elements. XML-special
characters, including generic angle brackets, are escaped. Comments wrap at
110 columns without reformatting declarations or implementation code.

The conventions follow Embarcadero's Delphi 12 documentation for
[XML Documentation Comments](https://docwiki.embarcadero.com/RADStudio/Athens/en/XML_Documentation_Comments)
and its guidance to place comments immediately before the
[documented symbol](https://docwiki.embarcadero.com/RADStudio/Sydney/en/Delphi_Comments).
No C#-specific `typeparam`, `inheritdoc`, `value`, or Markdown formatting is used.

Each enumeration value has its own preceding XML summary. The enum type summary
also describes every value, providing a fallback when an IDE displays the type
documentation rather than the individual member documentation. This does not
change enum names, order, values or scoped-enum directives.

Methods describe fluent mutation, cloning, callback identity, SQL construction
versus execution, parameterized output versus sensitive diagnostic previews,
NULL policies, cursor positioning, and ownership where applicable. Provider
contracts distinguish portable expectations from concrete FireDAC behavior.
Exception comments describe verified failure paths; they are not exhaustive
lists of exceptions the RTL, application callbacks, drivers or setters may raise.

## Regeneration and repeatable audit

`tools/query_documentation.py` is the documentation source of truth for the
fluent declarations generated by `tools/generate_query.py` into both Query.Core
and Query. The generator emits comments on declarations only. Handwritten
documentation stays beside its declarations. Existing implementation layout is
preserved, and generator checks still compare all tokens, including comments.

Run from the repository root:

```text
python tools/check_xml_documentation.py
python tools/generate_query.py --check
python tools/generate_oracle.py --check
python -m unittest discover -s tools -p "test_*.py"
git diff --check
```

The coverage checker reports every unit, parses each documentation block as XML,
checks the supported tag set, compares parameter names/order with each method
signature, requires return documentation, checks all enum values, and rejects
duplicate exception cref entries. It scans
the declaration forms used in this repository; it is not a general Delphi
parser or proof of semantic correctness. Manual comparison against implementation
and tests remains necessary.

An independent comparison against the base revision verified identical non-XML
Pascal tokens and byte-for-byte equivalent implementation text in all 20 units.
Enum layout and XML comments are the only production-source differences.

## Existing behavior noted during review

These limitations were documented without changing behavior:

- Query comments are stored and cloned, but built-in compilers do not emit them.
- Firebird WrapValue uppercases the entire quoted identifier; it does not
  preserve mixed-case identifiers supplied with explicit quotes.
- Pending Not is ignored by raw predicate compilation; callers must include the
  required NOT in their trusted SQL fragment.
- Object UPDATE key validation rejects TQueryNull (including converted empty
  nullables); it is not a general SQL NULL check for arbitrary Variant values.

## Verification results

Both Core and FireDAC projects were rebuilt through Project > Build in Delphi 12
Community Edition (RAD Studio 23.0), Base configuration, for Win32 and Win64.
Community Edition rejects command-line compilation, so the existing build script
was used with `-TestsOnly` after the IDE builds.

| Suite | Win32 passed | Win64 passed | Failed / errors / ignored / leaked |
| --- | ---: | ---: | --- |
| Core | 940 | 940 | 0 / 0 / 0 / 0 |
| FireDAC / SQLite and memory fields | 94 | 94 | 0 / 0 / 0 / 0 |

Both generator consistency checks pass (69 paired oracle scenarios); all 15
generator regression tests pass, including seven focused documentation tests. The documentation coverage/XML audit
and `git diff --check` pass. Tests and project files remain unchanged.

Delphi Help Insight was actually inspected on the generic
`TQueryResultMappingHelper.ToList<TRatedBook>` call in
`test/NullableMappingExamples.pas`. The IDE rendered the summary, Options
parameter, escaped generic return type, and ownership/cursor remarks correctly.
This is a representative check, not verification of every declaration.

An earlier attempt to inspect an enum member was interrupted when the IDE window
became unavailable. Member-specific enum rendering and exhaustive overload
rendering have not been confirmed. Type-level summaries include all enum values
as a fallback. SQLite and memory-field integration tests do not establish runtime
behavior for other database servers or FireDAC drivers.

## PR #29 clarity review

The follow-up review compared generated and handwritten comments with their
implementations across the entire coverage checklist. Templates are now grouped
by behavior rather than sharing a general parameter dictionary. In particular:

- Select, GroupBy, OrderBy and OrderByDesc explain the concrete
  `Books.{Id, Title}` expansion. Only Select mentions select aliases.
  ExpandExpression documents the first marker, final brace, comma splitting,
  trimming and lack of identifier validation.
- Aggregate arguments are stored as supplied. Standalone aggregates expand
  shorthand only through the DISTINCT rewrite; their clone removes LIMIT,
  ORDER BY and GROUP BY but retains OFFSET. Aggregate filters use WHERE only.
- Predicate overloads distinguish values, groups, scalar subqueries and value
  lists, including equality shortcuts and empty IN/NOT IN lists.
- Raw overloads distinguish supplied bindings from an empty binding list.
  Raw set operations require the caller's operation keyword. The literal
  question-mark escape remains in executable SQL; debug formatting removes it.
- JOIN, CTE, write, result-access and compiler arguments describe their own
  overloads. Converter registration names the specific duplicate registration.
  SelectAggregate accepts trusted function text without validating it.
- Repeated callback/cloning statements and getter summaries were shortened,
  while ownership, cursor progression, NULL policies and failure conditions
  remain documented. A single exception tag combines all conditions for each
  exception class. Core/query/mapping/compiler comments contain about 4,000
  fewer whitespace-separated words than the initial documentation revision.

Generation preserves declaration layout when only XML comments change, as well
as preserving implementation layout. Focused regressions cover shorthand scope,
argument relevance, overload distinctions, empty collections, optional filters,
raw placeholders/keywords, exception consolidation, XML escaping, and repeated
generation without layout changes. The final audit reports zero errors and all
20 production units still have identical non-XML tokens and implementation text
compared with main.

Core Win32 and Win64 were rebuilt successfully in the Delphi 12 IDE during this
review, with zero compiler errors/warnings/hints; 940 tests passed on each.
Subsequent edits only polished comments; the token/implementation comparison
was repeated after those edits. FireDAC's existing Win32 and Win64 executables
were rerun, with 94 tests passing on each and no failures, errors, ignored tests
or leaks. These are the executables built during the initial PR validation,
not fresh FireDAC builds for this follow-up.

Additional Help Insight checks for an enum value, Where, Select and Compile
could not be completed: the IDE window disappeared while navigating to the
examples (`foreground window did not report a process id`), and recovery
reported `launched app did not expose a targetable window`. A subsequent
[documented IDE AutoBuild](https://docwiki.embarcadero.com/RADStudio/Athens/en/IDE_Command_Line_Switches_and_Options)
attempt produced neither a fresh FireDAC executable nor an error report.
No new rendering verification is claimed. The earlier generic mapping-method
inspection remains the only successful Help Insight check; enum-member,
overload, shorthand and Compile rendering remain unconfirmed.
