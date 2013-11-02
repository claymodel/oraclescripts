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

#echo "line_limit=$line_limit time_limit=$time_limit" > list.tmp

sqlplus -s "/ as sysdba" <<! | awk '{if(NF>=5)print $3" "$4}'|tail -$line_limit

col instart_fmt format a20
col inst_name format a10
col db_name format a10
col snap_id format 9999999
col snapdat format a20
col lvl format 999
col commnt format a20
set lines 300 pages 9999 heading off feedback off

select  distinct
      di.instance_name                                  inst_name
     , di.db_name                                        db_name
     , s.snap_id                                         snap_id
     , to_char(s.snap_time,'YYYYMMDDHH24miss')        snapdat
     , s.snap_level                                      lvl
     , substr(s.ucomment, 1,60)                          commnt
  from (select * from perfstat.stats\$snapshot where snap_time>sysdate-10) s
     , perfstat.stats\$database_instance di
 where s.dbid = di.dbid and s.instance_number = di.instance_number
   and di.dbid             = (select dbid from v\$database)
   and di.instance_number  = (select instance_number from v\$instance)
   and di.startup_time     = s.startup_time
   and (s.snap_time >= 
          (select max(snap_time) from perfstat.stats\$snapshot 
           where snap_time>sysdate-10 and dbid=s.dbid and instance_number=s.instance_number 
           and snap_time <sysdate-$time_limit/1440)
        or s.snap_time >= sysdate-$time_limit/1440)
 order by db_name, instance_name, snap_id;

!

sqlplus -s "/as sysdba" <<!| awk '{if(NF>=1)print}'
set lines 125 pages 200 heading off feedback off
select 'dbid='||dbid from v\$database;
select 'inst_num='||instance_number from v\$instance;
!
