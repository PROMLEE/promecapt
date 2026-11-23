#!/usr/bin/env python3
"""Check generated documentation, links and cross-document consistency.

- Repository-local link targets, including raw and blob/main GitHub URLs and #anchors
- Documentation URLs opened by the app
- The current version in .release-version across READMEs, guides, changelog and release notes
- Four-language update-window notes for every release
- Menu and button names quoted in documentation exist in the UI catalog
"""
from pathlib import Path
import json
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'scripts'))
from appcast_notes import LANGUAGES  # noqa: E402

subprocess.run([sys.executable, str(ROOT / 'scripts/generate-llms.py'), '--check'], check=True)
files = sorted(ROOT.glob('*.md')) + sorted((ROOT / 'docs').rglob('*.md'))
files += [ROOT / name for name in ('llms.txt', 'llm.txt', 'llms-full.txt')]
errors = []
checked = 0
REPO_PREFIXES = ('https://raw.githubusercontent.com/PROMLEE/promecapt/main/',
                 'https://github.com/PROMLEE/promecapt/blob/main/',
                 'https://github.com/PROMLEE/promecapt/tree/main/')
READMES = ['README.md', 'README.ko.md', 'README.ja.md', 'README.zh-CN.md']


def slug(heading):
    """GitHub's heading anchor: lowercase, drop punctuation, spaces become hyphens."""
    text = re.sub(r'<[^>]+>|[`*_]', '', heading).strip().lower()
    return re.sub(r'[^\w\- ]', '', text).replace(' ', '-')


anchor_cache = {}


def anchors(path):
    if path not in anchor_cache:
        found, counts, fenced = set(), {}, False
        for line in path.read_text().splitlines():
            if line.startswith('```'):
                fenced = not fenced
            if fenced:
                continue
            if match := re.match(r'#{1,6}\s+(.*)', line):
                name = slug(match[1])
                found.add(name if name not in counts else f'{name}-{counts[name]}')
                counts[name] = counts.get(name, 0) + 1
            found.update(re.findall(r'(?:id|name)="([^"]+)"', line))
        anchor_cache[path] = found
    return anchor_cache[path]


def check_link(source, ref, label):
    global checked
    prefix = next((p for p in REPO_PREFIXES if ref.startswith(p)), None)
    parts = urlsplit(ref)
    if prefix:
        target = ROOT / unquote(urlsplit(ref[len(prefix):]).path)
    elif parts.scheme or ref.startswith('//'):
        return
    elif ref.startswith('#'):
        target = source
    else:
        target = source.parent / unquote(parts.path)
    checked += 1
    if not target.resolve().is_relative_to(ROOT) or not target.exists():
        errors.append(f'{label}: missing link target {ref}')
    elif parts.fragment and target.suffix == '.md' and parts.fragment not in anchors(target):
        errors.append(f'{label}: missing anchor #{parts.fragment} in {target.relative_to(ROOT)}')


for file in files:
    content = file.read_text()
    refs = re.findall(r'\]\(([^)\s]+)\)', content)
    refs += re.findall(r'(?:href|src)="([^"]+)"', content)
    for ref in refs:
        check_link(file, ref, str(file.relative_to(ROOT)))

# Documentation pages the app opens must exist.
for swift in sorted((ROOT / 'Sources').rglob('*.swift')):
    for ref in re.findall(r'"(https://github\.com/PROMLEE/promecapt/(?:blob|tree)/main/[^"]+)"', swift.read_text()):
        check_link(swift, ref, str(swift.relative_to(ROOT)))

# Every README links to all four language versions.
for name in READMES:
    nav = set(re.findall(r'href="(README[^"]*\.md)"', (ROOT / name).read_text()))
    if nav != set(READMES):
        errors.append(f'{name}: language links should be {READMES}, found {sorted(nav)}')

# The current release is described consistently.
version = (ROOT / '.release-version').read_text().strip()
for name in READMES + ['docs/INSTALL.md', 'docs/INSTALL.ko.md']:
    for tag in re.findall(r'--branch v([\w.-]+)', (ROOT / name).read_text()):
        if tag != version:
            errors.append(f'{name}: clones v{tag}, current release is {version}')
for name in ['docs/INSTALL.md', 'docs/INSTALL.ko.md']:
    for found in re.findall(r'Promecapt-([\d.]+)-macos', (ROOT / name).read_text()):
        if found != version:
            errors.append(f'{name}: example archive uses {found}, current release is {version}')
if not (ROOT / 'docs/FEATURES.md').read_text().startswith(f'# Feature status — Promecapt {version}\n'):
    errors.append(f'docs/FEATURES.md: heading should name Promecapt {version}')
if f'Current release: {version}.' not in (ROOT / 'llms.txt').read_text():
    errors.append(f'llms.txt: current release should be {version}')
if f'docs/releases/{version}.md' not in (ROOT / 'llms.txt').read_text():
    errors.append(f'llms.txt: link the {version} release notes')
changelog = re.findall(r'^## (\S+)', (ROOT / 'CHANGELOG.md').read_text(), re.M)
if not changelog or changelog[0] != version:
    errors.append(f'CHANGELOG.md: first entry should be {version}')

# Release notes: Markdown, changelog entry and four-language update-window notes.
releases = ROOT / 'docs/releases'
for notes in sorted(releases.glob('*.md')):
    release = notes.stem
    if release not in changelog:
        errors.append(f'CHANGELOG.md: missing entry for {release}')
    # Localized update-window notes started with 1.1.1.
    if release not in ('1.0.0', '1.1.0') and not (releases / f'{release}.appcast.json').exists():
        errors.append(f'docs/releases/{release}.appcast.json: missing update-window notes')
for path in sorted(releases.glob('*.appcast.json')):
    release = path.name.removesuffix('.appcast.json')
    label = str(path.relative_to(ROOT))
    if not (releases / f'{release}.md').exists():
        errors.append(f'{label}: missing docs/releases/{release}.md')
    notes = json.loads(path.read_text())
    if sorted(notes) != sorted(LANGUAGES):
        errors.append(f'{label}: languages should be {list(LANGUAGES)}, found {sorted(notes)}')
        continue
    counts = {language: len(notes[language].get('changes', [])) for language in LANGUAGES}
    if len(set(counts.values())) != 1 or not counts['en']:
        errors.append(f'{label}: change lists differ in length {counts}')
    for language in LANGUAGES:
        entry = notes[language]
        if sorted(entry) != ['changes', 'heading', 'link', 'notice']:
            errors.append(f'{label} [{language}]: unexpected fields {sorted(entry)}')
        elif release not in entry['heading']:
            errors.append(f'{label} [{language}]: heading does not name {release}')
current_notes = releases / f'{version}.appcast.json'
if current_notes.exists():
    current = json.loads(current_notes.read_text())
    for path in sorted(releases.glob('*.appcast.json')):
        notes = json.loads(path.read_text())
        for language in LANGUAGES:
            if language in notes and notes[language].get('link') != current[language]['link']:
                errors.append(f'{path.relative_to(ROOT)} [{language}]: link text differs from {version}')

# Bold menu / button names ending in an ellipsis must match the app's UI catalog.
catalog = json.loads((ROOT / 'Sources/Promecapt/Resources/Translations.json').read_text())
ui_terms = set(catalog['en'])
for language in catalog.values():
    ui_terms.update(language.values())
for file in files:
    for term in re.findall(r'\*\*([^*\n]+?…)\*\*', file.read_text()):
        for part in (piece.strip() for piece in term.split('→')):
            if part.endswith('…') and part not in ui_terms:
                errors.append(f'{file.relative_to(ROOT)}: "{part}" is not an app menu or button name')

if errors:
    raise SystemExit('\n'.join(errors))
print(f'Validated {checked} repository links across {len(files)} documentation files, '
      f'release {version} references and {len(list(releases.glob("*.appcast.json")))} update-note files')
