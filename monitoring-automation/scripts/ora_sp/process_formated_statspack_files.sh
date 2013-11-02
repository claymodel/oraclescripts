#!/bin/sh

if [[ $# -lt 1 ]]; then
  exit 1;
fi

HH=`date +"%H"`
MI=`date +"%M"`

if [[ "$MI" != "17" && "$MI" != "47" ]];then exit; fi

filetype=$1

DIR_HOME=$(cd "$(dirname "$0")/../.."; pwd)
DIR_SCRIPT_BIN=$DIR_HOME/scripts/ora_sp
DIR_BASE=$DIR_HOME/tmp/ora_sp  

repdir=$DIR_BASE

if [[ ! -d $repdir ]]; then
  exit 1;
fi

cd $repdir
if [[ $? -gt 0 ]]; then
  exit 1;
fi

for filename in `ls ${filetype}* 2>/dev/null` ; do
  tablename=`echo "$filename"|awk '{print "snap_ora_sp_"$1}' FS='-'`
  parameters=`echo "$filename"|awk '{print $2}' FS='-'`
  dbid=`echo "$parameters"|awk '{print $1}' FS='_'`
  inst=`echo "$parameters"|awk '{print $2}' FS='_'`
  begin=`echo "$parameters"|awk '{print $3}' FS='_'`
  end=`echo "$parameters"|awk '{print substr($4,1,index($4,".")-1)}' FS='_'`
  if [[ "$tablename" != "" && "$dbid" != "" && "$inst" != "" && "$begin" != "" && "$end" != ""  && -f "$filename" ]]; then
     cat "$filename"|sed "s/^/$dbid $inst $begin $end /"
  fi
  rm -rf "$filename"
done
