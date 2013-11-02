sqlplus / as sysdba <<!

delete smartmon_report.snap_ora_session where host_name not like '%yy%' and host_name not like '%zw%' and host_name not like '%xy%';
commit;

!
