#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DEVICE_NAME="${1:-iPhone 17}"
BUNDLE_ID="${BUNDLE_ID:-com.ipchae.sample}"
DEEPLINK_URL="${DEEPLINK_URL:-ipchae://auth-callback#access_token=fake&refresh_token=fake&type=magiclink}"

cd "$ROOT_DIR"

./scripts/ios/generate_xcodeproj.sh >/dev/null

xcodebuild \
  -project ios-app/IPCHAEAppSample/IPCHAEAppSample.xcodeproj \
  -scheme IPCHAEApp \
  -destination "platform=iOS Simulator,name=${DEVICE_NAME}" \
  build >/tmp/ipchae_deeplink_xcodebuild.log

UDID="$(
  xcrun simctl list devices available \
    | rg -F "${DEVICE_NAME} (" \
    | head -n 1 \
    | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
)"

if [ -z "$UDID" ]; then
  echo "Unable to find simulator UDID for device: $DEVICE_NAME"
  exit 1
fi

APP_PATH="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*IPCHAEApp.app" -type d | head -n 1)"

if [ -z "$APP_PATH" ]; then
  echo "Unable to find built app bundle path in DerivedData."
  exit 1
fi

xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl install "$UDID" "$APP_PATH" >/dev/null
xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
xcrun simctl openurl "$UDID" "$DEEPLINK_URL" >/dev/null

echo "Deep-link E2E passed: device=${DEVICE_NAME}, bundle=${BUNDLE_ID}"
