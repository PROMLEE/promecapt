#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/check-localization.py
if [[ ! -d .build/artifacts/sparkle/Sparkle/Sparkle.xcframework ]]; then swift package resolve; fi
SPARKLE_DIR="$PWD/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64"
mkdir -p .build/checks-module-cache
SOURCES=()
for source in Sources/Promecapt/*.swift; do
  if [[ "$source" != */main.swift ]]; then SOURCES+=("$source"); fi
done
xcrun swiftc -parse-as-library -module-cache-path .build/checks-module-cache \
  -F "$SPARKLE_DIR" -framework Sparkle -Xlinker -rpath -Xlinker "$SPARKLE_DIR" \
  "${SOURCES[@]}" scripts/Checks.swift -o .build/PromecaptChecks
.build/PromecaptChecks "$@"
