#!/usr/bin/env python3
"""Validate UI catalogs, interpolation placeholders, and language completeness."""
import json
from pathlib import Path
import re
root = Path(__file__).resolve().parent.parent
catalog = json.loads((root / 'Sources/Promecapt/Resources/Translations.json').read_text())
keys = set()
for path in (root / 'Sources/Promecapt').glob('*.swift'):
    if path.name == 'Localization.swift':
        continue
    for literal in re.findall(r'\bL\(("(?:[^"\\]|\\.)*")', path.read_text()):
        keys.add(json.loads(literal))
# These raw values are serialized identifiers, translated only at their UI boundary.
keys.update(['주석 선택','펜','형광펜','사각형','타원','선','화살표','텍스트','번호','가리기','자르기','모자이크','블러','블랙박스'])
for language in ['en', 'ja', 'zh-Hans']:
    missing = keys - catalog[language].keys()
    assert not missing, (language, sorted(missing))
    for key in keys:
        text = catalog[language][key]
        assert text.strip(), (language, key)
        assert sorted(re.findall(r'\{\d+\}', key)) == sorted(re.findall(r'\{\d+\}', text)), (language, key, text)
print(f'{len(keys)} UI keys complete in Korean, English, Japanese and Simplified Chinese')
