#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
SAMPLE_DIR="$ROOT_DIR/ios-app/IPCHAEAppSample"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen not found. Install with: brew install xcodegen"
  exit 1
fi

cd "$SAMPLE_DIR"
xcodegen generate

echo "Generated: $SAMPLE_DIR/IPCHAEAppSample.xcodeproj"
