#!/bin/sh
#
# checkstat.sh -- check minivend daemon status, and restart if not there
# 

####  EDIT THIS!  ########
####      |       ########  This belongs in the crontab of MVENDUSER
####      V       ########

MVENDUSER=minivend
MVENDHOME=/home/minivend
RESTART=$MVENDHOME/bin/restart

# Uncomment this line for SYSV systems
# IRIX, Solaris, HP-UX, etc.
#MINIVEND=`ps -ef | grep "^$MVENDUSER.*minivend" | grep -v 'grep\|checkstat'`

# Uncomment this line for BSD-like systems
# works for BSD, Linux, SunOS, ?Digital UNIX?
MINIVEND=`ps -waxu | grep "^$MVENDUSER.*minivend" | grep -v 'grep\|checkstat'`

####      ^       ########
####      |       ########
####  EDIT THIS!  ########

# END CONFIGURABLE VARIABLES

if test -n "$MINIVEND"
then
	rm -f $MVENDHOME/bin/mv_failed
else 

	if test ! -f $MVENDHOME/bin/mv_failed
	then
	touch $MVENDHOME/bin/mv_failed
	cat <<EOF
ALERT: MINIVEND SERVER IS DOWN!

The latest check of the MiniVend server indicates it is not
running.

We will try to restart the server now, but if there are
still problems, do a manual restart.

To manually restart the server, log in as the minivend
user and do:

	$RESTART

EOF
	$RESTART
	fi

fi
