<div align="center">
  <img src="assets/app-icon.svg" width="112" alt="Promecapt icon">
  <h1>Promecapt</h1>
  <p><strong>Capture. Annotate. Keep it in sight.</strong></p>
  <p>A native macOS screenshot, annotation, pinning and GIF recording app.</p>
  <p><a href="README.md">English</a> · <a href="README.ko.md">한국어</a> · <a href="README.ja.md">日本語</a> · <a href="README.zh-CN.md">简体中文</a></p>
  <p><a href="https://github.com/PROMLEE/promecapt/releases">Download</a> · <a href="#quick-start">Quick start</a> · <a href="https://github.com/PROMLEE/promecapt/issues">Report an issue</a></p>
  <p>macOS 13+ · Apple Silicon & Intel · MIT License · v1.0.0</p>
</div>

![Illustrated capture, annotation and pinning workflow](assets/overview.svg)

## Why Promecapt?

Select a window or region, annotate it without leaving the screen, and pin the result above your other apps. Keep a reference nearby, extract text from a small area, or record a short GIF—all from the menu bar.

- **Capture in place.** Automatic window and accessible element detection, eight resize handles, and keyboard adjustments.
- **Editable annotations.** Pen, highlighter, shapes, arrows, text and numbered badges. Select an annotation later to move, resize or restyle it.
- **Redact in one tool.** Mosaic, blur and black box, with scroll-wheel width or strength controls.
- **Pin images and GIFs.** Floating, resizable references with zoom, opacity, groups, click-through and restoration after relaunch. GIF pins keep playing.
- **Region OCR.** Drag only the text you want to recognize; review and copy the result. Current OCR languages: Korean and English.
- **Capture history.** `,` and `.` move through captures and restore their surrounding screen context.
- **GIF recording.** Visible recording region; configurable frame rate, resolution, duration and pointer. Preview, copy, pin or save when finished.
- **Four UI languages.** Korean, English, Japanese and Simplified Chinese, with system language detection and a manual setting.

## Install

Download a ZIP from [Releases](https://github.com/PROMLEE/promecapt/releases), choosing **arm64** for Apple Silicon or **x86_64** for Intel. Unzip, move **Promecapt.app** to Applications, and launch it. Look for the capture-frame icon in your menu bar.

**Signing status:** the initial distribution is ad-hoc signed, not Apple Developer ID signed or notarized. macOS may block opening it. Review the source and build locally, or follow [Apple's instructions for opening a trusted app](https://support.apple.com/102445). No security protections need to be disabled globally.

On first capture, allow Promecapt in **System Settings → Privacy & Security → Screen Recording** (called **Screen & System Audio Recording** on newer macOS), then relaunch. Accessibility permission enables app-element detection and more reliable global shortcuts. Audio is not recorded.

## Quick start

| Action | Default shortcut / gesture |
| --- | --- |
| Capture a region or window | `⌥⌘1`, then drag or click an automatically detected target |
| Copy capture / pin capture | `⌘C` / `⌘Enter` |
| Pin clipboard | `⌥⌘3` |
| Show / hide all pins | `⌥⌘4` |
| Browse older / newer captures | `,` / `.` during capture |
| Cancel capture / close a pin | `Esc` |
| Open settings | Menu bar icon → Settings, or `⌘,` while the app is active |
| Change stroke width / redaction strength | Scroll over the image, or use the numeric stepper |
| Move / zoom a pin | Drag / scroll |
| Change pin opacity | `Ctrl` + scroll |
| Edit a still-image pin in place | `Space`; use the selection tool to edit existing annotations |
| Record a GIF | Menu bar → Record GIF region, or the capture toolbar's GIF button |

Choose the **F1 / F3 / F4** preset or your own shortcuts in Settings → Shortcuts. In media-key mode, use `Fn+F1` or enable standard function keys in macOS. `Enter` confirms text; it does not finish a capture.

Settings → General selects your language and Dock visibility. Menu bar operation works with the Dock icon hidden.

## GIF recording

Settings → GIF offers **5–30 fps**, a **640 / 1280 / 1920 px long edge or original Retina pixels**, and **15 / 30 / 60 second** limits. The app never upscales the source. Static screens may produce fewer frames; recording also stops at 256 MiB of temporary frame files.

A red dashed border and light outside shading mark the recording region without blocking clicks. After stopping, the result window provides playback, **Copy**, **Pin** and **Save**. Copy includes original GIF data, a GIF attachment path and a PNG fallback; animation when pasted depends on the receiving app. Recording stays within one display, excludes Promecapt windows, and captures no audio. GIF annotation, rotation and frame editing are not supported yet.

## Privacy & storage

Capture, annotation and OCR processing happen locally. There is no account, upload service or analytics in the app.

History stores the selected image **and the full display snapshot with its selection position**, so browsing can restore the surrounding screen. Keep this in mind when capturing private material. The history limit and Clear History remove these backgrounds too; pins are stored separately. Older cropped-only records use the current capture's screen background because their original context was never saved.

Existing Promepaste users keep their preferences and library. For compatibility, the bundle identifier remains `com.promlee.promepaste` and the library remains under `~/Library/Application Support/Promepaste`. GIF clipboard attachments are cached locally and older copies expire when new copies are made.

## Build from source

Requires macOS 13+, Swift 5.9+ and Xcode Command Line Tools. Full Xcode is needed for `swift test`. No external Swift package dependencies.

```sh
git clone https://github.com/PROMLEE/promecapt.git
cd promecapt
bash scripts/test-local.sh
bash scripts/package.sh
open dist/Promecapt.app
```

The local check runner works without the full Xcode installation. CI also runs XCTest on Apple Silicon and Intel. `ARCH=x86_64` or `ARCH=arm64` selects a packaging target. See [testing](docs/QA.md), [release instructions](docs/RELEASING.md) and the [changelog](CHANGELOG.md).

## Contributing

Bug reports, accessibility improvements and translation fixes are welcome. Include macOS version, CPU architecture, app version and concise reproduction steps; remove private screen content before attaching examples. Start with [CONTRIBUTING.md](CONTRIBUTING.md). UI strings are in `Sources/Promecapt/Resources/Translations.json`.

Developer ID signing, notarization and a signed automatic updater are planned; **automatic updates are not implemented in 1.0.0**. The design is documented in [AUTO-UPDATE.md](docs/AUTO-UPDATE.md).

## License & attribution

[MIT License](LICENSE)—personal and commercial use, modification and redistribution are permitted under its terms. Promecapt is an independent project inspired by screen-capture workflows, not affiliated with Snipaste. No Snipaste source code, binaries or visual assets are distributed with this project. The app and menu bar icons are generated from Promecapt's shared capture-frame mark.
