-- This query returns the latest archivelog in the archivelog rman backup sets up to which can be recoverd.
-- For rac environments, it first gets the highest sequence number per thread and then the thread#, sequence with
-- the lowest next_change#

select *
from ( select bad.thread#, bad.sequence#, bad.next_change#, to_char(bad.next_time, 'DD/MM/YYYY HH24:MI:SS') next_time
       from v$backup_archivelog_details bad
       where (thread#, sequence#) in
               ( select bad2.thread#, max(bad2.sequence#) last_sequence#
                 from v$backup_archivelog_details bad2
                 group by bad2.thread#
               )
             and resetlogs_time =
               ( select resetlogs_time
                 from v$database_incarnation
                 where status = 'CURRENT'
               )
       order by bad.next_change#
     )
where rownum = 1;
