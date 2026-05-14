#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  darken-wallpapers.sh — Selectively darken bright wallpapers via ImageMagick
#
#  Logic: measure each image's perceptual brightness. Images already below
#  DARK_THRESHOLD are left untouched. Brighter images are scaled down, with
#  the very brightest receiving the most aggressive darkening (down to MIN_SCALE).
#  The relationship is linear between DARK_THRESHOLD (no change) and 1.0 (MAX darkening).
#
#  Usage:
#    ./darken-wallpapers.sh [INPUT_DIR] [OUTPUT_DIR]
#    ./darken-wallpapers.sh                          # uses defaults below
#    ./darken-wallpapers.sh ~/walls ~/walls-dark
#    ./darken-wallpapers.sh ~/walls ~/walls-dark --dry-run
# ═══════════════════════════════════════════════════════════════════════════════

# ─── PARAMETERS — tweak these ────────────────────────────────────────────────

INPUT_DIR="${1:-$PWD}"        # Source folder of images
OUTPUT_DIR="${2:-$PWD/darker/}"  # Where processed images are saved
FINAL_DIR="$PWD/final/"

# Brightness threshold (0.0–1.0 perceptual luminance scale):
# Images at or below this mean brightness are copied untouched.
# 0.20 is fairly dark; raise to 0.30 if you want to protect more images.
DARK_THRESHOLD=0.15

# Scale factor applied to the very brightest images (mean ≈ 1.0).
# 0.45 maps peak whites to ~45% — pretty aggressive, cornea-friendly.
# 0.50 = map whites to 50%. 0.35 = really dim. 0.60 = subtler.
MIN_SCALE=0.40

# Gamma applied after the multiply, to further reshape the tone curve.
# 1.0 = no effect (linear). 0.8 = darken midtones. 1.2 = lift shadows.
# Use to taste once MIN_SCALE is dialled in.
GAMMA=0.9

# Quality for JPEG output (1–100). Ignored for PNG/WebP lossless.
JPEG_QUALITY=92

# File types to process (space-separated extensions, case-insensitive handled below)
EXTENSIONS="jpg jpeg png webp tiff"

# ─── END OF PARAMETERS ───────────────────────────────────────────────────────

DRY_RUN=0
[[ "${*}" == *"--dry-run"* ]] && DRY_RUN=1

# Colour output helpers
RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[0;33m'
CYN='\033[0;36m'; GRY='\033[0;37m'; RST='\033[0m'; BLD='\033[1m'

# ── Sanity checks ─────────────────────────────────────────────────────────────
if ! command -v convert &>/dev/null; then
    echo -e "${RED}ERROR: ImageMagick 'convert' not found. Install it first.${RST}"
    exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
    echo -e "${RED}ERROR: Input directory '$INPUT_DIR' does not exist.${RST}"
    exit 1
fi

[[ $DRY_RUN -eq 1 ]] && echo -e "${YLW}DRY RUN — no files will be written${RST}\n"

mkdir -p "$OUTPUT_DIR"

# ── Print config summary ──────────────────────────────────────────────────────
echo -e "${BLD}Settings${RST}"
echo -e "  Input dir      : ${CYN}$INPUT_DIR${RST}"
echo -e "  Output dir     : ${CYN}$OUTPUT_DIR${RST}"
echo -e "  Dark threshold : ${CYN}$DARK_THRESHOLD${RST}  (images ≤ this are left alone)"
echo -e "  Min scale      : ${CYN}$MIN_SCALE${RST}   (brightest images multiplied by this)"
echo -e "  Gamma          : ${CYN}$GAMMA${RST}    (post-scale tone curve; 1.0 = off)"
echo -e "  JPEG quality   : ${CYN}$JPEG_QUALITY${RST}"
echo ""

# ── Process files ─────────────────────────────────────────────────────────────
processed=0; skipped=0; errors=0

# Build a glob that covers all extensions case-insensitively
shopt -s nullglob nocaseglob
declare -a all_files=()
for ext in $EXTENSIONS; do
    all_files+=( "$INPUT_DIR"/*.$ext )
done
shopt -u nullglob nocaseglob

total=${#all_files[@]}
if [ "$total" -eq 0 ]; then
    echo -e "${YLW}No image files found in $INPUT_DIR${RST}"
    exit 0
fi
echo -e "Found ${BLD}$total${RST} image(s)\n"

for img in "${all_files[@]}"; do
    [ -f "$img" ] || continue

    filename=$(basename "$img")
    ext_lower="${filename##*.}"
    ext_lower="${ext_lower,,}"
    outpath="$OUTPUT_DIR/$filename"

    # ── Measure perceptual (luminosity-weighted) brightness ──────────────────
    # Convert to grayscale using standard Rec.709 luminance weights, get mean.
    mean=$(magick "$img" -colorspace Gray -format "%[fx:mean]" info: 2>/dev/null)

    if [ -z "$mean" ]; then
        echo -e "  ${RED}ERROR${RST}  $filename — could not read (skipping)"
        (( errors++ ))
        continue
    fi

    printf "%-50s  mean=${CYN}%.3f${RST}  " "$filename" "$mean"

    # ── Decision: dark enough to leave alone? ────────────────────────────────
    is_dark=$(awk "BEGIN { print ($mean <= $DARK_THRESHOLD) ? 1 : 0 }")

    if [ "$is_dark" = "1" ]; then
        if [ $DRY_RUN -eq 0 ]; then
            cp "$img" "$outpath"
        fi
        echo -e "${GRY}→ unchanged${RST}"
        (( skipped++ ))
        continue
    fi

    # ── Interpolate scale factor ─────────────────────────────────────────────
    #   mean == DARK_THRESHOLD  →  scale = 1.0  (imperceptible change)
    #   mean == 1.0             →  scale = MIN_SCALE  (maximum darkening)
    #   Linear ramp between those two anchors.
    scale=$(awk "BEGIN {
        ratio = ($mean - $DARK_THRESHOLD) / (1.0 - $DARK_THRESHOLD)
        if (ratio < 0) ratio = 0
        if (ratio > 1) ratio = 1
        sf = 1.0 - ratio * (1.0 - $MIN_SCALE)
        printf \"%.4f\", sf
    }")

    # ── Build and run the ImageMagick command ────────────────────────────────
    # -evaluate multiply scales all RGB channels uniformly (preserves hue).
    # -gamma reshapes the tone curve afterwards if GAMMA != 1.0.
    # -quality only affects JPEG/WebP lossy output.
    if [ $DRY_RUN -eq 0 ]; then
        magick "$img" \
            -evaluate multiply "$scale" \
            -gamma "$GAMMA" \
			-modulate 100,140,100 \
            -quality "$JPEG_QUALITY" \
            "$outpath"
        status=$?
    else
        status=0
    fi

    if [ "$status" -ne 0 ]; then
        echo -e "${RED}→ FAILED (ImageMagick error $status)${RST}"
        (( errors++ ))
    else
        echo -e "${GRN}→ darkened${RST}  scale=${BLD}${scale}${RST}"
        (( processed++ ))
    fi
done

gowall convert --dir "$OUTPUT_DIR" -t gruvbox-ex --output "$FINAL_DIR"

# shopt -s nullglob nocaseglob
# declare -a dark_files=()
# for ext in $EXTENSIONS; do
#     dark_files+=( "$OUTPUT_DIR"/*.$ext )
# done
# shopt -u nullglob nocaseglob
#
# for img in "${all_files[@]}"; do
#     outpath="$FINAL_DIR/$filename"
# 	gowall convert img -t gruvbox --output "$outpath"
# done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLD}Done.${RST}"
echo -e "  ${GRN}Darkened  : $processed${RST}"
echo -e "  ${GRY}Unchanged : $skipped${RST}"
[[ $errors -gt 0 ]] && echo -e "  ${RED}Errors    : $errors${RST}"
[[ $DRY_RUN -eq 0 ]] && echo -e "  Output    : ${CYN}$OUTPUT_DIR${RST}"
