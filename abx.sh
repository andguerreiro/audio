#!/bin/bash
set -u
shopt -s nullglob

# ------------------------------------------------------------
# TRUE ABX test using TWO synchronized mpv instances
# Switching by volume (no rewind, stable)
# ------------------------------------------------------------

# --- Dependencies ---
for cmd in mpv socat; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Missing dependency: $cmd"
        exit 1
    fi
done

# --- Find audio files ---
FILES=( *.flac *.mp3 *.ogg *.wav *.aac )
if [ "${#FILES[@]}" -lt 2 ]; then
    echo "Need at least two audio files in the directory."
    exit 1
fi

# Use the first two files found
FILES=("${FILES[0]}" "${FILES[1]}")

# --- Randomize A / B ---
if (( RANDOM % 2 )); then
    FILE_A="${FILES[0]}"
    FILE_B="${FILES[1]}"
else
    FILE_A="${FILES[1]}"
    FILE_B="${FILES[0]}"
fi

# --- Randomize X ---
if (( RANDOM % 2 )); then
    X_IS="A"
else
    X_IS="B"
fi

SOCK_A="/tmp/mpv_abx_a.sock"
SOCK_B="/tmp/mpv_abx_b.sock"
rm -f "$SOCK_A" "$SOCK_B"

# --- Start both players paused ---
mpv --no-video \
    --no-terminal \
    --input-terminal=no \
    --input-default-bindings=no \
    --pause \
    --volume=100 \
    --input-ipc-server="$SOCK_A" \
    "$FILE_A" \
    </dev/null >/dev/null 2>&1 &
PID_A=$!

mpv --no-video \
    --no-terminal \
    --input-terminal=no \
    --input-default-bindings=no \
    --pause \
    --volume=0 \
    --input-ipc-server="$SOCK_B" \
    "$FILE_B" \
    </dev/null >/dev/null 2>&1 &
PID_B=$!

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

# --- Volume switch helper ---
set_volumes() {
    echo "{ \"command\": [\"set_property\", \"volume\", $1] }" | socat - "$SOCK_A" >/dev/null
    echo "{ \"command\": [\"set_property\", \"volume\", $2] }" | socat - "$SOCK_B" >/dev/null
}

# --- Cleanup ---
cleanup() {
    echo
    echo "Stopping test..."
    kill "$PID_A" "$PID_B" >/dev/null 2>&1
    rm -f "$SOCK_A" "$SOCK_B"
    echo
    echo "RESULT:"
    echo "→ File A: $FILE_A"
    echo "→ File B: $FILE_B"
    echo "→ X was:  $X_IS"
    echo
    exit 0
}
trap cleanup INT TERM

# --- UI ---
echo
echo "TRUE ABX test started"
echo "A = reference A"
echo "B = reference B"
echo "X = hidden sample"
echo
echo "Controls:"
echo "A / B / X = switch"
echo "G = guess (then press A or B)"
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
        X|x)
            if [[ "$X_IS" == "A" ]]; then
                set_volumes 100 0
            else
                set_volumes 0 100
            fi
            echo "→ Playing X"
            ;;
        G|g)
            echo
            echo "Your guess? (A/B)"
            read -rsn1 guess
            echo
            if [[ "${guess^^}" == "$X_IS" ]]; then
                echo "✔ Correct!"
            else
                echo "✘ Wrong."
            fi
            echo
            ;;
    esac
done
