# Audio A/B and ABX Testing Scripts

Small command-line tools for **critical audio listening tests** using `mpv`.
They allow instant, gapless switching between two synchronized audio files.

## Requirements
- `mpv`
- `socat`

Install on Debian/Ubuntu: `sudo apt install mpv socat`

## Usage
1. Place a script (`ab.sh` or `abx.sh`) and **two audio files** in the same directory.
2. Make it executable: `chmod +x ab.sh` (or `abx.sh`).
3. Run it: `./ab.sh` or `./abx.sh`.

## Controls
- **A / B**: play reference A or B
- **X**: play hidden sample (ABX only)
- **G**: guess X (ABX only)
- **Ctrl+C**: quit and show results

## Sample File
- Download a sample file for tests here: [helpguide.sony.net/high-res/sample1/v1/en](https://helpguide.sony.net/high-res/sample1/v1/en/index.html)
