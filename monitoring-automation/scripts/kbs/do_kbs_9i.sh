#!/usr/bin/ksh
set +x

# Copyright (c) 2007-2008
# Filename:  	kill_blocker_session.sh
# Author:     	Zhang Hua
# Version:      V3.5
# History:	
#     2009-09-02	Zhang Hua 	V1.0	Initial
#     2009-11-25	Zhang Hua 	V2.0	Update
#          1. ����RAC�����ػỰ�����������������Ự��Ҳ��������Զ�̽ڵ�ĻỰ��
#             ���ű�����ɱ����������������ı��ػỰ��
#          2. ����RAC�����ű�����ɱ�����ػỰ��
#             Զ�̻Ự��������˱��ػỰ������������Ҫ�����ű������ڸ�Զ�̽ڵ��ϡ�
#          3. �����ỰҲ������ϵͳ���̣����ű������ƽ�����ɱ���û��Ự��
#          4. ���ű����ȴ�ӡϵͳ������Դ������������ر��� holder session ����Ϣ��
#             ����ֻ������������ holder session ������ɱ������Щ�����ǣ�
#             > �����Ự��������ʱ�䳬�����ޣ��� MAX_CTIME_TO_KILL ���壩����
#               ϵͳ�����������Ự�뱻�����Ự�������������ޣ��ɱ��� MAX_SESSIONS_TO_KILL ���壩
#             > ֻ��ɱ���û����̣�v$session.type = 'USER')
#             > ��ɱ��һ��BOSSӦ�ã��ж������ǣ�
#               v$session.machine in ( 'sw3a', 'sw3b' ) and program = 'JDBC Thin Client'
#          5. ���ű���ʹ��gv$lock��ͼ��ȷ���漰��Դ���õġ�RAC����ĸ�������Դ��
#             ���ڱ��ص� Blocker �Ự��ͳһʹ�����������ȷ����
#                  select l.sid
#                  from v$lock l
#                  where ( id1, id2, type ) in ( select id1, id2, type from gv$lock where request > 0 )
#                    and request = 0 
#
#              Ϊ���� ORA-600[15602]����ʱʹ�� gv$lock 
#                                               and gl.inst_id = sys_context( 'USERENV', 'INSTANCE' ) 
#     2009-12-28	Zhang Hua 	V3.0	Update
#          1. �޸�����־�ļ����ƣ���������������������RAC�����е����������
#          2. ����־�ļ��У���ӡ��ǰ�����ݿ�ʵ�����ƣ�������RAC�����е����������
#          3. �޸���MY_PROCESS_COUNT�����ļ��㣬������ grep -v vi����������ظ����̡���
#          4. ���� 2. Local Lock Holders: Waits ���֣�
#             ������ p1raw �ֶΣ�ȥ���� WAIT_TIME �ֶ�
#          5. �����е� kill ���������������־�ļ��У��Լ���Ƿ�ɱ���˷��������ĻỰ��
#          6. ���� Blocker �Ự�������� 3. Local Lock Holders: SQLs in Open Cursor ���֣�
#             �Է�����������������ԭ��
#             ��� 4. Local Lock Holders: Session Locks ���ֵ� hash_value����ȷ����ǰ�� SQL ��䡣
#
#     2010-02-02	Zhang Hua 	V3.1	Update
#          1. ������ 4. Local Lock Holders: Session Locks ��ѯ������ֶε�˳�򣬽� program �ᵽǰ��
#             ���������ַ����� 20
#
#     2010-08-26	Zhang Hua 	V3.2	Update
#          1. ���ű��տ�ʼִ��ʱ����������Ѿ����ظ�ִ�еĽű�����ִ�� hanganalyze
#
#     2010-09-06	Zhang Hua 	V3.3	Update
#          1. ��oradebug dump�ļ��Ĵ�С����Ϊ���2GB
#
#     2011-05-26	Zhang Hua 	V3.5	Update
#          1. ���������Ҫ���滻���������ű�ͬ���Ĳ���
#
#     2012-02-13	Zhang Hua 	V4.0	Update
#          1. �����ű�������������� smartmon ϵͳ�������ںϣ���Ҫ�䶯������
#             ��־�ļ�������в��ٰ��������Ϣ�����ǽ���Щ��Ϣ��¼�� smartmon ϵͳ�����ݿ��С�
#             �� smartmon ϵͳ���е��ã����ٷ��� crontab �С�
#             �����ò������õ���ʼ�������ļ��У��������ڴ˽ű��С�
#
#     2012-02-16	Sun Lin/Zhang Hua		V4.0.1	Update
#	       1. ��v4.0���������ʵ��޸�����Ӧsmartmon���л���
#	       2. �Ż��޸���ɱ���ű��ӳ�������ܵ�����Ϣ��ʧ��Bug
#          3. �޸��˵ڶ���SQL��������������yy���ݿ����Բ�����
#
#     2013-02-06	Zhang Hua 	V4.1	Update
#          1. ����ʹ�������ļ� /ptfs/monitor/cfg/HandSet.ini
##################################################################################################

# Set the program file name # Added in V4.0.1
FILE_NAME=kill_blocker_session.sh

# Get the base directory and other directories
DIR_HOME=$(cd "$(dirname "$0")/../.."; pwd)
DIR_SCRIPT_BIN=$DIR_HOME/scripts/kbs
DIR_BASE=$DIR_HOME/tmp/kbs  # Added in V4.0.1
DIR_TMP=$DIR_HOME/tmp/kbs/tmp
DIR_LOG=$DIR_HOME/tmp/kbs/log
DIR_DATA=$DIR_HOME/tmp/kbs/data

for dir in $DIR_BASE $DIR_TMP $DIR_LOG $DIR_DATA ; do  	# Added in V4.0.1
	if [[ ! -d "$dir" ]];then
		mkdir "$dir"
	fi
done

# Set the runtime enviorenmen
if [[ -f ~/.profile ]];then
	. ~/.profile
elif [[ -f ~/.bash_profile ]];then # Added in V4.0.1
	. ~/.bash_profile
fi

## V4.1	Modified
SMSWARN="/usr/bin/smswarn"

if [[ -f $DIR_SCRIPT_BIN/kill_blocker_session.ini ]];then
	. $DIR_SCRIPT_BIN/kill_blocker_session.ini
	HAND=$HAND1,$HAND2,$HAND3,$HAND4,13969008018
else
	## Set the max ctime for lock holder before kill sessions
	MAX_CTIME_TO_KILL=45

	## Set the max number of lock holders & waiters before kill sessions
	MAX_SESSIONS_TO_KILL=30

	## Set the max number of lock holders & waiters before hanganalyze
	LOCK_WAITERS_TO_DUMP=20000      ## ��ʱ����systemstate dump 2010-09-06
	
	HAND=13953110187,13969055390,13954199911,13553158595,13969008018
fi

DATE=`date +%Y%m%d`                         ## Below use it as part of the filename
TIMESTAMP=`date +"%Y%m%d%H%M%S"`            ## Below use it as the timestamp for each time of run
HOST_NAME=`hostname`

# Set the runtime log files
LogDaily=$DIR_LOG/kbs_`hostname`_$DATE.log
LogOnce=$DIR_TMP/TmpLogOnce_$DATE.log
KillOnce=$DIR_TMP/TmpKillOnce_$DATE.log
KillOnceScript=$DIR_TMP/TmpKillOnce_$DATE.sh

# Print run information: begin to execute
begin_time=`date +"%Y%m%d%H%M%S "` # Added in V4.0.1

echo ""                     >> $LogDaily
TIME=`date +"%Y%m%d %H:%M:%S"`
echo "$TIME    kill_blocker_session.sh begin"                   >> $LogDaily
echo "$TIME    Timestamp: $TIMESTAMP"                           >> $LogDaily

# Check if there is the same script running
MY_PROCESS_COUNT=`ps -ef| grep "$FILE_NAME" | grep -v grep | grep -v insert_file | grep -v vi | wc -l`

if [ $MY_PROCESS_COUNT -ge "2" -a $MY_PROCESS_COUNT -le "3" ]
then 
  TIME=`date +"%Y%m%d %H:%M:%S"`
  MSG="$TIME    Found $MY_PROCESS_COUNT kill_blocker_session.sh running on `hostname`, do hanganalyze, please check."
  echo ''                   >> $LogDaily
  echo $MSG                 >> $LogDaily

  $SMSWARN $HAND $MSG

  # Do hanganalyze
  sqlplus '/ as sysdba' <<!
    oradebug setmypid
    alter session set max_dump_file_size = '2048M';
    
    oradebug hanganalyze 3
    oradebug tracefile_name
    
    exit
!
  
  # Print run information: Execution finish
  date +"%Y%m%d%H%M%S"

  ## Quit from running
  exit 2
  
elif [ $MY_PROCESS_COUNT -gt "3" ]
then
  TIME=`date +"%Y%m%d %H:%M:%S"`
  MSG="$TIME    Found $MY_PROCESS_COUNT kill_blocker_session.sh running on `hostname`, please check."
  echo ''                   >> $LogDaily
  echo $MSG                 >> $LogDaily

  $SMSWARN $HAND $MSG

  # Print run information: Execution finish
  date +"%Y%m%d%H%M%S"
  exit 2
fi

# Get the database name and instance name
TIME=`date +"%Y%m%d %H:%M:%S"`
echo "$TIME    Get the database configuration: begin"           >> $LogDaily

sqlplus -s '/ as sysdba' <<!    >/dev/null 
  set linesize 145
  set pagesize 3000
  set verify off echo off feedback off heading off
  
  spool $LogOnce
  
  select 'db_name: ' || name db_name
  from v\$database;

  select 'instance_name: ' || instance_name instance_name
  from v\$instance;

  spool off
  exit
!

DATABASE_NAME=`grep "db_name: "         $LogOnce | awk '{print $2}'`
INSTANCE_NAME=`grep "instance_name: "   $LogOnce | awk '{print $2}'`

TIME=`date +"%Y%m%d %H:%M:%S"`
echo "$TIME    Get the database configuration: done"            >> $LogDaily
echo "$TIME    Database Name: ${DATABASE_NAME}"                 >> $LogDaily
echo "$TIME    Instance Name: ${INSTANCE_NAME}"                 >> $LogDaily

# Get diagnostics info
TIME=`date +"%Y%m%d %H:%M:%S"`
echo "$TIME    Get the diagnostic info: begin"                  >> $LogDaily

sqlplus '/ as sysdba' <<!    >/dev/null
  set linesize 200
  set pagesize 3000
  set long 40000
  set verify off echo off feedback off timing on time on
  
  spool $LogOnce

  PROMPT Diag Info Part 1. Global Locks: Holders and Waiters
  select 'snap_ora_lock_sessions ${TIMESTAMP} ' || 
    '$DATABASE_NAME $INSTANCE_NAME $TIMESTAMP ' || 
    to_char( sysdate, 'YYYYMMDDHH24MISS' ) || ' ' ||
    inst_id || ' ' || sid || ' ' || id1 || ' ' ||
    id2 || ' ' || type || ' ' || lmode || ' ' || 
    block || ' ' || request || ' ' || ctime text_data
  from gv\$lock
  where ( id1, id2, type ) in ( select id1, id2, type from gv\$lock where request > 0 )
  order by id1, request;

  PROMPT Diag Info Part 2. Local Lock Holders: Waits
  select /*+ rule */
    distinct 'snap_ora_lock_waits ${TIMESTAMP} ' || 
    '$DATABASE_NAME $INSTANCE_NAME $TIMESTAMP ' || 
    to_char( sysdate, 'YYYYMMDDHH24MISS' ) || ' ' || 
    sys_context( 'userenv', 'instance' ) || ' ' ||
    sw.sid || ' ' || sw.state || ' ' || replace( sw.event, ' ', '_' ) || ' ' ||
    sw.p1 || ' ' || sw.p1raw || ' ' || sw.p2 || ' ' || 
    sw.p3 || ' ' || sw.SECONDS_IN_WAIT text_data
    from v\$lock l, v\$session_wait sw
    where l.sid = sw.sid
      and l.sid in ( select gl.sid
                     from gv\$lock gl
                     where ( id1, id2, type ) in ( select id1, id2, type from gv\$lock where request > 0 )
                       and request = 0
                       and gl.inst_id = sys_context( 'USERENV', 'INSTANCE' ) 
                   );

  PROMPT Diag Info Part 3. Local Lock Holders: SQLs in Open Cursor
  select 'snap_ora_lock_cursors ${TIMESTAMP} ' || 
    '$DATABASE_NAME $INSTANCE_NAME $TIMESTAMP ' || 
    to_char( sysdate, 'YYYYMMDDHH24MISS' ) || ' ' || 
    sys_context( 'userenv', 'instance' ) || ' ' ||
    c.sid || ' ' || c.user_name || ' ' ||
    c.hash_value || ' ' || c.sql_text text_data
  from v\$open_cursor c 
  where c.sid in ( select gl.sid
                   from gv\$lock gl
                   where ( id1, id2, type ) in ( select id1, id2, type from gv\$lock where request > 0 )
                     and request = 0
                     and gl.inst_id = sys_context( 'USERENV', 'INSTANCE' ) 
                 )
  order by c.sid;


  PROMPT Diag Info Part 4. Local Lock Holders: Session Locks
  select /*+ rule */
    'snap_ora_lock_locks ${TIMESTAMP} ' || 
    '$DATABASE_NAME $INSTANCE_NAME $TIMESTAMP ' || 
    to_char( sysdate, 'YYYYMMDDHH24MISS' ) || ' ' || 
    sys_context( 'userenv', 'instance' ) || ' ' ||
    s.sid || ' ' || p.spid || ' ' ||
    replace( s.machine, ' ', '_' ) || ' ' ||
    replace( s.program, ' ', '_' ) || ' ' ||
    l.type || ' ' || l.lmode || ' ' || l.request || ' ' || 
    l.block || ' ' || l.id1 || ' ' || l.id2 || ' ' || 
    l.ctime || ' ' || s.sql_hash_value || ' ' || s.prev_hash_value text_data
  from v\$lock l, v\$session s, v\$process p
  where l.sid = s.sid and s.paddr = p.addr
    and l.sid in ( select gl.sid
                   from gv\$lock gl
                   where ( id1, id2, type ) in ( select id1, id2, type from gv\$lock where request > 0 )
                     and request = 0
                     and gl.inst_id = sys_context( 'USERENV', 'INSTANCE' ) 
                 )
  order by l.sid, l.lmode desc, l.ctime desc;

  PROMPT Diag Info Part 5. Local Lock Waiters: Waiting SQLs
  -- Note: To prevent ORA-600 [15602], use select id1, id2, type from v\$lock where request > 0
  -- When there are many sessions envolved, eg 45, select v$sqltext will slow, so still use v$sqlarea

  select 
    'snap_ora_lock_sqls ${TIMESTAMP} ' || 
    '$DATABASE_NAME $INSTANCE_NAME $TIMESTAMP ' || 
    to_char( sysdate, 'YYYYMMDDHH24MISS' ) || ' ' || 
    sys_context( 'userenv', 'instance' ) || ' ' ||
    s.sid || ' ' || 
    replace( s.program, ' ', '_' ) || ' ' ||
    replace( s.machine, ' ', '_' ) || ' ' ||
    s.sql_hash_value text_data
  from v\$session s
  where s.sid in ( select gl.sid
                   from gv\$lock gl
                   where ( id1, id2, type ) in ( select id1, id2, type from gv\$lock where request > 0 )
                     and request > 0 
                     and gl.inst_id = sys_context( 'USERENV', 'INSTANCE' ) 
                 )
  order by s.sid;

  -- The info below do NOT need to send to smartmon
  PROMPT Diag Info Part 6. Local Lock Holders: Max ctime
  set heading off
  
  -- Only list user sessions as this is the condition to kill
  select /*+ rule */
    'max_ctime: ' || nvl( max( ctime ), 0 ) max_ctime
  from v\$lock l, v\$session s
  where l.sid = s.sid
    and s.type = 'USER'
    and l.sid in ( select gl.sid
                   from gv\$lock gl
                   where ( id1, id2, type ) in ( select id1, id2, type from gv\$lock where request > 0 )
                     and request = 0
                     and gl.inst_id = sys_context( 'USERENV', 'INSTANCE' ) 
                 );

  spool off

  -- Spool kill script to kill local holder session
  set echo off heading off linesize 80
  spool $KillOnce

  select /*+ rule */ 
    'kill -9 ' || p.spid cmd
  from v\$lock l, v\$session s, v\$process p
  where l.sid = s.sid and s.paddr = p.addr 
    and ( l.id1, l.id2, l.type ) in ( select id1, id2, type from gv\$lock where request > 0 )
    and l.request = 0
    and s.type = 'USER'
    and s.sid not in ( select sid from v\$session ses
                       where ses.type = 'USER' 
                         and ses.machine in (  'sw3a', 'sw3b' ) 
                         and ses.program = 'JDBC Thin Client'
                     );

  spool off

  exit
!

# Log the run-time info
TIME=`date +"%Y%m%d %H:%M:%S"`
echo "$TIME    Get the diagnostic info: done"                   >> $LogDaily
echo ""                                                         >> $LogDaily
echo "$TIME    The run-time info:"                              >> $LogDaily
cat $LogOnce | grep "PROMPT Diag Info"                          >> $LogDaily

# Send the diagnostic data to smartmon
TMP_DATAFILE_MAME=$DIR_TMP/tmp_${HOST_NAME}_${DATABASE_NAME}_${TIMESTAMP}.dat
awk '{ if($2=="'$TIMESTAMP'") { for(i=1;i<=NF;i++) printf $i" "; print "" } }' $LogOnce > $TMP_DATAFILE_MAME



# Generate kill script
cat $KillOnce | grep -v SQL | grep -v cmd | grep 'kill ' > $KillOnceScript

MAX_CTIME=`sed -n '/^max_ctime/p' $LogOnce | awk '{print $2}'`
HOLDER_AND_WAITERS=`cat $TMP_DATAFILE_MAME | grep snap_ora_lock_sessions | wc -l`

echo ''                                                         >> $LogDaily
echo "defined MAX_CTIME_TO_KILL   " = $MAX_CTIME_TO_KILL        >> $LogDaily
echo "defined MAX_SESSIONS_TO_KILL" = $MAX_SESSIONS_TO_KILL     >> $LogDaily
echo "defined LOCK_WAITERS_TO_DUMP" = $LOCK_WAITERS_TO_DUMP     >> $LogDaily

echo "found MAX_CTIME         " = $MAX_CTIME                    >> $LogDaily
echo "found HOLDER_AND_WAITERS" = $HOLDER_AND_WAITERS           >> $LogDaily

echo "prepared kill commands  " =                               >> $LogDaily
cat $KillOnceScript                                             >> $LogDaily
echo ""                                                         >> $LogDaily

## Decide whether to do hanganalyze
if [ $MAX_CTIME -ge "$MAX_CTIME_TO_KILL" -a $HOLDER_AND_WAITERS -ge "$LOCK_WAITERS_TO_DUMP" ]
then
  # Do hanganalyze
  sqlplus -s '/ as sysdba' <<!      1>/dev/null
    oradebug setmypid
    alter session set max_dump_file_size = '2048M';
    
    oradebug hanganalyze 3
    oradebug dump systemstate 11
    oradebug tracefile_name
    
    exit
!

  # Log
  TIME=`date +"%Y%m%d %H:%M:%S"`
  echo "$TIME    Conditions meet, dumped systemsate."               >> $LogDaily
else
  # Log
  TIME=`date +"%Y%m%d %H:%M:%S"`
  echo "$TIME    Conditions NOT meet, no need to dump systemsate."  >> $LogDaily
fi


## Decide whether to kill blocker session
if [ $MAX_CTIME -ge "$MAX_CTIME_TO_KILL" -a $HOLDER_AND_WAITERS -ge "$MAX_SESSIONS_TO_KILL" ]
then
  # Run kill session script
  sh $KillOnceScript #Commented in V4.0.1
  
  # Wakeup PMON, do resource clean
  sqlplus -s '/ as sysdba' <<!      >/dev/null
    set verify off echo off feedback off heading off
    
    oradebug setmypid;
    oradebug wakeup 2;
  
    exit
!

  # Send SMS
  KILLED_PROCESS=`wc -l $KillOnceScript | awk '{print $1}'`
  TIME=`date +"%Y%m%d %H:%M:%S"`
  MSG="$TIME kill_blocker_session.sh killed $KILLED_PROCESS Oracle process(es) on `hostname`."
  MSG=$MSG" The total holder and waiter sessions are $HOLDER_AND_WAITERS. "
  MSG=$MSG" The max lock ctime is $MAX_CTIME."
  $SMSWARN $HAND $MSG 1>/dev/null
  
  # Log
  TIME=`date +"%Y%m%d %H:%M:%S"`
  echo "$TIME    Conditions meet, kill session(s)."                 >> $LogDaily
  echo "$TIME    Session(s) be killed: "                            >> $LogDaily
  cat $KillOnceScript                                               >> $LogDaily
  
  # Send info to smartmon
  #MSG="${TIMESTAMP} snap_ora_lock_kill_log "
  MSG="snap_ora_lock_kill_log ${TIMESTAMP} "
  #MSG=$MSG" ${DATABASE_NAME} ${INSTANCE_NAME} ${TIMESTAMP} ${KILLED_PROCESS}"
  awk '{print "snap_ora_lock_kill_log '$TIMESTAMP' '$DATABASE_NAME' '$INSTANCE_NAME' '$TIMESTAMP' " $3}' $KillOnceScript >> $TMP_DATAFILE_MAME
  #echo $MSG >> $TMP_DATAFILE_MAME
else
  # Log
  TIME=`date +"%Y%m%d %H:%M:%S"`
  echo "$TIME    Conditions NOT meet, no need to kill sessions."    >> $LogDaily
fi

rm $LogOnce
rm $KillOnce
rm $KillOnceScript

# rm the tmp datafile if it's zero size
if [[ -f $TMP_DATAFILE_MAME && `wc -c $TMP_DATAFILE_MAME | awk '{print $1}'` == 0 ]]; then
  rm -f $TMP_DATAFILE_MAME
else
  # Send datafile to smartmon
  DATAFILE_NAME=$DIR_DATA/${HOST_NAME}_${DATABASE_NAME}_${TIMESTAMP}.dat
  #mv $TMP_DATAFILE_MAME $DATAFILE_NAME

  # split datafile into 6 files according to table names
  _SESSION_FILE=${DATAFILE_NAME}.sm_session
  _WAIT_FILE=${DATAFILE_NAME}.sm_wait
  _CURSOR_FILE=${DATAFILE_NAME}.sm_cursor
  _LOCK_FILE=${DATAFILE_NAME}.sm_lock
  _SQL_FILE=${DATAFILE_NAME}.sm_sql
  _KILL_FILE=${DATAFILE_NAME}.sm_kill

  awk '{if($2=="'$TIMESTAMP'" && $1=="snap_ora_lock_sessions")print}' $TMP_DATAFILE_MAME > $_SESSION_FILE
  CNT_SESSIONS=`wc -l $_SESSION_FILE|awk '{print $1}'`
  if [[ $CNT_SESSIONS == 0 ]];then rm -f $_SESSION_FILE ; fi

  awk '{if($2=="'$TIMESTAMP'" && $1=="snap_ora_lock_waits")print}' $TMP_DATAFILE_MAME > $_WAIT_FILE
  CNT_WAITS=`wc -l $_WAIT_FILE|awk '{print $1}'`
  if [[ $CNT_WAITS == 0 ]];then rm -f $_WAIT_FILE ; fi

  awk '{if($2=="'$TIMESTAMP'" && $1=="snap_ora_lock_cursors")print}' $TMP_DATAFILE_MAME > $_CURSOR_FILE
  CNT_CURSORS=`wc -l $_CURSOR_FILE|awk '{print $1}'`
  if [[ $CNT_CURSORS == 0 ]];then rm -f $_CURSOR_FILE ; fi

  awk '{if($2=="'$TIMESTAMP'" && $1=="snap_ora_lock_locks")print}' $TMP_DATAFILE_MAME > $_LOCK_FILE
  CNT_LOCKS=`wc -l $_LOCK_FILE|awk '{print $1}'`
  if [[ $CNT_LOCKS == 0 ]];then rm -f $_LOCK_FILE ; fi
 
  awk '{if($2=="'$TIMESTAMP'" && $1=="snap_ora_lock_sqls")print}' $TMP_DATAFILE_MAME > $_SQL_FILE
  CNT_SQLS=`wc -l $_SQL_FILE|awk '{print $1}'`
  if [[ $CNT_SQLS == 0 ]];then rm -f $_SQL_FILE ; fi
  
  awk '{if($2=="'$TIMESTAMP'" && $1=="snap_ora_lock_kill_log")print}' $TMP_DATAFILE_MAME > $_KILL_FILE
  CNT_KILL=`wc -l $_KILL_FILE|awk '{print $1}'`
  if [[ $CNT_KILL == 0 ]];then rm -f $_KILL_FILE ; fi

fi

# Print the run information: Execution finish
TIME=`date +"%Y%m%d %H:%M:%S"`
echo "$TIME    kill_blocker_session.sh end"                     >> $LogDaily

if [[ "$CNT_KILL" == "" ]];then CNT_KILL=0 ; fi
if [[ "$CNT_SESSIONS" == "" ]];then CNT_SESSIONS=0 ; fi
if [[ "$CNT_WAITS" == "" ]];then CNT_WAITS=0 ; fi
if [[ "$CNT_CURSORS" == "" ]];then CNT_CURSORS=0 ; fi
if [[ "$CNT_LOCKS" == "" ]];then CNT_LOCKS=0 ; fi
if [[ "$CNT_SQLS" == "" ]];then CNT_SQLS=0 ; fi

end_time=`date +"%Y%m%d%H%M%S"` # Added in V4.0.1
echo "$begin_time $end_time $TIMESTAMP $CNT_KILL $CNT_SESSIONS $CNT_WAITS $CNT_CURSORS $CNT_LOCKS $CNT_SQLS"	# Added in V4.0.1

