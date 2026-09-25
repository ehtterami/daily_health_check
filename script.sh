#!/usr/bin/bash

# Exit On Error
set -euo pipefail

# Running Privilege Check
privilege_check() {
	if [ $EUID -ne 0 ]; then
		echo "Script must run as root"
		exit 1
	fi
}

# Log Name
file_name() {
	echo "$(date '+%Y-%m-%d')"
}

# Log Path
FILEPATH="/var/log/daily_health"

# Root Disk Usage Check
root_disk_usage() {
	local ROOT_DISK_USAGE="$(df / | awk 'NR==2 {print $5}' | tr -d '%')"
	echo $ROOT_DISK_USAGE
}

# Directories Disk Usages
dir_usage() {
	local dirs=("$@")

	for d in "${dirs[@]}"; do
		du $d -d 2 | sort -nr | awk '$1 > 0 {print $2}' | head -5
	done
}

# Logged Users Count
logged_users() {
	local USERS="$(who | wc -l)"
	echo $USERS
}

# Get Failed SSH Login Attempts
failed_login_attempts() {
	local LOGS=("/var/log/secure" "/var/log/auth.log")
	local ATTEMPTS=0
	if [ -f $LOGS[0] ]; then
		ATTEMPTS="$(grep -cE 'authentication failed|Failed password' $LOGS[0])"
	elif [ -f $LOGS[1] ]; then
		ATTEMPTS="$(grep -cE 'authentication failed|Failed password' $LOGS[1])"
	else
		ATTEMPTS="$(journalctl -u sshd --no-pager 2> /dev/null | grep -cE 'authentication failed|Failed password')"
	fi

	echo $ATTEMPTS
}

# Get Service Status
service_check() {
	local SERVICE=$1
	echo "$(systemctl is-active --quiet $SERVICE && echo 'on' || echo 'off')"
}

# Get Memory Status
memory_check() {
	read -r TOTMEM USEDMEM FREMEM < <(free -h | awk 'NR==2 {print $2, $3, $4}')
}

{
	privilege_check

	FILENAME=$(file_name)
	LOGPATH="$FILEPATH/$FILENAME"

	if [[ ! -d $FILEPATH ]]; then
		mkdir -p $FILEPATH
	fi
	if [[ ! -f $LOGPATH ]]; then
		touch $LOGPATH
	fi

	ROOT_DISK_USAGE=$(root_disk_usage)
	DIRS=("/var" "/home")
	FAILED_LOGINS=$(failed_login_attempts)
	LOGGED_USERS=$(logged_users)

	memory_check

	echo "-------- $FILENAME --------" >> $LOGPATH
	(( ROOT_DISK_USAGE > 80 )) && echo " ! RDU: $ROOT_DISK_USAGE%" || echo " - RDU: $ROOT_DISK_USAGE%" >> $LOGPATH
	echo " - Disk Usage [ /var ]" >> $LOGPATH
	dir_usage /var >> $LOGPATH
	echo " - Disk Usage [ /home ]" >> $LOGPATH
	dir_usage /home >> $LOGPATH
	echo " - Service Check [ sshd ]" >> $LOGPATH
	service_check sshd >> $LOGPATH
	echo " - Service Check [ crond ]" >> $LOGPATH
	service_check crond >> $LOGPATH
	echo " - Failed Logins: $FAILED_LOGINS/$LOGGED_USERS" >> $LOGPATH
	echo " - Logged Users: $LOGGED_USERS" >> $LOGPATH
	echo " - Memo:" >> $LOGPATH
	echo "   - Total: $TOTMEM" >> $LOGPATH
	echo "   - Used: $USEDMEM" >> $LOGPATH
	echo "   - Free: $FREMEM" >> $LOGPATH
	echo "-------- End Of Log --------" >> $LOGPATH
}
