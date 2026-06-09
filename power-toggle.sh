#!/bin/bash

# Cycles: performance -> balanced -> power-saver -> performance
# Requires: tlp (with sudo NOPASSWD), notify-send

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/power_profile"

current=$(cat "$STATE_FILE" 2>/dev/null || echo "power-saver")

case "$current" in
	performance)  next="power-saver" ;;
	balanced)     next="performance" ;;
	power-saver)  next="balanced" ;;
	*)            next="balanced" ;;
esac

case "$next" in
	performance)
		label="Performance"
		icon="power-profile-performance"
		tlp_cmd="sudo tlp performance"
		;;
	balanced)
		label="Balanced"
		icon="power-profile-balanced"
		tlp_cmd="sudo tlp balanced"
		;;
	power-saver)
		label="Power Saver"
		icon="power-profile-power-saver"
		tlp_cmd="sudo tlp power-saver"
		;;
esac

echo "$next" > "$STATE_FILE"
notify-send -i "$icon" -u low -t 2500 "Power Profile" "Switched to: $label"
( $tlp_cmd || notify-send -u critical -t 3000 "Power Profile" "Failed to apply: $label" ) &
