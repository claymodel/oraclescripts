#!/bin/bash

. `dirname $0`/settings.sh

if [ "$JAVA_HOME" == "" ]; then
    echo JAVA_HOME not set. Log out and back in?
    exit
fi

cd $USER_HOME

if [ -e rcuHome ]; then
    echo rcuHome exists.
else
    mkdir rcuHome
    cd rcuHome
    unzip -q $INSTALLER_LOCATION/$VERSION_TO_INSTALL/rcuHome.zip
fi
