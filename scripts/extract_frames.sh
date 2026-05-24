#!/usr/bin/env bash
# scripts/extract_frames.sh — extract key frames from a session video.
#
# Usage:
#   scripts/extract_frames.sh <session-id> <timestamp> [<timestamp> ...]
#
# Examples:
#   scripts/extract_frames.sh 2026-03-07-LVS 12:30 28:10 41:00 52:20
#   scripts/extract_frames.sh 2026-03-07-cramer-review 05:00 22:15 38:40 50:00
#
# Reads frames/<session-id>.mp4, applies a crop to remove the right-side
# participant video panel (default 412 px), downscales to 1600 px wide,
# writes JPEGs to figures/<session-id>/frame-<HH>m<MM>.jpg.
#
# Override crop width with FRAMES_CROP_WIDTH env var if the participant
# panel is a different size; override scale with FRAMES_SCALE_WIDTH.

set -euo pipefail

if [[ $# -lt 2 ]]; then
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
  exit 64
fi

SESSION="$1"
shift
TIMESTAMPS=("$@")

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INPUT="$REPO_ROOT/frames/$SESSION.mp4"
OUTDIR="$REPO_ROOT/figures/$SESSION"

if [[ ! -f "$INPUT" ]]; then
  echo "error: source video not found: $INPUT" >&2
  exit 66
fi

FFMPEG="${FFMPEG_BIN:-ffmpeg}"
if ! command -v "$FFMPEG" >/dev/null 2>&1; then
  # Fall back to the winget install location on Windows
  WINGET="C:/Users/dspfa/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-8.1.1-full_build/bin/ffmpeg.exe"
  if [[ -x "$WINGET" ]]; then
    FFMPEG="$WINGET"
  else
    echo "error: ffmpeg not found; set FFMPEG_BIN or add ffmpeg to PATH" >&2
    exit 69
  fi
fi

# Probe source resolution. We need ffprobe, not ffmpeg.
# `${FFMPEG/ffmpeg/ffprobe}` swaps only the FIRST occurrence of "ffmpeg",
# which for a full WinGet path replaces the parent directory's "ffmpeg-..."
# segment instead of the binary name. Use `${FFMPEG##*/}` then rebuild,
# or just replace the .exe basename explicitly.
FFMPEG_DIR="$(dirname "$FFMPEG")"
FFPROBE="$FFMPEG_DIR/ffprobe.exe"
[[ -x "$FFPROBE" ]] || FFPROBE="$FFMPEG_DIR/ffprobe"
if [[ ! -x "$FFPROBE" ]]; then
  # fall back to PATH ffprobe
  FFPROBE="ffprobe"
fi

SRC_WIDTH=$("$FFPROBE" -v error -select_streams v:0 \
  -show_entries stream=width -of csv=p=0 "$INPUT" 2>/dev/null | tr -d '\r')
SRC_HEIGHT=$("$FFPROBE" -v error -select_streams v:0 \
  -show_entries stream=height -of csv=p=0 "$INPUT" 2>/dev/null | tr -d '\r')
[[ -n "$SRC_WIDTH"  ]] || SRC_WIDTH=3072
[[ -n "$SRC_HEIGHT" ]] || SRC_HEIGHT=1372

# Default crop: remove right 412 px (participant panel).
# Width that survives must be even (h264 requirement after scaling).
CROP_PIXELS_REMOVED="${FRAMES_CROP_WIDTH:-412}"
CROP_WIDTH=$(( SRC_WIDTH - CROP_PIXELS_REMOVED ))
CROP_WIDTH=$(( CROP_WIDTH - CROP_WIDTH % 2 ))

SCALE_WIDTH="${FRAMES_SCALE_WIDTH:-1600}"
VF="crop=${CROP_WIDTH}:${SRC_HEIGHT}:0:0,scale=${SCALE_WIDTH}:-2"

mkdir -p "$OUTDIR"

echo "session:    $SESSION"
echo "source:     $INPUT  (${SRC_WIDTH}x${SRC_HEIGHT})"
echo "crop:       ${CROP_WIDTH}x${SRC_HEIGHT}  (removed right ${CROP_PIXELS_REMOVED} px)"
echo "scale:      width ${SCALE_WIDTH}"
echo "outdir:     $OUTDIR"
echo

for t in "${TIMESTAMPS[@]}"; do
  name=$(echo "$t" | tr ':' 'm')
  out="$OUTDIR/frame-${name}.jpg"
  printf "  %s -> %s ... " "$t" "$(basename "$out")"
  "$FFMPEG" -hide_banner -loglevel error -ss "$t" -i "$INPUT" \
    -frames:v 1 -vf "$VF" -q:v 2 -y "$out"
  size=$(stat -c%s "$out" 2>/dev/null || stat -f%z "$out")
  printf "%s bytes\n" "$size"
done

echo
echo "done. $(ls "$OUTDIR"/frame-*.jpg | wc -l) frames in $OUTDIR"
