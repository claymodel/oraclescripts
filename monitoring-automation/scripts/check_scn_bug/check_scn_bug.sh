#?/bin/sh

if [[ -f ~/.profile ]];then . ~/.profile ; elif [[ -f ~/.bash_profile ]];then . ~/.bash_profile ; else exit; fi

sqlplus -s '/as sysdba' @ scripts/check_scn_bug/check_scn_bug.sql |awk '{if(NF>0 && length($1)>3 && substr($1,1,4)!="----")print}' |
	grep -n ""|sed 's/:/ /'
