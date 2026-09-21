#!/usr/bin/bash

# daily_health_check
# Daily base server health check and report

# Check running privilege
if [ $EUID -ne 0 ]; then
	echo "Script must run as root"
	exit 1
fi

# Root disk usage check
RDU="$(df / | awk 'NR==2 {print $5}' | tr -d '%')"

if [ "$RDU" -gt 80 ]; then
	echo "Root disk usage is greater than 80 percent"
fi

# /var /home top five largest dirs
DIRS=("/var" "/home")
for d in "${DIRS[@]}"; do
	USEDIR="$(du "$d" -d 2 | sort -nr | awk '$1 > 0 {print $2}' | head -5)"
	echo $USEDIR
	echo
done

# Logged users count
USRS="$(who | wc -l)"
echo "Logged users: $USRS"

# Get failed ssh login attempts
if [ -f "/var/log/secure" ]; then
	ATTMPTS="$(grep -cE 'authentication failed|Failed password' /var/log/secure)"
elif [ -f "/var/log/auth.log" ]; then
	ATTMPTS="$(grep -cE 'authentication failed|Failed password' /var/log/auth.log)"
else
	ATTMPTS="$(journalctl -u sshd --no-pager 2> /dev/null | grep -cE 'authentication failed|Failed password')"
fi

echo "Failed Login Attempts: $ATTMPTS"

# Check if important services are running
SERVS=("sshd" "rsyslog" "crond")

for s in "${SERVS[@]}"; do
	CMD="$(systemctl is-active --quiet $s && echo 'on' || echo 'off')"
	echo $CMD
done

# Get used and free memory state
TOTMEM="$(free -h | awk 'NR==2 {print $2}')"
USEDMEM="$(free -h | awk 'NR==2 {print $3}')"
FREEMEM="$(free -h | awk 'NR==2 {print $4}')"

echo "Total Memo: $TOTMEM"
echo "Used Memo: $USEDMEM"
echo "Free Memo: $FREEMEM"

if [ ! -d /var/log/daily_health/ ]; then
	mkdir /var/log/daily_health/
fi

FILNAME="$(date '+%Y-%m-%d')"
FILPATH="/var/log/daily_health/$FILNAME"

if [ ! -f $FILPATH ]; then
	touch $FILPATH
fi

echo "Root Disk Usage Log" >> $FILPATH
echo $RDU >> $FILPATH
echo "Largest Dirs" >> $FILEPATH
echo $USEDIR >> $FILEPATH
echo "Logged Users" >> $FILEPATH
echo $USRS
echo "Failed Auth Attempts" >> $FILPATH
echo $ATTMPTS
echo "Services Stats" >> $FILPATH
echo $CMD
echo "Memory Stats" >> $FILPATH
echo "T: $TOTMEM" >> $FILPATH
echo "U: $USEDMEM" >> $FILPATH
echo "F: $FREEMEM" >> $FILPATH
