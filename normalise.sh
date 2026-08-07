#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  darken-wallpapers.sh — Selectively darken bright wallpapers via ImageMagick
#
#  Stages, in order, each independently cached so re-running only does new work:
#    1. darken   — measure brightness, darken images above DARK_THRESHOLD
#    2. gowall   — run the gowall colour-scheme conversion
#    3. resize   — pad the result onto a fixed canvas with a coloured border,
#                  guaranteeing a minimum margin on every side, saved as PNG
#
#  Usage:
#    ./darken-wallpapers.sh [INPUT_DIR] [OUTPUT_DIR]
#    ./darken-wallpapers.sh                          # uses defaults below
#    ./darken-wallpapers.sh ~/walls ~/walls-dark
#    ./darken-wallpapers.sh ~/walls ~/walls-dark --dry-run
# ═══════════════════════════════════════════════════════════════════════════════

# ─── PARAMETERS — tweak these ────────────────────────────────────────────────

INPUT_DIR="${1:-$PWD}"        # Source folder of images
OUTPUT_DIR="${2:-$PWD/darker/}"  # Where darkened images are saved
FINAL_DIR="$PWD/final/"       # Where gowall output is saved
RESIZED_DIR="$PWD/resized/"   # Where the framed, resized PNGs are saved

# Brightness threshold (0.0–1.0 perceptual luminance scale):
# Images at or below this mean brightness are copied untouched.
# 0.20 is fairly dark; raise to 0.30 if you want to protect more images.
# DARK_THRESHOLD=0.15
DARK_THRESHOLD=0.4

# Scale factor applied to the very brightest images (mean ≈ 1.0).
# 0.45 maps peak whites to ~45% — pretty aggressive, cornea-friendly.
# 0.50 = map whites to 50%. 0.35 = really dim. 0.60 = subtler.
# MIN_SCALE=0.40
MIN_SCALE=0.65

# Gamma applied after the multiply, to further reshape the tone curve.
# 1.0 = no effect (linear). 0.8 = darken midtones. 1.2 = lift shadows.
# Use to taste once MIN_SCALE is dialled in.
# GAMMA=0.9
GAMMA=1.0

# Quality for JPEG output (1–100). Ignored for PNG/WebP lossless.
JPEG_QUALITY=92

# File types to process (space-separated extensions, case-insensitive handled below)
EXTENSIONS="jpg jpeg png webp tiff"

# ─── Resize / frame stage ────────────────────────────────────────────────────
# Pads the gowall output onto a fixed canvas of RESIZE_WIDTH x RESIZE_HEIGHT,
# preserving aspect ratio, so the image is never cropped. The two border
# fractions set the MINIMUM blank margin on each axis — the margin on the
# other axis is usually larger, since the image is scaled to fit inside a
# box that already has both margins subtracted from it.

RESIZE_WIDTH=1920
RESIZE_HEIGHT=1080
RESIZE_BG_COLOUR="#1d1816"   # frame colour, any ImageMagick-recognised value
RESIZE_VERT_BORDER=0.05      # min. fraction of height left blank, top & bottom
RESIZE_HORIZ_BORDER=0.05     # min. fraction of width left blank, left & right

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

mkdir -p "$OUTPUT_DIR" "$FINAL_DIR" "$RESIZED_DIR"

# ── Print config summary ──────────────────────────────────────────────────────
echo -e "${BLD}Settings${RST}"
echo -e "  Input dir      : ${CYN}$INPUT_DIR${RST}"
echo -e "  Output dir     : ${CYN}$OUTPUT_DIR${RST}"
echo -e "  Dark threshold : ${CYN}$DARK_THRESHOLD${RST}  (images ≤ this are left alone)"
echo -e "  Min scale      : ${CYN}$MIN_SCALE${RST}   (brightest images multiplied by this)"
echo -e "  Gamma          : ${CYN}$GAMMA${RST}    (post-scale tone curve; 1.0 = off)"
echo -e "  JPEG quality   : ${CYN}$JPEG_QUALITY${RST}"
echo -e "  Resize canvas  : ${CYN}${RESIZE_WIDTH}x${RESIZE_HEIGHT}${RST}"
echo -e "  Resize frame   : ${CYN}$RESIZE_BG_COLOUR${RST}"
echo -e "  Resize v-margin: ${CYN}$RESIZE_VERT_BORDER${RST}  (min. fraction of height, top & bottom)"
echo -e "  Resize h-margin: ${CYN}$RESIZE_HORIZ_BORDER${RST}  (min. fraction of width, left & right)"
echo ""

# ── Process files ─────────────────────────────────────────────────────────────
processed=0; skipped=0; errors=0; resized=0; resize_cached=0

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
	stem="${filename%.*}"
	outpath="$OUTPUT_DIR/$filename"

	# gowall may change the extension, so match final/resized output on stem only.
	shopt -s nullglob
	final_matches=( "$FINAL_DIR/${stem}".* )
	resized_matches=( "$RESIZED_DIR/${stem}".* )
	shopt -u nullglob

	final_done=0
	[ ${#final_matches[@]} -gt 0 ] && final_done=1

	resized_done=0
	[ ${#resized_matches[@]} -gt 0 ] && resized_done=1

	# ── Skip entirely if all three stages are already done ────────────────────
	if [ "$final_done" = "1" ] && [ "$resized_done" = "1" ]; then
		printf "%-50s  ${GRY}→ all stages done, skipping${RST}\n" "$filename"
		(( skipped++ ))
		continue
	fi

	# ── Stages 1 & 2: darken, then gowall — skipped if stage 2 already done ───
	if [ "$final_done" = "0" ]; then
		im_done=0
		[ -f "$outpath" ] && im_done=1

		if [ "$im_done" = "0" ]; then
			# ── Measure perceptual (luminosity-weighted) brightness ──────────
			mean=$(magick "$img" -colorspace Gray -format "%[fx:mean]" info: 2>/dev/null)

			if [ -z "$mean" ]; then
				echo -e "  ${RED}ERROR${RST}  $filename — could not read (skipping)"
				(( errors++ ))
				continue
			fi

			printf "%-50s  mean=${CYN}%.3f${RST}  " "$filename" "$mean"

			# ── Decision: dark enough to leave alone? ─────────────────────────
			is_dark=$(awk "BEGIN { print ($mean <= $DARK_THRESHOLD) ? 1 : 0 }")

			if [ "$is_dark" = "1" ]; then
				if [ $DRY_RUN -eq 0 ]; then
					cp "$img" "$outpath"
				fi
				echo -ne "${GRY}→ unchanged  ${RST}"
				(( processed++ ))
			else
				# ── Interpolate scale factor ──────────────────────────────────
				scale=$(awk "BEGIN {
					ratio = ($mean - $DARK_THRESHOLD) / (1.0 - $DARK_THRESHOLD)
					if (ratio < 0) ratio = 0
					if (ratio > 1) ratio = 1
					sf = 1.0 - ratio * (1.0 - $MIN_SCALE)
					printf \"%.4f\", sf
				}")

				# ── Run ImageMagick ─────────────────────────────────────────────
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
					echo -e "${RED}→ IM FAILED (error $status)${RST}"
					(( errors++ ))
					continue
				fi
				echo -ne "${GRN}→ darkened (scale=${scale})  ${RST}"
				(( processed++ ))
			fi
		else
			printf "%-50s  ${YLW}→ IM cached  ${RST}" "$filename"
		fi

		# ── gowall stage ────────────────────────────────────────────────────────
		if [ $DRY_RUN -eq 0 ]; then
			gowall convert "$outpath" -t oxide --output "$FINAL_DIR"
			gw_status=$?
		else
			gw_status=0
		fi

		if [ "$gw_status" -ne 0 ]; then
			echo -e "${RED}→ gowall FAILED (error $gw_status)${RST}"
			(( errors++ ))
			continue  # don't attempt resize on a failed file
		else
			echo -e "${GRN}→ gowall done${RST}"
		fi
	else
		printf "%-50s  ${YLW}→ darken+gowall cached  ${RST}\n" "$filename"
	fi

	# ── Stage 3: resize onto a fixed, framed canvas ────────────────────────────
	if [ "$resized_done" = "1" ]; then
		echo -e "  ${GRY}→ resize cached${RST}"
		(( resize_cached++ ))
		continue
	fi

	if [ $DRY_RUN -eq 1 ]; then
		echo -e "  ${YLW}→ would resize onto ${RESIZE_WIDTH}x${RESIZE_HEIGHT} canvas${RST}"
		continue
	fi

	shopt -s nullglob
	final_input=( "$FINAL_DIR/${stem}".* )
	shopt -u nullglob

	if [ ${#final_input[@]} -eq 0 ]; then
		echo -e "  ${RED}ERROR${RST}  $filename — no final image found for resize stage"
		(( errors++ ))
		continue
	fi

	resized_out="$RESIZED_DIR/${stem}.png"

	# BOX is the maximum space the image may occupy on the canvas.
	# -resize fits within this box preserving aspect ratio, so whichever
	# dimension is the tighter constraint wins, and the margin on the
	# other axis ends up larger than the configured minimum.
	box_w=$(awk "BEGIN { print int($RESIZE_WIDTH * (1 - 2 * $RESIZE_HORIZ_BORDER)) }")
	box_h=$(awk "BEGIN { print int($RESIZE_HEIGHT * (1 - 2 * $RESIZE_VERT_BORDER)) }")

	magick \
		-size "${RESIZE_WIDTH}x${RESIZE_HEIGHT}" \
		canvas:"$RESIZE_BG_COLOUR" \
		\( "${final_input[0]}" -resize "${box_w}x${box_h}" \) \
		-gravity center \
		-composite \
		"$resized_out"
	resize_status=$?

	if [ "$resize_status" -ne 0 ]; then
		echo -e "  ${RED}→ resize FAILED (error $resize_status)${RST}"
		(( errors++ ))
	else
		echo -e "  ${GRN}→ resized${RST}"
		(( resized++ ))
	fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLD}Done.${RST}"
echo -e "  ${GRN}IM processed : $processed${RST}"
echo -e "  ${GRN}Resized      : $resized${RST}"
[[ $resize_cached -gt 0 ]] && echo -e "  ${GRY}Resize cached: $resize_cached${RST}"
echo -e "  ${GRY}Fully cached : $skipped${RST}"
[[ $errors -gt 0 ]] && echo -e "  ${RED}Errors       : $errors${RST}"
if [[ $DRY_RUN -eq 0 ]]; then
	echo -e "  Framed output : ${CYN}$RESIZED_DIR${RST}"
	echo -e "  Gowall output : ${CYN}$FINAL_DIR${RST}"
fi
