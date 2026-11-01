# Install Promecapt without an Apple Developer account

**You do not need a paid Apple Developer account to build and run Promecapt on your own Mac.** Developer ID signing and notarization affect how macOS verifies a downloaded app; their absence does not mean that the app can only run on its author's computer.

Choose either a local source build or a prebuilt DMG or ZIP. Both still need the macOS permissions used by a screen-capture app. Company-managed Macs may restrict either option; check with your IT administrator if policy blocks installation.

[한국어 설치 가이드](INSTALL.ko.md) · [English README](../README.md) · [日本語](../README.ja.md#ソースからビルド) · [简体中文](../README.zh-CN.md#从源码构建)

## Option A — Build locally, with free Apple tools

### 1. Install the command-line tools

Open Terminal and run:

```sh
xcode-select --install
```

Finish Apple's installer before continuing. If the tools are already installed, macOS may simply report that fact. A paid developer membership, signing certificate and App Store Connect credentials are not needed.

Verify your compiler:

```sh
swift --version
```

Use **Swift 5.9 or newer**. The app runs on macOS 13+, but building requires a macOS / Command Line Tools combination that supplies a compatible compiler. Update your available Apple tools or macOS if the compiler is too old. Full Xcode is optional for packaging; it is required for the XCTest command `swift test`.

### 2. Download the released source and build the app

Run these commands in the folder where you want to keep the source:

```sh
git clone --branch v1.1.0 --depth 1 https://github.com/PROMLEE/promecapt.git
cd promecapt
bash scripts/package.sh
```

This produces `dist/Promecapt.app` and a ZIP for your Mac's CPU. The script uses a local **ad-hoc signature** by default. It does not need an Apple Developer login, certificate, private key or signing secret. Swift Package Manager downloads the pinned Sparkle updater framework.

This is a source build, not an Apple-notarized build. It does not override an employer's device policy or other macOS access controls.

### 3. Install in your own Applications folder

Quit any existing Promecapt instance before replacing it. The following destination is your personal Applications folder and does not require administrator access:

```sh
mkdir -p "$HOME/Applications"
ditto dist/Promecapt.app "$HOME/Applications/Promecapt.app"
open "$HOME/Applications/Promecapt.app"
```

You can instead move the app to `/Applications` in Finder if you have permission. Use **one installation at a stable path** so permissions attach to the app you actually launch. For normal use, launch the packaged `.app`, rather than `swift run` or the executable inside `.build`.

### 4. Allow capture and element detection

1. Open **System Settings → Privacy & Security → Screen Recording** (or **Screen & System Audio Recording** on newer macOS).
2. Enable **Promecapt**, then quit and reopen the app if requested.
3. Enable **Promecapt** under **Accessibility** for app-element detection and enhanced global shortcuts.
4. Use the capture-frame icon in the menu bar. The default capture shortcut is `⌥⌘1`; select the F1 preset in Settings → Shortcuts if desired.

Dock visibility can be off while the app keeps running. Reopen the app from Applications to open settings.

## Option B — Use a prebuilt release

1. Download from the [official Releases page](https://github.com/PROMLEE/promecapt/releases): `arm64` for Apple Silicon, `x86_64` for Intel.
2. Compare the downloaded file's SHA-256 with its accompanying `.sha256` file. For example, run `shasum -a 256 Promecapt-1.0.0-macos-arm64.zip` in the download folder and compare the first hash value.
3. **DMG (recommended):** open it and drag **Promecapt.app** onto **Applications** in the installation window. Eject the disk image and launch the installed app from Applications. **ZIP:** unzip and move the app to Applications manually.
4. The current release is ad-hoc signed and **not Developer ID signed or notarized**. If macOS blocks an unidentified / unnotarized app, review the source and checksum first. If you trust this exact app, follow [Apple's per-app opening procedure](https://support.apple.com/en-us/102445): after attempting to open it, use **System Settings → Privacy & Security → Open Anyway**, then confirm the app in the prompt.
5. Complete the capture permissions above.

A warning that software is damaged or contains malware is not the same as an unidentified-developer warning. Stop and check the download / contact the maintainer in that case. Do not disable Gatekeeper globally or remove security controls to install Promecapt. Managed devices may not offer a per-app exception.

The DMG is a drag-to-install container, not an automatic installer. It does not change signing or notarization status. ZIP downloads remain available.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| `xcode-select` opens an installer | Finish the installer, then rerun `swift --version`. |
| Compiler is older than Swift 5.9 | Update compatible Apple command-line tools / macOS before building. |
| App is running but there is no Dock icon | Use the menu bar icon, or reopen the `.app` to reach settings. |
| F1 changes brightness | Use `Fn+F1`, change macOS function-key behavior, or choose another shortcut. |
| Screen capture is denied even though its switch is on | Quit the app. A new ad-hoc build may need its own existing Promecapt permission entry refreshed in System Settings; add the exact installed `.app` and relaunch. Leave unrelated apps' permissions untouched. |
| Internal buttons / text fields are not detected | Check Accessibility permission. Detection also depends on what the target app exposes. |
| A company Mac blocks the app | Ask IT about approved installation / local compilation. Local builds do not bypass organization policy. |

## Build checks and updates

`bash scripts/test-local.sh` runs local checks using Command Line Tools; `swift test` additionally requires full Xcode. The release is tested on both Apple Silicon and Intel in CI.

From 1.1.0, use Settings → About → Check for Updates, or opt in to automatic download, installation and relaunch. Version 1.0.0 needs one manual installation of 1.1.0. You can also quit the app and replace it with a newer official build, or build a newer reviewed release tag at the same installation path. Keep your library; do not delete application data just to refresh a permission.
