#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "An iOS build requires macOS with Xcode. No iOS binary was produced." >&2
  exit 2
fi
if [[ ! -f FLX.xcodeproj/project.pbxproj ]]; then
  python3 Scripts/generate-project.py
fi
xcodebuild -project FLX.xcodeproj -scheme FLX -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
