"""Replace explicitly marked generated Pascal sections without changing other code."""

import re


def pascal_tokens(source: str) -> list[str]:
    """Ignore layout while preserving strings, comments, directives and tokens."""
    pattern = (r"'(?:''|[^'])*'|//[^\r\n]*|\{[^}]*\}|\(\*.*?\*\)|"
               r'\s+|[A-Za-z_][A-Za-z_0-9]*|\$[0-9A-Fa-f]+|'
               r'\d+(?:\.\d+)?(?:[Ee][+-]?\d+)?|:=|<>|<=|>=|\.\.|\(\.|\.\)|\S')
    return [token for token in re.findall(pattern, source, re.DOTALL)
            if not token.isspace()]


def replace_section(source: str, name: str, generated: str, indent: str = '') -> str:
    begin = f'{indent}// BEGIN GENERATED: {name}'
    end = f'{indent}// END GENERATED: {name}'
    lines = source.splitlines(keepends=True)
    starts = [i for i, line in enumerate(lines) if line.rstrip('\r\n') == begin]
    stops = [i for i, line in enumerate(lines) if line.rstrip('\r\n') == end]
    if len(starts) != 1 or len(stops) != 1 or starts[0] >= stops[0]:
        raise ValueError(f'Missing, duplicated, or reversed generated section: {name}')
    start, stop = starts[0], stops[0]
    existing = ''.join(lines[start + 1:stop])
    replacement = generated.rstrip('\r\n') + '\n'
    # Documentation changes must not reformat the synchronized Pascal code.
    if pascal_tokens(existing) == pascal_tokens(replacement):
        replacement = existing
    else:
        docs = re.compile(r'(?:^[ \t]*///[^\n]*\n)+', re.MULTILINE)
        old_docs, new_docs = list(docs.finditer(existing)), list(docs.finditer(replacement))
        if (len(old_docs) == len(new_docs)
                and pascal_tokens(docs.sub('', existing)) == pascal_tokens(docs.sub('', replacement))):
            replacement = existing
            for old, new in reversed(list(zip(old_docs, new_docs))):
                replacement = replacement[:old.start()] + new.group() + replacement[old.end():]
    return ''.join(lines[:start + 1]) + replacement + ''.join(lines[stop:])


def update_files(outputs: dict, check: bool = False) -> None:
    """Preserve existing Pascal layout, UTF-8 BOMs, and use CRLF when writing."""
    stale = []
    for path, content in outputs.items():
        if not path.exists() or pascal_tokens(path.read_text(encoding='utf-8-sig')) != pascal_tokens(content):
            stale.append(path)
    if check and stale:
        raise SystemExit('Generated files are stale: ' + ', '.join(map(str, stale)))
    if not check:
        for path in stale:
            encoding = 'utf-8-sig' if path.exists() and path.read_bytes().startswith(b'\xef\xbb\xbf') else 'utf-8'
            path.write_text(outputs[path], encoding=encoding, newline='\r\n')
