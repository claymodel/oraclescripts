#!/bin/bash

# need to determine whether we're on OEL5 or OEL6
. `dirname $0`/osver.sh

#upgrade any packages
yum -y update


# this is so that we can install the VirtualBox extensions
# but it also gets us UEK (the enhanced kernel)
yum -y install kernel*

# and everyone NEEDS a compiler
yum -y install gcc
yum -y install glibc
yum -y install glibc-devel
yum -y install glibc-headers
yum -y install libaio
yum -y install libaio-devel
yum -y install unixODBC-devel
yum -y install libstdc++-devel
yum -y install elfutils-libelf-devel
yum -y install ksh

yum -y install Xorg
yum -y install xorg-x11-utils
yum -y install gnome-panel
yum -y install nautilus
yum -y install gnome-terminal
yum -y install firefox

# if you make me use nothing but vi I'll probably hunt you down and
# beat you to a bloody pulp with the install CD
yum -y install emacs

# slight differences between Oracle 5 and 6
if [ "$OS_VER" == "5" ]; then
    yum -y install gnome-session
    yum -y install vnc-server

    # this installs all of the dependencies for the DB
    yum -y install oracle-validated
elif [ $"$OS_VER" == "6" ]; then

    # you may also need the 32 bit flavors for some products
    # I found this out when installing OID 11.1.1.6 on OL 6
    yum -y install glibc-devel.i686

    yum -y install tigervnc-server

    yum -y install compat-libstdc++-33

    # this installs all of the dependencies for the DB 11g R2
    yum -y install oracle-rdbms-server-11gR2-preinstall
else
    echo "Update the script"
fi

echo You should probably reboot now to pick up the new kernel
