#!/bin/bash

. `dirname $0`/settings.sh

mkdir $ORADB_LOCATION
chown -R $ORA_USER:oinstall $ORADB_LOCATION
chmod -R 775 $ORADB_LOCATION

cat >> $USER_HOME/.bash_profile <<EOF
umask 022
ORACLE_BASE=$ORADB_LOCATION
ORACLE_SID=orcl
export ORACLE_BASE ORACLE_SID

EOF

chown $ORA_USER.oinstall $USER_HOME/.bash_profile


