#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/docs/orchestration/metrics/render}"
DATE_TAG="$(date +%Y%m%d-%H%M%S)"
STROKES="${STROKES:-240}"
POINTS="${POINTS:-160}"
UNDO_RATIO="${UNDO_RATIO:-0.20}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

JSON_OUT="$OUTPUT_DIR/editor-spike-${DATE_TAG}.json"
MD_OUT="$OUTPUT_DIR/render-metrics-${DATE_TAG}.md"

swift run --package-path ios-app/CoreDomain EditorSpikeCLI \
  --strokes "$STROKES" \
  --points "$POINTS" \
  --undo-ratio "$UNDO_RATIO" > "$JSON_OUT"

cat > "$MD_OUT" <<EOF
# Render Metrics Snapshot (${DATE_TAG})

## Automated Capture
1. Source CLI: \`EditorSpikeCLI\`
2. Strokes: ${STROKES}
3. Points per stroke: ${POINTS}
4. Undo ratio: ${UNDO_RATIO}
5. Raw JSON: \`${JSON_OUT}\`

## Manual iPad Device Capture (Fill Required)
1. Device model:
2. OS version:
3. Scene setup:
4. Measured FPS (avg / p5):
5. Input latency (ms avg / p95):
6. Memory usage (MB avg / peak):
7. Thermal throttling observed (yes/no):

## Notes
1. This file is generated to keep Gate A evidence reproducible.
2. Fill the manual section after on-device profiling run.
EOF

echo "Render metrics captured:"
echo "  JSON: $JSON_OUT"
echo "  MD:   $MD_OUT"
