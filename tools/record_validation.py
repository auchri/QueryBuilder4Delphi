"""Record successful local DUnitX runs and verify executable architectures."""
from pathlib import Path
import hashlib
import json
import struct
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
results = []
for platform, machine in [('Win32', 0x14c), ('Win64', 0x8664)]:
    folder = root / 'build' / platform
    exe = (folder / 'QueryBuilder.Tests.exe').read_bytes()
    pe = struct.unpack_from('<I', exe, 0x3c)[0]
    assert exe[:2] == b'MZ' and exe[pe:pe+4] == b'PE\0\0'
    assert struct.unpack_from('<H', exe, pe+4)[0] == machine, 'Wrong executable architecture'
    report = ET.parse(folder / 'results.xml').getroot()
    cases = report.findall('.//test-case')
    assert int(report.attrib['total']) == len(cases) > 0
    assert all(c.attrib.get('success') == 'True' for c in cases), 'Failed test case'
    assert report.attrib['errors'] == report.attrib['failures'] == '0'
    assert report.attrib['not-run'] == report.attrib['ignored'] == '0'
    results.append(dict(platform=platform, peMachine=hex(machine), tests=len(cases),
                        passed=len(cases), failed=0, errors=0, ignored=0,
                        executableSha256=hashlib.sha256(exe).hexdigest()))

summary = dict(date='2026-10-21', compiler='Delphi 12 Community Edition, RAD Studio 23.0',
               sourceCommit='df4a2377750d34fc057c81886b481e7309ef975e',
               buildMethod='IDE: Project / Build, Base configuration, zero warnings',
               referenceResults=552, directComparisons=540, correctedBehaviorCases=12,
               additionalTests=51,
               goldenSha256=hashlib.sha256((root / 'test/golden.json').read_bytes()).hexdigest(),
               results=results)
(root / 'docs/validation-results.json').write_text(json.dumps(summary, indent=2)+'\n', encoding='utf-8', newline='\n')
print(json.dumps(summary, indent=2))
