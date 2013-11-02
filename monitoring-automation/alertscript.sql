set lines 999
set pages 999
set feedback off
set serveroutput off
set heading off
col hn format a50
col msg format a900
select host_name||'['||(select min(substr(value,7)) from configurations c
                          where conf_name='IP Address' and value like '10.19.%' and host_name=t.host_name
                          and check_time=(select max(check_time) from configurations where host_name=c.host_name 
                          and conf_name=c.conf_name))
                 ||']' hn,
	decode(subclass,'AIX','','Linux','',subclass)||' '||conf_name||
	' changed from '||old_value||' to '||new_value||' @'||
	to_char(modify_time-(select difference/24/3600 from check_datetime where host_name=t.host_name),'hh24:mi') msg
from conf_modifications t
where modify_time-(select difference/24/3600 from check_datetime where host_name=t.host_name)>sysdate-5/1440
union
select host_name||'['||(select min(substr(value,7)) from configurations c
                          where conf_name='IP Address' and value like '10.19.%' and host_name=t.host_name
                          and check_time=(select max(check_time) from configurations where host_name=c.host_name
			  and conf_name=c.conf_name))
                 ||']' hn,
	program||'.'||Group_name||' '||status msg
from snap_ggs_status t where t.check_time=(select max(check_time) from snap_ggs_status where host_name=t.host_name)
and check_time-(select difference from check_datetime where host_name=t.host_name)/3600/24>sysdate-5/24/60
and status!='RUNNING' and host_name not in ('tdbyj1','tyy1a')
union
select  host_name||'['||(select min(substr(value,7)) from configurations c
                          where conf_name='IP Address' and value like '10.19.%' and host_name=x.host_name
                          and check_time=(select max(check_time) from configurations where host_name=c.host_name and conf_name=c.conf_name))
                 ||']' hn,
        decode(trunc(lag/2),    0,null,' Lag '||lag||' mins')||
        decode(trunc(cpu_usage/90),0,null,' cpu='||cpu_usage) ||
        decode(trunc(mem_usage/90)*page_in,0,null,' mem='||mem_usage||'and page_in='||page_in)||
        decode(trunc(io_local_tps/1000),0,null,' io_local_tps='||io_local_tps)||
        decode(trunc(io_storage_tps/40000),0,null,' io_storage_tps='||io_storage_tps)||
        decode(trunc(net_rbps/90000000),0,null,' net_receive_mps='||round(net_rbps/1024/1024)||' ('||receive_ip||')')||
	decode(trunc(net_sbps/90000000),0,null,' net_send_mps='||round(net_sbps/1024/1024)||' ('||send_ip||')')||
        decode(net_err,0,null,' net_err='||net_err)||
        decode(net_drop,0,null,' net_drop='||net_drop) msg
from     (
select  host_name, 
        round((sysdate-end_time)*24*60,1) lag,
        100-avg_id cpu_usage, 
        100*avg_avm/(avg_avm+avg_fre) mem_usage ,
        avg_pi page_in,
        avg_ltps io_local_tps, 
        avg_stps io_storage_tps, 
        max_rbps net_rbps,
				(select min(value) from configurations ic where host_name=y.host_name 
								and check_time=(select max(check_time) from configurations where host_name=ic.host_name and conf_name=ic.conf_name)
				 				and conf_name='IP Address' 
								and subclass=(select interface from snap_host_netstat it where host_name=y.host_name and check_time>=y.check_time-5/24/60
																		 and it.receive_bytes=y.max_rbps)) receive_ip,
        max_sbps net_sbps,
				(select min(value) from configurations ic where host_name=y.host_name 
								and check_time=(select max(check_time) from configurations where host_name=ic.host_name and conf_name=ic.conf_name)
				 				and conf_name='IP Address' 
								and subclass=(select interface from snap_host_netstat it where host_name=y.host_name and check_time>=y.check_time-5/24/60
																		 and it.transmit_bytes=y.max_sbps)) send_ip,
        sum_err net_err, 
        sum_drop net_drop
from 
(
-- 过去5分钟主机平均性能
select  t.host_name,
				max(n.check_time) check_time, 
        max(t.check_time)-(select difference from check_datetime where host_name=t.host_name)/3600/24 end_time,  
        round(avg(r)) avg_r,
        round(avg(b)) avg_b,
        round(avg(pi)) avg_pi,
        round(avg(po)) avg_po,
        round(avg(us)) avg_us,
        round(avg(sy)) avg_sy,
        round(avg(id)) avg_id,
        round(avg(wa)) avg_wa,
        round(avg(avm)) avg_avm,
        round(avg(fre)) avg_fre,
        round(avg(proc)) avg_proc,
        round(avg(act_proc)) avg_act_proc,
        round(avg(i.local_tps)) avg_ltps, 
        round(avg(i.local_read_mps)) avg_lread_mps, 
        round(avg(i.local_write_mps)) avg_lwrite_mps,
        round(avg(i.storage_tps)) avg_stps, 
        round(avg(i.storage_read_mps)) avg_sread_mps, 
        round(avg(i.storage_write_mps)) avg_swrite_mps,
        round(max(n.receive_bytes)) max_rbps,
        round(max(n.transmit_bytes)) max_sbps,
        sum(n.receive_err+n.transmit_err) sum_err, 
        sum(n.receive_drop+n.transmit_drop) sum_drop
from perf_host_vmstat t ,perf_host_iostat i, snap_host_netstat n
where t.check_time>=(select max(check_time) from perf_host_vmstat where host_name=t.host_name)-5/24/60
and t.check_time=i.check_time(+) and t.check_time=n.check_time(+)
and t.host_name=i.host_name(+) and t.host_name=n.host_name (+)
group by t.host_name 
) y
) x
where (lag>=4 and host_name !='skt2b') or (cpu_usage>=90 and host_name not like 'tjs%')
or mem_usage>=90 and page_in>0 
or ((io_local_tps>=2000
or io_storage_tps >= 40000 )
and host_name not like 'ruei%' )
or net_err>0 
or net_drop>0
union
select distinct host_name||'['||(select min(substr(value,7)) from configurations c
                          where conf_name='IP Address' and value like '10.19.%' and host_name=t.host_name
                          and check_time=(select max(check_time) from configurations where host_name=c.host_name
			  and conf_name=c.conf_name))
                 ||']' hn,
	'fs '||mount_point||', '||capacity||'% used, '|| 
	 decode(trunc(available_m/1024),
	        0,'0'||round(available_m/1024,1),
		round(available_m/1024,1))||'g left' msg
from snap_host_df t where t.check_time=(select max(check_time) from snap_host_df where host_name=t.host_name)
and capacity>95 and available_m<100 and mount_point !='/tmp'
and check_time-(select difference from check_datetime where host_name=t.host_name)/3600/24 > sysdate-5/24/60
union
select host_name||'['||(select min(substr(value,7)) from configurations c
                          where conf_name='IP Address' and value like '10.19.%' and host_name=t.host_name
                          and check_time=(select max(check_time) from configurations where host_name=c.host_name
                          and conf_name=c.conf_name))
                 ||']' hn,
        'LGWR switch at '||to_char(end_time,'hh24:mi')||' in '||seconds||' seconds' msg
from (
select x.host_name,
                         y.alert_time end_time,
       round((y.alert_time-x.alert_time)*86400) seconds
from
(select rownum n, b.*   from
(select * from snap_ora_alert where content like '%Thread % advanced to log sequence %'
 order by host_name, alert_time, line, check_time) b) x,
(select rownum n, b.*   from
(select * from snap_ora_alert where content like '%Thread % advanced to log sequence %'
 order by host_name, alert_time, line, check_time) b) y
where x.host_name=y.host_name and x.n+1=y.n
and y.alert_time = (select max(alert_time)
 from snap_ora_alert where host_name=x.host_name
 and content like '%Thread % advanced to log sequence %')
) t where seconds<0 and end_time>=sysdate-5/1440
union
select distinct t.host_name||'['||(select min(substr(value,7)) from configurations c
                          where conf_name='IP Address' and value like '10.19.%' and host_name=t.host_name
                          and check_time=(select max(check_time) from configurations where host_name=c.host_name
                          and conf_name=c.conf_name))
                 ||']' hn,
        ' ['
        ||to_char((t.check_time-(select difference/86400 from check_datetime where host_name = t.host_name)),'hh24:mi')
        ||'] '
        ||'sid: '||t.sid||', user: '||t.dbuser||', ['||t.osuser||'@'||t.machine||'], blocking '||t.blocking||' sessions'
        ||decode(t.hash_value, '0' , null, ' || '||'holder sql: '||nvl((select sql_text from snap_ora_sqltext where hash_value=t.hash_value and piece=0 and host_name=t.host_name),'unknown'))
        ||decode(x.hash_value, '0',null, ' || '||'waiter sql: '||nvl((select sql_text from snap_ora_sqltext where hash_value=x.hash_value and piece=0 and host_name=t.host_name),'unknown'))
        msg
from snap_ora_lock t, snap_ora_lock x 
where t.host_name=x.host_name and t.check_time=x.check_time
and x.session_type='wait' and t.session_type='hold' and x.waiting_for=t.sid
and t.check_time=(select max(check_time) from snap_ora_lock where host_name=t.host_name)
and t.sid not in (select sid from snap_ora_lock where host_name=t.host_name and check_time=t.check_time and session_type='wait')
and  t.check_time-(select difference from check_datetime where host_name=t.host_name)/3600/24 > sysdate-5/24/60
and t.check_time in (select check_time from perf_ora_basic 
where host_name=t.host_name  and blocked_session>10 and check_time>sysdate-5/24/60)
union
select host_name||'['||(select min(substr(value,7)) from configurations c
                          where conf_name='IP Address' and value like '10.19.%' and host_name=t.host_name
                          and check_time=(select max(check_time) from configurations where host_name=c.host_name))
                 ||']',
        content
from snap_ora_alert t where
check_time-(select difference from check_datetime where host_name=t.host_name)/3600/24 > sysdate-5/24/60
and substr(content,1,4) ='ORA-'	and substr(content,1,9)!='ORA-01555'
union
select distinct hn, 'Instance down '||lag||' mins' msg
from (select host_name||'['||(select min(substr(value,7)) from configurations c
                          where conf_name='IP Address' and value like '10.19.%' and host_name=t.host_name
                          and check_time=(select max(check_time) from configurations where host_name=c.host_name
                          and conf_name=c.conf_name))
                 ||']' hn,
        round((sysdate-(select max(check_time) from perf_ora_basic where host_name=t.host_name)+(select difference from check_datetime where host_name=t.host_name)/3600/24)*24*60) lag 
from perf_ora_basic t where host_name !='skt2b') where lag>=4 
union
select host_name||'['||(select min(substr(value,7)) from configurations c
                          where conf_name='IP Address' and value like '10.19.%' and host_name=t.host_name
                          and check_time=(select max(check_time) from configurations where host_name=c.host_name 
			  and conf_name=c.conf_name))
                 ||']' hn,
	decode(ora_service,1,null,' instance DOWN!')||
	decode(open_mode,1,null,' db not open normally.')||
	decode(listener,0,' listener is down.',null)||
	decode(blocked_session,0,null,' '||holding_session||' blocking '||blocked_session||'.')||
	decode(user_session, 0, null, decode(trunc(latch_free*10/user_session),0,null,' '||latch_free||' latch free.')) ||
	decode(user_session, 0, null, decode(trunc(scattered_read*10/user_session),0,null,' '||scattered_read||' db file scattered read.')) msg
	--decode(user_session, 0, null, decode(trunc(scattered_read*10/user_session),0,null,' '||scattered_read||' db file scattered read.')) ||
	--decode(unavailable_indexes,0,null,' '||unavailable_indexes||' unavailable indexes.')||
	--decode(unusable_index_parts,0,null,' '||unusable_index_parts||' unusable index parts.') msg
from perf_ora_basic t where t.check_time=(select max(check_time) from perf_ora_basic where host_name=t.host_name)
and  check_time-(select difference from check_datetime where host_name=t.host_name)/3600/24 > sysdate-5/24/60
and (ora_service!=1 or open_mode!=1 or listener=0 or blocked_session>10 
--or (unavailable_indexes+unusable_index_parts>0 and substr(host_name,length(host_name),1)!='b')
or ((latch_free>10 or scattered_read>10) and host_name not in ('ls1','ls2')))
union
select distinct host_name||'['||(select min(substr(value,7)) from configurations c
                          where conf_name='IP Address' and value like '10.19.%' and host_name=t.host_name
                          and check_time=(select max(check_time) from configurations where host_name=c.host_name
			  and conf_name=c.conf_name))
                 ||']' hn,
	'tablespace '||tablespace_name||', '||used_pct||'% used, '||
	decode(trunc(free_m/1024),0,'0'||round(free_m/1024,1),round(free_m/1024,1))||'g left' msg
from snap_ora_tablespace t where t.check_time=(select max(check_time) from snap_ora_tablespace where host_name=t.host_name)
and check_time-(select difference from check_datetime where host_name=t.host_name)/3600/24>sysdate-5/24/60
and used_pct>90 and free_m/1024<2 and status=1
order by 1;
