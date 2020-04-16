#!/bin/bash

# Change in to the lineage build directory.
cd ~/android/lineage

# Get the device list.
source ~/.WundermentOS/devices.sh

# Import the destination e-mail address to send logs to.
source ~/.WundermentOS/log-email-address.sh

# Update the source code from GitHub.
~/bin/repo sync --force-sync > ~/tasks/cron/logs/repo.sync.log 2>&1

# Check to see if repo sync failed for some reason.
# Note: grep returns 0 when it matches some lines and 1 when it doesn't.
grep "error" ~/tasks/cron/logs/repo.sync.log >/dev/null 2>&1
if [ $? -eq 0 ]
then
	# Send the log via e-mail
	cat ~/tasks/cron/logs/repo.sync.log | mail -s "WundermentOS Repo Sync Error" $WOS_LOGDEST

	# Exit the script with an error condition.
	exit 1
fi

# Find out how long ago the F-Droid apk was downloaded (in seconds).
LASTFD=$(expr `date +%s` - `stat -c %Z ~/android/lineage/packages/apps/F-Droid/FDroid.apk`)

for DEVICE in $WOS_DEVICES; do
	echo "Checking secruity patch level for $DEVICE..."

	# Let's see if we've had a security patch update since yesterday.
	grep "PLATFORM_SECURITY_PATCH :=" ~/android/lineage/build/core/version_defaults.mk > ~/devices/$DEVICE/status/current.security.patch.txt
	diff ~/devices/$DEVICE/status/last.security.patch.txt ~/devices/$DEVICE/status/current.security.patch.txt > /dev/null 2>&1
	if [ $? -eq 1 ]
	then
   		cp ~/devices/$DEVICE/status/current.security.patch.txt ~/devices/$DEVICE/status/last.security.patch.txt

		# check to see if we should re-download F-Droid.apk before running the build.
		if [ $LASTFD -gt 86400 ]; then
			echo "Downloading F-Droid..."

			cd /tasks/source
			./update-f-droid-apk.sh

			# Reset the LASTFD variable so we don't download FDroid.apk for each device we're building for.
			LASTFD=0
		fi

   		# Update blobs and firmware.
		echo "Updating $DEVICE stock os..."
		cd ~/devices/$DEVICE/stock_os
   		./get-stock-os.sh

   		# Start the build/sign process and send it to the background.
		echo "Building $DEVICE..."
		cd ~/devices/$DEVICE/build
   		./build.sh nohup_build_sign

		cd ~/tasks/cron
	fi
done
