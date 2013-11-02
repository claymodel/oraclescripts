if [[ -f ~/.profile ]];then
  . ~/.profile
elif [[ -f ~/.bash_profile ]];then
  . ~/.bash_profile
fi

sqlplus -s "/ as sysdba" <<!|awk '{if(NF>0)for(i=1;i<=NF;i++)print $i}' FS='@'|awk '{if(NF>0){for(i=1;i<NF;i++)printf $1" ";print $NF}}'
set lines 9999 pages 9999 feedback off heading off

select 'para='||parallel||'@'       para
     , 'versn='||version||'@'        versn
     , 'host_name='||host_name||'@'      host_name
     , 'db_name='||db_name||'@'        db_name
     , 'inst_name='||instance_name||'@'  inst_name
     , 'btime="'||to_char(snap_time, 'YYYYMMDD HH24:MI:SS')||'"'  btime
  from stats\$database_instance di
     , stats\$snapshot          s
 where s.snap_id          = $begin_snap
   and s.dbid             = $dbid
   and s.instance_number  = $inst_num
   and di.dbid            = s.dbid
   and di.instance_number = s.instance_number
   and di.startup_time    = s.startup_time;

select 'etime="'||to_char(snap_time, 'YYYYMMDD HH24:MI:SS')||'"'  etime
  from stats\$snapshot     s
 where s.snap_id          = $end_snap
   and s.dbid             = $dbid
   and s.instance_number  = $inst_num;

!
