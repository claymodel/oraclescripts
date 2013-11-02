#!/usr/bin/ksh
set +x

# Copyright (c) 2007-2008
# Filename:  	kill_blocker_session.sh
# Author:     	Zhang Hua
# Version:      V3.5
# History:	
#     2009-09-02	Zhang Hua 	V1.0	Initial
#     2009-11-25	Zhang Hua 	V2.0	Update
#          1. 对于RAC，本地会话可以阻塞本地其它会话，也可以阻塞远程节点的会话，
#             本脚本可以杀死满足这两种情况的本地会话。
#          2. 对于RAC，本脚本仅能杀死本地会话；
#             远程会话如果引起了本地会话的阻塞，则需要将本脚本部署在该远程节点上。
#          3. 阻塞会话也可能是系统进程，本脚本被限制仅允许杀死用户会话。
#          4. 本脚本首先打印系统中锁资源的争用情况，特别是 holder session 的信息，
#             但是只有满足条件的 holder session 才允许被杀死。这些条件是：
#             > 阻塞会话持有锁的时间超过上限（由 MAX_CTIME_TO_KILL 定义）并且
#               系统中锁的阻塞会话与被阻塞会话的数量超过上限（由变量 MAX_SESSIONS_TO_KILL 定义）
#             > 只能杀死用户进程（v$session.type = 'USER')
#             > 不杀死一级BOSS应用，判断依据是：
#               v$session.machine in ( 'sw3a', 'sw3b' ) and program = 'JDBC Thin Client'
#          5. 本脚本中使用gv$lock视图来确定涉及资源争用的、RAC级别的各种锁资源，
#             对于本地的 Blocker 会话，统一使用下面的条件确定：
#                  select l.sid
#                  from v$lock l
#                  where ( id1, id2, type ) in ( select id1, id2, type from gv$lock where request > 0 )
#                    and request = 0 
#
#              为避免 ORA-600[15602]，临时使用 gv$lock 
#                                               and gl.inst_id = sys_context( 'USERENV', 'INSTANCE' ) 
#     2009-12-28	Zhang Hua 	V3.0	Update
#          1. 修改了日志文件名称，包含了主机名，以利于RAC环境中的问题分析。
#          2. 在日志文件中，打印当前的数据库实例名称，以利于RAC环境中的问题分析。
#          3. 修改了MY_PROCESS_COUNT变量的计算，增加了 grep -v vi，避免错报“重复进程”。
#          4. 对于 2. Local Lock Holders: Waits 部分，
#             增加了 p1raw 字段，去掉了 WAIT_TIME 字段
#          5. 将所有的 kill 进程命令输出在日志文件中，以检查是否杀死了符合条件的会话。
#          6. 对于 Blocker 会话，增加了 3. Local Lock Holders: SQLs in Open Cursor 部分，
#             以分析可能引起阻塞的原因。
#             结合 4. Local Lock Holders: Session Locks 部分的 hash_value，以确定当前的 SQL 语句。
#
#     2010-02-02	Zhang Hua 	V3.1	Update
#          1. 调整了 4. Local Lock Holders: Session Locks 查询结果中字段的顺序，将 program 提到前列
#             并增大其字符数到 20
#
#     2010-08-26	Zhang Hua 	V3.2	Update
#          1. 当脚本刚开始执行时，如果发现已经有重复执行的脚本，则执行 hanganalyze
#
#     2010-09-06	Zhang Hua 	V3.3	Update
#          1. 将oradebug dump文件的大小限制为最大2GB
#
#     2011-05-26	Zhang Hua 	V3.5	Update
#          1. 根据孙麟的要求，替换了与其他脚本同步的部分
#
#     2012-02-13	Zhang Hua 	V4.0	Update
#          1. 将本脚本的运行与孙麟的 smartmon 系统进行了融合，主要变动包括：
#             日志文件的输出中不再包括诊断信息，而是将这些信息记录到 smartmon 系统的数据库中。
#             由 smartmon 系统进行调用，不再放在 crontab 中。
#             将配置参数放置到初始化参数文件中，而不是在此脚本中。
#
#     2012-02-16	Sun Lin/Zhang Hua		V4.0.1	Update
#	       1. 在v4.0基础上做适当修改已适应smartmon运行环境
#	       2. 张华修改了杀锁脚本延迟输出可能导致信息丢失的Bug
#          3. 修改了第二条SQL，因性能问题在yy数据库难以查出结果
#
#     2013-02-06	Zhang Hua 	V4.1	Update
#          1. 不再使用配置文件 /ptfs/monitor/cfg/HandSet.ini
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
	LOCK_WAITERS_TO_DUMP=20000      ## 暂时禁用systemstate dump 2010-09-06
	
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

