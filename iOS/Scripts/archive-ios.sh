#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${FLX_APPLE_TEAM_ID:?Set FLX_APPLE_TEAM_ID to your Apple Developer team ID}"
: "${FLX_BUNDLE_ID:?Set FLX_BUNDLE_ID to your registered bundle identifier}"
command -v xcodebuild >/dev/null 2>&1 || { echo 'macOS and Xcode are required.' >&2; exit 2; }
if [[ ! -f FLX.xcodeproj/project.pbxproj ]]; then
  python3 Scripts/generate-project.py
fi
xcodebuild -project FLX.xcodeproj -scheme FLX -configuration Release \
  -destination 'generic/platform=iOS' -archivePath .build/FLX.xcarchive \
  DEVELOPMENT_TEAM="$FLX_APPLE_TEAM_ID" PRODUCT_BUNDLE_IDENTIFIER="$FLX_BUNDLE_ID" \
  -allowProvisioningUpdates archive
echo 'Archive created. Validate in Xcode Organizer before TestFlight distribution.'
