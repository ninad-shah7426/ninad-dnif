#!/bin/bash

# Initialize JSON output
echo "{" > system_stats.json

# Log file path
LOG_FILE="/DNIF/PICO/log/eps-governor.log"

# Get the first and last timestamp from the log file
first_timestamp=$(awk '{print $1, $2}' "$LOG_FILE" | head -1)
last_timestamp=$(awk '{print $1, $2}' "$LOG_FILE" | tail -1)

# Convert timestamps to seconds since epoch
start_time=$(date -d "$first_timestamp" +%s)
end_time=$(date -d "$last_timestamp" +%s)

# Calculate total duration in seconds
total_time=$((end_time - start_time))

# Extract EPS values and calculate total
total_eps=$(grep -oP "EPS : \K[0-9]+" "$LOG_FILE" | awk '{sum+=$1} END {print sum}')
eps_count=$(grep -oP "EPS : \K[0-9]+" "$LOG_FILE" | wc -l)

# Calculate average EPS (Avoid division by zero)
if [ "$total_time" -gt 0 ]; then
    avg_eps=$(echo "$total_eps / $total_time" | bc -l)
else
    avg_eps=0
fi

# Append EPS calculations to JSON output
echo "\"eps_statistics\": {" >> system_stats.json
echo "  \"first_log_time\": \"$first_timestamp\"," >> system_stats.json
echo "  \"last_log_time\": \"$last_timestamp\"," >> system_stats.json
echo "  \"total_time_seconds\": \"$total_time\"," >> system_stats.json
echo "  \"total_eps\": \"$total_eps\"," >> system_stats.json
echo "  \"average_eps\": \"$avg_eps\"" >> system_stats.json
echo "}," >> system_stats.json

echo "}" >> system_stats.json

