# Release code signing

Official releases use one persistent self-signed code-signing certificate. Its public certificate and SHA-1 identity pin are in `updates/code-signing-certificate.pem` and `updates/code-signing-sha1.txt`. SHA-1 here identifies the certificate for macOS; it is not the archive integrity hash.

## For users

- The first update from an older ad-hoc release changes the app identity. Screen Recording and Accessibility may need one final removal and re-addition in System Settings, followed by an app restart.
- Later releases keep the same bundle identifier and certificate so macOS can recognize the same app. A local Sparkle update test preserved both permissions. This does not guarantee every macOS version will preserve permission state.
- Self-signing is not Apple notarization. The documented **Open Anyway** step can still be necessary. Users do not need to install or trust a certificate.
- Sparkle separately verifies every update with the existing Ed25519 public key.

## Release maintainers

Store the existing production identity in repository Actions secrets:

| Secret | Value |
| --- | --- |
| `MACOS_SIGNING_P12` | Base64 of the production PKCS#12 archive |
| `MACOS_SIGNING_PASSWORD` | Its export password |
| `SPARKLE_ED_PRIVATE_KEY` | Existing Sparkle update signing key |

`with-release-signing.py` imports the identity into a temporary keychain, adds it to the search list during packaging, restores the previous list and deletes the keychain afterward. It makes no certificate trust changes. Packaging verifies the embedded certificate against the tracked pin. The release workflow refuses to package without signing secrets; separate pull-request CI artifacts are ad-hoc test builds.

Back up the production private key, certificate, PKCS#12 archive and password securely outside the repository. Reuse them on every release; regenerating or replacing the certificate defeats permission continuity. Never commit private material or include it in release artifacts. The production identity is distinct from the earlier local experiment certificate.

Developer ID builds can use `SIGNING_MODE=developer-id SIGNING_IDENTITY='Developer ID Application: …'`. Local source builds default to ad-hoc signing and do not share the official release identity.
