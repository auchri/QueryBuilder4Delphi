"""XML documentation source for generated fluent declarations, grouped by behavior."""

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
    lines = [f'<summary>{escape(summary, quote=False)}</summary>']
    lines += [f'<param name="{name}">{escape(text, quote=False)}</param>' for name, text in params]
    if returns:
        lines.append(f'<returns>{escape(returns, quote=False)}</returns>')
    if remarks:
        lines.append(f'<remarks>{escape(remarks, quote=False)}</remarks>')
    conditions = {}
    for name, text in exceptions:
        if text not in conditions.setdefault(name, []):
            conditions[name].append(text)
    lines += [f'<exception cref="{name}">{escape(" ".join(texts), quote=False)}</exception>'
              for name, texts in conditions.items()]
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


# Shared only where the builder uses the same operation for these arguments.
COLUMN = 'Column name, optionally qualified by a table.'
OPERATOR = 'Comparison operator accepted by the selected compiler.'
SUBQUERY = 'Non-nil query to clone; later changes to the source do not affect this clause.'
CALLBACK = 'Called immediately with a new query in the current engine scope; must return that query.'
EXPANSION = ("QueryBuilder4Delphi expands 'Books.{Id, Title}' into 'Books.Id' and 'Books.Title'. "
             'This is library shorthand, not SQL syntax.')


def predicate_doc(name, names):
    prefix, component, negative, suffix = re.fullmatch(r'(Or)?(Where|Having)(Not)?(.*)', name).groups()
    clause = component.upper()
    params = {'Column': COLUMN, 'Op': OPERATOR, 'Query': SUBQUERY, 'Callback': CALLBACK,
              'Value': 'Comparison value, normally bound as a SQL parameter.'}
    remarks, exceptions = [], []
    kind = {
        'Null': 'an IS NULL test', 'True': 'a test for the dialect true literal',
        'False': 'a test for the dialect false literal', 'Between': 'an inclusive BETWEEN test',
        'In': 'an IN test against a value list' if 'Values' in names else 'an IN test against a subquery',
        'Exists': 'an EXISTS test', 'Like': 'a LIKE pattern comparison',
        'Starts': 'a LIKE comparison with a trailing % wildcard',
        'Ends': 'a LIKE comparison with a leading % wildcard',
        'Contains': 'a LIKE comparison with leading and trailing % wildcards',
        'Date': 'a comparison of the date portion of a column',
        'Time': 'a comparison of the time portion of a column',
        'DatePart': 'a comparison of a date part of a column',
        'Raw': 'a trusted SQL predicate', 'Columns': 'a comparison between two columns',
        'Sub': 'a scalar subquery on the left of a value comparison',
    }.get(suffix)
    if kind is None:
        if 'Group' in names or ('Callback' in names and 'Column' not in names):
            kind = 'a parenthesized predicate group'
            params['Group'] = 'Non-nil query whose predicates are cloned into the group.'
            remarks.append('Uses WHERE predicates when present, otherwise HAVING predicates; empty groups are omitted.')
        elif {'Query', 'Callback'} & names:
            kind = 'a column comparison with a scalar subquery'
        else:
            kind = 'a column/value comparison'
    summary = f'Appends {kind} to {clause}' + (' and negates it.' if negative else '.')
    if prefix:
        remarks.append('Joins this predicate with OR.')
    if 'Op' not in names and suffix in ('', 'Date', 'Time', 'DatePart', 'Sub') and 'Value' in names:
        remarks.append('Uses equality (=).')
    if suffix == '' and 'Value' in names:
        remarks.append('Direct SQL NULL values compile to IS NULL for equality, or IS NOT NULL for other operators or negation. Boolean values use dialect literals.')
    if suffix == 'Between':
        params.update(Lower='Inclusive lower bound.', Higher='Inclusive upper bound.')
    elif suffix == 'In' and 'Values' in names:
        params['Values'] = 'Values copied and deduplicated using supported, type-sensitive equality.'
        remarks.append('An empty list compiles to ' + ('true for NOT IN.' if negative else 'false for IN.'))
    elif suffix == 'Exists':
        exceptions.append(('EQueryException', 'The subquery is nil or has no FROM clause.'))
    elif suffix in ('Like', 'Starts', 'Ends', 'Contains'):
        params.update(Value='Non-null string, or variable resolving to a string. Wildcards retain their pattern meaning.',
                      EscapeCharacter='Optional SQL LIKE escape text; Value is not escaped automatically.')
    elif suffix == 'Columns':
        params.update(First='Left column name.', Second='Right column name, quoted as an identifier rather than bound as a value.')
    elif suffix in ('Date', 'Time', 'DatePart'):
        params['Value'] = 'Comparison value, bound as supplied; no date/time conversion is performed by this method.'
        if suffix == 'DatePart':
            params['Part'] = 'Date part name containing ASCII letters or underscores; supported names depend on the compiler.'
    if suffix == 'Raw':
        raw_parameters(params, names, remarks)
        remarks.append('Pending Not does not negate raw predicates; include any required NOT in Sql.')
    return summary, params, remarks, exceptions


def raw_parameters(params, names, remarks):
    params['Sql'] = ('Trusted SQL fragment. ? marks a value placeholder outside quoted text and comments; '
                     '{identifier} and [identifier] request dialect quoting.')
    if 'Bindings' in names:
        params['Bindings'] = 'Placeholder values in order. Arrays expand into parameter lists, except TBytes.'
    else:
        remarks.append('Supplies no bindings; unescaped value placeholders require the overload with Bindings.')
    remarks.append('Never interpolate untrusted input into Sql. A literal question mark can be marked as \\?; the escape remains in executable SQL.')


def identifier_doc(name, names):
    summary, purpose = {
        'Select': ('Appends selected columns and switches to SELECT.', 'Columns to select, in output order'),
        'GroupBy': ('Appends grouping columns.', 'Columns used to group rows'),
        'OrderBy': ('Appends ascending sort columns.', 'Sort columns, in priority order'),
        'OrderByDesc': ('Appends descending sort columns.', 'Sort columns, in priority order'),
    }[name]
    arg = 'Columns' if 'Columns' in names else 'Column'
    text = purpose if arg == 'Columns' else purpose.replace('Columns', 'Column').replace('columns', 'column')
    if name == 'Select':
        text += '; an explicit AS alias is accepted'
    return summary, {arg: text + '.'}, [EXPANSION], []


def raw_doc(name, names):
    summary = {
        'SelectRaw': 'Appends a trusted SQL select expression and switches to SELECT.',
        'FromRaw': 'Replaces the FROM clause in the current engine scope with trusted SQL.',
        'GroupByRaw': 'Appends a trusted SQL grouping expression.',
        'OrderByRaw': 'Appends a trusted SQL ordering expression.',
    }.get(name, 'Appends a complete SQL set-operation fragment, including its keyword.')
    params, remarks, exceptions = {}, [], []
    raw_parameters(params, names, remarks)
    if name in ('CombineRaw', 'UnionRaw', 'ExceptRaw', 'IntersectRaw'):
        operation = name.removesuffix('Raw').upper()
        if operation == 'COMBINE':
            operation = 'UNION'
        remarks.insert(0, f'Supply the complete fragment, for example {operation} SELECT ...; the method adds no operation keyword.')
        exceptions.append(('EQueryException', 'This query is not a SELECT query.'))
    return summary, params, remarks, exceptions


def aggregate_doc(name, names):
    standalone = name.startswith('As')
    operation = name[2:] if standalone else name[6:]
    operation = {'Average': 'AVG'}.get(operation, operation.upper())
    params, remarks, exceptions = {}, [], []
    if standalone:
        summary = f'Switches to a standalone {operation} aggregate.'
        if name == 'AsCount' and not names:
            summary = 'Switches to a standalone COUNT(*).'
        if 'Columns' in names:
            params['Columns'] = 'Counted column names, stored as supplied; an empty array selects COUNT(*).'
        if 'Column' in names:
            params['Column'] = 'Aggregated column name, stored as supplied.'
        remarks.append('Compilation removes LIMIT, ORDER BY and GROUP BY from a clone, retaining OFFSET. Only the DISTINCT rewrite expands column shorthand through Select.')
    else:
        summary = f'Appends a {operation} select expression and switches to SELECT.'
        params.update(Column='Aggregated column name; accepts an explicit AS alias. Column shorthand is not expanded.',
                      Filter='Optional callback configuring a new query whose WHERE predicates filter this aggregate; must return that query.')
        remarks.append('The filter runs immediately when assigned. Compilation uses FILTER where supported, otherwise CASE; support depends on the database.')
        exceptions.append(('EQueryException', 'Filter returns a different query or nil.'))
    return summary, params, remarks, exceptions


def set_doc(name, names):
    operation = name.removesuffix('All').upper()
    summary = f'Appends a cloned SELECT using {operation}' + (' ALL.' if name.endswith('All') else '.')
    params = {'Query': SUBQUERY, 'Callback': CALLBACK,
              'All': 'True to request the ALL form; False requests the distinct form.'}
    remarks = ['Both queries must be SELECT queries. Operation and ALL support depend on the database.']
    return summary, params, remarks, [('EQueryException', 'Either query is not a SELECT query.')]


def scope_doc(name, names):
    return (f'Invokes the callback on this query with clauses scoped to {name[3:]}.',
            {'Callback': 'Required callback receiving this query; must return the same instance.'},
            ['Always runs immediately; compilation selects the engine-specific clauses. The previous scope is restored even on failure. Shared state such as Method is not engine-scoped.'],
            [('EQueryException', 'Callback returns a different query or nil.')])


def fluent_doc(name, signature):
    name = name.lstrip('&')
    ps = parameters(signature)
    names = {p for p, _ in ps}
    if re.match(r'(Or)?(Where|Having)', name):
        family = predicate_doc
    elif name in ('Select', 'GroupBy', 'OrderBy', 'OrderByDesc'):
        family = identifier_doc
    elif name.endswith('Raw'):
        family = raw_doc
    elif name.startswith(('As', 'Select')):
        family = aggregate_doc
    elif name.startswith('For'):
        family = scope_doc
    else:
        family = set_doc
    summary, descriptions, remarks, exceptions = family(name, names)
    if 'Callback' in names and family is not scope_doc:
        exceptions.extend([('EArgumentNilException', 'Callback is not assigned.'),
                           ('EQueryException', 'Callback returns a different query or nil.')])
    return xml_doc(summary, [(p, descriptions[p]) for p, _ in ps],
                   'This query instance, modified in place.', ' '.join(remarks) or None, exceptions)
