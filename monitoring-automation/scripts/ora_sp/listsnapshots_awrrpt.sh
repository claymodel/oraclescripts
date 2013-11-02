#!/bin/sh

if [[ -f "~/.profile" ]];then
   . ~/.profile
elif [[ -f "~/.bash_profile" ]];then
   . ~/.bash_profile
fi

line_limit=999
if [[ $# -gt 0 ]];then line_limit=$1; fi
if [[ $line_limit -le 1 ]];then line_limit=999; fi

time_limit=99999999
if [[ $# -gt 1 ]];then time_limit=$2; fi
if [[ $time_limit -le 0 ]];then time_limit=9999999; fi

#echo "line_limit=$line_limit time_limit=$time_limit"

sqlplus -s "/as sysdba" <<!|awk '{if(NF>=5)print $3" "$4}'|tail -$line_limit

col inst_name format a30
col db_name format a30
col snap_id format 999999999
col snapdat format a20
col lvl format 999999999
set lines 150 pages 300 heading off feedback off serveroutput off

select  di.instance_name                                  inst_name
     , di.db_name                                        db_name
     , s.snap_id                                         snap_id
     , to_char(s.end_interval_time,'yyyymmddhh24miss') snapdat
     , s.snap_level                                      lvl
  from dba_hist_snapshot s
     , dba_hist_database_instance di
 where s.dbid              = (select dbid from v\$database)
   and di.dbid             = s.dbid
   and s.instance_number   = (select instance_number from v\$instance)
   and di.instance_number  = s.instance_number
   and di.dbid             = s.dbid
   and di.instance_number  = s.instance_number
   and (s.end_interval_time >= (
          select max(end_interval_time) from dba_hist_snapshot where end_interval_time>sysdate-10 
          and dbid=s.dbid and instance_number=s.instance_number 
          and end_interval_time <sysdate-$time_limit/1440
         )
        or s.end_interval_time >= sysdate-$time_limit/1440
       )
 order by db_name, instance_name, snap_id;

!

sqlplus -s "/as sysdba" <<!| awk '{if(NF>=1)print}'
set lines 125 pages 200 heading off feedback off
select 'dbid='||dbid from v\$database;
select 'db_name='||name from v\$database;
select 'inst_num='||instance_number from v\$instance;
select 'inst_name='||instance_name from v\$instance;
!
