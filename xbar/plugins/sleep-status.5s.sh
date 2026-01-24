#!/bin/bash

# Sleep Status for xbar
# Shows whether your Mac is ready to sleep or something is blocking it

# Get all assertions
assertions=$(pmset -g assertions 2>/dev/null)

# Extract blockers (PreventUserIdleSystemSleep and PreventSystemSleep lines with process info)
blockers=$(echo "$assertions" | grep -E "PreventUserIdleSystemSleep|PreventSystemSleep" | grep "named:" | \
    grep -vi "Prevent sleep while display is on" | \
    grep -vi "BTLEAdvertisement" | \
    grep -vi "Handoff" | \
    grep -vi "PreventUserIdleSystemSleep     0" | \
    grep -vi "PreventSystemSleep             0")

# Count actual blockers
if [ -z "$blockers" ]; then
    count=0
else
    count=$(echo "$blockers" | wc -l | tr -d ' ')
fi

# Menu bar icon
if [ "$count" -eq 0 ]; then
    echo "☾"
else
    echo "☕ $count"
fi

echo "---"

# Status summary
if [ "$count" -eq 0 ]; then
    echo "✓ Mac can sleep normally | color=green"
else
    echo "⚠ $count process(es) blocking sleep | color=orange"
fi

echo "---"

# Show blockers if any
if [ "$count" -gt 0 ]; then
    echo "Blocking processes:"
    echo "$blockers" | while read -r line; do
        # Extract process name and reason
        proc=$(echo "$line" | grep -oE "pid [0-9]+\([^)]+\)" | head -1)
        reason=$(echo "$line" | grep -oE 'named: "[^"]+"' | sed 's/named: //' | tr -d '"')
        if [ -n "$proc" ]; then
            echo "• $proc | color=red"
            echo "  $reason | color=gray size=12"
        fi
    done
    echo "---"
fi

# Quick actions
echo "---"
echo "Show all assertions"
pmset -g assertions | while read -r line; do
    echo "-- $line | font=Menlo size=11 color=#FBFFFF trim=false"
done
echo "Show recent wake/sleep"
pmset -g log | grep -E "Entering.Sleep|Wake.from|DarkWake" | tail -40 | while read -r line; do
    # Slightly off-white avoids dimming
    echo "-- $line | font=Menlo size=11 color=#FBFFFF trim=false"
done
echo "---"
echo "Refresh | refresh=true"
