"""XML documentation source for generated fluent declarations (not implementations)."""

import re
from html import escape
from textwrap import wrap


def parameters(signature):
    """Read parameter groups in the generator's Delphi signatures."""
    result = []
    for group in signature.split(';'):
        if ':' not in group:
            continue
        names, kind = group.split(':', 1)
        names = re.sub(r'^\s*(const|out|var)\s+', '', names)
        result.extend((name.strip(), kind.strip()) for name in names.split(','))
    return result


def xml_doc(summary, params=(), returns=None, remarks=None, exceptions=(), indent='    '):
    lines = [f'<summary>{escape(summary)}</summary>']
    lines += [f'<param name="{name}">{escape(text)}</param>' for name, text in params]
    if returns:
        lines.append(f'<returns>{escape(returns)}</returns>')
    if remarks:
        lines.append(f'<remarks>{escape(remarks)}</remarks>')
    lines += [f'<exception cref="{name}">{escape(text)}</exception>' for name, text in exceptions]
    rendered = []
    width = 110 - len(indent) - 4
    for line in lines:
        if len(line) <= width:
            rendered.append(line)
        else:
            opening, body, closing = re.fullmatch(r'(<[^>]+>)(.*)(</[^>]+>)', line).groups()
            rendered.extend([opening, *wrap(body, width=width, break_long_words=False,
                                           break_on_hyphens=False), closing])
    return '\n'.join(indent + '/// ' + line for line in rendered)


PARAMS = {
    'Column': 'Column identifier, optionally qualified by a table name.',
    'Columns': 'Column identifiers, in output order. The table.{a,b} shorthand is expanded.',
    'Op': 'Comparison operator accepted by the compiler whitelist.',
    'Value': 'Comparison value; ordinary values become SQL parameters.',
    'Lower': 'Inclusive lower bound, bound as a parameter.',
    'Higher': 'Inclusive upper bound, bound as a parameter.',
    'Group': 'Non-nil query whose predicates are cloned into a parenthesized group.',
    'Query': 'Non-nil query to clone; subsequent changes to the source do not change this clause.',
    'Callback': 'Called immediately with a new query in the current engine scope; must return that same query.',
    'Values': 'Values to copy and deduplicate by supported, type-sensitive equality; not retained as an array reference.',
    'Sql': 'Trusted SQL fragment. Use ? for values and {identifier} or [identifier] for dialect quoting. Escape a literal ? as \\?.',
    'Bindings': 'Values for unquoted ? placeholders in order. Arrays expand into parameter lists, except TBytes.',
    'First': 'Left column identifier, quoted by the compiler.',
    'Second': 'Right column identifier, quoted by the compiler rather than bound as a value.',
    'EscapeCharacter': 'Optional SQL LIKE escape text. Wildcards in Value are not escaped automatically.',
    'Part': 'Date part accepted by the selected compiler; supported parts vary by dialect.',
    'Filter': 'Optional callback configuring aggregate predicates; must return its supplied query.',
    'All': 'True to retain duplicates using the ALL form; database support depends on dialect.',
}


def fluent_doc(name, signature):
    name = name.lstrip('&')
    ps = parameters(signature)
    names = {p for p, _ in ps}
    remarks = []
    exceptions = []
    descriptions = dict(PARAMS)
    if re.match(r'(Or)?(Where|Having)', name):
        component = 'HAVING' if 'Having' in name else 'WHERE'
        suffix = name.split('Having' if 'Having' in name else 'Where', 1)[1]
        neg = suffix.startswith('Not')
        suffix = suffix.removeprefix('Not')
        join = 'OR' if name.startswith('Or') else 'AND'
        kind = {
            'Null': 'an IS NULL test', 'True': 'a comparison with the dialect true literal',
            'False': 'a comparison with the dialect false literal', 'Between': 'an inclusive BETWEEN test',
            'In': 'an IN test against a subquery' if {'Query', 'Callback'} & names else 'an IN test against a value list',
            'Exists': 'an EXISTS test against a query with a FROM clause',
            'Like': 'a LIKE pattern comparison', 'Starts': 'a LIKE comparison with a trailing % wildcard',
            'Ends': 'a LIKE comparison with a leading % wildcard',
            'Contains': 'a LIKE comparison with leading and trailing % wildcards',
            'Date': 'a comparison of the date portion', 'Time': 'a comparison of the time portion',
            'DatePart': 'a comparison of a date part', 'Raw': 'a trusted SQL predicate',
            'Columns': 'a comparison between two column identifiers',
            'Sub': 'a scalar subquery on the left of a value comparison',
        }.get(suffix)
        if kind is None:
            if 'Group' in names or ('Callback' in names and 'Column' not in names):
                kind = 'a parenthesized predicate group'
            elif {'Query', 'Callback'} & names:
                kind = 'a column comparison with a scalar subquery'
            else:
                kind = 'a column/value comparison'
        summary = f'Appends {kind} to {component}, joined with {join}' + (' and negated.' if neg else '.')
        if 'Op' not in names and (suffix in ('', 'Date', 'Time', 'DatePart', 'Sub')) and 'Value' in names:
            remarks.append('Uses equality (=).')
        if suffix == 'In' and 'Values' in names:
            remarks.append('An empty list compiles to ' + ('true for NOT IN.' if neg else 'false for IN.'))
        if suffix == 'Exists':
            exceptions.append(('EQueryException', 'The subquery is nil or has no FROM clause.'))
        if suffix == '' and 'Value' in names:
            remarks.append('SQL NULL values compile to IS NULL for equality, or IS NOT NULL for other operators or negation. Boolean values use dialect literals.')
        if suffix in ('Like', 'Starts', 'Ends', 'Contains'):
            descriptions['Value'] = 'Non-null string or variable resolving to a string. SQL wildcard characters retain their pattern meaning.'
    elif name in ('Select', 'GroupBy', 'OrderBy', 'OrderByDesc'):
        summary = {'Select': 'Appends selected column identifiers and switches the query to SELECT.',
                   'GroupBy': 'Appends grouping column identifiers.',
                   'OrderBy': 'Appends ascending sort column identifiers.',
                   'OrderByDesc': 'Appends descending sort column identifiers.'}[name]
        descriptions['Column'] = 'Column identifier or table.{a,b} shorthand; SELECT also accepts an explicit AS alias.'
    elif name.endswith('Raw'):
        summary = {
            'SelectRaw': 'Appends a trusted SQL select expression and switches to SELECT.',
            'FromRaw': 'Replaces the FROM clause in the current engine scope with trusted SQL.',
            'GroupByRaw': 'Appends a trusted SQL grouping expression.',
            'OrderByRaw': 'Appends a trusted SQL ordering expression.',
        }.get(name, 'Appends a trusted SQL set-operation fragment, including its operation keyword.')
    elif name.startswith('As'):
        agg = {'AsAverage': 'AVG', 'AsAvg': 'AVG'}.get(name, name[2:].upper())
        summary = f'Switches the query to a standalone {agg} aggregate.'
        if name == 'AsCount':
            remarks.append('No columns, or an empty column array, selects COUNT(*).')
    elif name.startswith('Select'):
        summary = f'Appends a {name[6:].upper()} aggregate select expression with an optional predicate filter.'
        remarks.append('Uses FILTER where supported, otherwise a CASE expression; SQL support varies by dialect.')
    elif name.startswith('For'):
        dialect = name[3:]
        summary = f'Invokes the callback immediately on this query, scoping added clauses to {dialect}.'
        descriptions['Callback'] = 'Required callback receiving this query; must return the same instance. The previous engine scope is restored even on failure.'
        remarks.append('The callback always runs; only compilation filters clauses by engine. Shared query state such as Method is not engine-scoped.')
    else:
        operation = name.removesuffix('All').upper()
        summary = f'Appends a cloned SELECT using {operation}' + (' ALL.' if name.endswith('All') else '.')
        remarks.append('Both queries must be SELECT queries. ALL and operation availability depend on the target database.')
        exceptions.append(('EQueryException', 'Either query is not a SELECT query.'))
    if 'Sql' in names:
        remarks.append('SQL syntax is supplied by the caller; identifier markers only perform quoting. Never interpolate untrusted input into Sql.')
        if 'Bindings' not in names:
            remarks.append('This overload supplies no bindings.')
    if 'Callback' in names and not name.startswith('For'):
        exceptions.extend([('EArgumentNilException', 'Callback is not assigned.'),
                           ('EQueryException', 'Callback returns a different query or nil.')])
    elif name.startswith('For'):
        exceptions.append(('EQueryException', 'Callback returns a different query or nil.'))
    if name.endswith('Raw') and ('Where' in name or 'Having' in name):
        remarks.append('Pending Not does not negate raw predicates; include any required NOT in Sql.')
    return xml_doc(summary, [(p, descriptions[p]) for p, _ in ps],
                   'This query instance for further fluent configuration; no SQL is executed.',
                   ' '.join(remarks) or None, exceptions)
