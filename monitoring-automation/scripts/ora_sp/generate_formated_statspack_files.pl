#!/bin/perl

if(@ARGV < 1){
  $report_count=1;
}else{
  $report_count=@ARGV[0];
}

$report_dir='';
if(@ARGV >=3 ){
  $report_dir=@ARGV[2];
}

$report_minutes=0;
if(@ARGV >=2){
  $report_minutes=@ARGV[1];
}

# Get the snapshots list
$script='listsnapshots_statspack.sh';
$tmpi=$report_count+1;
open (SHIN, "sh $script $tmpi $report_minutes|")||die("Can't open/execute script file $script");
@content=<SHIN>;
for($i=0;$i<@content;$i++){
  $line=@content[$i];
  if ($line =~ /(\d+) +(\d+)/){
    @snapidlist[$i]=$1;
    @snaptimelist[$i]=$2;
  }
  if($line =~ /\w+=\w+/){
    @paramlist[$i-@snapidlist]=$&;
    $dbid=$1 if($line=~/dbid=(\d+)/);
    $inst=$1 if($line=~/inst_num=(\d+)/);
  }
}
close(SHIN);

# Run the statspack script to get reports
$j=@snapidlist;
$j--;
for($i=0;$i<$j;$i++){
  $begin_snap=@snapidlist[$i];
  $begin_time=@snaptimelist[$i];
  $end_snap=@snapidlist[$i+1];
  $end_time=@snaptimelist[$i+1];

  $identifier="${dbid}_${inst}_${begin_snap}_${end_snap}";
  
  if( $report_dir eq '' || $report_dir eq './' || $report_dir eq '.'){
    $work_dir="repdir_$identifier";
    $report_dir='./';
  }else{
    $work_dir="${report_dir}/repdir_$identifier";
    system("if [[ ! -d $report_dir ]];then mkdir $report_dir ; fi");
  }

  system("if [[ ! -d $work_dir ]];then mkdir $work_dir ; fi");
  $script="$work_dir/sprep_${identifier}.sh";
  open (SHOUT , ">$script") || die ("Can't create script to run the reports $script");
  $script_param="$work_dir/sprep_${begin_snap}_${end_snap}_param.sh";
  open (SHOUT_PARAM , ">$script_param") || die ("Can't create script to run the reports $script_param");
  print SHOUT "identifier=$identifier\n";
  print SHOUT "workdir=$work_dir\n";
  foreach $param (@paramlist){
    print SHOUT "$param\n";
    print SHOUT_PARAM "$param\n";
  }
  print SHOUT ("begin_snap=$begin_snap\n");
  print SHOUT_PARAM ("begin_snap=$begin_snap\n");
  print SHOUT ("end_snap=$end_snap\n");
  print SHOUT_PARAM ("end_snap=$end_snap\n");
  close(SHOUT_PARAM); 
  system("cat $script_param getsnapparameters_statspack.sh > $script_param.tmp && mv $script_param.tmp $script_param");

  open (SHIN, "sh $script_param|")||die ("Can't execute the script $script_param");
  @content=<SHIN>; 
  for($k=0;$k<@content;$k++){
    $param=@content[$k];
    print SHOUT ("$param");
    $db_name=$1 if($param=~/db_name=(\w+)/);
    $inst_name=$1 if($param=~/inst_name=(\w+)/);
  }
  close (SHIN);
  system("rm -f $script_param");
  close(SHOUT); 
  system("cat $script sprep.sh > $script.tmp && mv $script.tmp $script && sh $script >/dev/null && rm -f $script");

  # Parse the internal reports into formated files
  &parse_colon_seperated_type_value("$work_dir/1.load_profile_$identifier.lst"
                                   ,"$report_dir/load_profile-$identifier.lst" 
                                   ,"per sec","per transaction");
  &parse_colon_seperated_type_value("$work_dir/2.instance_efficiency_percentages_$identifier.lst"
                                   ,"$report_dir/instance_effici-$identifier.lst"
                                   ,"begin","end");
  &parse_multicolumn_type_value("$work_dir/3.top_wait_events_$identifier.lst"
                               ,"$report_dir/top_wait_events-$identifier.lst"
                               ,4);
  &parse_colon_seperated_type_value("$work_dir/4.cluster_specific_ratios_$identifier.lst"
                                   ,"$report_dir/cluster_specific-$identifier.lst");
  &parse_multicolumn_type_value("$work_dir/5.miscellaneous_ges_cluster_statistics_$identifier.lst"
                               ,"$report_dir/ges_cluster_stat-$identifier.lst"
                               ,3);
  &parse_multicolumn_type_value("$work_dir/6.system_event_$identifier.lst"
                               ,"$report_dir/system_event-$identifier.lst"
                               ,5);
  &parse_multicolumn_type_value("$work_dir/7.background_process_wait_events_$identifier.lst"
                               ,"$report_dir/background_wait-$identifier.lst"
                               ,5);
  &parse_sql_list("$work_dir/8.sql_statements_order_by_buffer_gets_$identifier.lst"
                 ,"$report_dir/sql_buffer_gets-$identifier.lst"
                 ,7);
  &parse_sql_list("$work_dir/9.sql_statements_order_by_physical_reads_$identifier.lst"
                 ,"$report_dir/sql_physical_r-$identifier.lst"
                 ,7);
  &parse_sql_list("$work_dir/10.sql_statements_order_by_executions_$identifier.lst"
                 ,"$report_dir/sql_executions-$identifier.lst"
                 ,6);
  &parse_sql_list("$work_dir/11.sql_statements_order_by_parse_calls_$identifier.lst"
                 ,"$report_dir/sql_parse_calls-$identifier.lst"
                 ,4);
  &parse_sql_list("$work_dir/12.sql_statements_order_by_shareable_memory_$identifier.lst"
                 ,"$report_dir/sql_shareable_mem-$identifier.lst"
                 ,4);
  &parse_sql_list("$work_dir/13.sql_statements_order_by_version_count_$identifier.lst"
                 ,"$report_dir/sql_version_count-$identifier.lst"
                 ,3);
  &parse_multicolumn_type_value("$work_dir/14.instance_activity_statistics_$identifier.lst"
                               ,"$report_dir/instance_activity-$identifier.lst"
                               ,3);
  &parse_multicolumn_type_value("$work_dir/17.tablespace_io_stats_$identifier.lst"
                               ,"$report_dir/tablespace_io-$identifier.lst"
                               ,8);
  &parse_multicolumn_type_value("$work_dir/18.file_io_statistics_$identifier.lst"
                               ,"$report_dir/file_io-$identifier.lst"
                               ,8,2);
   
  # Output the report infomation
  print "$dbid $db_name $inst $inst_name $begin_snap $begin_time $end_snap $end_time\n";

  # Clear work directory
  system("if [[ -d $work_dir ]];then rm -rf $work_dir; fi");
}


sub parse_colon_seperated_type_value{
  my($filename_s1, $output_filename_s1, $typeA_firstLine,$typeA_secondLine)=@_;
  $typeA_firstLine=~tr/ /_/;
  $typeA_secondLine=~tr/ /_/;
  my($s1_repfile)="";
  my($s1_outfile)="";
  open(s1_repfile,"$filename_s1")||die("Can't open report file $filename_s1");
  open(s1_outfile,">$output_filename_s1")||die("Can't open output file $output_filename_s1");
  my(@s1_content)=<s1_repfile>;
  my(@s1_line)="";
  my($s1_i)=0;
  my($s1_j)=0;
  my($s1_col)='';
  my($s1_columnName)='';
  my($s1_processedColumnName)='';
  my(@typeAcolumns)=( 'Redo size', 'Logical reads', 'Block changes', 'Physical reads', 'Physical writes', 
                 'User calls', 'Parses', 'Hard parses', 'Sorts', 'Logons', 'Executes', 
                 'Memory Usage %', '% SQL with executions>1', '% Memory for SQL w/exec>1');
  my(@typeBcolumns)=('Transactions', '% Blocks changed per Read', 'Recursive Call %', 
                  'Rollback per transaction %', 'Rows per Sort',
                  'Buffer Nowait %', 'Redo NoWait %', 'Buffer  Hit   %','In-memory Sort %',
                  'Library Hit   %', 'Soft Parse %', 'Execute to Parse %', 'Latch Hit %',
                  'Parse CPU to Parse Elapsd %', '% Non-Parse CPU',
                  'Ave global cache get time (ms)', 'Ave global cache convert time (ms)', 
                  'Ave build time for CR block (ms)', 'Ave flush time for CR block (ms)', 
                  'Ave send time for CR block (ms)', 'Ave time to process CR block request (ms)', 
                  'Ave receive time for CR block (ms)', 'Ave pin time for current block (ms)', 
                  'Ave flush time for current block (ms)', 'Ave send time for current block (ms)', 
                  'Ave time to process current block request (ms)', 'Ave receive time for current block (ms)', 
                  'Global cache hit ratio', 'Ratio of current block defers', 
                  '% of messages sent for buffer gets', '% of remote buffer gets', 
                  'Ratio of I/O for coherence', 'Ratio of local vs remote work', 
                  'Ratio of fusion vs physical writes', 'Ave global lock get time (ms)', 
                  'Ave global lock convert time (ms)', 'Ratio of global lock gets vs global lock releases', 
                  'Ave message sent queue time (ms)', 'Ave message sent queue time on ksxp (ms)', 
                  'Ave message received queue time (ms)', 'Ave GCS message process time (ms)', 
                  'Ave GES message process time (ms)', '% of direct sent messages', 
                  '% of indirect sent messages', '% of flow controlled messages');
  foreach $s1_line (@s1_content){
    $s1_line=~ tr/,//d;
    $s1_line=~s/\#+/-1/g;
    foreach $s1_col (@typeAcolumns){
      $s1_columnName=$s1_col;
      $s1_columnName=~s/\(/\\\(/g;
      $s1_columnName=~s/\)/\\\)/g;
      if($s1_line=~/$s1_columnName:\s+(-?[\d]+\.?\d*)\s+(-?\d+\.?\d*)/){
        my($s1_processedColumnName)=$s1_col;
        my($s1_value1)=$1;
        my($s1_value2)=$2;
        $s1_processedColumnName=~ s/ +/ /g;
        #$s1_processedColumnName=~ s/ %|% /%/g;
        $s1_processedColumnName=~ s/ /_/g;
        print s1_outfile ("${s1_processedColumnName}_${typeA_firstLine} $s1_value1\n${s1_processedColumnName}_${typeA_secondLine} $s1_value2\n");
      }
    } # End of Type A Columns
    foreach $s1_col (@typeBcolumns){
      $s1_columnName=$s1_col;
      $s1_columnName=~s/\(/\\\(/g;
      $s1_columnName=~s/\)/\\\)/g;
      if($s1_line=~/$s1_columnName:\s+(-?\d+\.?\d*)/){
        my($s1_processedColumnName)=$s1_col;
        my($s1_value)=$1;
        $s1_processedColumnName=~ s/ +/ /g;
        #$s1_processedColumnName=~ s/ %|% /%/g;
        $s1_processedColumnName=~ s/ /_/g;
        print s1_outfile ("$s1_processedColumnName $s1_value\n");
      }
    } # End of Type B Columns
  }
  close(s1_outfile);
  close(s1_repfile);
}

sub parse_multicolumn_type_value{
  my($filename_s2, $output_filename_s2, $s2_columnsCount,$s2_headerColumns)=@_;
  $s2_headerColumns=1 if($s2_headerColumns eq "");
  
  my($s2_patternStr)='(^\S+.*\S+)';
  for($s2_i=0;$s2_i<$s2_columnsCount;$s2_i++){
     $s2_patternStr.='\s+(-?\d+\.?\d*)';
  }
  my($s2_processedColumnName)="";
  my(@s2_value)=();
  my($s2_repfile)="";
  my($s2_outfile)="";
  open(s2_repfile,$filename_s2)||die("Can't open report file $filename_s2");
  open(s2_outfile,">$output_filename_s2")||die("Can't open output file $output_filename_s2");
  my(@s2_content)=<s2_repfile>;
  my($s2_line)="";
  my($s2_result)="";
  my($s2_i)=0;
  my($s2_j)=0;
  foreach $s2_line (@s2_content){
    $s2_line=~s/,//g;
    $s2_line=~s/\#+/-1/g;
    $s2_result="";
    $s2_processedColumnName="";
    if ($s2_columnsCount==4 && $s2_line=~/CPU time\s+(-?\d+\.?\d*)\s+0\s+(-?\d+\.?\d*)/){
         $s2_processedColumnName='CPU time';
         $s2_result=" 0 $1 0 $2";
    }else{
      if($s2_line=~/$s2_patternStr/){
         $s2_processedColumnName=$1;
         $s2_result="";
         for($s2_i=0;$s2_i<$s2_columnsCount;$s2_i++){
           $s2_j=$s2_i+2;
           @s2_value[$s2_i]=$$s2_j;
           $s2_result.=" $$s2_j";
         }
      }
    }
    if($s2_result ne "" ){
      $s2_processedColumnName=~s/ +/ /g;
      $s2_processedColumnName=~s/ /_/g if($s2_headerColumns==1);
      print s2_outfile ("${s2_processedColumnName}$s2_result\n");
    }
  }
  close(s2_outfile);
  close(s2_repfile); 
}

sub parse_sql_list{
  my($filename_s3, $output_filename_s3, $valuesCount)=@_;
  my($s3_repfile)="";
  my($s3_outfile)="";
  open(s3_repfile,$filename_s3)||die("Can't open report file $filename_s3");
  open(s3_outfile,">$output_filename_s3")||die("Can't open output file $output_filename_s3");
  my(@s3_content)=<s3_repfile>;
  my($s3_line)="";
  my($s3_patternStr)="";
  my($s3_i)=0;
  my($s3_j)=0;
  my($s3_result)="";
  my($s3_moduleStr)="";
  my($s3_tmpstr)="";

  $s3_patternStr='^\s+';
  for ($s3_i=0;$s3_i<$valuesCount-1;$s3_i++){
    $s3_patternStr.='(-?[\d,\#]+\.?\d*)\s+'
  }
  $s3_patternStr.='(-?\d+)';
  for $s3_line (@s3_content){
    if($s3_line =~ /$s3_patternStr/){
      if($s3_result ne "") {
        $s3_result=~s/\#+/-1/g;
        print s3_outfile ("$s3_result unknown unknown\n");
        $s3_result="";
      }
      for($s3_i=1;$s3_i<=$valuesCount;$s3_i++){
        $s3_tmpstr=$$s3_i;
        $s3_tmpstr=~s/,//g;
        $s3_result.="$s3_tmpstr ";
      }
    }elsif($s3_line=~/Module: (\S+.*\S+)/){
      $s3_moduleStr="$1";
      $s3_moduleStr=~s/ /_/g;
      $s3_result.="unknown $s3_moduleStr";
      $s3_result=~s/\#+/-1/g;
      print s3_outfile ("$s3_result\n");
      $s3_result="";
    }
  }
  close(s3_outfile);
  close(s3_repfile);  
}
