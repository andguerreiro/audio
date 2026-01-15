#!/bin/bash
set -euo pipefail
shopt -s nullglob

# ------------------------------------------------------------
# Simple A/B comparison using two synchronized mpv instances
# ------------------------------------------------------------

# --- Check for required commands ---
REQUIRED_CMDS=("mpv" "socat")
MISSING_CMDS=()

for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_CMDS+=("$cmd")
    fi
done

if [ "${#MISSING_CMDS[@]}" -ne 0 ]; then
    echo "Missing required packages: ${MISSING_CMDS[*]}"
    echo "Install with: sudo apt install ${MISSING_CMDS[*]}"
    exit 1
fi

# --- Find audio files ---
FILES=( *.flac *.ogg *.mp3 *.wav *.aac )

if [ "${#FILES[@]}" -lt 2 ]; then
    echo "Need at least two audio files in the directory."
    exit 1
fi

# Only take the first two
FILES=("${FILES[0]}" "${FILES[1]}")

# --- Randomize A and B ---
if (( RANDOM % 2 )); then
    FILE_A="${FILES[0]}"
    FILE_B="${FILES[1]}"
else
    FILE_A="${FILES[1]}"
    FILE_B="${FILES[0]}"
fi

SOCK_A="/tmp/mpv_ab_a.sock"
SOCK_B="/tmp/mpv_ab_b.sock"

rm -f "$SOCK_A" "$SOCK_B"

# --- Start both players paused and fully isolated ---
mpv --no-video \
    --no-terminal \
    --input-terminal=no \
    --input-default-bindings=no \
    --pause \
    --volume=100 \
    --input-ipc-server="$SOCK_A" \
    "$FILE_A" \
    </dev/null >/dev/null 2>&1 &
MPV_A_PID=$!

mpv --no-video \
    --no-terminal \
    --input-terminal=no \
    --input-default-bindings=no \
    --pause \
    --volume=0 \
    --input-ipc-server="$SOCK_B" \
    "$FILE_B" \
    </dev/null >/dev/null 2>&1 &
MPV_B_PID=$!

# --- Wait for sockets ---
for _ in {1..100}; do
    [[ -S "$SOCK_A" && -S "$SOCK_B" ]] && break
    sleep 0.05
done

if [[ ! -S "$SOCK_A" || ! -S "$SOCK_B" ]]; then
    echo "Failed to start mpv instances."
    exit 1
fi

# --- Unpause both at the same time ---
echo '{ "command": ["set_property", "pause", false] }' | socat - "$SOCK_A" >/dev/null
echo '{ "command": ["set_property", "pause", false] }' | socat - "$SOCK_B" >/dev/null

# --- Volume switching ---
set_volumes() {
    local vol_a="$1"
    local vol_b="$2"

    echo "{ \"command\": [\"set_property\", \"volume\", $vol_a] }" | socat - "$SOCK_A" >/dev/null
    echo "{ \"command\": [\"set_property\", \"volume\", $vol_b] }" | socat - "$SOCK_B" >/dev/null
}

# --- Cleanup ---
cleanup() {
    echo
    echo "Stopping test..."
    kill "$MPV_A_PID" "$MPV_B_PID" >/dev/null 2>&1 || true
    rm -f "$SOCK_A" "$SOCK_B"
    echo
    echo "RESULT:"
    echo "→ File A: $FILE_A"
    echo "→ File B: $FILE_B"
    echo
    exit 0
}
trap cleanup SIGINT SIGTERM

# --- UI ---
echo
echo "A/B comparison started"
echo "A = first reference"
echo "B = second reference"
echo
echo "Controls:"
echo "A = switch to A"
echo "B = switch to B"
echo "Ctrl+C = quit"
echo

# --- Main loop ---
while true; do
    read -rsn1 key
    case "$key" in
        A|a)
            set_volumes 100 0
            echo "→ Playing A"
            ;;
        B|b)
            set_volumes 0 100
            echo "→ Playing B"
            ;;
    esac
done
