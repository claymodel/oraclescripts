#!/bin/sh

HH=`date +"%H"`
MI=`date +"%M"`
MO=`expr $MI / 30`

#if [[ "$HH" != "00" || "$MO" != "1" ]];then exit; fi
#lines=0
#minutes=1440

if [[ "$MI" != "07" && "$MI" != "37" ]];then exit; fi
lines=0
minutes=30

DIR_HOME=$(cd "$(dirname "$0")/../.."; pwd)
DIR_SCRIPT_BIN=$DIR_HOME/scripts/ora_sp
DIR_BASE=$DIR_HOME/tmp/ora_sp

cd $DIR_SCRIPT_BIN

if [[ -f ~/.bash_profile ]];then
   . ~/.bash_profile
elif [[ -f ~/.profile ]];then
   . ~/.profile
fi

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
  perl generate_formated_statspack_files.pl $lines $minutes $DIR_BASE
elif [[ "$main_version" == "10" || "$main_version" == "11" ]];then
  perl generate_formated_awrrpt_files.pl $lines $minutes $DIR_BASE
fi

exit 0;  
