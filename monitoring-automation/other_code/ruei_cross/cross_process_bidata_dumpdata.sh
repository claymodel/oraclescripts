process_id=$$
x=`ps -ef|awk '{if($2!="'$process_id'")print}'|grep "cross_process_bidata"|grep -v grep|wc -l|awk '{print $1}'`
if [[ "$x" -gt 1 ]];then
	#echo "waiting for another process"
	#echo "$x"
	exit
fi
if [[ -f ~/.bash_profile ]];then
	. ~/.bash_profile
elif [[ -f ~/.profile ]];then
	. ~/.profile
fi

cd /home/oracle/dump

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

 ## Read the source table partitions

 sourceTablePartsList=${table}_parts.lst
 >$sourceTablePartsList
sqlplus -s 'uxinsight/oracle123' <<!
	set lines 100
	set pages 9999
	set heading off
	set feedback off
	col partition_name format a30
	col high_value format a10
	col partition_position format 99999
	spool $sourceTablePartsList
	select partition_name, high_value  from user_tab_partitions
	where table_name='$table' order by partition_position;
	spool off
!

if [[ -f $sourceTablePartsList ]] ; then

 ## Get the source pointer
	tmpTable='POINTER_FOR_BIDATA_MASTER';
	if [[ "$table" == "WG__BIDATA_PROPERTIES" ]];then
		tmpTable='POINTER_FOR_BIDATA_PROPER';
	elif [[ "$table" == "WG__BIDATA_USERFLOWS" ]];then
		tmpTable='POINTER_FOR_BIDATA_USERFL';
	fi
	
	currPeriodID=`{
		echo "set heading off";
		echo "set feedback off";
		echo "select period_id from $tmpTable ;";
	}|sqlplus -s 'uxinsight/oracle123'|awk '{if(NF>0)print $1}'`
	echo ""
	echo "Current Period_ID=$currPeriodID"
	echo ""

 ## Get the prepaired source partitions
	prepairedPartsList=${sourceTablePartsList}.prepaired_parts
	>$prepairedPartsList
	line="";
	cat $sourceTablePartsList|awk '{if(NF>0)print}'|while read line;do
		part_name=`echo $line|awk '{print $1}'`
		high_value=`echo $line|awk '{print $2}'`
		if [[ $high_value -lt $currPeriodID && $high_value != 0 ]];then
			echo $part_name >> $prepairedPartsList
		fi
	done	

  ## Remove the partitions which have been done
	alreadyDoneParts=${sourceTablePartsList}.already_done_parts.lst
	>$alreadyDoneParts
	sqlplus -s 'uxinsight/oracle123'@ls2 <<!
		set lines 100
		set pages 9999
		set heading off
		set feedback off
		spool $alreadyDoneParts
		select distinct partition_name from bidata_parts_status 
		where table_name='$table' 
		  and (status = 'DUMPED' or status like 'DOWNLOAD%' or status like 'IMPORT%' 
                       or status like 'ANAL%' or status like 'CLEAR%' or status='DONE');
		spool off
!
	line=""
	inList="false"
	cat $alreadyDoneParts|awk '{if(NF>0)print $1}'|while read line;do
		i=1
		inList="false"
		lineNo=0
		while [[ $i -le `cat $prepairedPartsList|wc -l|awk '{print $1}'` ]];do
			tmpline=`head -$i $prepairedPartsList|tail -1|awk '{print $1}'`
			if [[ "$line" == "$tmpline" ]];then
				inList="true"
				lineNo=$i
			fi
			i=`expr $i + 1`
		done
		if [[ "$inList" == "true" ]];then
			sed "$lineNo d" $prepairedPartsList > $prepairedPartsList.tmp && mv $prepairedPartsList.tmp $prepairedPartsList
		fi
	done
	rm -f $alreadyDoneParts
	cat $prepairedPartsList

  ## Process prepaired parts list line by line
cat $prepairedPartsList|awk '{if(NF>0)print $1}'|while read part;do
	echo ""
	echo "Processing partition $part for table $table"
	echo ""

	exchangeTable="EX_MASTER_${part}"
	if [[ $table == "WG__BIDATA_PROPERTIES" ]];then
		exchangeTable="EX_PROPER_${part}"
	elif [[ $table == "WG__BIDATA_USERFLOWS" ]];then
		exchangeTable="EX_USERFL_${part}"
	fi
	high_value=`cat $sourceTablePartsList|awk '{if($1=="'$part'")print $2}'`
	now=`date +"%d%H"`
	dumpfile=${table}.${part}.${now}.$RANDOM.dmp

	sqlplus 'uxinsight/oracle123'@ls2 <<!
		insert into bidata_parts_status (job_time,host_name,table_name, partition_name, dumpfile, exchange_table, high_value, status, start_time)
		values (sysdate,'$HOSTNAME','$table','$part','$dumpfile','$exchangeTable','$high_value','PROCESSING',sysdate);
		commit;
		exit;
!

     ## Create temp table for partition exchange on source database	
	extCnt=`{ echo "select count(1) CNT from user_tables where table_name ='$exchangeTable';" ; } |
		sqlplus -s 'uxinsight/oracle123'|grep -v CNT|awk '{if(NF==1 && substr($1,1,1)!="-")print $1}'`

        ## Clear previously dirty data
	if [[ "$extCnt" != 0 ]];then
		sqlplus 'uxinsight/oracle123' <<!
			drop table $exchangeTable ;
!
	fi

        ## Exchange partition to table
	sqlplus 'uxinsight/oracle123' <<!
		create table $exchangeTable as select * from $table where rownum<1 ;
		alter table $table exchange partition $part with table $exchangeTable ;
!
    ## Dump exchanged table out to directory expdump
	sqlplus 'uxinsight/oracle123'@ls2 <<!
		update bidata_parts_status set status='DUMPING',start_exp_time=sysdate where host_name='$HOSTNAME'
		and table_name='$table' and partition_name='$part'
		and dumpfile='$dumpfile' and high_value='$high_value' and exchange_table='$exchangeTable' and status='PROCESSING';
		commit;
		exit;
!
	rm -f /home/oracle/dump/${dumpfile}*
	#expdp uxinsight/oracle123 tables=uxinsight.$exchangeTable directory=expdump dumpfile=$dumpfile logfile=$dumpfile.log compression=all parallel=6
	expdp uxinsight/oracle123 tables=uxinsight.$exchangeTable directory=expdump dumpfile=$dumpfile logfile=$dumpfile.log compression=all

    ## Inform LS2 to get the dumpfile and do the rest work
	sqlplus 'uxinsight/oracle123'@ls2 <<!
		update bidata_parts_status set status='DUMPED',end_exp_time=sysdate where host_name='$HOSTNAME'
		and table_name='$table' and partition_name='$part'
		and high_value='$high_value' and exchange_table='$exchangeTable' and (status='DUMPING' or status='PROCESSING');
		commit;
		exit;
!

done 
    ## Clear work area
	rm -f $prepairedPartsList
	rm -f $sourceTablePartsList
fi
done
