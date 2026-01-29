#!/bin/bash

# Sleep Status for xbar
# Shows whether your Mac is ready to sleep or something is blocking it

# xbar renders pure white (#FFFFFF) as gray, so use off-white instead
WHITE="#FBFFFF"

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

# Awake History - shows sessions from past 7 days, flags >8h as potential blockers
echo "Awake History | size=12 color=gray"
pmset -g log 2>/dev/null | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}" | \
    awk '($4 == "Sleep" || $4 == "Wake") && $5 != "Requests" && !/Maintenance Sleep/' | \
    awk -v now="$(date +%s)" -v today="$(date +%Y-%m-%d)" -v WHITE="$WHITE" '
    BEGIN {
        MAX_AGE = 604800      # 7 days in seconds
        MAX_SESSIONS = 20     # max sessions to display
        MIN_SESSION = 300     # 5 min - minimum awake duration to count as session
        LONG_AWAKE = 28800    # 8 hours - threshold for "long awake" warning
    }
    function fmt_dur(s) {
        if (s < 60) return int(s) "s"
        if (s < 3600) return int(s/60) "m"
        h = int(s/3600); m = int((s%3600)/60)
        return m > 0 ? h "h " m "m" : h "h"
    }
    function get_ts(d, t) {
        cmd = "date -j -f \"%Y-%m-%d %H:%M:%S\" \"" d " " t "\" +%s 2>/dev/null"
        cmd | getline r; close(cmd); return r
    }
    function fmt_dt(d, t) {
        tm = substr(t, 1, 5)
        if (d == today) return tm
        cmd = "date -j -f \"%Y-%m-%d\" \"" d "\" \"+%b %d\" 2>/dev/null"
        cmd | getline r; close(cmd); return r " " tm
    }
    {
        ts = get_ts($1, $2)
        if (ts == "" || (now - ts) > MAX_AGE) next
        n++; T[n] = ts; E[n] = $4; D[n] = fmt_dt($1, $2)
    }
    END {
        if (n == 0) { print "No activity | color=gray"; exit }

        # Build sessions: find Wake→Sleep pairs with >5min awake time
        sc = 0
        for (i = 1; i <= n && sc < MAX_SESSIONS; i++) {
            if (E[i] != "Wake") continue
            # Check if this wake follows >5min of sleep (or is first event)
            if (i > 1 && E[i-1] == "Sleep" && (T[i] - T[i-1]) < MIN_SESSION) continue

            wake_ts = T[i]; wake_dt = D[i]
            # Find next Sleep that ends this session (>5min after a wake)
            sleep_ts = 0; sleep_dt = ""
            for (j = i + 1; j <= n; j++) {
                if (E[j] == "Sleep") {
                    # Check if >5min since last wake in this span
                    last_wake = wake_ts
                    for (k = j - 1; k >= i; k--) { if (E[k] == "Wake") { last_wake = T[k]; break } }
                    if ((T[j] - last_wake) >= MIN_SESSION) {
                        sleep_ts = T[j]; sleep_dt = D[j]; break
                    }
                }
            }
            dur = sleep_ts > 0 ? (sleep_ts - wake_ts) : (now - wake_ts)
            if (dur >= MIN_SESSION) {
                sc++
                SW[sc] = wake_dt; SS[sc] = sleep_dt; SD[sc] = dur
                SA[sc] = (sleep_ts == 0)
            }
            if (sleep_ts > 0) i = j
        }

        # Output sessions newest first - flag long sessions as potential sleep blockers
        for (i = sc; i >= 1; i--) {
            d = fmt_dur(SD[i])
            if (SA[i]) print SW[i] " → now (" d ") | color=green"
            else if (SD[i] > LONG_AWAKE) print SW[i] " → " SS[i] " (" d ") ⚠ Long | color=orange"
            else print SW[i] " → " SS[i] " (" d ") | color=" WHITE
        }
        if (sc == 0) print "No awake sessions | color=gray"
    }'

# Submenus
echo "---"

echo "Scheduled Wakes"
echo "-- Upcoming system wake events | color=gray size=12"
pmset -g sched 2>/dev/null | grep -E "^\s*\[" | while read -r line; do
    time=$(echo "$line" | grep -oE "[0-9]{2}/[0-9]{2}/[0-9]{4} [0-9]{2}:[0-9]{2}")
    source=$(echo "$line" | grep -oE "'[^']+'" | tr -d "'" | sed 's/com.apple.alarm.user-invisible-//' | sed 's/com.apple.//')
    echo "-- $time - $source | font=Menlo size=10 color=$WHITE"
done

echo "Raw Sleep Log"
echo "-- Recent pmset events for debugging | color=gray size=12"
pmset -g log 2>/dev/null | grep -E "Entering.Sleep|Wake.from|DarkWake" | tail -40 | while read -r line; do
    echo "-- $line | font=Menlo size=10 color=$WHITE trim=false"
done

echo "---"
echo "Refresh | refresh=true"
