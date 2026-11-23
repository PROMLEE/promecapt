# Updates

From 1.1.0, Promecapt supports manual and automatic updates through Sparkle 2.

[한국어](AUTO-UPDATE.ko.md)

## Use

- **Manual:** menu bar → Check for Updates…, or Settings → About → Check for Updates…
- **Automatic (optional):** Settings → About → Automatically download, install and relaunch. It is off by default.
- Only stable releases are checked, once a day. Turning the option on also checks once.
- Installation and relaunch wait while a capture, recording, annotation edit, OCR result or unsaved GIF result is open.
- The About tab shows the installed version, build, source revision, CPU and OS, plus the latest check result and time.
- Version 1.0.0 has no updater, so install 1.1.0 or later once from the DMG.

## Distribution

Architecture-specific `appcast-arm64.xml` / `appcast-x86_64.xml` files are published as stable-release assets on GitHub Releases. The app embeds its CPU's `releases/latest/download/appcast-CPU.xml` address and the Ed25519 public key. The version is read from the app's Info.plist rather than a separate UI constant.

Build with `package.sh` → `package-dmg.sh` → `sign-release.sh`. The last step signs the ZIP and feed, then verifies the ZIP signature separately with the public key embedded in the app. Archives and feeds are uploaded to the same draft release and published together. Published assets are never replaced.

The GitHub Actions secret `SPARKLE_ED_PRIVATE_KEY` holds the signing private key. If it is missing or does not match the app's public key, the release job fails. Never put the key in logs, source or release assets. Sign locally with `generate-appcast.py --version VERSION --arch CPU --key-file PRIVATE_FILE`.

## Signing and permissions

Sparkle verifies Ed25519 signatures on the feed and the update archive. Signature errors or network failures leave the current app in place. Feeds are per CPU and never downgrade automatically. Pins, annotations and groups are saved before installation; if saving fails, quitting is cancelled.

Apple Developer ID signing and notarization are separate from update signing. From 1.1.2, official releases reuse a persistent self-signed certificate. The transition from earlier ad-hoc signing may require one permission refresh; later releases keep the same certificate and bundle ID. This is not Apple notarization, so first-launch approval is still separate. Install into Applications from the DMG.

The persistent certificate is imported from the GitHub Actions secrets `MACOS_SIGNING_P12` and `MACOS_SIGNING_PASSWORD`. Releases fail if the certificate does not match the tracked public fingerprint. See [code-signing maintenance](CODE_SIGNING.md).

For developers: ad-hoc and self-signed builds load the upstream-signed Sparkle framework through a Library Validation exception entitlement on the app and its embedded components signed with the same certificate, while keeping the Hardened Runtime. Developer ID builds sign embedded components with the same identity and do not use that exception. System Gatekeeper settings are never changed.

## Verification

- `swift test` and `bash scripts/test-local.sh`
- A correctly signed ZIP, a tampered ZIP and a ZIP signed with another key
- Manual checks in the About tab, the latest version, errors and last-check time
- The automatic option persists and relaunch waits while work is open
- Old → new replacement, relaunch and version change with a separate test app
- The existing app and library stay intact offline, with unwritable paths and on signature errors

The DEBUG-only test bundle uses the ID `com.promlee.promecapt.update-test` and keeps its library in a separate `TestLibrary` beside the app. Only this bundle accepts loopback HTTP feeds; release builds have no such exception. Do not upload test files to public releases.

Official documentation: [Sparkle setup](https://sparkle-project.org/documentation/) · [Publishing updates](https://sparkle-project.org/documentation/publishing/)
