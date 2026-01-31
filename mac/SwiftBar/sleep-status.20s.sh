#!/bin/bash

# <xbar.title>Sleep Blockers and Awake History</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>github.com/liubsp</xbar.author>
# <xbar.desc>Shows whether your Mac is ready to sleep or blocked by processes and awake history.</xbar.desc>
# <xbar.dependencies>pmset,defaults</xbar.dependencies>

# We check the system appearance to determine colors based on theme.
if [ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" == "Dark" ]; then
    COLOR_PRIMARY="#FFFFFE" # Passive items are rendered with Secondary Label styling (gray), so use off-white instead
    COLOR_GREEN="green"
    COLOR_ORANGE="orange"
    COLOR_RED="red"
    COLOR_GRAY="gray"
else
    COLOR_PRIMARY="#000001" # Passive items are rendered with Secondary Label styling (gray), so use off-black instead
    COLOR_GREEN="#0D5D20"   # Dark green
    COLOR_ORANGE="#8B3E00"  # Dark orange
    COLOR_RED="#8B0000"     # Dark red
    COLOR_GRAY="#444444"    # Dark gray
fi

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
    [ "$count" -eq 1 ] && word="process" || word="processes"
    echo "⚠ $count $word blocking sleep | color=$COLOR_ORANGE"
fi

echo "---"

# Show blockers if any
if [ "$count" -gt 0 ]; then
    echo "Blocking Processes"
    echo "$blockers" | while read -r line; do
        # Extract process name and reason
        proc=$(echo "$line" | grep -oE "pid [0-9]+\([^)]+\)" | head -1)
        reason=$(echo "$line" | grep -oE 'named: "[^"]+"' | sed 's/named: //' | tr -d '"')
        if [ -n "$proc" ]; then
            echo "• $proc | color=$COLOR_RED"
            # Wrap long reason lines
            echo "$reason" | fold -s -w 50 | while read -r part; do
                [ -n "$part" ] && echo "  $part | font=Menlo color=$COLOR_PRIMARY size=10"
            done
        fi
    done
    echo "---"
fi

# Awake History - shows recent sessions and flags long sessions as potential sleep blockers.
# pmset log has limited history and may return less sessions than MAX_SESSIONS.
echo "Awake History | color=$COLOR_GRAY"
pmset -g log 2>/dev/null | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}" | \
    awk '($4 == "Sleep" || $4 == "Wake") && $5 != "Requests" && !/Maintenance Sleep/' | \
    awk -v now="$(date +%s)" -v today="$(date +%Y-%m-%d)" -v COLOR_PRIMARY="$COLOR_PRIMARY" \
        -v COLOR_ORANGE="$COLOR_ORANGE" -v COLOR_GRAY="$COLOR_GRAY" -v COLOR_GREEN="$COLOR_GREEN" '
    BEGIN {
        MAX_SESSIONS = 15     # max sessions to display
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
        if (d == today) return sprintf("%16s", tm)
        cmd = "date -j -f \"%Y-%m-%d\" \"" d "\" \"+%a %b %d\" 2>/dev/null"
        cmd | getline r; close(cmd); return r " " tm
    }
    {
        ts = get_ts($1, $2)
        n++; T[n] = ts; E[n] = $4; D[n] = fmt_dt($1, $2)
    }
    END {
        if (n == 0) { print "No activity | color=" COLOR_PRIMARY; exit }

        # Build sessions: find Wake→Sleep pairs with >5min awake time
        sc = 0
        for (i = 1; i <= n && sc < MAX_SESSIONS; i++) {
            if (E[i] != "Wake") continue

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
            if (SA[i]) print SW[i] " → now (" d ") | font=Menlo color=" COLOR_GREEN
            else if (SD[i] > LONG_AWAKE) print SW[i] " → " SS[i] " (" d ") ⚠ Long | font=Menlo color=" COLOR_ORANGE
            else print SW[i] " → " SS[i] " (" d ") | font=Menlo color=" COLOR_PRIMARY
        }
        if (sc == 0) print "No awake sessions | color=" COLOR_PRIMARY
    }'
