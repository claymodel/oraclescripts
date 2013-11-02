#!/bin/bash

. `dirname $0`/settings.sh

echo VNC Password: $VNC_PASS
echo Oracle user: $ORA_USER

umask 077

if [ -e $USER_HOME/.vnc/passwd ]; then
    echo "VNC password file already exists for $ORA_USER"
else
    echo "Making VNC password file for $ORA_USER"
    mkdir $USER_HOME/.vnc
    echo $VNC_PASS | vncpasswd -f > $USER_HOME/.vnc/passwd
    chown -R $ORA_USER $USER_HOME/.vnc
    ls -la $USER_HOME/.vnc
fi

if [ -e /etc/sysconfig/vncservers.bak ]; then
    echo /etc/sysconfig/vncservers already exists
    ls -l /etc/sysconfig/vncservers*
    exit
fi

cp /etc/sysconfig/vncservers /etc/sysconfig/vncservers.bak

cat >> /etc/sysconfig/vncservers <<EOF

VNCSERVERS="1:$ORA_USER"
#VNCSERVERARGS[1]="-geometry 1024x768"
VNCSERVERARGS[1]="-geometry 1280x1024"
EOF

chkconfig --level 345 vncserver on
chkconfig --list vncserver

service vncserver start

# now add it to avahi if it's installed
if [ -d /etc/avahi/services ]; then 
    echo Avahi seems to be installed.
    if [ -e /etc/avahi/services/rfb.service ]; then
	echo /etc/avahi/services/rfb.service already exists
    else
	cat > /etc/avahi/services/rfb.service <<EOF
<?xml version="1.0" standalone='no'?>  
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">  
<service-group>  
  <name replace-wildcards="yes">%h</name>  
  <service>  
    <type>_rfb._tcp</type>  
    <port>5901</port>  
  </service>  
</service-group>  
EOF
    fi

    # I used to just reload but often Avahi isn't running in the first
    # place.  The right way to do this would be to detect whether
    # Avahi is running (via "service avahi-daemon status") but it's
    # just as easy to stop and start it.  The stop may fail but the
    # start should succeed.
    #service avahi-daemon reload
    
    service avahi-daemon stop
    service avahi-daemon start
fi
