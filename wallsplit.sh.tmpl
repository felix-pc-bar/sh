#!/usr/bin/env bash
set -euo pipefail
# =========================
# CONFIG
# =========================
WALL_DIR="$HOME/Pictures/photos-gowall/final/"
LEFT_OUTPUT="HDMI-A-1"
RIGHT_OUTPUT="DP-3"
LEFT_RES="1920x1080"
RIGHT_RES="1920x1080"
BG_COLOUR="#282828"
VERT_BORDER=0.25    # fraction of screen height left blank on EACH side (top & bottom)
HORIZ_BORDER=0.05   # fraction of screen width left blank on EACH side (left & right)
                    # becomes the binding constraint for exceedingly skinny/portrait images
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-box"
TRANSITION="grow"
TRANSITION_DURATION=0.8
# =========================
mkdir -p "$CACHE_DIR"
mapfile -t IMAGES < <(find "$WALL_DIR" -type f \( \
	-iname "*.jpg" -o \
	-iname "*.jpeg" -o \
	-iname "*.png" -o \
	-iname "*.webp" \
\))
if [ "${#IMAGES[@]}" -eq 0 ]; then
	echo "No images found in $WALL_DIR"
	exit 1
fi
IMAGE="${IMAGES[RANDOM % ${#IMAGES[@]}]}"
make_wall() {
	local RES="$1"
	local OUT="$2"
	local W="${RES%x*}"
	local H="${RES#*x}"
	# BOX is the maximum space the image may occupy.
	# -resize fits within this box preserving aspect ratio, so whichever
	# dimension is the tighter constraint wins — vertical for wide images,
	# horizontal for tall/skinny ones.
	local BOX_W=$(awk "BEGIN { print int($W * (1 - 2 * $HORIZ_BORDER)) }")
	local BOX_H=$(awk "BEGIN { print int($H * (1 - 2 * $VERT_BORDER)) }")
	magick \
		-size "${W}x${H}" \
		canvas:"$BG_COLOUR" \
		\( "$IMAGE" \
			-resize "${BOX_W}x${BOX_H}" \
		\) \
		-gravity center \
		-composite \
		"$OUT"
}
LEFT_IMG="$CACHE_DIR/left.png"
RIGHT_IMG="$CACHE_DIR/right.png"
make_wall "$LEFT_RES" "$LEFT_IMG"
make_wall "$RIGHT_RES" "$RIGHT_IMG"
if ! pgrep -x awww-daemon >/dev/null; then
	awww-daemon &
	sleep 0.5
fi
awww img -o "$LEFT_OUTPUT" "$LEFT_IMG" \
	--transition-type "$TRANSITION" \
	--transition-duration "$TRANSITION_DURATION" \
	--transition-fps 60
awww img -o "$RIGHT_OUTPUT" "$RIGHT_IMG" \
	--transition-type "$TRANSITION" \
	--transition-duration "$TRANSITION_DURATION" \
	--transition-fps 240
echo "Applied boxed wallpaper: $IMAGE"
