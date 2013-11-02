#!/bin/bash

. `dirname $0`/settings.sh

ORAENV_ASK=NO
ORACLE_SID=orcl

export ORAENV_ASK
export ORACLE_SID


if [ -e /usr/local/bin/oraenv ]; then
    ENVSCRIPT=/usr/local/bin/oraenv
elif [ -e $USER_HOME/bin/oraenv ]; then
    ENVSCRIPT=$USER_HOME/bin/oraenv
elif [ -e $ORADB_LOCATION/product/11.2.0/dbhome_1/bin/oraenv ]; then
    ENVSCRIPT=$ORADB_LOCATION/product/11.2.0/dbhome_1/bin/oraenv
else
    echo Cannot find oraenv script
    exit 1
fi

# I put the oraenv script's path in $PATH before anything else
# I think this is right and sensible
export PATH=`dirname $ENVSCRIPT`:$PATH
#echo PATH: $PATH

echo running oraenv from $ENVSCRIPT
. $ENVSCRIPT

cat | sqlplus sys/ABcd1234@orcl as sysdba <<EOF
alter system set processes=500 scope=spfile;
alter system set open_cursors=800 scope=spfile;
shutdown immediate
quit
EOF

echo sleeping 5 seconds
sleep 5

echo starting DB up again
/etc/init.d/oracle start

#cat | sqlplus sys/ABcd1234 as sysdba <<EOF
#startup
#EOF
