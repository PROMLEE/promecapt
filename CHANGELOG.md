# Changelog

## 1.1.11

- Open GitHub Sponsors from the menu bar or Settings → About.

## 1.1.10

- Copy OCR text with Command-C and close the result window after a successful copy. Copy selected text, or all text when nothing is selected; the Copy all button also closes the window.
- Keep GIF recording controls on the recording display, including monitors with negative or vertically arranged coordinates.

## 1.1.9

- Reorder toolbar buttons in Settings → Tools by dragging rows or using Move up / Move down.
- Vertically center capture dimensions and show them only in region-adjustment mode.
- Keep tool buttons on the first row; show color, width and conceal settings on a second row only when needed.
- Add Remember last capture tool (off by default) to start the next capture with the last explicitly chosen tool.

## 1.1.8

- Use one adjacent, borderless toolbar row with monochrome selection indicators.
- Enter capture width and height directly in pixels; oversized values stay within the display.
- Choose visible buttons in Settings → Tools. Hidden actions remain available in All tools (…).
- Make the shortcut card translucent while keeping text opaque, and document how to open the separate image editor.

## 1.1.7

- Replace duplicate capture dimensions with one size readout and a draggable shortcut card; H collapses or expands the card.
- Use Shift-drag for a square and Command-drag to preserve the aspect ratio at the start of a region adjustment.
- Add automatic target detail settings: Fine, Balanced (default), Prefer large areas and Windows only.
- Read the entire selected capture with OCR or O; use Option-click or Shift-O for a smaller OCR region.

## 1.1.6

- Drag empty toolbar space to reposition capture and pin-edit tools.
- Keep the manually chosen position when switching tools or resizing contextual controls.
- Constrain the entire toolbar to the display’s visible area, below the menu bar and notch.

## 1.1.5

- Keep the drawing tool active when automatically selecting a newly drawn annotation. Adjust that object immediately, then draw again on empty space without reselecting the tool.
- Limit Space window-target switching to before capture selection; do not reset an active annotation tool.
- Resolve toolbar help from the current hit target after resizing/hiding controls, cancel stale delayed help and avoid duplicate native tooltips.
- Tighten button spacing while preserving native popup/color-well bezel clearance.

## 1.1.4

- Fit annotation symbols inside flexible-height native button bezels and keep enabled dark-mode icons white even in non-key capture windows.
- Reduce toolbar padding and remove its expanding spacer; size capture and pin-edit toolbars to visible controls.
- Add an explicit Apply button to the native color panel and restore its previous accessory view on close.
- Use the same icon buttons in the standalone editor.

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
