#!/usr/bin/env bash
set -euo pipefail
# Uses the integration driver's private SDL dummy event queue, no OS input.
test_binary="$1"
temp_root=$(cd "${TMPDIR:-/tmp}" && pwd -P)
media=$(mktemp -d "$temp_root/video-compare-video-loop.XXXXXXXX")
cleanup() {
  local resolved
  resolved=$(cd "$media" && pwd -P) || return
  if [[ "$resolved" == "$temp_root"/video-compare-video-loop.* && "${resolved%/*}" == "$temp_root" ]]; then
    rm -rf -- "$resolved"
  fi
}
trap cleanup EXIT
ffmpeg -hide_banner -loglevel error -y -f lavfi -i 'testsrc2=size=160x96:rate=25:duration=3' \
  -c:v libx264 -g 50 -bf 3 "$media/short.mp4"
ffmpeg -hide_banner -loglevel error -y -f lavfi -i 'testsrc2=size=160x96:rate=25:duration=4' \
  -vf hflip -c:v libx264 -g 50 -bf 3 "$media/long.mp4"
ffprobe -v error -select_streams v:0 -show_entries frame=best_effort_timestamp_time \
  -of csv=p=0 "$media/short.mp4" | awk -F, '$1 ~ /^[0-9]+\.[0-9]+$/ {print $1}' > "$media/pts.txt"
mkdir "$media/minimum" "$media/multi" "$media/short-right"
(cd "$media/minimum"; FRAME_STEP_TEST_VIDEO_LOOP=1 "$test_binary" 1 "$media/pts.txt" "$media/short.mp4" "$media/short.mp4")
(cd "$media/multi"; FRAME_STEP_TEST_VIDEO_LOOP=1 "$test_binary" 50 "$media/pts.txt" "$media/short.mp4" "$media/short.mp4" "$media/long.mp4")
(cd "$media/short-right"; FRAME_STEP_TEST_VIDEO_LOOP=1 "$test_binary" 3 "$media/pts.txt" "$media/long.mp4" "$media/short.mp4")
mkdir "$media/startup-buffer"
(cd "$media/startup-buffer"; FRAME_STEP_AUTO_BUFFER_LOOP=1 FRAME_STEP_TEST_VIDEO_LOOP=1 "$test_binary" 50 "$media/pts.txt" "$media/short.mp4" "$media/short.mp4")
