# Security

Promecapt processes captures and OCR locally. History includes full display snapshots, and GIF clipboard copies use local cached attachment files. Screen Recording and Accessibility are sensitive permissions; never ask users to disable macOS security protections globally.

Do not post a security-sensitive capture, credential or exploit with private data in a public issue. Use the repository's private vulnerability reporting feature if available. Otherwise open an issue asking for a private reporting channel without including sensitive details.

From 1.1.2, official releases reuse a pinned self-signed code-signing certificate. They are not Apple-notarized. Earlier releases and local source builds use ad-hoc signing. Only download releases from this repository or build from reviewed source.

From 1.1.0, Sparkle verifies Ed25519 signatures on update feeds and archives before installation. The update signing key is separate from the persistent macOS code-signing certificate. See [update security](docs/AUTO-UPDATE.md) and [code-signing maintenance](docs/CODE_SIGNING.md).
