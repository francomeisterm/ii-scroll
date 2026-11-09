#!/bin/bash
# Toggle gpu-screen-recorder: press once to start, again to stop and save.

if pgrep -f "^gpu-screen-recorder" > /dev/null; then
    pkill -SIGINT -f "^gpu-screen-recorder"
    notify-send "Recording stopped" "Saved to ~/Storage/Recordings" -i media-playback-stop 2>/dev/null
else
    out="$HOME/Storage/Recordings/$(date +%Y-%m-%d_%H-%M-%S).mp4"
    gpu-screen-recorder -w DP-1 -f 60 -a default_output -k hevc_hdr -q ultra -ffmpeg-video-opts "qp=20" -o "$out" &
    disown
    notify-send "Recording started" "$out" -i media-record 2>/dev/null
fi
