#!/bin/bash

BAT="/sys/class/power_supply/BAT0"
CACHE="/tmp/powerdraw_avg"

read_power() {
	if [ -f "$BAT/power_now" ]; then
		cat "$BAT/power_now"
	else
		current=$(cat "$BAT/current_now")
		voltage=$(cat "$BAT/voltage_now")
		echo $(( current * voltage / 1000000 ))
	fi
}

power=$(read_power)

prev=$(cat "$CACHE" 2>/dev/null || echo "$power")

avg=$(( (power + prev * 4) / 5 ))

echo "$avg" > "$CACHE"

watts=$(awk "BEGIN { printf \"%.1f\", $avg / 1000000 }")

echo "{\"text\":\"${watts}W\"}"
