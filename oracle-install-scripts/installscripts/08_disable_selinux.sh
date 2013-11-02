#!/bin/bash

FILE=/etc/selinux/config
BACKUP=$FILE.bak.$$

# Why grep when you can just run it?
. $FILE

if [ "$SELINUX" == "" ]; then
    echo Unable to determine SELINUX state.
    echo Please edit $FILE before continuing
fi
if [ "$SELINUXTYPE" == "" ]; then
    echo Unable to determine SELINUX type.
    echo Please edit $FILE before continuing
fi
#echo SELINUX: $SELINUX
#echo SELINUXTYPE: $SELINUXTYPE


# three possibilities:
# 1: Enforcing - we'll need to change it
# 2: Permissive - should be OK
# 3: Disabled - definitely OK

# going backwards
if [ "$SELINUX" == "disabled" ]; then
    echo SELINUX is disabled.
    echo No need to change it.
    exit
fi

if [ "$SELINUX" == "permissive" ]; then
    echo SELINUX is set to permissive
    echo No need to change it.
    exit
fi

# if we get here we're going to need a backup file
echo BACKUP file: $BACKUP

if [ -e $BACKUP ]; then
    echo $BACKUP already exists. This should not happen!
    ls -l $FILE $BACKUP
    echo "Please run script again"
    exit
fi

# this is basically the fall through case.
# i.e. Possibility #1 above

mv $FILE $BACKUP
sed -e 's/SELINUX=enforcing/SELINUX=permissive/' $BACKUP > $FILE

if [ -e $BACKUP ]; then
    echo '===================================='
    echo '|           OLD file               |'
    echo '===================================='
    cat $BACKUP
fi

echo '===================================='
echo '|           NEW file               |'
echo '===================================='
cat $FILE

