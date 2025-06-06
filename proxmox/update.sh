#!/bin/bash
# Usage: sudo ./update.sh

ROOT_EMAIL=$(pveum user list | awk '/root@pam/ { print $5 }')
LOG_FILE=$(mktemp /tmp/pve_upgrade.log.XXXXXX)
TIMEOUT_DURATION="5m"

# Commands to run: update, upgrade (with auto-yes), autoremove (with auto-yes)
UPDATE_COMMANDS='/usr/bin/pveupdate && yes y | /usr/bin/pveupgrade && yes y | apt autoremove'

timeout "$TIMEOUT_DURATION" bash -c "$UPDATE_COMMANDS" > "$LOG_FILE" 2>&1
COMMAND_EXIT_CODE=$?

if [ $COMMAND_EXIT_CODE -eq 0 ]; then
    STATUS="succeeded"
else
    STATUS="failed"
fi

SUBJECT="PVE update cron at $HOSTNAME $STATUS"
BODY=$(cat "$LOG_FILE")
echo "$BODY" | mail -s "$SUBJECT" "$ROOT_EMAIL"
