# Feature status — Promecapt 1.1.7

| Area | Included | Limits |
| --- | --- | --- |
| Capture | Region, window, accessible elements; target detail presets; square/aspect-constrained handles; shortcut card | Element detection varies by target app's accessibility support |
| Annotations | Pen, highlighter, shapes, arrows, text, numbers; optional automatic selection after drawing and explicit reselection | Flattened images cannot recover old annotation objects |
| Redaction | Mosaic, blur, opaque black box; numeric and wheel adjustment | Mosaic and blur are visual effects; choose opaque black box for complete coverage |
| Pins | Move, resize, opacity, groups, hide, click-through recovery, persisted annotations | Full-image transformations flatten still-image annotations |
| OCR | Full capture or smaller selected region; editable result; local Vision processing | Korean and English recognition; UI languages are separate |
| History | Comma / period traversal, full screen context and original selection | Old cropped-only entries use the current desktop background |
| GIF | Configurable fps, long edge, time limit and cursor; region overlay; preview, copy, animated pin, save | One display, no audio or Promecapt windows; no GIF annotation/rotation/frame editing; temporary-frame budget |
| Languages | Korean, English, Japanese, Simplified Chinese; automatic or manual choice | Existing editors use their creation-time language; native OS dialogs follow macOS |
| Distribution | Apple Silicon and Intel DMG / ZIP; ZIP installation offer; optional SHA-256 checksums; MIT | Persistent self-signed certificate from 1.1.2; not Apple notarized |
| Updates | Manual checks; optional automatic download, installation and relaunch via Sparkle | Stable releases only; 1.0.0 needs one manual installation; first migration from ad-hoc signing may require permission refresh |

See the [README](../README.md), [testing guide](QA.md), and [release guide](RELEASING.md) for operation and verification.
