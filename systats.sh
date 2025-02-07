#!/bin/bash

# Initialize JSON output
echo "{" > system_stats.json

dirs=("/DNIF" "/")
echo "Checking mount points:"
for dir in "${dirs[@]}"; do
    if [ -d "$dir" ]; then
        size=$(df -h "$dir" | awk 'NR==2 {print $2}')
        used=$(df -h "$dir" | awk 'NR==2 {print $3}')
        avail=$(df -h "$dir" | awk 'NR==2 {print $4}')
        mounted=$(mount | grep " $dir " | awk '{print $1}')
        
        echo "\"$dir\": {" >> system_stats.json
        echo "  \"exists\": true," >> system_stats.json
        echo "  \"size\": \"$size\"," >> system_stats.json
        echo "  \"used\": \"$used\"," >> system_stats.json
        echo "  \"available\": \"$avail\"," >> system_stats.json
        echo "  \"mounted\": \"$mounted\"" >> system_stats.json
        echo "}," >> system_stats.json
    else
        echo "\"$dir\": {" >> system_stats.json
        echo "  \"exists\": false" >> system_stats.json
        echo "}," >> system_stats.json
    fi
done

# Check if directories are in LVM or static
echo "\nChecking if directories are in LVM or static:"
echo "\"lvm_status\": {" >> system_stats.json
for dir in "${dirs[@]}"; do
    mount_point=$(df "$dir" --output=source | tail -n1)
    if [[ "$mount_point" == /dev/mapper/* ]]; then
        echo "  \"$dir\": \"LVM\"," >> system_stats.json
    else
        echo "  \"$dir\": \"Static\"," >> system_stats.json
    fi
done
echo "}," >> system_stats.json

# CPU Core Count
echo "\nChecking CPU core count:"
cpu_cores=$(nproc)
echo "\"cpu_cores\": \"$cpu_cores\"," >> system_stats.json

# Memory Usage
echo "\nChecking Memory Usage:"
total_ram=$(free -h | awk '/Mem:/ {print $2}')
used_ram=$(free -h | awk '/Mem:/ {print $3}')
avail_ram=$(free -h | awk '/Mem:/ {print $7}')

echo "\"memory\": {" >> system_stats.json
echo "  \"total\": \"$total_ram\"," >> system_stats.json
echo "  \"used\": \"$used_ram\"," >> system_stats.json
echo "  \"available\": \"$avail_ram\"" >> system_stats.json
echo "}," >> system_stats.json

# Check running Docker containers
echo "\nDocker containers running:"
echo "\"docker_containers\": [" >> system_stats.json
docker ps --format "{ \"ID\": \"{{.ID}}\", \"Name\": \"{{.Names}}\", \"Status\": \"{{.Status}}\" }," >> system_stats.json
echo "]," >> system_stats.json

# Check if pico-v9 container is present
echo "\nChecking if pico-v9 container is present:"
pico_mount=$(docker inspect pico-v9 --format='{{json .Mounts}}' 2>/dev/null)
if [ -n "$pico_mount" ]; then
    echo "\"pico-v9_mount\": $pico_mount," >> system_stats.json
else
    echo "\"pico-v9_mount\": \"Not found\"," >> system_stats.json
fi

# List additional running processes excluding system defaults
echo "\nAdditional running processes:"
echo "\"additional_processes\": [" >> system_stats.json
ps aux --sort=-%mem | awk '{print "{ \"User\": \""$1"\", \"PID\": \""$2"\", \"CPU\": \""$3"\", \"Memory\": \""$4"\", \"Command\": \""$11"\" },"}' | grep -vE "root|systemd|kthreadd|ksoftirqd" >> system_stats.json
echo "]," >> system_stats.json

# Check for non-native Ubuntu packages safely
echo "\nNon-native Ubuntu packages installed:"
echo "\"non_native_packages\": [" >> system_stats.json

if [ -f /var/log/installer/initial-status.gz ]; then
    comm -23 <(dpkg --get-selections | awk '{print $1}' | sort) <(gzip -dc /var/log/installer/initial-status.gz | awk '{print $2}' | sort) | while read pkg; do
        version=$(dpkg -s "$pkg" 2>/dev/null | grep "Version:" | awk '{print $2}')
        echo "{ \"Package\": \"$pkg\", \"Version\": \"$version\" }," >> system_stats.json
    done
else
    echo "{ \"Error\": \"initial-status.gz not found, unable to determine non-native packages\" }," >> system_stats.json
fi

echo "]," >> system_stats.json

# List all active services excluding native system services
echo "\nNon-native active services:"
echo "\"non_native_services\": [" >> system_stats.json
systemctl list-units --type=service --state=running | grep -vE "systemd|dbus|snapd|networkd|udev|cron" | awk '{print "{ \"Service\": \""$1"\", \"Status\": \""$4"\" },"}' >> system_stats.json
echo "]," >> system_stats.json

# List services running inside containerized supervisorctl
echo "\nServices running inside containers via supervisorctl:"
echo "\"container_supervisord_services\": [" >> system_stats.json
docker ps --format "{{.Names}}" | while read container; do
    services=$(docker exec "$container" supervisorctl status 2>/dev/null | awk '{print "{ \"Service\": \""$1"\", \"Status\": \""$2"\" },"}')
    echo "$services" >> system_stats.json
done
echo "]," >> system_stats.json

# Read /etc/hosts
echo "\nReading /etc/hosts:"
echo "\"hosts_file\": [" >> system_stats.json
awk '{print "{ \"Line\": \""$0"\" },"}' /etc/hosts >> system_stats.json
echo "]," >> system_stats.json

# Check network interfaces and IP addresses
echo "\nChecking network interfaces and IP addresses:"
echo "\"network_interfaces\": [" >> system_stats.json
ip -o addr show | awk '{print "{ \"Interface\": \""$2"\", \"IP\": \""$4"\" },"}' >> system_stats.json
echo "]," >> system_stats.json

# Check IP routes
echo "\nChecking IP routes:"
echo "\"ip_routes\": [" >> system_stats.json
ip route show | awk '{print "{ \"Route\": \""$0"\" },"}' >> system_stats.json
echo "]," >> system_stats.json

# Check UFW status and rules
echo "\nChecking UFW status and rules:"
echo "\"ufw_status\": [" >> system_stats.json
ufw status verbose | awk '{print "{ \"Rule\": \""$0"\" },"}' >> system_stats.json
echo "]," >> system_stats.json

# Check iptables rules (including legacy)
echo "\nChecking iptables rules:"
echo "\"iptables_rules\": [" >> system_stats.json
iptables -S | awk '{print "{ \"Rule\": \""$0"\" },"}' >> system_stats.json
iptables-legacy -S 2>/dev/null | awk '{print "{ \"Rule\": \""$0"\" },"}' >> system_stats.json
echo "]," >> system_stats.json

# Check /etc/fstab for /DNIF and /
echo "\nChecking /etc/fstab for /DNIF and /:"
echo "\"fstab_entries\": [" >> system_stats.json
grep -E "/DNIF| / " /etc/fstab | awk '{print "{ \"Entry\": \""$0"\" },"}' >> system_stats.json
echo "]," >> system_stats.json

echo "}" >> system_stats.json

