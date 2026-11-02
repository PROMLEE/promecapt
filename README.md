<div align="center">
  <img src="assets/app-icon.svg" width="88" alt="Promecapt">
  <h1>Promecapt</h1>
  <p><strong>Capture. Annotate. Keep it in sight.</strong></p>
  <p>An open-source screenshot tool for macOS. Capture, annotate, pin and record GIFs.</p>
  <p><a href="https://github.com/PROMLEE/promecapt/releases/latest">Download</a> · <a href="docs/INSTALL.md">Install guide</a> · <a href="https://github.com/PROMLEE/promecapt/issues">Issues</a></p>
  <p>macOS 13+ · Apple Silicon & Intel · MIT</p>
  <p><a href="README.md">English</a> · <a href="README.ko.md">한국어</a> · <a href="README.ja.md">日本語</a> · <a href="README.zh-CN.md">简体中文</a></p>
</div>

![Actual Promecapt editor with rectangle, arrow and numbered annotations on sample data.](assets/screenshots/editor.jpg)

<p align="center"><sub>Real app screenshots · sample data · English UI</sub></p>

## Features

| Feature | Included |
| --- | --- |
| **Capture** | Regions, windows and accessible app elements |
| **Annotate** | Pen, shapes, arrows, text, numbers and editable objects |
| **Redact** | Mosaic, blur and opaque black box |
| **Pin** | Floating images and animated GIFs, zoom, opacity and groups |
| **OCR** | Select a text region; recognize Korean and English locally |
| **GIF** | 5–30 fps, resolution / duration controls, preview, copy, pin and save |

UI: 한국어 · English · 日本語 · 简体中文. [Feature limits](docs/FEATURES.md) · [Manual & optional automatic updates](docs/AUTO-UPDATE.md) from 1.1.0. Install 1.1.0 manually once if upgrading from 1.0.0.

<details>
<summary>GIF settings</summary>

![GIF settings](assets/screenshots/gif-settings.jpg)

</details>

## Install

1. Download the DMG for **Apple Silicon (arm64)** or **Intel (x86_64)** from [Releases](https://github.com/PROMLEE/promecapt/releases/latest).
2. Open the DMG and drag **Promecapt.app** onto **Applications**, then eject the disk image.
3. Open the app; enable **Screen Recording** and **Accessibility** when needed.

**Not notarized yet.** If macOS blocks a trusted download, follow the [installation guide](docs/INSTALL.md). Local builds need no paid Apple Developer account.

## Shortcuts

| Action | Shortcut |
| --- | --- |
| Capture | `⌥⌘1` |
| Copy / pin capture | `⌘C` / `⌘Enter` |
| Pin clipboard | `⌥⌘3` |
| Show / hide pins | `⌥⌘4` |
| Previous / next capture | `,` / `.` |
| Cancel / close pin | `Esc` |

Customize shortcuts, including F1, in Settings → Shortcuts. Use `Fn+F1` in media-key mode.

## Build from source

Requires free Apple Command Line Tools and Swift 5.9+. No paid developer account or signing certificate.

```sh
xcode-select --install # complete the installer before continuing
git clone --branch v1.1.1 --depth 1 https://github.com/PROMLEE/promecapt.git
cd promecapt
bash scripts/package.sh
mkdir -p "$HOME/Applications"
ditto dist/Promecapt.app "$HOME/Applications/Promecapt.app"
open "$HOME/Applications/Promecapt.app"
```

## Documentation

[Install guide](docs/INSTALL.md) · [Usage](docs/USAGE.md) · [Contributing](CONTRIBUTING.md) · [Changelog](CHANGELOG.md) · [llms.txt](llms.txt)

Local processing; no uploads or analytics. History includes full display snapshots. [Storage & privacy](docs/USAGE.md#privacy--storage).

[MIT](LICENSE) — personal and commercial use.
