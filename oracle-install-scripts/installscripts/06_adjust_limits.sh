#!/bin/bash

. `dirname $0`/settings.sh

# need to determine whether we're on OEL5 or OEL6
. `dirname $0`/osver.sh

if [ "$OS_VER" == "5" ]; then
    echo The oracle-validated package takes care of MOST of this for you

elif [ $"$OS_VER" == "6" ]; then
    echo The oracle-rdbms-server-11gR2-preinstall package takes care of MOST of this for you
fi


if [ "$ORA_USER" != "oracle" ]; then
    echo "Database will not be installed as oracle."
    echo "Limits need to be adjusted for $ORA_USER."

    cat >> /etc/security/limits.conf <<EOF
$ORA_USER           soft    nproc   2047
$ORA_USER           hard    nproc   16384
$ORA_USER           soft    nofile  1024
$ORA_USER           hard    nofile  65536
EOF

fi
