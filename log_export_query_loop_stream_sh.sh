#!/bin/bash

for stream in {AUTHENTICATION,FIREWALL}; do # Loop over the specified streams

 # Define the start and end times
 START_TIME="2026-01-05T00:00:00"
 END_TIME="2026-01-05T04:00:00"
 
 # Convert times to seconds since epoch
 start_epoch=$(date -d "$START_TIME IST" +%s)
 end_epoch=$(date -d "$END_TIME IST" +%s)
 
 # Loop over each hour
 while [ "$start_epoch" -lt "$end_epoch" ]; do
   # Calculate end of the current 1-hour window
   next_epoch=$((start_epoch + 3600)) # 3600 seconds = 1 hour
   
   # Ensure next_epoch doesn't go beyond the original END_TIME
   if [ "$next_epoch" -gt "$end_epoch" ]; then
     next_epoch=$end_epoch
   fi
 
   # Format times in required format
   start_time_str=$(date -d "@$start_epoch" "+%Y-%m-%dT%H:%M:%S")
   end_time_str=$(date -d "@$next_epoch" "+%Y-%m-%dT%H:%M:%S")
 
   echo "Running export from $start_time_str to $end_time_str"
   python3 log_export.py -q "_fetch * from event where \$Stream=$stream AND \$DevSrcIP=192.227.165.211 AND \$StartTime=$start_time_str AND \$EndTime=$end_time_str limit 10000" -sid default -ft csv
 
   # Move to next interval
   start_epoch=$next_epoch
 done;
done
