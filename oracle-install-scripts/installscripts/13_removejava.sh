#!/bin/bash

. `dirname $0`/osver.sh

if [ "$OS_VER" == "5" ]; then
    rpm -e java-1.4.2-gcj-compat-1.4.2.0-40jpp.115 gjdoc-0.7.7-12.el5.x86_64 antlr-2.7.6-4jpp.2.x86_64

elif [ "$OS_VER" == "6" ]; then
    #rpm -e java-1.6.0-openjdk-1.6.0.0-1.43.1.10.6.el6_2.x86_64
    yum -y remove java-1.6.0-openjdk java-1.5.0-gcj
fi

