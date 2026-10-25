#!/usr/bin/env bash
# render darktable's Lightroom import of every case in cases/ and put it next
# to Lightroom's export of the same case:
#   DT_SRC=/path/to/darktable ./compare.sh
#
# darktable only runs the Lightroom import when the darkroom opens an image
# for the first time: dt_dev_read_history_ext() skips it without a full
# pipe, and darktable-cli has none at that point. To render headless, this
# script drops that condition in src/develop/develop.c, rebuilds, renders,
# then restores develop.c and rebuilds again. develop.c must be unmodified
# when it starts.
#
# BUILD_CMD runs a build of DT_SRC (default: cmake --build "$DT_SRC/build")
# and DT_CLI is the darktable-cli it produces (default:
# "$DT_SRC/build/bin/darktable-cli"). Needs GraphicsMagick (gm) on the PATH.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
DT_SRC=$(cd "${DT_SRC:?set DT_SRC to the darktable checkout to test}" && pwd)
CASES=${CASES:-$HERE/cases}
OUT=${OUT:-$HERE/out}
BUILD_CMD=${BUILD_CMD:-cmake --build "$DT_SRC/build"}
CLI=${DT_CLI:-$DT_SRC/build/bin/darktable-cli}
DEVELOP_C="$DT_SRC/src/develop/develop.c"
GATE='    if(dev->full.pipe && dev->full.pipe->loading && first_run)'

if ! git -C "$DT_SRC" diff --quiet -- src/develop/develop.c; then
  echo "src/develop/develop.c has local changes; commit or stash them first" >&2
  exit 1
fi
if ! grep -qxF "$GATE" "$DEVELOP_C"; then
  echo "the Lightroom import condition in develop.c has changed; update GATE in $0" >&2
  exit 1
fi

restore()
{
  git -C "$DT_SRC" checkout -- src/develop/develop.c
  echo "restored develop.c, rebuilding" >&2
  eval "$BUILD_CMD" > "$OUT/build-restore.log" 2>&1 || echo "rebuild failed, see $OUT/build-restore.log" >&2
}

mkdir -p "$OUT/darktable" "$OUT/compare"
trap restore EXIT
GATE="$GATE" perl -pi -e 's/^\Q$ENV{GATE}\E$/    if(first_run)/' "$DEVELOP_C"
echo "building darktable-cli that runs the Lightroom import" >&2
eval "$BUILD_CMD" > "$OUT/build.log" 2>&1 || { echo "build failed, see $OUT/build.log" >&2; exit 1; }

SUMMARY="$OUT/imported-modules.txt"
: > "$SUMMARY"

for raw in "$CASES"/*; do
  case "$raw" in *.xmp|*.XMP|*.jpg|*.JPG|*.acr|*.ACR) continue ;; esac
  name=$(basename "${raw%.*}")
  xmp=$(ls "$CASES/$name".xmp "$CASES/$name".XMP 2>/dev/null | head -1 || true)
  lr=$(ls "$CASES/$name".jpg "$CASES/$name".JPG 2>/dev/null | head -1 || true)
  if [ -z "$xmp" ]; then echo "skipping $name: no $name.xmp" >&2; continue; fi

  # a fresh folder and library per case, so the import runs as on first open
  work=$(mktemp -d)
  cp "$raw" "$xmp" "$work/"
  dt="$OUT/darktable/$name.jpg"
  rm -f "$dt"
  "$CLI" "$work/$(basename "$raw")" "$dt" --width 1200 --height 1200 --hq true \
    --core --configdir "$work/config" --conf write_sidecar_files=never -d params \
    > "$work/log" 2>&1 || { echo "darktable-cli failed on $name, see $work/log" >&2; continue; }

  # the import appends to the auto-applied history and, for a raw, always
  # starts with colorin, so its modules follow the second colorin
  modules=$(grep -o 'loaded module [a-z0-9]* from history' "$work/log" | awk '{print $3}' \
    | awk '$0 == "colorin" { n++ } n >= 2' | tr '\n' ' ')
  printf '%-26s %s\n' "$name" "$modules" | tee -a "$SUMMARY"

  if [ -n "$lr" ]; then
    # gm montage only applies the options given before the images
    gm montage -tile 2x1 -geometry '1200x1200>+8+8' -pointsize 28 -title "$name" \
      -label Lightroom "$lr" -label darktable "$dt" "$OUT/compare/$name.jpg"
  else
    echo "  no $name.jpg from Lightroom, darktable render only" >&2
  fi
  rm -rf "$work"
done

echo "renders in $OUT/darktable, side-by-sides in $OUT/compare, modules in $SUMMARY" >&2
