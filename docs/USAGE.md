# Using Promecapt

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
| Change stroke width / redaction strength | Scroll over the image (one unit per wheel step), or use the numeric stepper |
| Move / zoom a pin | Drag / scroll |
| Change pin opacity | `Ctrl` + scroll |
| Edit a still-image pin in place | `Space`; use the selection tool to edit existing annotations |
| Record a GIF | Menu bar → Record GIF region, or the capture toolbar's GIF button |

Choose the **F1 / F3 / F4** preset or your own shortcuts in Settings → Shortcuts. In media-key mode, use `Fn+F1` or enable standard function keys in macOS. `Enter` confirms text; it does not finish a capture.

From 1.1.3, annotation options appear only when they apply to the active tool or selected annotation. A wheel detent changes width or redaction strength by one unit; trackpad motion accumulates distance without momentum edits. Pin zoom changes by 3% and Ctrl-wheel opacity by two percentage points per normalized step.

From 1.1.4, the annotation toolbar fits its visible controls. Dark-mode enabled icons stay white. In the color panel, choose a color and press **Apply** (or Return) to close the panel and resume editing.

From 1.1.5, automatic annotation selection leaves the drawing tool active: adjust the new object or drag on empty space to draw the next one. Choose the selection arrow explicitly to work with any older annotation. Space switches window targeting only before a capture region is selected.

Settings → General selects your language and Dock visibility. Menu bar operation works with the Dock icon hidden.

## GIF recording

Settings → GIF offers **5–30 fps**, a **640 / 1280 / 1920 px long edge or original Retina pixels**, and **15 / 30 / 60 second** limits. The app never upscales the source. Static screens may produce fewer frames; recording also stops at 256 MiB of temporary frame files.

A red dashed border and light outside shading mark the recording region without blocking clicks. After stopping, the result window provides playback, **Copy**, **Pin** and **Save**. Copy includes original GIF data, a GIF attachment path and a PNG fallback; animation when pasted depends on the receiving app. Recording stays within one display, excludes Promecapt windows, and captures no audio. GIF annotation, rotation and frame editing are not supported yet.

## Privacy & storage

Capture, annotation and OCR processing happen locally. There is no account, upload service or analytics in the app.

History stores the selected image **and the full display snapshot with its selection position**, so browsing can restore the surrounding screen. Keep this in mind when capturing private material. The history limit and Clear History remove these backgrounds too; pins are stored separately.

Your preferences and library remain on this Mac. GIF clipboard attachments are cached locally and older copies expire when new copies are made.


Drag empty space in a capture or pin-edit toolbar to move it. The position is retained during that editing session, including tool changes, and kept inside the display’s visible area below the menu bar/notch.
