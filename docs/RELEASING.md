# Releasing Promecapt

## Version and checks

The first public version is **1.0.0**. Update `scripts/package.sh`, `CHANGELOG.md`, the four READMEs, and `docs/releases/VERSION.md` together. The executable, app bundle and download assets use **Promecapt**. Keep the app identifier and data format stable across releases; changes require a migration plan.

Run `bash scripts/test-local.sh`, `swift test` with full Xcode, and `bash scripts/package.sh`. Confirm the installed app and archive show the same version, all four UI languages load, both icons use the shared mark, and captures / existing pins still work. Do not include local captures, `.build`, `dist`, signing materials or research notes in the source repository.

CI uses the standard `macos-15` arm64 and `macos-15-intel` runners documented in the [GitHub runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners). The Release workflow builds both architectures and attaches DMGs, ZIPs and SHA-256 files to a **draft** release. If the version already has a release, it skips building and publishing; publishing a draft therefore does not rebuild or overwrite that release when its tag event arrives.

## Create a release

Use Actions → Release → Run workflow with the next version (for example `1.1.0`), or push its matching tag. Review both build results, download the archives, verify checksums and check the notes before publishing the draft. Ensure the uploaded package version matches its tag. Never replace an already published archive silently; increment the version for changes.

A manual workflow dispatch can create the first draft and tag from `main`; no local GitHub CLI credential is required for the Actions job, which uses the repository-scoped `GITHUB_TOKEN`. Workflow permissions are read-only except the release publishing job's `contents: write`.

## Current signing status

No Developer ID identity is configured. The initial packages use ad-hoc signatures and are **not notarized**. Disclose this in the README and release notes. This does not offer Apple's verified-developer installation experience. Do not tell users to disable Gatekeeper globally, reset unrelated permissions or edit the TCC database.

Developer ID packaging, when an identity is available:

```sh
SIGNING_IDENTITY='Developer ID Application: NAME (TEAMID)' VERSION=1.1.0 bash scripts/package.sh
xcrun notarytool submit dist/Promecapt-1.1.0-macos-arm64.zip --keychain-profile promecapt-notary --wait
xcrun stapler staple dist/Promecapt.app
codesign --verify --strict dist/Promecapt.app
spctl --assess --type execute --verbose dist/Promecapt.app
```

Configure the notarization profile in the owner's Keychain first; do not commit credentials. After stapling, rebuild the ZIP and checksum, then verify the final downloaded archive. Repeat for each architecture. Certificate import and notarization are not implemented by the current workflows.

## Permission refresh and updates

Ad-hoc rebuilding may invalidate this app's existing Screen Recording or Accessibility association. Refresh only the same app's entries in System Settings and relaunch; OS authentication is completed by the user. Preserve the user's library and shortcut choices.

From 1.1.0, Release CI signs architecture-specific archives and feeds using `SPARKLE_ED_PRIVATE_KEY`. See [AUTO-UPDATE.md](AUTO-UPDATE.md). Update assets and feeds must be published together in the same stable release. Version 1.0.0 has no updater and requires one manual bootstrap installation.

## Drag-to-install DMG

After packaging, run `bash scripts/package-dmg.sh`. It creates a Finder window with the app, an Applications link and a directional arrow. Python packaging tools are pinned in `scripts/dmg-requirements.txt` and installed only in `.build/dmg-venv`; the app has no new runtime dependencies. `APP_PATH=/path/to/Promecapt.app` packages an already signed app without rebuilding it. Version and CPU architecture come from that app.

The script verifies the DMG checksum, mounts it read-only, checks the app signature and Applications link, and compares all app files with the input. Finder metadata must not be written onto the signed app. Release CI generates DMG and ZIP for both architectures. For notarized releases, staple the app before creating either container.
