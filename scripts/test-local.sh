#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/check-localization.py
mkdir -p .build/checks-module-cache
SOURCES=()
for source in Sources/Promecapt/*.swift; do
  if [[ "$source" != */main.swift ]]; then SOURCES+=("$source"); fi
done
xcrun swiftc -parse-as-library -module-cache-path .build/checks-module-cache \
  "${SOURCES[@]}" scripts/Checks.swift -o .build/PromecaptChecks
.build/PromecaptChecks "$@"
