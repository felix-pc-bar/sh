#!/bin/sh

STATE_FILE="/tmp/gamma_state"

SERVICE="rs.wl-gammarelay"
OBJ="/"
IFACE="rs.wl.gammarelay"

set_normal() {
	busctl --user set-property $SERVICE $OBJ $IFACE Brightness d 1.0
	busctl --user set-property $SERVICE $OBJ $IFACE Temperature q 6500
	echo "normal" > "$STATE_FILE"
}

set_night() {
	busctl --user set-property $SERVICE $OBJ $IFACE Brightness d 0.4
	busctl --user set-property $SERVICE $OBJ $IFACE Temperature q 4500
	echo "night" > "$STATE_FILE"
}

if [ ! -f "$STATE_FILE" ]; then
	set_normal
	exit 0
fi

CURRENT="$(cat "$STATE_FILE")"

if [ "$CURRENT" = "night" ]; then
	set_normal
else
	set_night
fi
