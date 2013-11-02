runMode="default"
while getopts cm FLAGNAME 2>/dev/null; do
  case $FLAGNAME in
    c)  runMode="check"
        ;;
    m)  runMode="manual"
        ;;
    \?) echo "($0) Error: there are unexpected arguments."
        exit 2
        ;;
  esac
done

echo "运行模式：$runMode"

tableList=tmp.tobecleaned_tablelist.lst

sqlplus -s uxinsight/oracle123 <<!
	set pages 9999
	set lines 300
	set feedback off
	set heading off
	col rownum format 9999
	col a format a8
	col b format a20
	col c format a2
	col d format a2
	col e format a13
	col f format a2
	col g format a14
	col h format a2
	col i format a19
	col j format a2
	col k format a19
	col p format a70
	alter session set nls_date_format='yyyymmdd';
	spool $tableList
	select rownum,c,a,d,b,e,f,g,h,i,j,k,p from (
	select  ' ' c, a, ' ' d, b , 
		decode((select count(1) from user_tables where table_name=b),1,'LOCAL_EXIST','LOCAL_DROPPED') e, ' ' f,
		decode(substr(b,1,4),'RUEI','N/A',
			decode((select count(1) from user_tables@ruei where table_name=b),1,'REMOTE_EXIST','REMOTE_DROPPED')) g, ' ' h,
		decode((select count(1) from businesses where trunc(job_date+1,'dd')=a),0,'NO_DATA_IN_BUSINESS','BUSINESS_FINE') i, ' ' j,
		decode((select count(1) from business_halls where trunc(job_date+1,'dd')=a),0,'NO_DATA_IN_HALL','HALL_FINE') k, p
	from (
	select distinct trunc(job_time) a, exchange_table b, 
		decode((select count(1) from user_tab_partitions@ruei where table_name=t.table_name and partition_name=t.partition_name),
			1, table_name||':'||partition_name, 'N/A') p 
	from bidata_parts_status t
	where status='ANALYZED'
	union
        select distinct trunc(job_time,'dd'), 'RUEI_'||high_value, 'N/A' from bidata_parts_status
        where status='ANALYZED'
	order by 1,2 ,3)
	order by 2,4) -- where e='EXIST'
	order by 3,5;
	spool off
!

if [[ $runMode != "check" ]];then

    echo ""
    if [[ $runMode == "manual" ]];then    
    	echo "请输入待删除的起始序号（默认保留最近两天数据）："|awk '{for(i=1;i<=NF;i++)printf $i}' FS=''
    	read beginNo
    
    	if [[ "$beginNo" != "" ]];then
    		echo "请输入待删除的截止序号（默认保留最近两天数据）："|awk '{for(i=1;i<=NF;i++)printf $i}' FS=''
    		read endNo
    	fi
    fi

    if [[ "$beginNo" != "" ]];then
    	echo "Begin=$beginNo"|awk '{for(i=1;i<=NF;i++)printf $i}' FS=''
    fi
    
    if [[ "$endNo" != "" ]];then
    	echo " ; End=$endNo"
    else
    	echo ""
    fi
    
    if [[ "$beginNo" != "" ]];then
    	cat $tableList|awk '{if($1>='"$beginNo"')print}' >$tableList.tmp && mv $tableList.tmp $tableList
    fi
    
    if [[ "$endNo" != "" ]];then
    	cat $tableList|awk '{if($1<='"$endNo"')print}' >$tableList.tmp && mv $tableList.tmp $tableList
    else
    	timeline=`echo "select to_char(sysdate-1,'yyyymmdd') from dual;"|sqlplus -s '/as sysdba'|awk '{if(NF>0)print}'|tail -1`
    	cat $tableList|awk '{if($2<'"$timeline"')print}' >$tableList.tmp && mv $tableList.tmp $tableList
    	echo ""
    fi
    
    dropList=$tableList.tobedropped
    if [[ -f $tableList ]];then
    	cat $tableList|awk '{if($6=="BUSINESS_FINE" && $7=="HALL_FINE")print}'>$dropList
    fi
   
     
    if [[ -f $dropList && `cat $dropList|awk '{if(NF>0)print}'|wc -l|awk '{print $1}'` -gt 0 ]];then

	if [[ `cat $dropList|awk '{if($4=="LOCAL_EXIST")print $3}'|wc -l|awk '{print $1}'` -gt 0 ]];then
    		echo "删除本地数据..."
    		for table in `cat $dropList|awk '{if($4=="LOCAL_EXIST")print $3}'`;do
    			echo "drop table $table;"|sqlplus -s "uxinsight/oracle123"|awk '{if(NF>0)print}'
    		done
	fi
    
    	echo ""	
	if [[ `cat $dropList|awk '{if($5=="REMOTE_EXIST")print $3}'|wc -l|awk '{print $1}'` -gt 0 ]];then
    		echo "删除源数据..."
    		for table in `cat $dropList|awk '{if($5=="REMOTE_EXIST")print $3}'`;do
    			echo "drop table $table;"|sqlplus -s "uxinsight/oracle123"@ruei |awk '{if(NF>0)print}'
    		done
	fi
    
    	echo ""
	if [[ `cat $dropList|awk '{if($8!="N/A")print $3}'|wc -l|awk '{print $1}'` -gt 0 ]];then
    		echo "删除源表分区..."
    		for line in `cat $dropList|awk '{if ($8!="N/A")print $8}'`;do
    			table=`echo $line|awk '{print $1}' FS=':'`
    			part=`echo $line|awk '{print $2}' FS=':'`
    			echo "alter table $table drop partition $part ;"|sqlplus -s "uxinsight/oracle123"@ruei |awk '{if(NF>0)print}'
    		done
	fi
    fi
    
    > $dropList
    if [[ -f $tableList ]];then
    	cat $tableList|awk '{if(($6!="BUSINESS_FINE" || $7!="HALL_FINE") && ($4=="LOCAL_EXIST" || $5=="REMOTE_EXIST" || $8!="N/A"))print}' >$dropList
    fi
    
    if [[ `cat $dropList|awk '{if(NF>0)print}'|wc -l|awk '{print $1}'` -gt 0 ]];then
    	echo "以下数据因未完成报表统计而被保留，请检查"
    	cat $dropList	
    fi
fi

rm -f $dropList $tableList $tableList.tmp
