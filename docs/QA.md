# Testing Promecapt

## Automated checks

```sh
python3 scripts/check-localization.py
bash scripts/test-local.sh
swift test  # full Xcode required
bash scripts/package.sh
codesign --verify --strict dist/Promecapt.app
shasum -a 256 -c dist/Promecapt-1.0.0-macos-arm64.zip.sha256
```

The local check runner covers image geometry and pixel output, editable annotations, OCR crop bounds, shortcut normalization, history traversal and context persistence, animated GIF encoding and clipboard bytes, pin restoration, overlay transparency, and UI language lookup. Catalog checks require all UI keys and placeholders in English, Japanese and Simplified Chinese. Korean is the source language. The 1.0.0 preparation passed 135 local checks; XCTest additionally runs in CI on both CPU architectures.

## Manual acceptance

- Launch the packaged app. Check its capture-frame app icon and matching monochrome menu-bar icon. Reopen from Applications to reach settings. Repeat with the Dock icon hidden.
- Select each UI language, verify menus and settings, and reopen editors. Confirm persisted tool identifiers and existing history still load. Check long English labels and Asian text for clipping.
- From another app, invoke capture with configured shortcuts, including bare F1 and Fn+F1 as appropriate to the keyboard. Check the actual crosshair before selection and drawing, hand cursor for moving, and resize cursors on handles. Close and confirm the pointer returns to normal.
- Detect windows and exposed app elements; drag a manual region. Check `Tab`, eight handles and arrow-key adjustments. Empty toolbar background must not dismiss capture.
- Draw, add text and numbered badges, redact, scroll to adjust and explicitly reselect annotations. Verify undo/redo, `Enter` text confirmation, `⌘C`, `⌘Enter` and `Esc`.
- OCR only a selected text region and confirm outside text is excluded. Current OCR recognition languages are Korean and English, independently of UI language.
- Save a capture and inspect history with `,` / `.`. New records restore their background and original pixel selection; legacy cropped-only records show the current background. Confirm exported crop pixels are preserved.
- Change GIF frame rate, long edge and time limit. Record changing synthetic content. Check the click-through recording border and shading; controls and app overlays must not appear in the exported GIF.
- Stop manually and at the time limit. Preview, copy, pin and save. Decode multiple frames, compare original GIF bytes after copying/saving, and confirm animated pins restore after app relaunch. Revert temporary test settings afterward.
- Exercise groups, ungrouping, hiding and click-through recovery. Close test pins and keep user-created data untouched.

## Signing and permissions

Ad-hoc rebuilt binaries can lose their existing macOS permission association. Refresh only this app's existing Screen Recording and Accessibility entries in System Settings, then relaunch. Authentication is completed by the user. Do not edit the TCC database, reset unrelated app permissions or disable system protections. Developer ID signing and notarization remain release prerequisites for a smoother trusted installation experience.
