#!/usr/bin/env bash
# Screen recording via gpu-screen-recorder (hardware encode, so recording while gaming costs
# almost no FPS). Replay buffer idea taken from caelestia-shell's Recorder.
#
# Usage:
#   record.sh                       toggle: region recording (slurp), or stop the running recording
#   record.sh --region 'X,Y WxH'    toggle: record the given region (slurp format)
#   record.sh --fullscreen          toggle: record the focused output
#   record.sh --sound               add desktop audio (combine with the above)
#   record.sh --replay              toggle the replay buffer (keeps the last N seconds in RAM)
#   record.sh --save-replay         save the replay buffer to disk
#   record.sh --stop                stop the recording (not the replay buffer)
#
# Settings come from ~/.config/illogical-impulse/config.json, .screenRecord.*

# Scroll port: use the local hyprctl stand-in (scripts/scroll/hyprctl) for monitors
PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scroll" && pwd):$PATH"

CONFIG_FILE="$HOME/.config/illogical-impulse/config.json"
cfg() { # cfg <key> <default>
    local v
    v=$(jq -r ".screenRecord.$1 // empty" "$CONFIG_FILE" 2>/dev/null)
    echo "${v:-$2}"
}

RECORDING_DIR="$(cfg savePath "$HOME/Videos")"
RECORDING_DIR="${RECORDING_DIR/#\~/$HOME}"
CODEC="$(cfg codec hevc)"
QUALITY="$(cfg quality very_high)"
FPS="$(cfg fps 60)"
AUDIO="$(cfg audioSource default_output)"
REPLAY_SECONDS="$(cfg replaySeconds 30)"
VIDEO_OPTS="$(cfg ffmpegVideoOpts "")"

getdate() {
    date '+%Y-%m-%d_%H.%M.%S'
}
getactivemonitor() {
    hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name'
}
# PIDs of gpu-screen-recorder, split into normal recordings and the replay buffer (-r)
recording_pids() {
    pgrep -a -f '^gpu-screen-recorder' | awk '!/ -r [0-9]/ {print $1}'
}
replay_pids() {
    pgrep -a -f '^gpu-screen-recorder' | awk '/ -r [0-9]/ {print $1}'
}
notify() {
    notify-send "$@" -a 'Recorder' & disown
}

mkdir -p "$RECORDING_DIR"
cd "$RECORDING_DIR" || exit

# parse flags without modifying $@
ARGS=("$@")
MANUAL_REGION=""
SOUND_FLAG=0
FULLSCREEN_FLAG=0
for ((i=0;i<${#ARGS[@]};i++)); do
    case "${ARGS[i]}" in
        --region)
            if (( i+1 < ${#ARGS[@]} )); then
                MANUAL_REGION="${ARGS[i+1]}"
            else
                notify "Recording cancelled" "No region specified for --region"
                exit 1
            fi ;;
        --sound) SOUND_FLAG=1 ;;
        --fullscreen) FULLSCREEN_FLAG=1 ;;
        --replay)
            pids=$(replay_pids)
            if [[ -n "$pids" ]]; then
                kill -INT $pids
                notify "Replay buffer off" "Stopped keeping the last ${REPLAY_SECONDS}s"
            else
                gpu-screen-recorder -w "$(getactivemonitor)" -f "$FPS" -a "$AUDIO" -k "$CODEC" -q "$QUALITY" \
                    -c mp4 -r "$REPLAY_SECONDS" -replay-storage ram -o "$RECORDING_DIR" \
                    ${VIDEO_OPTS:+-ffmpeg-video-opts "$VIDEO_OPTS"} > /dev/null 2>&1 & disown
            fi
            exit 0 ;;
        --save-replay)
            pids=$(replay_pids)
            if [[ -n "$pids" ]]; then
                kill -USR1 $pids
                notify "Replay saved" "Last ${REPLAY_SECONDS}s saved to $RECORDING_DIR"
            else
                notify "Replay buffer is off" "Turn it on first"
            fi
            exit 0 ;;
        --stop)
            pids=$(recording_pids)
            [[ -n "$pids" ]] && kill -INT $pids
            exit 0 ;;
    esac
done

pids=$(recording_pids)
if [[ -n "$pids" ]]; then
    kill -INT $pids
    notify "Recording stopped" "Saved to $RECORDING_DIR"
    exit 0
fi

OUTFILE="$RECORDING_DIR/recording_$(getdate).mp4"
AUDIO_ARGS=()
[[ $SOUND_FLAG -eq 1 ]] && AUDIO_ARGS=(-a "$AUDIO")
EXTRA_ARGS=()
[[ -n "$VIDEO_OPTS" ]] && EXTRA_ARGS=(-ffmpeg-video-opts "$VIDEO_OPTS")

if [[ $FULLSCREEN_FLAG -eq 1 ]]; then
    exec gpu-screen-recorder -w "$(getactivemonitor)" -f "$FPS" -k "$CODEC" -q "$QUALITY" \
        "${AUDIO_ARGS[@]}" "${EXTRA_ARGS[@]}" -o "$OUTFILE"
fi

# Region recording. If a manual region was provided via --region, use it; otherwise run slurp.
if [[ -n "$MANUAL_REGION" ]]; then
    region="$MANUAL_REGION"
else
    if ! region="$(slurp 2>&1)"; then
        notify "Recording cancelled" "Selection was cancelled"
        exit 1
    fi
fi
# slurp's "X,Y WxH" -> gpu-screen-recorder's "WxH+X+Y"
if [[ "$region" =~ ^(-?[0-9]+),(-?[0-9]+)\ ([0-9]+)x([0-9]+)$ ]]; then
    gsr_region="${BASH_REMATCH[3]}x${BASH_REMATCH[4]}+${BASH_REMATCH[1]}+${BASH_REMATCH[2]}"
else
    notify "Recording cancelled" "Could not parse region: $region"
    exit 1
fi
# HDR capture only works for a whole monitor
exec gpu-screen-recorder -w region -region "$gsr_region" -f "$FPS" -k "${CODEC%_hdr}" -q "$QUALITY" \
    "${AUDIO_ARGS[@]}" "${EXTRA_ARGS[@]}" -o "$OUTFILE"
