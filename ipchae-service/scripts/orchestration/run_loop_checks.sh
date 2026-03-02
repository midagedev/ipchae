#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[1/3] Node unit tests"
npm run test

echo "[2/3] Node type/svelte checks"
npm run check

if [ -f "ios-app/CoreDomain/Package.swift" ]; then
  echo "[3/4] Swift package tests (CoreDomain)"
  swift test --package-path ios-app/CoreDomain
else
  echo "[3/4] Swift package tests skipped (ios-app/CoreDomain missing)"
fi

if [ -f "ios-app/AppShell/Package.swift" ]; then
  echo "[4/4] Swift package tests (AppShell)"
  swift test --package-path ios-app/AppShell
else
  echo "[4/4] Swift package tests skipped (ios-app/AppShell missing)"
fi

echo "Loop checks complete"
