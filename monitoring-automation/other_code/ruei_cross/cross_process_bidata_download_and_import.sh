process_id=$$
if [[ `ps -ef|awk '{if($2!="'$process_id'")print}'|grep "cross_process_bidata"|grep -v grep|wc -l|awk '{print $1}'` -gt 0 ]];then
	#echo waiting for another process
	exit
fi

if [[ -f ~/.bash_profile ]];then
	. ~/.bash_profile
elif [[ -f ~/.profile ]];then
	. ~/.profile
fi

cd /jsbak/RUEI_PRODUCT/dump

## Clear unfinished dump jobs with owner name uxinsight
unfinishedJobsList=unfinishedJobsList.lst
>$unfinishedJobsList
sqlplus -s '/ as sysdba' <<!
	set lines 200
	set pages 9999
	set heading off
	set feedback off
	col job_name format a100
	spool $unfinishedJobsList
	select ''''||replace(job_name,'=','\=')||'''' JN from dba_datapump_jobs where owner_name='UXINSIGHT' 
	and state != 'NOT RUNNING';
	spool off
!
cat $unfinishedJobsList|awk '{if(NF>0)print $1}'|while read line ; do
	expdp uxinsight/oracle123 ATTACH=$line <<!
		kill_job
		yes
		exit
!
done

rm -f $unfinishedJobsList

## Main

for table in WG__BIDATA_MASTER WG__BIDATA_PROPERTIES WG__BIDATA_USERFLOWS ; do

  ## Query partitions already dumped by source database
	dumpedPartsList=dumped_parts_${table}.lst	
	sqlplus -s 'uxinsight/oracle123' <<!
		set heading off
		set feedback off
		set pages 9999
		set lines 300
		col dumpfile format a100
		col exchange_table format a30
		col high_value format 999999999999
		col host_name format a30
		col partition_name format a30
		spool $dumpedPartsList
		select host_name, dumpfile, exchange_table, high_value, partition_name
		 from bidata_parts_status
		 where (status='DUMPED' or status = 'DOWNLOADED')
		       and table_name='$table' order by host_name,job_time;
		spool off
!

  ## Get by sftp and import to local database one by one
	line=""
	cat $dumpedPartsList|awk '{if(NF>0)print}'|while read line ; do
		host_name=`echo $line|awk '{print $1}'`
		dumpfile=`echo $line|awk '{print $2}'`
		exchangeTable=`echo $line|awk '{print $3}'`
		high_value=`echo $line|awk '{print $4}'`
		part=`echo $line|awk '{print $5}'`
		
		echo ""
		echo "Processing partition $part of table $table"
		echo ""
		
     ## Get dump file by sftp
		ip_address="10.19.243.193"
		if [[ $host_name == "ruei32" ]];then
			ip_address="10.19.243.193"
		fi	
	
		if [[ ! -f $dumpfile ]];then	

echo "Start from "
date

			echo "Downloading dump file by sftp from host $host_name"
	sqlplus -s 'uxinsight/oracle123' <<!
		update bidata_parts_status set status='DOWNLOADING',start_ftp_time=sysdate where host_name='$host_name'
		and table_name='$table' and partition_name='$part'
		and dumpfile='$dumpfile' and high_value='$high_value' and exchange_table='$exchangeTable' and status='DUMPED';
		commit;
		exit;
!
	sftp root@$ip_address <<!
		cd /home/oracle/dump
		mget $dumpfile
!
			if [[ -f $dumpfile ]];then 
	sqlplus -s 'uxinsight/oracle123' <<!
		update bidata_parts_status set status='DOWNLOADED',end_ftp_time=sysdate where host_name='$host_name'
		and table_name='$table' and partition_name='$part'
		and dumpfile='$dumpfile' and high_value='$high_value' and exchange_table='$exchangeTable' and status='DOWNLOADING';
		commit;
		exit;
!
				echo "Dump file downloaded"
			fi
		fi
		
    ## Import dump file
		if [[ -f $dumpfile ]];then 
			extCnt=`{ echo "select count(1) CNT from user_tables where table_name ='$exchangeTable';" ; } |
				sqlplus -s 'uxinsight/oracle123'|grep -v CNT|awk '{if(NF==1 && substr($1,1,1)!="-")print $1}'`
			if [[ "$extCnt" == "0" ]];then
				####{ echo "drop table $exchangeTable ; "; }|sqlplus -s 'uxinsight/oracle123'
	sqlplus -s 'uxinsight/oracle123' <<!
		update bidata_parts_status set status='IMPORTING',start_imp_time=sysdate where host_name='$host_name'
		and table_name='$table' and partition_name='$part'
		and dumpfile='$dumpfile' and high_value='$high_value' and exchange_table='$exchangeTable' and status='DOWNLOADED';
		commit;
		exit;
!
				echo "Importing $dumpfile"

	impdp uxinsight/oracle123 directory=RUEI_DUMP dumpfile=$dumpfile logfile=$dumpfile.log remap_tablespace=USERS:SUNL_MON

	sqlplus -s 'uxinsight/oracle123' <<!
		update bidata_parts_status set status='IMPORTED',end_imp_time=sysdate where host_name='$host_name'
		and table_name='$table' and partition_name='$part'
		and dumpfile='$dumpfile' and high_value='$high_value' and exchange_table='$exchangeTable' and status='IMPORTING';
		commit;
		exit;
!
			fi
		fi


	done
  ## Clear work area
	rm -f $dumpedPartsList
done
   
  ## Clear imported exchange tables, partitions, dump files from source database and local dumpfiles
  importedList=importedList.lst
  sqlplus -s uxinsight/oracle123 <<!
	set lines 300
	set pages 9999
	set heading off
	set feedback off
	col dumpfile format a100
	col exchange_table format a30
	col host_name format a30
	col partition_name format a30
	col table_name format a30
	spool $importedList
	select dumpfile, exchange_table,host_name,partition_name,table_name from bidata_parts_status
	where (status='IMPORTED' or status='CLEARING')
	order by job_time;

	spool off
!

  line=""
  cat $importedList|awk '{if(NF>0)print}'|while read line ; do
	dumpfile=`echo $line|awk '{print $1}'`
	exchangeTable=`echo $line|awk '{print $2}'`
	host_name=`echo $line|awk '{print $3}'`
	part=`echo $line|awk '{print $4}'`
	table=`echo $line|awk '{print $5}'`

        sqlplus -s 'uxinsight/oracle123' <<!
                update bidata_parts_status set status='CLEARING',start_clearing_time=sysdate where host_name='$host_name'
                and dumpfile='$dumpfile' and exchange_table='$exchangeTable' and status='IMPORTED';
                commit;
                exit;
!
	
	## Clear exchange table
#		sqlplus -s 'uxinsight/oracle123'@ruei <<!
#			drop table $exchangeTable ;
#			alter table $table drop partition $part ;
#!
	## Clear source dump file
		sftp root@10.19.243.193<<!
			rm /home/oracle/dump/$dumpfile
!
	## Clear local dump file
		rm -f $dumpfile

        sqlplus -s 'uxinsight/oracle123' <<!
                update bidata_parts_status set status='CLEARED',end_clearing_time=sysdate where host_name='$host_name'
                and dumpfile='$dumpfile' and exchange_table='$exchangeTable' and status='CLEARING';
                commit;
                exit;
!

  done

  rm -f $importedList
## Check whether there are three high_value with same value for three different tables with the status='IMPORTED' or status like 'CLEAR%'
tmpfile=analyzing.tmp
sqlplus -s uxinsight/oracle123 <<! |awk '{if(NF>0 && $1!="HOST_NAME" && substr($1,1,1) !="-")print $1" "$2}' >$tmpfile
        set feedback off
        set heading off
        set pages 999
        set lines 300

        select host_name, high_value from 
        (select host_name, high_value, count(distinct table_name) cnt
         from bidata_parts_status where status='IMPORTED' or status like 'CLEAR%' 
         group by host_name, high_value)
        where cnt=3;
!
hvs=`cat $tmpfile|awk '{if($1=="ruei32")print $2}'`
host_name="ruei32"
for high_value in `echo $hvs` ; do
echo "Analyzing $high_value"
sqlplus -s 'uxinsight/oracle123' <<!
        update bidata_parts_status set status='ANALYZING', start_analysis_time=sysdate 
        where (status='IMPORTED' or status like 'CLEAR%') and host_name='$host_name' and high_value='$high_value';
        commit;
!

tmp_table_name=RUEI_$high_value

extabs=`sqlplus -s uxinsight/oracle123 <<!|awk '{if(NF>0 && $1!="EXCHANGE_TABLE" && substr($1,1,1) !="-")print $1}'
        set feedback off
        set heading off
        set pages 999
        set lines 300
        select distinct exchange_table from bidata_parts_status t 
        where high_value='$high_value' and (status='ANALYZING')
        and job_time=(select max(job_time) from bidata_parts_status where exchange_table = t.exchange_table) order by 1;
!`

echo $extabs
master_table=`echo $extabs|awk '{print $1}'`
proper_table=`echo $extabs|awk '{print $2}'`
userfl_table=`echo $extabs|awk '{print $3}'`

echo $master_table
echo $proper_table
echo $userfl_table

echo "Create tmp table $tmp_table_name"

sqlplus -s uxinsight/oracle123 <<!

alter session enable parallel dml;
alter session enable parallel ddl;

create table $tmp_table_name as
select /*+ parallel(a,12) parallel(b,6)*/
to_date('197001010800','yyyymmddhh24mi')+a.PERIOD_ID/1440 ctime,
a.page_load_time, a.dynamic_network_time network_response, a.dynamic_server_time server_response, 
a.pageview_id, a.client_ip, a.user_id, b.NAME uf_name, b.step
from $master_table a,  $userfl_table b
where a.PERIOD_ID=b.PERIOD_ID(+) and a.pageview_id=b.pageview_id(+)
;

--echo "Generating Data from tmp table"

insert into businesses
select /*+ parallel(t,12) parallel(c,12)*/ 
'$high_value', (select to_date('19700101','yyyymmdd') + $high_value /1440 - 1 from dual) , 
(select to_date('1970010108','yyyymmddhh24') + $high_value /1440 - 1 from dual),
(select to_date('1970010118','yyyymmddhh24') + $high_value /1440 - 1 from dual), 
c.region_name,
round(avg(decode(t.UF_NAME,'包月量查询',t.page_load_time,null)/1000),2) 包月量查询,
round(avg(decode(t.UF_NAME,'补卡',t.page_load_time,null)/1000),2) 补卡,
round(avg(decode(t.UF_NAME,'查询个人客户资料',t.page_load_time,null)/1000),2) 查询个人客户资料,
round(avg(decode(t.UF_NAME,'查询用户资料',t.page_load_time,null)/1000),2) 查询用户资料,
round(avg(decode(t.UF_NAME,'产品变更',t.page_load_time,null)/1000),2) 产品变更,
round(avg(decode(t.UF_NAME,'登录',t.page_load_time,null)/1000),2) 登录,
round(avg(decode(t.UF_NAME,'改付费计划',t.page_load_time,null)/1000),2) 改付费计划,
round(avg(decode(t.UF_NAME,'改密码',t.page_load_time,null)/1000),2) 改密码,
round(avg(decode(t.UF_NAME,'改资料',t.page_load_time,null)/1000),2) 改资料,
round(avg(decode(t.UF_NAME,'个人客户开户',t.page_load_time,null)/1000),2) 个人客户开户,
round(avg(decode(t.UF_NAME,'过户',t.page_load_time,null)/1000),2) 过户,
round(avg(decode(t.UF_NAME,'积分查询',t.page_load_time,null)/1000),2) 积分查询,
round(avg(decode(t.UF_NAME,'缴费',t.page_load_time,null)/1000),2) 缴费,
round(avg(decode(t.UF_NAME,'缴费回退',t.page_load_time,null)/1000),2) 缴费回退,
round(avg(decode(t.UF_NAME,'梦网业务订购或取消',t.page_load_time,null)/1000),2) 梦网业务订购或取消,
round(avg(decode(t.UF_NAME,'停开机',t.page_load_time,null)/1000),2) 停开机,
round(avg(decode(t.UF_NAME,'详单查询',t.page_load_time,null)/1000),2) 详单查询,
round(avg(decode(t.UF_NAME,'用户资料变更',t.page_load_time,null)/1000),2) 用户资料变更,
round(avg(decode(t.UF_NAME,'余额查询',t.page_load_time,null)/1000),2) 余额查询,
round(avg(decode(t.UF_NAME,'账单查询',t.page_load_time,null)/1000),2) 账单查询
from $tmp_table_name t, data_client_info c
where to_number(to_char(t.ctime,'hh24'),'99') between 8 and 18
and (lower(substr(t.user_id,1,8))=lower(substr(c.user_id,1,8)))
and c.is_main='是' 
and  t.step in ('查询','查询明细话单','提交','选择验证方式','签入','显示客户资料','点击提交')
group by c.region_name
order by 1;

commit;

insert into business_halls
select /*+ parallel(t,12) parallel(c,12)*/ 
'$high_value', (select to_date('19700101','yyyymmdd') + $high_value /1440 - 1 from dual) ,
(select to_date('1970010108','yyyymmddhh24') + $high_value /1440 - 1 from dual),
(select to_date('1970010118','yyyymmddhh24') + $high_value /1440 - 1 from dual),
c.region_name, c.business_hall, c.is_main,
round(avg(t.page_load_time)/1000,2) page_load_time,
round(avg(t.network_response)) network_response,
round(avg(t.server_response)) server_response,
count(distinct t.pageview_id) pageviews,
count(distinct t.client_ip) clients,
count(distinct t.user_id) users
from $tmp_table_name t, data_client_info c
where to_number(to_char(t.ctime,'hh24'),'99') between 8 and 18
and lower(substr(t.user_id,1,8))=lower(substr(c.user_id,1,8))
group by c.region_name, c.business_hall,c.is_main
order by 1,2;

commit;
!

cd /jsbak/RUEI_PRODUCT
#sh ruei_2.5.10_report_daily
sh ruei_2.5.8_report_daily

date
echo "DONE"
sqlplus -s 'uxinsight/oracle123' <<!
        update bidata_parts_status set status='ANALYZED', end_analysis_time=sysdate 
        where status='ANALYZING' and host_name='$host_name' and high_value='$high_value';
        commit;
!

## Clear local database

done

## Clear work area
rm -f $tmpfile

pwd
cd /jsbak/RUEI_PRODUCT
pwd
sh cross_process_bidata_clean_history_data.sh
