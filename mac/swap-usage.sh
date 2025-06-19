#!/bin/bash

# Get all process IDs
# Only PIDs using > 50MB RSS
pids=($(ps -axo pid=,rss= | awk '$2 > 50000 {print $1}'))
total=${#pids[@]}
count=0

printf "#\tPID\tSWAP\tCOMMAND\n"

for pid in "${pids[@]}"; do
    count=$((count + 1))

    swap=$(sudo vmmap "$pid" 2>/dev/null | grep "swapped_out=" | sed -n 's/.*swapped_out=\([0-9.]*[GMK]\).*/\1/p')

    # Set color based on the unit
    color=""
    reset="\033[0m"
    if [[ $swap == *G ]]; then
        color="\033[31m"  # Red for "G"
    elif [[ $swap == *M ]]; then
        color="\033[33m"  # Yellow for "M"
    elif [[ $swap == *K ]]; then
        color="\033[32m"  # Green for "K"
    fi

    cmd=$(ps -p "$pid" -o comm=)
    printf "%s\t%s\t%b%s%b\t%s\n" "$count/$total" "$pid" "$color" "$swap" "$reset" "$cmd"
done
