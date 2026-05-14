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

BOX_SCALE=0.65   # fraction of screen used by image box

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

	local BOX_W=$(awk "BEGIN { print int($W * $BOX_SCALE) }")
	local BOX_H=$(awk "BEGIN { print int($H * $BOX_SCALE) }")

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
