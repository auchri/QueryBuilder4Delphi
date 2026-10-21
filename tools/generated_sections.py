"""Replace explicitly marked generated Pascal sections without changing other code."""


def replace_section(source: str, name: str, generated: str, indent: str = '') -> str:
    begin = f'{indent}// BEGIN GENERATED: {name}'
    end = f'{indent}// END GENERATED: {name}'
    lines = source.splitlines(keepends=True)
    starts = [i for i, line in enumerate(lines) if line.rstrip('\r\n') == begin]
    stops = [i for i, line in enumerate(lines) if line.rstrip('\r\n') == end]
    if len(starts) != 1 or len(stops) != 1 or starts[0] >= stops[0]:
        raise ValueError(f'Missing, duplicated, or reversed generated section: {name}')
    start, stop = starts[0], stops[0]
    return ''.join(lines[:start + 1]) + generated.rstrip('\r\n') + '\n' + ''.join(lines[stop:])


def update_files(outputs: dict, check: bool = False) -> None:
    """Check all outputs before writing; preserve UTF-8 BOMs and use Pascal CRLF."""
    stale = []
    for path, content in outputs.items():
        if not path.exists() or path.read_text(encoding='utf-8-sig') != content:
            stale.append(path)
    if check and stale:
        raise SystemExit('Generated files are stale: ' + ', '.join(map(str, stale)))
    if not check:
        for path in stale:
            encoding = 'utf-8-sig' if path.exists() and path.read_bytes().startswith(b'\xef\xbb\xbf') else 'utf-8'
            path.write_text(outputs[path], encoding=encoding, newline='\r\n')
