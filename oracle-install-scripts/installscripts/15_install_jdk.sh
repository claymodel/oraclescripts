#!/bin/bash

. `dirname $0`/settings.sh

cd ~

# I should pick the version from settings.sh
$INSTALLER_LOCATION/jdk/jdk-6u32-linux-x64.bin 
