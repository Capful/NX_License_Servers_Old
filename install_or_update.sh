#!/bin/sh

#
#  ============================================================================
#
#  SSQ Unified License Server Installer for Windows / Linux / MacOS
#  2006-2017 TeAM SolidSQUAD-SSQ
#  
#  02.05.2017: Initial revision
#
#  30.05.2017: Major rewrite
#
#  10.10.2017: Fixed for-loop BASH-isms
#              Added LSB info to init scripts
#              Detecting init system properly
#              revert to osx_dos2unix if GNU dostools not installed
#
#  24.10.2017: Add OpenRC and SysV support in (un)install_service
#              Fixed lmgrd.install
#
#  27.10.2017: Fixed old Upstart job installation and removal
#  28.10.2017: Added timestamping for core and modules
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
	NAME="$2" # because $1 is "-q"
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
#                          Create folder structure
#  ============================================================================

#
# $1 - whether use chown ("chown") or not ("nochown")
#

create_folder_structures()
{
		# Remove everything from Bin / Licenses / Logs folder

		rm -rf "$SCRIPTDIR/Bin"
		mkdir "$SCRIPTDIR/Bin"

		rm -rf "$SCRIPTDIR/Licenses"
		mkdir "$SCRIPTDIR/Licenses"

		rm -rf "$SCRIPTDIR/Logs"
		mkdir "$SCRIPTDIR/Logs"

		# initialize timestamp file

		[ -e "$SCRIPTDIR/Vendors/_SSQ_/.timestamp" ] && echo "_SSQ_ `cat "$SCRIPTDIR/Vendors/_SSQ_/.timestamp"`" > "$SCRIPTDIR/Logs/.timestamps"

		if [ "$1" = "chown" ]
		then
			chown -R root:$NOGROUP "$SCRIPTDIR/Logs"
			chmod -R 775 "$SCRIPTDIR/Logs"
		fi
}

#  ============================================================================
#                               Process vendor modules
#  ============================================================================

#
# $1 - whether use chown ("chown") or not ("nochown")
#
# Other requirements:
#
# DOS2UNIX must point to valid dos2unix (POSIX) or osx_dos2unix wrapper (MacOS)
#

process_vendor_modules()
{

	find "$SCRIPTDIR/Vendors" -type d -name "Bin" | while read VENDORBIN
	do
		find "$VENDORBIN" -type f ! -name "SSQ__*.bin" -exec cp -a "{}" "$SCRIPTDIR/Bin/" \;

		# process OSARCH64-only daemons if OSARCH64 is defined

		if [ ! -z "$OSARCH64" ]
		then
			find "$VENDORBIN" -type f -name "SSQ__*__"$OSARCH64".bin" | while read VENDORCONFIG
			do
				VENDOREXECNAME="`basename "$VENDORCONFIG" | sed 's/^SSQ__//;s/__'$OSARCH64'.bin//'`"
				cp -a "$VENDORCONFIG" "$SCRIPTDIR/Bin/$VENDOREXECNAME"

				if [ "$1" = "chown" ]
				then
					chown root:$NOGROUP "$SCRIPTDIR/Bin/$VENDOREXECNAME"
					chmod 755 "$SCRIPTDIR/Bin/$VENDOREXECNAME"
				fi
			done
		fi

		# process also OSARCH32-only daemons

		find "$VENDORBIN" -type f -name "SSQ__*__"$OSARCH32".bin" | while read VENDORCONFIG
		do
			VENDOREXECNAME="`basename "$VENDORCONFIG" | sed 's/^SSQ__//;s/__'$OSARCH32'.bin//'`"
			if [ ! -e "$SCRIPTDIR/Bin/$VENDOREXECNAME" ]
			then
				cp -a "$VENDORCONFIG" "$SCRIPTDIR/Bin/$VENDOREXECNAME"

				if [ "$1" = "chown" ]
				then
					chown root:$NOGROUP "$SCRIPTDIR/Bin/$VENDOREXECNAME"
					chmod 755 "$SCRIPTDIR/Bin/$VENDOREXECNAME"
				fi
			fi
		done
	done

	# if there are "$SCRIPTDIR/Bin/*.vendor_install" scripts, execute them

	export VENDOR_INSTALL_SCRIPTDIR="$SCRIPTDIR"
	export VENDOR_INSTALL_MACHINE="$MACHINE"
	find "$SCRIPTDIR/Bin/" -type f -name "*.vendor_install" -exec sh '{}' \;

	# process license files from Vendors/*/Licenses

	find "$SCRIPTDIR/Vendors/" -type d -name "Licenses" | while read VENDORBIN
	do
		find "$VENDORBIN" -type f -name "*__SSQ.*" | while read LICFILE
		do
			# check if there is no daemon copied and delete the license with user warning

			DAEMONNAME="`basename "$LICFILE" | sed 's/__.*$//'`"

			DAEMONNUM=`find "$SCRIPTDIR/Bin/" -type f -name "$DAEMONNAME*" ! -name "*.keywords" ! -name "*.install" ! -name "*.uninstall" | wc -l`
			[ $DAEMONNUM -eq 0 ] && echo "Skipping $DAEMONNAME license: no daemon available for platform!" && continue

			cp -a "$LICFILE" "$SCRIPTDIR/Licenses/"

			# add vendor timestamp to Logs/.timestamps

			TIMESTAMP_MODULENAME="`$CANONICALIZE "$VENDORBIN/.."`"
                        TIMESTAMP_MODULENAME="`basename "$TIMESTAMP_MODULENAME"`"
			[ -e "$VENDORBIN/../.timestamp" ] && echo "$TIMESTAMP_MODULENAME `cat "$VENDORBIN/../.timestamp"`" >> "$SCRIPTDIR/Logs/.timestamps"
		done

	done

	# convert file to Unix encoding for further processing

	find "$SCRIPTDIR/Licenses/" -type f | while read LICFILE
	do
		$DOS2UNIX -q "$LICFILE"
	done
}

#  ============================================================================
#             Combine text-based license files per licensing system
#  ============================================================================

#
#  $1 - license system name
#  $2 - whether to unix2dos or not
#

combine_text_licenses()
{
	LICSYSNAME="$1"
	IS_UNIX2DOS="$2"

	# do sanity checks

	LICFILENUM=`find "$SCRIPTDIR/Licenses/" -name "*__"$LICSYSNAME"__*" | wc -l`
	[ $LICFILENUM -eq 0 ] && return

	# prepare keywods for spliiting the headers and bodies

	HEADER_KEYWORDS=""
	BODY_KEYWORDS=""

	for GREP_KEYWORD in `cat "$SCRIPTDIR/Bin/$LICSYSNAME.keywords"`
	do
		HEADER_KEYWORDS="$HEADER_KEYWORDS;/$GREP_KEYWORD/p"
		BODY_KEYWORDS="$BODY_KEYWORDS;/$GREP_KEYWORD/d"
	done

	# split every license file for selected license server system to header / body pair

	find "$SCRIPTDIR/Licenses/" -name "*__"$LICSYSNAME"__*" | while read LICFILENAME
	do
		if [ ! -z "$HEADER_KEYWORDS" ]
		then
			sed -n "$HEADER_KEYWORDS" "$LICFILENAME" >> "$SCRIPTDIR/Licenses/"$LICSYSNAME"_SSQ.lic.header"
			sed "$BODY_KEYWORDS" "$LICFILENAME" >> "$SCRIPTDIR/Licenses/"$LICSYSNAME"_SSQ.lic.body"
		else
			cat "$LICFILENAME" >> "$SCRIPTDIR/Licenses/"$LICSYSNAME"_SSQ.lic.body"
		fi
	done

	# parse header again with keywords to remove duplicates

	cat "$SCRIPTDIR/Bin/$LICSYSNAME.keywords" | while read GREP_KEYWORD
	do
		grep -e "$GREP_KEYWORD" "$SCRIPTDIR/Licenses/"$LICSYSNAME"_SSQ.lic.header" | sort -u >> "$SCRIPTDIR/Licenses/"$LICSYSNAME"_SSQ.lic.header_uniq"
	done

	# now concatenate fixed header and body and remove unnecesary files

	cat "$SCRIPTDIR/Licenses/"$LICSYSNAME"_SSQ.lic.header_uniq" "$SCRIPTDIR/Licenses/"$LICSYSNAME"_SSQ.lic.body" > "$SCRIPTDIR/Licenses/"$LICSYSNAME"_SSQ.lic"
	rm -f "$SCRIPTDIR/Licenses/"$LICSYSNAME"_SSQ.lic.header"
	rm -f "$SCRIPTDIR/Licenses/"$LICSYSNAME"_SSQ.lic.header_uniq"
	rm -f "$SCRIPTDIR/Licenses/"$LICSYSNAME"_SSQ.lic.body"

	# now delete initial licenses from Licenses/*_LICSYSNAME_*

	find "$SCRIPTDIR/Licenses/" -name "*__"$LICSYSNAME"__*" -delete

	[ "$IS_UNIX2DOS" = "true" ] && unix2dos -q "$SCRIPTDIR/Licenses/"$LICSYSNAME"_SSQ.lic"
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
#                       Install Auto-Loaded Service
#  ============================================================================

#
# install_service "<service-name>" "<service-file-name-noext>" "<forking>" command args ...
#

install_service()
{
	SERVICENAME="$1"
	SERVICEFILE="$2"
	FORKING="$3"
	SERVICEBIN="$4"

	case $MACHINE in
		MSYS_NT-*) # This is Windows

			# do nothing here
		;;

		Linux)	# This is Linux

			# append command line arguments

			[ ! -z "$5" ] &&  COMMANDLINE="$5"

			while true
			do
				[ ! -z "$6" ] && COMMANDLINE="$COMMANDLINE $6" && shift || break
			done

			# Detect init system

			INITSYSTEM="`detect_linux_init_system`"

			# Make systemd unit

			if [ "$INITSYSTEM" = "systemd" ]
			then
				[ "$FORKING" = "daemon" ] && SERVICE_TYPE="forking" || SERVICE_TYPE="simple"

				SERVICEPATH=
				[ -z "$SERVICEPATH" ] && [ -d /etc/systemd/system/ ] && SERVICEPATH="/etc/systemd/system/"
				[ -z "$SERVICEPATH" ] && [ -d /usr/lib/systemd/system/ ] && SERVICEPATH="/usr/lib/systemd/system/"

				cat > "$SERVICEPATH$SERVICEFILE.service" << UNILICSRVSSQ_SERVICE
[Unit]
Description=$SERVICENAME
After=network.target

[Service]
User=nobody
Group=$NOGROUP

ExecStart=$SERVICEBIN $COMMANDLINE

StartLimitInterval=120s
StartLimitBurst=5
Type=$SERVICE_TYPE
TimeoutStopSec=60s
TimeoutStartSec=60s

[Install]
WantedBy=multi-user.target
UNILICSRVSSQ_SERVICE

				chown root:root "$SERVICEPATH$SERVICEFILE.service"
				systemctl daemon-reload
				systemctl enable $SERVICEFILE.service

				for i in 1 2 3 4 5;
				do
					systemctl start $SERVICEFILE.service
					[ $? -eq 0 ] && break;
					sleep 1s
				done

				return 0
			fi

			# Make Upstart script

			if [ "$INITSYSTEM" = "upstart" ]
			then
				[ "$FORKING" = "daemon" ] && UPSTART_EXPECT="expect fork" || UPSTART_EXPECT=""

				cat > "/etc/init/$SERVICEFILE.conf" << UNILICSRVSSQ_CONF
# $SERVICENAME - start $SERVICENAME
 
description "$SERVICENAME"
author "team.solidsquad@gmail.com"
 
# When to start the service
start on runlevel [2345]
 
# When to stop the service
stop on runlevel [016]
 
# Specify fork type
$UPSTART_EXPECT

# Set the kill timeout
kill timeout 60

# Set user and group
setuid nobody
setgid $NOGROUP
 
# Start the process
exec $SERVICEBIN $COMMANDLINE
UNILICSRVSSQ_CONF

				chown root:root "/etc/init/$SERVICEFILE.conf"
				[ -x /lib/init/upstart-job ] && ln -s /lib/init/upstart-job /etc/init.d/$SERVICEFILE
				[ ! -z "`initctl help | grep enable`" ] && initctl enable $SERVICEFILE
				initctl reload-configuration

				for i in 1 2 3 4 5;
				do
					service $SERVICEFILE start
					[ $? -eq 0 ] && break;
					sleep 1s
				done

				return 0
			fi

			# Make OpenRC script

			if [ "$INITSYSTEM" = "openrc" ]
			then
				[ "$FORKING" = "daemon" ] && OPENRC_EXPECT="expect fork" || OPENRC_EXPECT="--background"

				OPENRCRUN="`which openrc-run`"

				cat > "/etc/init.d/$SERVICEFILE" << UNILICSRVSSQ_SCRIPT
#!$OPENRCRUN

name="$SERVICENAME"
description="start $SERVICENAME"

command="$SERVICEBIN"
command_args="$COMMANDLINE"
user="nobody"
group="$NOGROUP"

depend() {
    need localmount
    use net
}

start() {
    ebegin "Starting $SERVICENAME"
    start-stop-daemon --exec \${command} $OPENRC_EXPECT -u \${user} -g \${group} --start -- \${command_args}
    eend $?
}

stop() {
    ebegin "Stopping $SERVICENAME"
    start-stop-daemon --stop --exec \${command}
    eend $?
}
UNILICSRVSSQ_SCRIPT

				chown root:root "/etc/init.d/$SERVICEFILE"
				chmod 755 "/etc/init.d/$SERVICEFILE"
				rc-update add $SERVICEFILE default

				for i in 1 2 3 4 5;
				do
					"/etc/init.d/$SERVICEFILE" start
					[ $? -eq 0 ] && break;
					sleep 1s
				done

				return 0
			fi

			# Make SysV script

			if [ "$INITSYSTEM" = "sysv" ]
			then
				[ "$FORKING" = "daemon" ] && SYSV_EXPECT="expect fork" || SYSV_EXPECT="--background"

				cat > "/etc/init.d/$SERVICEFILE" << UNILICSRVSSQ_SCRIPT
#!/bin/sh

### BEGIN INIT INFO
# Provides:          $SERVICEFILE
# Required-Start:    $local_fs $network
# Required-Stop:     $local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: $SERVICENAME
# Description:       $SERVICENAME service
### END INIT INFO

#
# chkconfig: 35 90 12
# description: start $SERVICENAME
#

command="$SERVICEBIN"
command_args="$COMMANDLINE"
user="nobody"
group="$NOGROUP"

# Start the service $SERVICENAME
start() {
        echo "Starting $SERVICENAME..."
        start-stop-daemon --exec \${command} $SYSV_EXPECT -u \${user} -g \${group} --start -- \${command_args}
        return $?
}

# Stop the service $SERVICENAME
stop() {
        echo "Stopping $SERVICENAME..."
        start-stop-daemon --stop --exec \${command}
        return $?
}

### main logic ###
case "\$1" in
  start)
        start
        ;;
  stop)
        stop
        ;;
  status)
        status $SERVICENAME
        ;;
  restart|reload|condrestart)
        stop
        start
        ;;
  *)
        echo $"Usage: \$0 {start|stop|restart|reload|status}"
        exit 1
esac

exit 0
UNILICSRVSSQ_SCRIPT

				chown root:root "/etc/init.d/$SERVICEFILE"
				chmod 755 "/etc/init.d/$SERVICEFILE"
				update-rc.d $SERVICEFILE defaults

				for i in 1 2 3 4 5;
				do
					"/etc/init.d/$SERVICEFILE" start
					[ $? -eq 0 ] && break;
					sleep 1s
				done

				return 0
			fi

			# The init system is not supported

			echo "Init system \"$INITSYSTEM\" is not supported! Exiting..."
			return 1
		;;
		Darwin)	# This is MacOS

			# append command line arguments

			PLISTCMD="<string>$SERVICEBIN</string>"
			[ ! -z "$5" ] && PLISTCMD="$PLISTCMD<string>$5</string>"

			while true
			do
				[ ! -z "$6" ] && PLISTCMD="$PLISTCMD<string>$6</string>" && shift || break
			done

			# populate proper arguments to plist

			echo "<?xml version='1.0' encoding='UTF-8'?><!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">" > /Library/LaunchDaemons/org.solidsquad.$SERVICEFILE.plist
			echo "<plist version='1.0'><dict><key>Label</key><string>org.solidsquad.$SERVICEFILE.plist</string><key>ProgramArguments</key><array>" >> /Library/LaunchDaemons/org.solidsquad.$SERVICEFILE.plist
			echo "$PLISTCMD</array><key>RunAtLoad</key><true/></dict></plist>" >> /Library/LaunchDaemons/org.solidsquad.$SERVICEFILE.plist

			launchctl load -w /Library/LaunchDaemons/org.solidsquad.$SERVICEFILE.plist
		;;
		*)	echo "$MACHINE is not supported! Exiting..."
			exit 1
		;;
	esac
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
				service $SERVICEFILE stop
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

		# find OS architecture based on batch file hack

		if [ "$OSARCH" = "AMD64" ]
		then
			OSARCH64="windows64"
			OSARCH32="windows32"
		else
			OSARCH64=""
			OSARCH32="windows32"
		fi

		# set not to chown() the folders

		USE_CHOWN="nochown"

		# set unix2dos

		IS_UNIX2DOS="true"

		;;
	Linux)	# This is Linux

		# Greet the user

		echo
		echo "Unified License Server Installer by TeAM SolidSQUAD-SSQ"
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

		which $DOS2UNIX 1>/dev/null 2>&1 
		[ $? -eq 1 ] && DOS2UNIX="osx_dos2unix"

		# find if nobody group exist

		NOGROUP=$( groups nobody | cut -d ' ' -f 3 )

		# change nobody's shell to /bin/sh

		usermod -s /bin/sh nobody

		# find OS architecture

		OSARCH="`uname -i`"

		[ "`expr substr $OSARCH 1 1`" != "x" ] && [ "`expr substr $OSARCH 1 1`" != "i" ] && OSARCH="`uname -m`"

		if [ "$OSARCH" = "x86_64" ]
		then
			OSARCH64="linux64"
			OSARCH32="linux32"
		else
			OSARCH64=""
			OSARCH32="linux32"
		fi

		# set chown() the folders

		USE_CHOWN="chown"

		# set unix2dos

		IS_UNIX2DOS="false"

		;;
	Darwin)	# This is MacOS

		# Greet the user

		echo
		echo "Unified License Server Installer by TeAM SolidSQUAD-SSQ"
		echo

		# Check if we are root user - otherwise call self with sudo and terminate

		if [ "`id -un`" != "root" ];
		then
			sudo sh "$0" "$*"
			exit 1
		fi

		# define OSX wrappers for GNU stuff

		CANONICALIZE="osx_canonicalize"
		DOS2UNIX="osx_dos2unix"

		# set NOGROUP

		NOGROUP="wheel"

		# find OS architecture

		OSARCH="`uname -m`"

		if [ "$OSARCH" = "x86_64" ]
		then
			OSARCH64="macos64"
			OSARCH32="macos32"
		else
			OSARCH64=""
			OSARCH32="macos32"
		fi

		# set chown() the folders

		USE_CHOWN="chown"

		# set unix2dos

		IS_UNIX2DOS="false"

		;;
	*)	echo "$MACHINE is not supported! Exiting..."
		exit 1
		;;
esac

# find the script directory

[ -z "$SCRIPTDIR" ] && SCRIPTDIR="`$CANONICALIZE "$0"`"
SCRIPTDIR="`dirname "$SCRIPTDIR"`"

# check presence of Vendors

[ ! -d "$SCRIPTDIR/Vendors" ] && echo "Cannot find Vendors folder in the script location! Exiting..." && exit 1

# uninstall old servers first

if [ -d "$SCRIPTDIR/Bin" ] 
then
	for VENDORUNINSTALLER in `find "$SCRIPTDIR/Bin/" -type f -name "*.uninstall"`
	do
		. "$VENDORUNINSTALLER"
	done
fi

# Remove everything from Bin / Licenses / Logs folder

create_folder_structures $USE_CHOWN

# process vendor configs

process_vendor_modules $USE_CHOWN

# look for text-based license file keywords and combine licenses

find "$SCRIPTDIR/Bin/" -type f -name "*.keywords" | while read VENDORKEYWORD
do
	LICSYSNAME="`basename "$VENDORKEYWORD" | sed 's/\..*$//'`"
	combine_text_licenses "$LICSYSNAME" "$IS_UNIX2DOS"
	rm -f "$VENDORKEYWORD"
done

# now install the new servers

for VENDORINSTALLER in `find "$SCRIPTDIR/Bin/" -type f -name "*.install"`
do
	. "$VENDORINSTALLER"
done

# Report success

exit 0