"""Small, localized HTML notes embedded in the signed Sparkle appcast."""
from html import escape
import json
from pathlib import Path

LANGUAGES = ('en', 'ko', 'ja', 'zh-Hans')


def render_notes(root: Path, version: str) -> dict[str, str]:
    path = root / 'docs' / 'releases' / f'{version}.appcast.json'
    if not path.exists():
        raise ValueError(f'Missing updater release notes: {path}')
    notes = json.loads(path.read_text())
    if set(notes) != set(LANGUAGES):
        raise ValueError('Updater notes must include all four UI languages')
    result = {}
    for language in LANGUAGES:
        entry = notes[language]
        if not entry['changes'] or not all(isinstance(x, str) and x.strip() for x in entry['changes']):
            raise ValueError(f'Empty change list for {language}')
        items = ''.join(f'<li>{escape(text)}</li>' for text in entry['changes'])
        result[language] = f'''<!doctype html>
<html lang="{language}"><head><meta charset="utf-8"><meta name="color-scheme" content="light dark">
<style>
:root {{color-scheme:light dark}}
body {{font:13px/1.65 -apple-system,BlinkMacSystemFont,sans-serif;margin:18px 20px;color:#202124;background:transparent;overflow-wrap:anywhere}}
h2 {{font-size:17px;line-height:1.35;margin:0 0 12px;font-weight:650}}
ul {{padding-left:20px;margin:0 0 16px}} li {{margin:6px 0}}
.notice {{font-size:12px;padding:10px 12px;border-radius:6px;background:#edf2f8;color:#334155}}
a {{color:#075ab8;text-decoration:none}} footer {{margin-top:14px}}
@media(prefers-color-scheme:dark) {{body {{color:#f1f3f5}} .notice {{background:#263241;color:#e0e7ef}} a {{color:#8bc4ff}}}}
</style></head><body><h2>{escape(entry['heading'])}</h2><ul>{items}</ul>
<p class="notice">{escape(entry['notice'])}</p>
<footer><a href="https://github.com/PROMLEE/promecapt/releases/tag/v{version}">{escape(entry['link'])}</a></footer>
</body></html>'''
    return result
