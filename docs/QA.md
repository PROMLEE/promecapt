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

## Updater acceptance (1.1.0)

- Manual check found a signed newer version; download / extraction and installation completed in an isolated app under the personal Applications folder.
- Enabling the automatic option downloaded and installed test version 1.1.2 over 1.1.1 without another install click. The relaunched process and About tab both reported 1.1.2, and the option remained on. A subsequent manual check reported up to date and refreshed the latest-version / last-check fields.
- Tampered archive and an archive signed by a different key failed verification against the bundled public key.
- The isolated DEBUG bundle uses its own app identifier, preferences, signing key and TestLibrary. Test feeds / archives are never published as production updates.

## Published DMG installation check (1.1.0)

- Downloaded the arm64 DMG through Safari from the public 1.1.0 release; its SHA-256 matched the published checksum.
- Opened the downloaded DMG in Finder, dragged the app onto Applications and selected Replace. Installed files matched the mounted app, and strict deep code-signature verification passed. Safari quarantine was preserved.
- Ejected the disk and launched `/Applications/Promecapt.app`. macOS blocked the unnotarized app; Done → Privacy & Security → Open Anyway → Open Anyway allowed this app to run. No global security settings or quarantine attributes were changed.
- The installed app reported 1.1.0 / revision 324a5fe, fetched the public update feed and reported up to date.
- Capture was denied despite the existing Screen Recording switch being on after replacing the local build. After user authentication, removed only the existing Promecapt entry, added `/Applications/Promecapt.app` and relaunched. Region capture then displayed its selection / annotation overlay successfully; Escape returned to Settings.

## Pending 1.1.1 UI acceptance

The Mac is locked and its owner is away. Release compilation, localization validation and the local regression checks are available; native UI acceptance is not complete. The owner explicitly requested publishing 1.1.1 for user testing before native acceptance. Do not label these behaviors as visually verified; the release notes disclose this limitation:

- ZIP fixture: installation offer, Run Here, Applications copy/relaunch, existing-app handling and no repeated prompt after installation.
- Capture: open the color well, change a shape color, confirm the panel remains above capture on each display, then close capture and confirm panel cleanup. Repeat in pinned-image editing.
- Shortcut: begin recording; click blank settings space, another control, another tab and another app. Confirm the prompt disappears and global hotkeys are restored.
- Fresh preferences: startup pin restoration is unchecked. An existing explicit opt-in remains enabled.
- Missing permissions: startup guide appears; request buttons open macOS permission flows for this installed app. Status updates after grant, hotkeys re-register, Done becomes available, and Later closes the guide. Existing stale ad-hoc entries may still require manual refresh.

### Toolbar contrast

The 1.1.1–1.1.2 bar used a custom dark palette. Its sRGB checks tested color constants, not the rendered interface or control geometry; these checks did not establish UI correctness. This approach has been replaced in the pending native-toolbar change below.

### Automatic annotation selection

Settings → Capture → Automatically select newly drawn annotations defaults to on. Verify shape / arrow / conceal / numbered badge creation switches to selection and exposes handles, Enter-confirmed text becomes selected, immediate move / resize / style editing works, and disabling the option preserves continuous drawing. Automated checks cover default-on, selected object editing, text confirmation and option-off behavior. Native mouse / handle validation remains pending Mac unlock.

## Native toolbar update — 1.1.3

- Capture and pin-edit controls use native AppKit button bezels and SF Symbols, semantic foreground/background colors and explicit 28pt button allocation. The two rows have separate heights and spacing; numeric entry fits the row.
- The standalone editor uses icon-only native segments and action buttons, so translated titles do not stretch or overlap at the 900pt minimum content width. Tooltips and accessibility names retain localized descriptions.
- `scripts/ToolbarLayoutChecks.swift`, called by `test-local.sh`, creates actual AppKit views in windows that are never ordered onscreen. It checks alignment bounds, painted control bounds and pairwise intersections for Korean, English, Japanese and Simplified Chinese in Aqua and Dark Aqua, including long history/OCR status and GIF visibility changes.
- The fixture renders 32 PNGs under `.build/toolbar-layout`. These are real offscreen view renders with synthetic blank editor content, not desktop screenshots or evidence of successful interaction. Inspected capture, OCR and minimum-width editor renders in both appearances. The full local checks pass.
- Remaining acceptance: on an unlocked Mac, open a live capture; select every tool; hover descriptions; edit thickness; open color/style controls; copy/pin/cancel; repeat on a pinned image and in a resized editor. Confirm selected/disabled states, legibility and cursor behavior on the actual screen. Native interaction remains pending because the owner cannot access the locked Mac. The owner explicitly requested publishing 1.1.3 to install and verify these changes personally; release notes disclose that remaining check.

### Contextual options and scroll input

- Show redaction styles only for the redaction tool or a selected redaction annotation. Show color only for colored annotations. Show the numeric parameter only when it applies; black box has no strength input. Hide all three during OCR/region selection and when selection mode has no selected object.
- Apply the same visibility policy in the capture/pin bar and standalone editor. Layout fixtures exercise every tool in all four languages and both appearances.
- Discrete wheel events change annotation width or redaction strength by exactly one unit, irrespective of macOS acceleration. Precise trackpad motion accumulates 24 points per step; each packet changes at most one step. Momentum and zero/horizontal deltas do not edit values. Direction changes and gesture completion clear accumulated distance.
- Pin zoom uses 3% per normalized step; Ctrl-wheel opacity uses two percentage points. Switching between the two resets the accumulator.
- Automated checks cover accelerated wheel packets, reverse direction, zero input, small precise deltas, a large packet, momentum, gesture end, invalid values and parameter bounds. Physical mouse/trackpad feel remains pending an unlocked Mac.
