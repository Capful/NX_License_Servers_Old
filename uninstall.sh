#!/bin/sh

#
#  ============================================================================
#
#  SSQ Unified License Server Un-Installer for Windows / Linux / MacOS
#  2006-2017 TeAM SolidSQUAD-SSQ
#  
#  02.05.2017: Initial revision
#  30.05.2017: Major rewrite
#  10.10.2017: Detecting init system properly
#  27.10.2017: Fixed old Upstart job installation and removal
#

#
#  ============================================================================
#

#  ============================================================================
#                             HELPER FUNCTIONS
#  ============================================================================

#  ============================================================================
#                            GNU WRAPPERS FOR OSX
#  ============================================================================

osx_dos2unix()
{
	NAME="$1"
	sed 's/\r$//' "$NAME" > "$NAME.tmp"
	cp "$NAME.tmp" "$NAME"
	rm "$NAME.tmp"
}

#
# taken from:
# https://stackoverflow.com/questions/1055671/how-can-i-get-the-behavior-of-gnus-readlink-f-on-a-mac/1116890#1116890
#

osx_canonicalize()
{
	TARGET_FILE="$1"

	cd "`dirname "$TARGET_FILE"`"
	TARGET_FILE="`basename "$TARGET_FILE"`"

	# Process "/.." edge case

	[ "$TARGET_FILE" = ".." ] && cd .. && TARGET_FILE=""

	# Iterate down a (possible) chain of symlinks

	while [ -L "$TARGET_FILE" ]
	do
		TARGET_FILE="`readlink "$TARGET_FILE"`"
		cd "`dirname "$TARGET_FILE"`"
		TARGET_FILE="`basename "$TARGET_FILE"`"
	done

	# Compute the canonicalized name by finding the physical path 
	# for the directory we're in and appending the target file.

	PHYS_DIR="`pwd -P`"
	RESULT="$PHYS_DIR/$TARGET_FILE"
	echo "$RESULT"
}

#  ============================================================================
#                          Remove folders
#  ============================================================================

remove_folders()
{
		# Remove everything from Bin / Licenses / Logs folder

		rm -rf "$SCRIPTDIR/Bin"
		rm -rf "$SCRIPTDIR/Licenses"
		rm -rf "$SCRIPTDIR/Logs"
}

#  ============================================================================
#                       Detect Linux Init System
#  ============================================================================

#
# detect_linux_init_system
#

detect_linux_init_system()
{
	# detect from rarest to most common

	IN=

	# detect SysVinit

	grep -i "=sysvinit" /proc/1/exe 1>/dev/null 2>/dev/null
	[ $? -eq 0 ] && IN="sysv"

	[ "$IN" == "sysv" ] && [ -d /etc/init.d ] && [ ! -z "`find /etc/init.d/ -type f -exec sed -n '1p' '{}' \; | sort -Vu | grep -i openrc`" ] && IN="openrc"

	# detect OpenRC

	grep -i "openrc " /proc/1/exe 1>/dev/null 2>/dev/null
	[ $? -eq 0 ] && IN="openrc"

	# detect Upstart

	grep -i "upstart-devel" /proc/1/exe 1>/dev/null 2>/dev/null
	[ $? -eq 0 ] && IN="upstart"

	# detect systemd

	grep -i "systemd " /proc/1/exe 1>/dev/null 2>/dev/null
	[ $? -eq 0 ] && IN="systemd"

	echo $IN
}

#  ============================================================================
#                       Un-Install Auto-Loaded Service
#  ============================================================================

#
# uninstall_service "<service-file-name-noext>"
#

uninstall_service()
{
	SERVICEFILE="$1"

	case $MACHINE in
		MSYS_NT-*) # This is Windows

			# do nothing here
		;;
		
		Linux)	# This is Linux

			# Remove license server from /etc/rc.local

			if [ -e /etc/rc.local ];
			then
				sed -i -n "/# START UNIFIED LICENSE SERVER BY TEAM SOLIDSQUAD-SSQ/!p" /etc/rc.local
			fi

			# Detect init system

			INITSYSTEM="`detect_linux_init_system`"

			# Remove systemd unit

			if [ "$INITSYSTEM" = "systemd" ]
			then
				systemctl stop $SERVICEFILE.service
				systemctl disable $SERVICEFILE.service
				rm -f /usr/lib/systemd/system/$SERVICEFILE.service
				rm -f /etc/systemd/system/$SERVICEFILE.service
				systemctl daemon-reload
				return 0
			fi

			# Remove Upstart script

			if [ "$INITSYSTEM" = "upstart" ]
			then
				initctl stop $SERVICEFILE
				[ ! -z "`initctl help | grep disable`" ] && initctl disable $SERVICEFILE
				rm -f /etc/init/$SERVICEFILE.conf
				rm -f /etc/init.d/$SERVICEFILE
				initctl reload-configuration
				return 0
			fi

			# Remove OpenRC script

			if [ "$INITSYSTEM" = "openrc" ]
			then
				"/etc/init.d/$SERVICEFILE" stop
				rc-update delete $SERVICEFILE default
				rm -f "/etc/init.d/$SERVICEFILE"
				return 0
			fi

			# Make SysV script

			if [ "$INITSYSTEM" = "sysv" ]
			then
				"/etc/init.d/$SERVICEFILE" stop
				update-rc.d $SERVICEFILE remove
				rm -f "/etc/init.d/$SERVICEFILE"
				return 0
			fi
		;;
		Darwin)	# This is MacOS

			launchctl unload /Library/LaunchDaemons/org.solidsquad.$SERVICEFILE.plist
			rm -f /Library/LaunchDaemons/org.solidsquad.$SERVICEFILE.plist
		;;
		*)	echo "$MACHINE is not supported! Exiting..."
			exit 1
		;;
	esac
}

#  ============================================================================
#                               START SCRIPT
#  ============================================================================

# check the OS type

MACHINE="`uname`"

case $MACHINE in
	MSYS_NT-*) # This is Windows

		# dont check root here - use the batch file to acquire
		# the elevated shell

		# define GNU stuff

		CANONICALIZE="readlink -f"
		DOS2UNIX="dos2unix"

		# reference this script from batch file

		SCRIPTDIR="`$CANONICALIZE "$_THIS_SCRIPT"`"

		;;
	Linux)	# This is Linux

		# Greet the user

		echo
		echo "Unified License Server Un-Installer by TeAM SolidSQUAD-SSQ"
		echo

		# Check if we are root user - otherwise call self with sudo and terminate

		if [ "`id -un`" != "root" ];
		then
			sudo sh "$0" "$*"
			exit 1
		fi

		# define GNU stuff

		CANONICALIZE="readlink -f"
		DOS2UNIX="dos2unix"

		;;
	Darwin)	# This is MacOS

		# Greet the user

		echo
		echo "Unified License Server Un-Installer by TeAM SolidSQUAD-SSQ"
		echo

		# define OSX wrappers for GNU stuff

		CANONICALIZE="osx_canonicalize"
		DOS2UNIX="osx_dos2unix"

		;;
	*)	echo "$MACHINE is not supported! Exiting..."
		exit 1
		;;
esac

# find the script directory

[ -z "$SCRIPTDIR" ] && SCRIPTDIR="`$CANONICALIZE "$0"`"
SCRIPTDIR="`dirname "$SCRIPTDIR"`"

# uninstall old servers first

if [ -d "$SCRIPTDIR/Bin" ] 
then
	for VENDORUNINSTALLER in `find "$SCRIPTDIR/Bin" -type f -name "*.uninstall"`
	do
		. "$VENDORUNINSTALLER"
	done
fi

# Remove everything from Bin / Licenses / Logs folder

remove_folders

# Report success

exit 0