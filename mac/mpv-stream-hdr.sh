#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title MPV Stream (HDR)
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖
# @raycast.argument1 { "type": "text", "placeholder": "URL" }

# Documentation:
# @raycast.author liubomyr
# @raycast.authorURL https://raycast.com/liubomyr


# Cleanup function to disable HDR no matter what
cleanup() {
  shortcuts run "Toggle HDR for the current monitor"
}
trap cleanup EXIT   # Run cleanup when the script exits for ANY reason

# Enable HDR via Shortcut
shortcuts run "Toggle HDR for the current monitor"

# Launch mpv
mpv "$1"
