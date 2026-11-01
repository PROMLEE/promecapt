#!/usr/bin/env python3
"""Check generated documentation and repository-local link destinations."""
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
subprocess.run([sys.executable, str(ROOT / 'scripts/generate-llms.py'), '--check'], check=True)
files = sorted(ROOT.glob('*.md')) + sorted((ROOT / 'docs').rglob('*.md'))
files += [ROOT / name for name in ('llms.txt', 'llm.txt', 'llms-full.txt')]
errors = []
checked = 0
raw_prefix = 'https://raw.githubusercontent.com/PROMLEE/promecapt/main/'
for file in files:
    content = file.read_text()
    refs = re.findall(r'\]\(([^)]+)\)', content)
    refs += re.findall(r'(?:href|src)="([^"]+)"', content)
    for ref in refs:
        if ref.startswith(raw_prefix):
            target = ROOT / unquote(urlsplit(ref[len(raw_prefix):]).path)
        elif urlsplit(ref).scheme or ref.startswith(('#', '//')):
            continue
        else:
            target = file.parent / unquote(urlsplit(ref).path)
        checked += 1
        if not target.resolve().is_relative_to(ROOT) or not target.exists():
            errors.append(f'{file.relative_to(ROOT)}: missing link target {ref}')
if errors:
    raise SystemExit('\n'.join(errors))
print(f'Validated {checked} repository links across {len(files)} documentation files')
