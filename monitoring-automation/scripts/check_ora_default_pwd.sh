#!/bin/sh

if [[ -f ~/.bash_profile ]];then
  . ~/.bash_profile
elif [[ -f ~/.profile ]];then
  . ~/.profile
fi


function check_login {
if [[ $# -lt 2 ]];then
  exit
fi

username=$1
password=$2

if [[ `echo "select sysdate from dual;"|sqlplus $username/$password|grep "ORA-01017: invalid username/password; logon denied"|wc -l` -gt 0 ]];then
  echo "$username $password invalid"
elif [[ `echo "select sysdate from dual;"|sqlplus $username/$password|grep "ORA-28000: the account is locked"|wc -l` -gt 0 ]];then
  echo "$username $password valid_but_locked"
else
  echo "$username $password logged_in"
fi

}

check_login system system
check_login system manager
check_login sys sys
check_login sys cHAnge_on_install
check_login scott scott
check_login dbsnmp dbsnmp
check_login rman rman
check_login scott tiger
