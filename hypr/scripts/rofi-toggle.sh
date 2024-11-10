#!/bin/sh

mode=${1:-"drun"}
if pgrep -x rofi; then
    killall rofi
else
    rofi -normal-window -show "$mode"
fi
