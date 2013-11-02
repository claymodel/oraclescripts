# this script is intended to be used by the other ones.
# don't run it directly!

# what user?
ORA_USER=fmwuser
ORA_PASS=ABcd1234

USER_HOME=/space/$ORA_USER

# where do you want the database
ORADB_LOCATION=$USER_HOME/database

# and the FMW location
FMW_LOCATION=$USER_HOME/middleware

VNC_PASS=ABcd1234

# Temporary workspace
# "small" files (like generated rsp files and the like) go in /tmp
# larger items (like unzipped installers) go in this directory
WORKSPACE=~/installbits


# These settings are related to stuff on my environment
INSTALLER_LOCATION=~/installers
VERSION_TO_INSTALL=rc3

DB_HOST=localhost
DB_PORT=1521
DB_SID=orcl

# this is for the RCU:
CONNECT_STRING=$DB_HOST:$DB_PORT:$DB_SID
SCHEMA_PREFIX=DEV

# WebLogic
WLSVERSION=10.3.6

# OUD bits
OUD_HOME=$FMW_LOCATION/Oracle_OUD

#OUD settings
OUD_INSTANCE_BASEDN="dc=oracleateam,dc=com"
OUD_INSTANCE_ROOTDN="cn=Directory Manager"
OUD_INSTANCE_ROOTPW="ABcd1234"

OUD_INSTANCE_LOAD_SAMPLE_USERS=TRUE
OUD_INSTANCE_NUM_SAMPLE_USERS=100

OUD_INSTANCE_LDAPPORT=1389
OUD_INSTANCE_ADMINPORT=4444
OUD_INSTANCE_JMXPORT=1689


# IAM bits
IAM_HOME=$FMW_LOCATION/Oracle_IAM

IAM_DOMAIN_LOCATION=$FMW_LOCATION/user_projects/domains/OAMDomain
OAM_DOMAIN_ADMINSERVER_PORT=7010


# Web Tier
#/home/cmjohnso/installers/webtier/11.1.1.6/webtier.zip
WEBTIER_ZIP_LOCATION=$INSTALLER_LOCATION/webtier/11.1.1.6/webtier.zip

WEBTIER_HOME=$FMW_LOCATION/Oracle_WT
WEBTIER_INSTANCE_NAME=instance1
WEBTIER_INSTANCE_LOCATION=$WEBTIER_HOME/instances/instance1
WEBTIER_OHS_COMPONENT_NAME=ohs1

# WebGates bits
WEBGATE_HOME=$FMW_LOCATION/Oracle_OAMWebGate

# OES bits
OESCLIENE_HOME=$FMW_LOCATION/Oracle_OESClient
