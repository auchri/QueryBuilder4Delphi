"""Audit this repository's exported Pascal declarations and Delphi XML comments.

Run from the repository root. The scanner is intentionally limited to the
declaration forms used in src, rather than claiming to be a Pascal parser.
"""
from collections import Counter
from pathlib import Path
import re
import xml.etree.ElementTree as ET

from query_documentation import parameters


def declarations(source):
    lines = source.splitlines()
    stack = []
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line == 'implementation':
            break
        if re.match(r'^(strict )?(private|protected|public|published)\b', line):
            if stack:
                stack[-1][1] = line.split()[0]
            i += 1
            continue
        visible = all(s[1] in ('public', 'published') for s in stack)
        owner = stack[-1][0] if stack else ''
        typ = re.match(r'^(\w+(?:<[^>]+>)?)\s*=\s*(.*)', line)
        method = re.match(r'^(?:class )?(function|procedure|constructor|destructor|operator)\s+(&?\w+)', line)
        prop = re.match(r'^property\s+(\w+)', line)
        field = re.match(r'^(\w+(?:,\s*\w+)*)\s*:', line) if stack else None
        kind = name = None
        if typ:
            name, rhs = typ.groups()
            kind = 'type'
            # Forward interface and single-line exception/attribute declarations
            # have no member block to enter.
            if re.match(r'(class|record|interface)\b', rhs) and not rhs.endswith(';'):
                stack.append([name, 'public' if visible else 'private'])
        elif method:
            kind, name = method.groups()
        elif prop:
            kind, name = 'property', prop[1]
        elif field:
            kind, name = 'field', field[1]
        elif line == 'end;' and stack:
            stack.pop()
        if kind:
            start = i
            if kind != 'type' or not re.match(r'(class|record|interface)\b', typ[2]):
                balance = lines[i].count('(') - lines[i].count(')')
                while (balance > 0 or ';' not in lines[i]) and i + 1 < len(lines):
                    i += 1
                    balance += lines[i].count('(') - lines[i].count(')')
            if visible:
                yield dict(kind=kind, name=name, owner=owner, start=start,
                           end=i, text=' '.join(s.strip() for s in lines[start:i+1]))
                if typ and typ[2].startswith('('):
                    for member_line in range(start + 1, i):
                        member = re.match(r'^\s*(\w+)\s*,?\s*$', lines[member_line])
                        if member:
                            yield dict(kind='enum member', name=member[1], owner=name,
                                       start=member_line, end=member_line,
                                       text=lines[member_line].strip())
        i += 1


def comment_before(lines, start):
    docs = []
    i = start - 1
    while i >= 0 and lines[i].lstrip().startswith('///'):
        docs.insert(0, lines[i].lstrip()[3:].strip())
        i -= 1
    return '\n'.join(docs)


def property_accessors(items):
    """Trivial accessors are documented by the property they implement."""
    return {(d['owner'], accessor)
            for d in items if d['kind'] == 'property'
            for accessor in re.findall(r'\b(?:read|write)\s+(\w+)', d['text'])}


def audit():
    errors = []
    allowed = {'summary', 'param', 'returns', 'remarks', 'exception', 'para', 'c', 'code', 'see'}
    for path in sorted(Path('src').glob('*.pas')):
        source = path.read_text(encoding='utf-8-sig')
        lines = source.splitlines()
        counts = Counter()
        items = list(declarations(source))
        accessors = property_accessors(items)
        for decl in items:
            label = f'{path}:{decl["start"] + 1}: {decl["owner"]}.{decl["name"]}'
            # A forward reference is not a second API definition.
            if re.search(r'= interface;', decl['text']):
                continue
            counts[decl['kind']] += 1
            doc = comment_before(lines, decl['start'])
            if not doc and (decl['owner'], decl['name']) in accessors:
                counts['accessor covered by property'] += 1
                continue
            if not doc:
                errors.append(label + ': missing XML documentation')
                continue
            try:
                root = ET.fromstring('<doc>' + doc + '</doc>')
            except ET.ParseError as exc:
                errors.append(label + ': ' + str(exc))
                continue
            crefs = [tag.get('cref') for tag in root.findall('exception')]
            if len(crefs) != len(set(crefs)):
                errors.append(label + ': duplicate exception cref')
            if root.find('summary') is None:
                errors.append(label + ': missing summary')
            for tag in root.iter():
                if tag is not root and tag.tag not in allowed:
                    errors.append(label + ': unsupported tag ' + tag.tag)
            if decl['kind'] in ('function', 'procedure', 'constructor', 'operator'):
                text = decl['text']
                signature = text[text.index('(')+1:text.rindex(')')] if '(' in text else ''
                expected = [p for p, _ in parameters(signature)]
                actual = [p.get('name') for p in root.findall('param')]
                if expected != actual:
                    errors.append(label + f': parameters {actual} != {expected}')
                if decl['kind'] in ('function', 'operator') and root.find('returns') is None:
                    errors.append(label + ': missing returns')
        print(f'{path.name}: ' + ', '.join(f'{n} {k}' for k, n in sorted(counts.items())))
    for error in errors:
        print(error)
    print(f'{len(errors)} documentation audit errors')
    return bool(errors)


if __name__ == '__main__':
    raise SystemExit(audit())
