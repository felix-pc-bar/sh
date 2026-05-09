#!/bin/bash

PIDFILE="/tmp/gsr-replay.pid"

OUTPUT_DIR="/mnt/hdd2/Screencap/linux"

OUTPUT="DP-3"

BITRATE="12M"

mkdir -p "$OUTPUT_DIR"

start_recorder() {
	gpu-screen-recorder \
		-w "$OUTPUT" \
		-f 60 \
		-k hevc \
		-bm cbr \
		-q 12000 \
		-ac opus \
		-a default_output \
		-a alsa_input.usb-ZOOM_Corporation_H2-00.analog-stereo \
		-c mkv \
		-cursor no \
		-r 60 \
		-ro "$OUTPUT_DIR" \
		-o "$OUTPUT_DIR/clip" \
		> /tmp/gsr.log 2>&1 &

	echo $! > "$PIDFILE"

	notify-send "Replay buffer" "Started"
}

stop_recorder() {
	if [[ -f "$PIDFILE" ]]; then
		kill "$(cat "$PIDFILE")"
		rm -f "$PIDFILE"
		notify-send "Replay buffer" "Stopped"
	fi
}

save_clip() {
	if [[ -f "$PIDFILE" ]]; then
		kill -USR1 "$(cat "$PIDFILE")"
		notify-send "Replay buffer" "Clip saved"
	fi
}

case "$1" in
	start)
		start_recorder
		;;

	stop)
		stop_recorder
		;;

	toggle)
		if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
			stop_recorder
		else
			start_recorder
		fi
		;;

	save)
		save_clip
		;;

	*)
		echo "Usage: $0 {start|stop|toggle|save}"
		exit 1
		;;
esac
