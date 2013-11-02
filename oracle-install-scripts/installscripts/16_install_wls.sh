#!/bin/bash

. `dirname $0`/settings.sh

if [ "$JAVA_HOME" == "" ]; then
    echo JAVA_HOME not set. Log out and back in?
    exit
fi

COMPONENTS=(
"WebLogic Server/Core Application Server"
"WebLogic Server/Administration Console"
"WebLogic Server/Configuration Wizard and Upgrade Framework"
"WebLogic Server/Web 2.0 HTTP Pub-Sub Server"
"WebLogic Server/WebLogic JDBC Drivers"
"WebLogic Server/Third Party JDBC Drivers"
"WebLogic Server/WebLogic Server Clients"
"WebLogic Server/WebLogic Web Server Plugins"
"WebLogic Server/UDDI and Xquery Support"
"Oracle Coherence/Coherence Product Files"
)

#NUMCOMPONENTS=${#COMPONENTS[@]}
#echo Installing $NUMCOMPONENTS components of WebLogic server

SAVE_IFS=$IFS
IFS="|"
CSTRING="${COMPONENTS[*]}"
IFS=$SAVE_IFS

#echo $CSTRING

TEMPFILE=/tmp/$$.xml
cat > $TEMPFILE <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<bea-installer> 
  <input-fields>
      <data-value name="BEAHOME"         value="$FMW_LOCATION" />
      <data-value name="WLS_INSTALL_DIR" value="$FMW_LOCATION/wlserver_10.3" />
      <!--data-value name="COMPONENT_PATHS" value="WebLogic Server/Core Application Server|WebLogic Server/Administration Console|WebLogic Server/Configuration Wizard and Upgrade Framework|WebLogic Server/Web 2.0 HTTP Pub-Sub Server|WebLogic Server/WebLogic JDBC Drivers|WebLogic Server/Third Party JDBC Drivers|WebLogic Server/WebLogic Server Clients|WebLogic Server/WebLogic Web Server Plugins|WebLogic Server/UDDI and Xquery Support"/-->
      <data-value name="COMPONENT_PATHS" value="$CSTRING"/>
      <data-value name="USE_EXTERNAL_ECLIPSE"           value="false" />
      <data-value name="INSTALL_NODE_MANAGER_SERVICE"   value="yes"  />
      <data-value name="NODEMGR_PORT"                   value="5559" />
      <data-value name="INSTALL_SHORTCUT_IN_ALL_USERS_FOLDER"   value="yes"/>
      <!--
      <data-value name="LOCAL_JVMS"value="D:\jrockit_160_05|D:\jdk160_05"/>
      -->

   </input-fields> 
</bea-installer>

EOF

#cat $TEMPFILE
#rm -i $TEMPFILE
#exit

java -jar $INSTALLER_LOCATION/wls/10.3.6/wls_generic.jar -mode=silent -silent_xml=$TEMPFILE
