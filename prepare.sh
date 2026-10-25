#!/usr/bin/env bash
# make one copy of a raw per test case, so each Lightroom edit gets its own
# sidecar and export named after the case:
#   ./prepare.sh /path/to/mire1.cr2
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
RAW=${1:?usage: $0 /path/to/raw}
EXT=${RAW##*.}
OUT="$HERE/cases"
mkdir -p "$OUT"

while read -r name _; do
  [ -z "$name" ] || [ "${name:0:1}" = "#" ] && continue
  [ -e "$OUT/$name.$EXT" ] || cp "$RAW" "$OUT/$name.$EXT"
done < "$HERE/cases.txt"

echo "copied $(ls "$OUT"/*."$EXT" | wc -l) cases into $OUT"
