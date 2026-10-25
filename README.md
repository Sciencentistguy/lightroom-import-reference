# Lightroom import reference set

Lightroom edits, their XMP sidecars and Lightroom's JPEG exports, next to
darktable's import of the same XMPs, for reviewing the Lightroom import PR.
Each case changes one thing on the same raw, so every difference between the
two renders can be traced to one setting.

The absolute look will differ: Lightroom renders with Adobe's camera profile
and tone curve, darktable with its own scene-referred defaults. Compare how
each case changes relative to `01-baseline` in both programs, not the
baseline itself.

## Steps

1. Make one copy of the raw per case. `mire1.cr2` from darktable's
   integration tests is a good choice, since maintainers already have it:

   ```sh
   ./prepare.sh /path/to/darktable/src/tests/integration/images/mire1.cr2
   ```

2. In Lightroom Classic, import `cases/` with **Add** (not Copy or Move).
3. Apply the edits below, each to the copy with the same name, starting from
   Lightroom's defaults. Leave everything else alone.
4. Select all, then **Metadata > Save Metadata to File** (Ctrl+S). This writes
   `cases/<name>.xmp` beside each raw.
5. Export all to the `cases/` folder: JPEG, sRGB, quality 90, resize to fit
   long edge 1200 px, no output sharpening, no watermark, file naming
   "Filename", so each export lands as `cases/<name>.jpg`.
6. From the shell you build darktable in:

   ```sh
   DT_SRC=/path/to/darktable ./compare.sh
   ```

   This needs a darktable checkout of the PR branch that already builds, and
   GraphicsMagick (`brew install graphicsmagick` on macOS). Set `BUILD_CMD`
   and `DT_CLI` if the build is not `cmake --build build` with
   `build/bin/darktable-cli`. To render on another machine instead, copy the
   whole folder there once the XMPs and JPEGs are in `cases/`.

   It writes darktable's renders to `out/darktable/`, side-by-sides to
   `out/compare/` and the modules each import added to
   `out/imported-modules.txt`.

7. Attach `cases/*.xmp`, `cases/*.jpg`, `out/compare/*.jpg` and
   `out/imported-modules.txt` to the PR.

`compare.sh` temporarily edits `src/develop/develop.c` in `DT_SRC` and
rebuilds, because darktable only runs the Lightroom import when the darkroom
first opens an image; the script's header explains, and it restores the file
and rebuilds when done.

## Edits

Lightroom has no numeric crop entry, so drag crops by eye; the XMP records
the exact values.

| case | edit in Lightroom |
| ---- | ----------------- |
| 01-baseline | none |
| 02-crop | Crop tool: trim roughly 10% off each edge, angle 0 |
| 03-crop-straighten-pos | Crop tool: trim roughly 10% off each edge, Angle +5 |
| 04-crop-straighten-neg | Crop tool: trim roughly 10% off each edge, Angle -12 |
| 05-crop-portrait | Photo > Rotate Left (Ctrl+[), then trim roughly 10% off each edge, Angle +3 |
| 06-crop-mirror | Photo > Flip Horizontal, then trim roughly 10% off each edge, Angle +3 |
| 07-exposure-plus | Basic: Exposure +1.00 |
| 08-exposure-minus | Basic: Exposure -1.00 |
| 09-blacks | Basic: Blacks -50 |
| 10-curve-linear | Tone Curve, point curve: Linear (explicitly selected) |
| 11-curve-medium | Tone Curve, point curve: Medium Contrast |
| 12-curve-strong | Tone Curve, point curve: Strong Contrast |
| 13-curve-custom | Tone Curve, point curve: add points near input 64 / output 40 and input 192 / output 215 |
| 14-curve-parametric | Tone Curve, parametric: Highlights +40, Lights +20, Darks -20, Shadows -40; drag the split points to roughly 20 / 50 / 80 |
| 15-clarity-plus | Basic: Clarity +60 |
| 16-clarity-minus | Basic: Clarity -60 |
| 17-hsl | HSL: Hue Red +30, Saturation Blue -50, Luminance Yellow +40 |
| 18-split-toning | Color Grading (Split Toning before Lightroom 10): Shadows hue 220 saturation 30, Highlights hue 40 saturation 30, Balance +20 |
| 19-vignette | Effects, Post-Crop Vignetting: Style Highlight Priority, Amount -40, Midpoint 40, Roundness +20, Feather 60 |
| 20-grain | Effects, Grain: Amount 50, Size 25, Roughness 60 |
| 21-spot-removal | Spot Removal, Clone: three spots anywhere |
| 21-spot-removal-rotated | Copy of 21-spot-removal with its spots, then Photo > Rotate Right (Ctrl+]) |
| 21-spot-removal-rotated-withheal | Copy of 21-spot-removal-rotated, then Spot Removal, Heal: brush one stroke |
| 21-spot-heal-circle | Spot Removal, Heal: three spots anywhere |
| 21-spot-heal-stroke | Spot Removal, Heal: brush one stroke |
| 21-spot-feather | Spot Removal, Clone: one spot, Feather 50 |
| 21-spot-opacity | Spot Removal, Clone: one spot, Opacity 50 |
| 21-spot-remove-tool | Remove: one spot (Lightroom also writes `21-spot-remove-tool.acr`) |
| 22-combined | Crop with Angle +4, Exposure +0.50, Blacks -20, point curve Medium Contrast, Clarity +30, Post-Crop Vignetting Amount -20, Grain Amount 20 |

The Remove tool fills from a patch Lightroom generates and stores in the
`.acr` sidecar, with no source in the image, so darktable skips those spots.

`cases.txt` lists what darktable is expected to import for each case;
`imported-modules.txt` shows what it did.

The importer reads only Lightroom's `SplitToning*` keys, so `18-split-toning`
also shows whether Lightroom 10 and later still write them alongside its
`ColorGrade*` keys.
