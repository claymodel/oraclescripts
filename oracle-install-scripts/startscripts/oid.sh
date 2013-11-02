#!/bin/sh
#
# oracle Init file for starting and stopping
# Oracle Internet Directory and/or Virtual Directory 11g.
#
# chkconfig: 345 81 29
# description: OID/OVD startup script

# Author: Chris Johnson (christopher.johnson@oracle.com)

# Please Note that this was written for my own purposes. It may or may
# not work in your environment.

# When you install this scroll down and edit the environment variables
# below to match up with your environment.

# IMPORTANT NOTE:
# this script should be placed somewhere in ~oracle and then
# HARD LINKED to files named oid.sh and ovd.sh you MUST use hard
# links rather than soft links so that it can detect which component
# you are trying to start from /etc/init.d

# Then you should symlink /etc/init.d/oid and /etc/init.d/ovd to that file
#
# The script will do all of this for you if you run it as root with
# the makelinks option

ORACLE_OWNER=oracle

# if you run this script as root (for example during system boot or shutdown)
# the only thing we should to honor is start or stop

# set some variables
if [ "$USER" == "root" ] ; then
    SCRIPT=$(readlink -f $0)
    SCRIPTPATH=`dirname $SCRIPT`

    su - $ORACLE_OWNER -c "$SCRIPT $1"
    
    if [ "$1" == "makelinks" ]; then
	cd /etc/init.d
	if [ ! -e oid ]; then
	    echo Creating symlink for /etc/init.d/oid
	    ln -s $SCRIPTPATH/oid.sh oid
	fi
	if [ ! -e ovd ]; then
	    echo Creating symlink for /etc/init.d/ovd
	    ln -s $SCRIPTPATH/ovd.sh ovd
	fi
    fi

    if [ "$1" == "register" ]; then
	chkconfig --add oid
	chkconfig --add ovd
    fi
    exit
fi

# this should get moved into some common place
ORACLE_BASE=~/database
ORACLE_SID=orcl
ORACLE_HOME=~/database/product/11.2.0/dbhome_1
ORAENV_ASK=NO
export ORACLE_BASE ORACLE_SID ORACLE_HOME ORAENV_ASK
. /usr/local/bin/oraenv > /dev/null

ORACLE_INSTANCE=~/Oracle/Middleware/asinst_1
export ORACLE_INSTANCE


# if the script is invoked as "oid" then set the ports to OID values
case "$0" in
*oid*)
    echo OID selected
    COMPONENT=oid
    DIRLISTENPORT=3060
    DIRBASE="dc=oracleateam,dc=com"
    DIRADMINDN="cn=orcladmin"
    DIRADMINPASSWORD="ABcd1234"
    ;;
*ovd*)
    COMPONENT=ovd
    DIRLISTENPORT=6501
    DIRBASE="dc=oracleateam,dc=com"
    DIRADMINDN="cn=orcladmin"
    DIRADMINPASSWORD="ABcd1234"
    ;;
*)
    echo "Unknown component"
    ;;
esac

##### DO NOT EDIT BELOW HERE #####
##################################

PATH=$ORACLE_INSTANCE/bin:$ORACLE_HOME/ldap/bin:$ORACLE_HOME/bin:$PATH
export PATH

if [ -f /lib/lsb/init-functions ]
then
        . /lib/lsb/init-functions
elif [ -f /etc/init.d/functions ]
then
        . /etc/init.d/functions
fi

usage()
{
   echo "Usage (as root):"
   echo "  $0 {start|stop|makelinks|register}"
   echo "Usage (as $ORACLE_OWNER):"
   echo "  $0 {start|stop|restart|shell|status|ping|modify}"
   echo "  $0 search <search string>"
   echo "  $0 search <search base> <search string>"
   exit 2
}

start() 
{
    echo "Starting $COMPONENT..."

    opmnctl start
    if [ "$COMPONENT" == "oid" ] ; then
	IASCOMPONENT=oid1
    fi
    if [ "$COMPONENT" == "ovd" ] ; then
	IASCOMPONENT=ovd1
    fi
    #opmnctl startproc ias-component=oid1
    opmnctl startproc ias-component=$IASCOMPONENT

    echo "sleeping 10 seconds to allow startup"
    sleep 10

    ret=1
    while [ "$ret" -ne "0" ]; do
	opmnctl status
	
	echo "Searching LDAP directory"
	ldapping
	ret=$?

	if [ "$ret" -ne "0" ]; then
	    echo "LDAP search failed."
	    echo "sleeping 5 more seconds"
	    sleep 5
	fi
    done
    echo "OID LDAP listener is now running and accessible."
    
    
}

ldapping()
{
    echo "Searching LDAP directory"
    ldapsearch -b $DIRBASE -h localhost -p $DIRLISTENPORT -D $DIRADMINDN -w $DIRADMINPASSWORD $DIRADMINDN dn
    return $?
}

search()
{
    echo "Searching LDAP directory with command line options:"

    if [ "$2" != "" ]; then
	SEARCHBASE=$1
	SEARCHSTRING=$2
    else
	SEARCHBASE=$DIRBASE
	SEARCHSTRING=$1
    fi

    echo "Searching directory."
    echo "  base: $SEARCHBASE"
    echo "string: $SEARCHSTRING"
    ldapsearch -b $SEARCHBASE -h localhost -p $DIRLISTENPORT -D $DIRADMINDN -w $DIRADMINPASSWORD $SEARCHSTRING
}

modify()
{
    echo "Executing LDAP modify"
    ldapmodify -h localhost -p $DIRLISTENPORT -D $DIRADMINDN -w $DIRADMINPASSWORD -a -c
}

stop()
{
    echo "Stopping Oracle Internet Directory..."

    opmnctl stopall
    echo "sleeping 10 seconds to allow complete shutdown"
    sleep 10
    opmnctl status

}

status()
{
    opmnctl status
}

makelinks()
{
#    if [ "$USER" == "$ORACLE_OWNER" ] ; then

    # this really only gets run as the $ORACLE_OWNER
    SCRIPT=$(readlink -f $0)
    SCRIPTPATH=`dirname $SCRIPT`
    echo script name is $SCRIPT
    echo script path is $SCRIPTPATH
    pushd $SCRIPTPATH > /dev/null
    echo Scripts are actually located in $PWD
    if [ ! -e oid.sh ]; then
	echo Creating hard link for oid.sh
	ln $SCRIPT oid.sh
    fi
    if [ ! -e ovd.sh ]; then
	echo Creating hard link for ovd.sh
	ln $SCRIPT ovd.sh
    fi
    popd -n > /dev/null
}

#### End of functions, beginning of main()

case "$1" in
 "")
     usage
     ;;

 "start")
     start
     ;;

 "stop")
     stop
     ;;

 "restart")
     stop
     start
     ;;

 "status")
     status
     ;;

 "ping")
     ldapping
     ;;

 "shell")
     echo Starting shell...
     bash -
     ;;

 "search")
     echo LDAP Search selected from command line
     search $2 $3
     ;;

 "modify")
     echo LDAP Modify selected from command line
     modify
     ;;

  "makelinks")
     echo makelinks selected from command line
     makelinks
     ;;
esac
