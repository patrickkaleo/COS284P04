#!/usr/bin/env bash
# Zip the two files the marker accepts: task1.asm and task2.asm.
set -euo pipefail

cd "$(dirname "$0")"

out="${1:-COS284P04.zip}"

rm -f "$out"
zip -X "$out" task1.asm task2.asm
echo "wrote $out"
