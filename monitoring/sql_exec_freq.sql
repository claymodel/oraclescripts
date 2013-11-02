set linesize 120
set pages 999
column avg_elapsed_sec format 99999D99
column disk_reads format 999999999
column buffer_gets format 999999999

select to_char(snap.begin_interval_time, 'DD/MM/YYYY HH24:MI:SS') btime, 
       to_char(snap.end_interval_time, 'DD/MM/YYYY HH24:MI:SS') etime, snap.snap_id, 
       snap.instance_number, sqlstat.executions_delta nbr_executions, 
       (sqlstat.elapsed_time_delta / sqlstat.executions_delta/1000000) avg_elapsed_sec,
       (sqlstat.disk_reads_delta / sqlstat.executions_delta) disk_reads, 
       (sqlstat.buffer_gets_delta / sqlstat.executions_delta) buffer_gets
from dba_hist_snapshot snap, dba_hist_sqlstat sqlstat
where snap.snap_id = sqlstat.snap_id(+)
      and snap.instance_number = sqlstat.instance_number(+)
      and sql_id = '&sql_id'
order by snap.snap_id, snap.instance_number;