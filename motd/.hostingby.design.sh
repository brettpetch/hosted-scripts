#!/bin/bash
user=$(whoami)
hostname=$(hostname -f)
cpu_load=$(cat /proc/loadavg | cut -d" " -f 1 | echo "scale=4; ($(</dev/stdin)/$(nproc))*100" | bc -l)
memory_usage=$(awk '/^Mem/ {print $3}' <(free -g))
memory_available=$(awk '/^Mem/ {print $2}' <(free -g))
disk_usage=$(quota -s -u $(whoami) | grep "/dev/" | awk '{print "Quota Used: " $2" / "$4}')
bandwidth_used=$(sudo box bw | grep "Used" | cut -d: -f2)
bandwidth_total=$(sudo box bw | grep "Total" | cut -d: -f2)
running_processes=$(ps aux | wc -l)
sys_uptime=$(uptime | awk '{print $3 " " $4}' | sed s'/.$//')

printf "         .:.:.:.\n"
printf "      -:::.   .:::-        Welcome back, %s! \n" "${user}"
printf "  .::::-:::.      -:::.    Hostname: %s \n" "${hostname}"
printf "  o.      .:.:::- .::/o    CPU Usage: %g%% \n" "${cpu_load}"
printf "  +.         .:.++:.  +    RAM Usage: %s GiB / %s GiB \n" "${memory_usage}" "${memory_available}"
printf "  +.   ...+::.        +    %s \n" "${disk_usage}"
printf "  o/::: .::.:.:...   .+    Bandwidth:%s /%s \n" "${bandwidth_used}" "${bandwidth_total}"
printf "  .:::-        :::-:::.    Processes: %s \n" "${running_processes}"
printf "      -:::.   .::/-        Uptime: %s \n" "${sys_uptime}"
printf "         .:.:.:.\n"
