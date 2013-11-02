#!/usr/bin/ksh
set +x

# Copyright (c) 2007-2008
# Filename:  	kill_blocker_session.sh
# Author:     	Zhang Hua

# Copyright (c) 2007-2008
# Filename:  	kill_blocker_session.sh
# Author:     	Zhang Hua
# Version:      V4.1
# History:	
#     2012-09-21	Zhang Hua 	V4.1.0	Update
#          1. ×÷Îª Wrapper ½Å±¾
#     2013-02-06	Zhang Hua 	V4.1.0	Review
#
##################################################################################################


DIR_HOME=$(cd "$(dirname "$0")/../.."; pwd)
DIR_SCRIPT_BIN=$DIR_HOME/scripts/kbs


version=`echo "select 'version='||version from v\\\$instance;"|sqlplus -s "/as sysdba"| awk '{if(NF>0 && substr($1,1,8)=="version=")print substr($1,9)}'`

if [[ "$version" == "" ]];then
  exit 1;
fi

if [[ `echo "$version"|awk '{print NF}'` -gt 1 ]];then
  exit 1;
fi

if [[ `echo "$version"|awk '{print NF}' FS='.'` -lt 2 ]]; then
  exit 1;
fi

main_version=`echo "$version"|awk '{print $1}' FS='.'`
if [[ "$main_version" == "9" ]]; then
  $DIR_SCRIPT_BIN/do_kbs_9i.sh
elif [[ "$main_version" == "10" || "$main_version" == "11" ]];then
  $DIR_SCRIPT_BIN/do_kbs_11g.sh
fi

