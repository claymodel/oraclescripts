
if [[ -f ~/.bash_profile ]];then . ~/.bash_profile ; elif [[ -f ~/.profile ]];then . ~/.profile ; fi

awrrpt_file=$workdir/awrrpt.lst

echo "dbid=$dbid, inst_num=$inst_num, bid=$bid, eid=$edi"

sqlplus -s "/as sysdba" <<!
set veri off echo off serveroutput off feedback off linesize 80 termout on heading off
spool $awrrpt_file
-- call the table function to generate the report
select output from table(dbms_workload_repository.awr_report_text($dbid,  
                                                            $inst_num,
                                                            $bid, $eid,
                                                            0));
spool off

!
