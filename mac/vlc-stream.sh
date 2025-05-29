#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title VLC Stream
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖
# @raycast.argument1 { "type": "text", "placeholder": "Placeholder" }

# Documentation:
# @raycast.author liubomyr
# @raycast.authorURL https://raycast.com/liubomyr

open -a VLC "$1"

