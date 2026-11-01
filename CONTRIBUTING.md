# Contributing to Promecapt

Thank you for helping improve Promecapt. Small, focused changes and reproducible bug reports are welcome.

## Development

Use macOS 13+, Swift 5.9+ and Xcode Command Line Tools. Run `bash scripts/test-local.sh` before submitting a change. With full Xcode installed, also run `swift test`. Package with `bash scripts/package.sh` and test the resulting `.app`, since screen permissions attach to the app identity.

Keep pull requests focused on one behavior and describe the problem, resulting behavior and verification. GUI changes should be checked in both light and dark appearance, with the Dock icon hidden, and with English labels as well as Korean. Include screenshot fixtures containing synthetic content rather than personal screens.

## Translations

The UI catalog is `Sources/Promecapt/Resources/Translations.json`. Korean source strings are stable lookup keys; the catalog contains `en`, `ja` and `zh-Hans`. Keep every `{0}`, `{1}`, etc. placeholder exactly once wherever the source uses it. Translate the surrounding sentence freely. Run `python3 scripts/check-localization.py`.

Persisted `DrawingTool` and `ConcealStyle` raw values are data-format identifiers: do not translate or rename them. Localize their labels at the UI boundary. Keep all four READMEs aligned when changing installation steps, privacy behavior or supported features. Existing editors use their creation-time language; new windows and menus follow the selected language immediately.

## Issues and security

Include app version, macOS version, CPU architecture, steps to reproduce, expected behavior and actual behavior. Screen captures can contain an entire display in their history context; remove private content before sharing files. Do not post credentials or signing keys. For sensitive security reports, see [SECURITY.md](SECURITY.md).

## License and assets

Contributions are provided under the project's MIT license. Only submit code and assets you have permission to contribute. Do not copy proprietary software code, icons or screenshots. The capture-frame mark is shared by `CaptureMark.swift` and the icon generator; keep its app and menu-bar variants visually consistent.
