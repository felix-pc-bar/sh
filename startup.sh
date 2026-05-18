#!/usr/bin/env bash

systemctl --user disable --now wallsplit.timer

awww-daemon --no-cache &

# Wait until the daemon is actually responsive before issuing commands
until awww img /dev/null >/dev/null 2>&1 || awww clear 000000 >/dev/null 2>&1; do
    sleep 0.1
done

awww clear 1d2021

hyprlock >/dev/null 2>&1 || exit 1

# Clear with no transition delay to close the post-unlock gap as tight as possible,
# then immediately kick off the wall animation in the background
awww clear 1d2021 && sleep 0.05 && /home/felix/repos/sh/wallsplit.sh &

sleep 2
kitty --hold fastfetch --color "#ffffff" --logo-color-1 "#e6e6e6" --logo-color-2 "#bbbbbb" &

exit 0
