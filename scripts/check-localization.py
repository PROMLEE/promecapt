#!/usr/bin/env python3
"""Validate UI catalogs, interpolation placeholders, and language completeness.

Pass --prune to remove catalog entries that no source file looks up any more.
"""
import json
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parent.parent
catalog_path = root / 'Sources/Promecapt/Resources/Translations.json'
catalog = json.loads(catalog_path.read_text())
LANGUAGES = ['en', 'ja', 'zh-Hans']
keys = set()
for path in (root / 'Sources/Promecapt').glob('*.swift'):
    if path.name == 'Localization.swift':
        continue
    for literal in re.findall(r'\bL\(("(?:[^"\\]|\\.)*")', path.read_text()):
        keys.add(json.loads(literal))
# These raw values are serialized identifiers, translated only at their UI boundary.
keys.update(['주석 선택','펜','형광펜','사각형','타원','선','화살표','텍스트','번호','가리기','자르기','모자이크','블러','블랙박스'])

assert sorted(catalog) == sorted(LANGUAGES), ('catalog languages', sorted(catalog))
unused = sorted(set().union(*(catalog[language].keys() for language in LANGUAGES)) - keys)
if unused and '--prune' in sys.argv:
    for language in LANGUAGES:
        for key in unused:
            catalog[language].pop(key, None)
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
    print(f'Removed {len(unused)} unused keys')
    unused = []
assert not unused, ('unused catalog keys; remove them or run with --prune', unused)

for language in LANGUAGES:
    missing = keys - catalog[language].keys()
    assert not missing, (language, sorted(missing))
    for key in keys:
        text = catalog[language][key]
        assert text.strip(), (language, key)
        assert not re.search('[가-힣]', text), ('untranslated Korean text', language, key, text)
        assert sorted(re.findall(r'\{\d+\}', key)) == sorted(re.findall(r'\{\d+\}', text)), (language, key, text)
        assert key.count('\n') == text.count('\n'), ('line count differs', language, key, text)
        assert key.endswith('…') == text.endswith('…'), ('trailing ellipsis differs', language, key, text)
print(f'{len(keys)} UI keys complete in Korean, English, Japanese and Simplified Chinese')
