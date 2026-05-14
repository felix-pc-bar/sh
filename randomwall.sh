#!/bin/sh
# pick random wallpaper
# depracated; use wallsplit.sh
wall=$(find "$HOME/Pictures/gruv-curated" -type f | shuf -n 1)
exec swaybg -m fill -i "$wall"

