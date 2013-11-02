#!/bin/sh

#dba id=204 admin=false users=oracle,sunl_mon,smartmon,optim adms=root registry=files
if [[ `uname` == 'AIX' ]];then
  userstr=`lsgroup dba|awk '{if(NF>0)for(i=1;i<=NF;i++)if(substr($i,1,6)=="users=")print substr($i,7)}'`
  echo "$userstr"|awk '{if(NF>0)for(i=1;i<=NF;i++)print $i}' FS=','
else
  for user in `cat /etc/passwd|awk '{print $1}' FS=':'`; do
    if [[ $user != '+' ]];then
      if [[ `groups $user|awk '{print $2}' FS=':'|awk '{for(i=1;i<=NF;i++)if($i=="dba")print $i}'` == 'dba' ]];then
        echo $user
      fi
    fi
  done
fi
