#!/bin/bash

. `dirname $0`/settings.sh

#echo ORA USER: $ORA_USER

echo Creating groups
/usr/sbin/groupadd oinstall
/usr/sbin/groupadd dba

echo Creating $ORA_USER
/usr/sbin/useradd -g oinstall -G dba -d $USER_HOME $ORA_USER
echo $ORA_PASS | passwd --stdin $ORA_USER

