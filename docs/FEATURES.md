# Feature status — Promecapt 1.0.0

| Area | Included | Limits |
| --- | --- | --- |
| Capture | Region, window, accessible elements; eight handles; keyboard adjustment | Element detection varies by target app's accessibility support |
| Annotations | Pen, highlighter, shapes, arrows, text, numbers; explicit reselection | Flattened images cannot recover old annotation objects |
| Redaction | Mosaic, blur, opaque black box; numeric and wheel adjustment | Mosaic and blur are visual effects; choose opaque black box for complete coverage |
| Pins | Move, resize, opacity, groups, hide, click-through recovery, persisted annotations | Full-image transformations flatten still-image annotations |
| OCR | User-selected region, editable result, local Vision processing | Korean and English recognition; UI languages are separate |
| History | Comma / period traversal, full screen context and original selection | Old cropped-only entries use the current desktop background |
| GIF | Configurable fps, long edge, time limit and cursor; region overlay; preview, copy, animated pin, save | One display, no audio or Promecapt windows; no GIF annotation/rotation/frame editing; temporary-frame budget |
| Languages | Korean, English, Japanese, Simplified Chinese; automatic or manual choice | Existing editors use their creation-time language; native OS dialogs follow macOS |
| Distribution | Apple Silicon and Intel ZIP workflows; SHA-256 checksums; MIT | Initial distribution is ad-hoc signed and not notarized |
| Automatic updates | Design only | No automatic updater in 1.0.0 |

See the [README](../README.md), [testing guide](QA.md), and [release guide](RELEASING.md) for operation and verification.
