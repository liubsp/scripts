#!/bin/bash
# Usage: ./update.sh <telepush_url>

# Check if Telepush URL is provided
if [ -z "$1" ]; then
    echo "Error: Telepush URL not provided."
    echo "Usage: $0 <telepush_url>"
    exit 1
fi

TELEPUSH_URL="$1"
LOG_FILE="/tmp/pve_upgrade.log"
TIMEOUT_DURATION="5m"

# Commands to run: update, upgrade (with auto-yes), autoremove (with auto-yes), and capture exit code
UPDATE_COMMANDS="(sudo /usr/bin/pveupdate && yes y | sudo /usr/bin/pveupgrade && yes y | sudo apt autoremove; echo \"Status code: \$?\")"

# Run commands with timeout, redirecting all output to the log file
timeout "$TIMEOUT_DURATION" bash -c "$UPDATE_COMMANDS" > "$LOG_FILE" 2>&1

# Check if the command completed within the timeout
if [ $? -eq 0 ]; then
    # Origin string for the notification message
    ORIGIN="PVE update cron at $HOSTNAME"

    # Format log content into JSON and send via curl
    jq -n \
       --rawfile f "$LOG_FILE" \
       --arg origin "$ORIGIN" \
       '{ origin: $origin, text: $f }' | \
    curl -X POST \
         -H "Content-Type: application/json" \
         -d @- \
         "$TELEPUSH_URL"
else
    # Handle timeout or command failure
    echo "Command timed out or failed. Check $LOG_FILE for details."
fi