#!/bin/bash

# <xbar.title>Year Progress</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>github.com/liubsp</xbar.author>
# <xbar.desc>Shows the current year's progress as a percentage</xbar.desc>

year=$(date +%Y)
start_of_year=$(date -j -f "%Y-%m-%d %H:%M:%S" "$year-01-01 00:00:00" +%s)
end_of_year=$(date -j -f "%Y-%m-%d %H:%M:%S" "$((year + 1))-01-01 00:00:00" +%s)
now=$(date +%s)

total_seconds=$((end_of_year - start_of_year))
elapsed_seconds=$((now - start_of_year))

progress=$(echo "scale=4; $elapsed_seconds * 100 / $total_seconds" | bc)
formatted=$(printf "%.3f" "$progress")

echo "🦦 ${formatted}%"
echo "---"
echo "Year $year Progress"
