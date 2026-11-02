# Changelog

## 1.1.3

- Use native macOS annotation controls and semantic appearance colors; prevent toolbar overlap across macOS versions and translations.
- Show color, width and redaction options only for applicable tools or selected annotations.
- Normalize accelerated wheel input to one width/strength unit per step; accumulate precise trackpad motion and ignore momentum.
- Use finer pin zoom (3%) and opacity (two percentage points) per normalized step.
- Reuse the same production signing certificate as 1.1.2.

## 1.1.2

- Reuse a pinned production code-signing certificate across releases to retain app identity. The first transition from ad-hoc signing may require permission refresh.
- Remove duplicate Settings entries and open the usage guide from Help.
- Move settings explanations into item-specific question-mark help popovers, with one sentence per line.

## 1.1.1

- Add an enabled-by-default option to select new annotations immediately for moving, resizing and style changes; disable it for continuous drawing.
- Offer installation into Applications when a ZIP app starts outside an Applications folder.
- Keep the annotation color panel above capture windows and close it with its editor.
- Use an opaque dark toolbar with bright semibold icons / labels, visible button borders and a clear selected-tool highlight.
- Cancel shortcut recording when clicking outside the recorder.
- Guide missing Screen Recording and Accessibility permissions on launch, with request buttons and live status.
- Default startup pin restoration to off; preserve explicit user preferences.

## 1.1.0

- Add manual update checks and opt-in automatic download, installation and relaunch through Sparkle.
- Verify signed, architecture-specific update feeds and archives.
- Defer installation during capture, recording, editing and open OCR / GIF results.
- Add an About tab with bundle version, build, revision, architecture, latest version and last check time.


## 1.0.0 — First public release

- Introduce **Promecapt**, an MIT-licensed, open-source alternative to proprietary screenshot tools for macOS.
- Share a capture-frame mark between the app icon and menu bar icon.
- Add Korean, English, Japanese and Simplified Chinese UI, with system detection and a language selector.
- Capture regions, windows and accessible app elements; resize and annotate in place.
- Draw editable shapes, arrows, text, numbered badges and redactions; run region OCR for Korean and English.
- Pin images and animated GIFs, group them, adjust opacity and restore them after relaunch.
- Browse capture history with `,` and `.`, preserving full-screen context for new captures.
- Record configurable GIFs with a visible region, then preview, copy, pin or save the original animation.
- Provide multilingual READMEs, contribution guidance and Apple Silicon / Intel build workflows.

Initial packages are ad-hoc signed and not notarized. Automatic updates, GIF frame editing and cross-display GIF regions are not included.
