#!/bin/bash

. `dirname $0`/settings.sh
. `dirname $0`/utils.sh


check_not_root

check_workspace

# PRODUCTDIR is where we'll find the unzipped Disk1/runinstaller
PRODUCTDIR=database
PRODUCTZIPS=linux.x64_11gR2_database_*

prep_productbits

goto_runinstaller_location

TEMPFILE=/tmp/$$.rsp

cat > $TEMPFILE <<EOF
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v11_2_0
oracle.install.option=INSTALL_DB_AND_CONFIG
ORACLE_HOSTNAME=localhost
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=$USER_HOME/oraInventory
SELECTED_LANGUAGES=en
ORACLE_HOME=$ORADB_LOCATION/product/11.2.0/dbhome_1
ORACLE_BASE=$ORADB_LOCATION
oracle.install.db.InstallEdition=EE
oracle.install.db.EEOptionsSelection=false
oracle.install.db.optionalComponents=
oracle.install.db.DBA_GROUP=dba
oracle.install.db.OPER_GROUP=dba
oracle.install.db.CLUSTER_NODES=
oracle.install.db.isRACOneInstall=false
oracle.install.db.racOneServiceName=
oracle.install.db.config.starterdb.type=GENERAL_PURPOSE
oracle.install.db.config.starterdb.globalDBName=$DB_SID
oracle.install.db.config.starterdb.SID=$DB_SID
oracle.install.db.config.starterdb.characterSet=AL32UTF8
oracle.install.db.config.starterdb.memoryOption=true
oracle.install.db.config.starterdb.memoryLimit=2285
oracle.install.db.config.starterdb.installExampleSchemas=true
oracle.install.db.config.starterdb.enableSecuritySettings=true
oracle.install.db.config.starterdb.password.ALL=$ORA_PASS
oracle.install.db.config.starterdb.password.SYS=$ORA_PASS
oracle.install.db.config.starterdb.password.SYSTEM=$ORA_PASS
oracle.install.db.config.starterdb.password.SYSMAN=$ORA_PASS
oracle.install.db.config.starterdb.password.DBSNMP=$ORA_PASS
oracle.install.db.config.starterdb.control=DB_CONTROL
oracle.install.db.config.starterdb.gridcontrol.gridControlServiceURL=
oracle.install.db.config.starterdb.automatedBackup.enable=false
oracle.install.db.config.starterdb.automatedBackup.osuid=
oracle.install.db.config.starterdb.automatedBackup.ospwd=
oracle.install.db.config.starterdb.storageType=FILE_SYSTEM_STORAGE
oracle.install.db.config.starterdb.fileSystemStorage.dataLocation=$ORADB_LOCATION/oradata
oracle.install.db.config.starterdb.fileSystemStorage.recoveryLocation=
oracle.install.db.config.asm.diskGroup=
oracle.install.db.config.asm.ASMSNMPPassword=
MYORACLESUPPORT_USERNAME=
MYORACLESUPPORT_PASSWORD=
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false
DECLINE_SECURITY_UPDATES=true
PROXY_HOST=
PROXY_PORT=
PROXY_USER=
PROXY_PWD=
PROXY_REALM=
COLLECTOR_SUPPORTHUB_URL=
oracle.installer.autoupdates.option=SKIP_UPDATES
oracle.installer.autoupdates.downloadUpdatesLoc=
AUTOUPDATES_MYORACLESUPPORT_USERNAME=
AUTOUPDATES_MYORACLESUPPORT_PASSWORD=
EOF

./runInstaller -silent -responseFile $TEMPFILE -waitforcompletion
