# Promecapt for Windows

This C#/.NET 8 WPF prototype captures a region on the monitor under the pointer. It opens the selected image for freehand annotation, highlighting, copying or pinning above other windows.

## Build

Run from the repository root with the .NET 8 SDK:

```sh
dotnet build windows/Promecapt/Promecapt.csproj -c Release
dotnet publish windows/Promecapt/Promecapt.csproj -c Release -r win-x64 --self-contained true -o dist/windows-x64
```

Build and publish also work from macOS with Windows targeting enabled. Run the published folder on Windows x64 by opening `Promecapt.exe`. Keep all files in that folder together. The Windows GitHub Actions workflow produces an equivalent downloadable artifact.

## First run on Windows

1. Open Promecapt from the notification area or press **Ctrl+Alt+1**. If another app registered the shortcut, use the notification-area menu.
2. Drag a region and release to open the editor. Press **Esc** to cancel.
3. Draw with the pen or highlighter. Press **Ctrl+Z** to remove the last stroke.
4. Press **Ctrl+C** to copy the image or **Ctrl+Enter** to pin it. The pinned window can be moved and resized, and **Esc** closes it while focused.

Check capture on a second monitor with different DPI and a negative origin, copy the annotated image into Paint and confirm its pixel dimensions, then pin it over another app. This is an initial implementation. OCR, GIF recording, capture history and Windows installation/update support are outside its current scope.
