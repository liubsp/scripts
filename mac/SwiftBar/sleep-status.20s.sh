#!/bin/bash

# <bitbar.title>Sleep Status</bitbar.title>
# <bitbar.version>v1.0</bitbar.version>
# <bitbar.author>github.com/liubsp</bitbar.author>
# <bitbar.desc>Shows whether your Mac is ready to sleep or blocked by processes and awake history.</bitbar.desc>
# <bitbar.dependencies>pmset,bash</bitbar.dependencies>

# We check the system appearance to determine the correct text color.
if [ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" == "Dark" ]; then
    TEXT_COLOR="#FBFFFF" # SwiftBar renders pure white (#FFFFFF) as gray, so use off-white instead
else
    TEXT_COLOR="black"
fi
COLOR_GREEN="green"
COLOR_ORANGE="orange"
COLOR_RED="red"
COLOR_GRAY="gray"

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
    echo ":moon.stars.fill:"
else
    echo ":cup.and.saucer.fill: $count"
fi

echo "---"

# Status summary
if [ "$count" -eq 0 ]; then
    echo "✓ Mac can sleep normally | color=$COLOR_GREEN"
else
    echo "⚠ $count process(es) blocking sleep | color=$COLOR_ORANGE"
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
            echo "• $proc | color=$COLOR_RED"
            echo "  $reason | color=$COLOR_GRAY size=12"
        fi
    done
    echo "---"
fi

# Awake History - shows sessions from past 7 days, flags >8h as potential blockers
echo "Awake History | size=12 color=$COLOR_GRAY"
pmset -g log 2>/dev/null | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}" | \
    awk '($4 == "Sleep" || $4 == "Wake") && $5 != "Requests" && !/Maintenance Sleep/' | \
    awk -v now="$(date +%s)" -v today="$(date +%Y-%m-%d)" -v WHITE="$TEXT_COLOR" '
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
