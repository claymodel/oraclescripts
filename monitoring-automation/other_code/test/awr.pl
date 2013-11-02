#!/bin/perl

$filename=@ARGV[0];

if ( ! -e "$filename" || ! open (FILE, "$filename") ) {
  # If can't open the awr report file, then output the error message, and exit
  die ("Can't open file $filename, or file doesn't exist.");
  exit;
}

$mode='';
@items=@item1=@item2=@item3=@item4=@itemPointer=();
@itemSet=(*item1,*item2,*item3,*item4);
$lastLineIsUseful=0;
while ($line = <FILE> ){
  $mode=&contentMode($line,$mode);  
  @items=&parseDataBlock($line,$mode);
  $itemCount=@items;
  if (@items > 0){
    printf ("mode=$mode; items=$itemCount; line=$line");
    for($i=0;$i<@items;$i++){
      *item=@items[$i];
      printf ("@item\n");
    }
    printf ("\n");
  }
}

# Close the awr report file.
close (FILE);

sub parseDataBlock {
  my($line,$mode,@result)=@_;
  my(@item)=();
  if( $mode eq 'Load Profile' ){                       # Load Profile
    @item=&parseMultiValues($line,4);
    @item=&parseMultiValues($line,2) if(@item==0);
    @item=&parseMultiValues($line,1) if(@item==0);
    if(@item>=2){
      @item1=(@item[0] . '_per_sec' , @item[1]); 
      @result=(*item1);
      if(@item == 3){
        @item2=(@item[0] . '_per_trans' , @item[2]); 
        @result[1]=*item2;
      }
      if(@item == 5){
        @item3=(@item[0] . '_per_exec' , @item[3]); 
        @item4=(@item[0] . '_per_call' , @item[4]); 
        @result[2]=*item3;
        @result[3]=*item4;
      }
    }
  } # End of Load Profile
  elsif ($mode eq 'Instance Efficiency Percentages' || $mode eq 'Shared Pool Statistics'){
    if ($mode eq 'Instance Efficiency Percentages'){   # Instance Efficiency Percentages
      @result=&parseMultiColumns($line,2);  
    } # End of Instance Efficiency Percentages
    elsif ($mode eq 'Shared Pool Statistics'){            # Shared Pool Statistics
      @item=&parseMultiValues($line,2);
      if(@item == 3){
        @item1=(@item[0].'_begin',@item[1]);
        @item2=(@item[0].'_end',@item[2]);
        @result=(*item1,*item2);
      }
    } # End of Shared Pool Statistics
  }
  elsif ($mode eq 'Top 5 Timed Foreground Events'){     # Top 5 Timed Foreground Events 
    @item1=&parseMultiValues($line,4,'SPACE');
    if (@item1==0){
      @item1=&parseMultiValues($line,2,'SPACE');
      if(@item1>0){
        @item1[4]=@item1[2];
        @item1[2]=@item1[1];
        @item1[3]=@item1[1]=0;
      }
    }
    @result=(*item1) if(@item1>0);
  } # End of Top 5 Timed Foreground Events
  elsif ($mode eq 'Foreground Wait Events' || $mode eq 'Background Wait Events'){ # Wait Events
    @item1=&parseMultiValues ($line,6,'SPACE');
    if(@item1>0){
      @item1=@item1[0,1,2,3,4,5];
    }else {
      @item1=&parseMultiValues ($line,5,'SPACE');
    }
    @result=(*item1) if(@item1>0);
  } # End of Wait Events
  elsif ($mode eq 'SQL ordered by Gets' 
      || $mode eq 'SQL ordered by Reads' 
      || $mode eq 'SQL ordered by Version Count' 
      || $mode eq 'SQL ordered by Parse Calls' 
      || $mode eq 'SQL ordered by Sharable Memory' 
      || $mode eq 'SQL ordered by Executions'){ # SQL ordered by Gets/Reads/Executions
    if(!$lastLineIsUseful){
      @item1=&parseStatsOfSQL($line,7) if($mode eq 'SQL ordered by Gets'||$mode eq 'SQL ordered by Reads');
      @item1=&parseStatsOfSQL($line,6) if($mode eq 'SQL ordered by Executions');
      @item1=&parseStatsOfSQL($line,3) if($mode eq 'SQL ordered by Parse Calls'||$mode eq 'SQL ordered by Sharable Memory');
      @item1=&parseStatsOfSQL($line,2) if($mode eq 'SQL ordered by Version Count');
      $lastLineIsUseful=1 if(@item1>0);
    }else{
      if($mode eq 'SQL ordered by Gets'||$mode eq 'SQL ordered by Reads'){
        $tmpstr=@item1[4];
        @item1[4]=$item1[5];
        @item1[5]=$tmpstr;
      }elsif($mode eq 'SQL ordered by Executions'){
        $tmpstr=@item1[3];
        @item1[3]=$item1[4];
        @item1[4]=$tmpstr;
      }else{
        $item1Length=@item1;
        $tmpstr=@item1[$item1Length-1];
        @item1[$item1Length-1]=0;
        @item1[$item1Length]=$tmpstr; 
      }
      ($tmpstr)=&parseStatsOfSQL($line,0);
      $tmpstr='unknown' if($tmpstr eq '');
      $item1Length=@item1;
      @item1[$item1Length]=$tmpstr;
      @result=(*item1);
      $lastLineIsUseful=0;
    }
  } # End of SQL ordered by Gets/Reads/Executions...
  elsif ($mode eq 'Instance Activity Stats'){     # Instance Activity Stats
    @item1=&parseMultiValues($line,3,'SPACE');
    @result=(*item1) if(@item1>0);
  } # End of Instance Activity Stats
  elsif ($mode eq 'Tablespace IO Stats'||$mode eq 'File IO Stats'){     # Tablespace IO Stats 
    if(!$lastLineIsUseful && ($line=~/^\s*([A-Z][A-Z|\d|_]*)\s*$/||$line=~/^\s*([A-Z][A-Z|\d|_]*)\s+(\S+)\s*$/)){
      @item1[0]=$1;
      @item1[1]=$2 if($mode eq 'File IO Stats');
      $lastLineIsUseful=1;
    }elsif($lastLineIsUseful){
      @item2=&parseMultiValues($line,8,'SPACE','NOHEAD');
      if(@item2>0 && @item1>0){
        @item1=(@item1[0],@item2) if ($mode eq 'Tablespace IO Stats'); 
        @item1=(@item1[0],@item1[1],@item2) if ($mode eq 'File IO Stats'); 
        @result=(*item1);
      }
      $lastLineIsUseful=0;
    }
  } # End of Tablespace IO Stats
  return(@result);
}

sub parseStatsOfSQL {
  my($line,$values)=@_;
  my($pattern,$tmpstr)=('','');
  my($i,$j)=(0,0);
  my(@item)=();
  if($values>0){
    $pattern='\\s*';
    for ($i=1;$i<=$values;$i++){
      $pattern.='(-?[\\d,]+\\.?\\d*|-?\\.\\d+|N/A)\\s+'; 
    }
    $pattern.='(\\S+)$';
    if ($line=~/$pattern/){
      for($i=0;$i<=$values;$i++){
        $j=$i+1;
        $tmpstr=$$j;
        $tmpstr=~ s/,//g;
        $tmpstr=~ s/^\./0\./;
        $tmpstr=~ s/^-\./-0\./;
        @item[$i]=$tmpstr;
      }
    }
  }elsif($line=~/^\s?Module:\s+(\S.*)/ ){
    $tmpstr=$1;
    $tmpstr=~s/\s+$//;
    $tmpstr=~s/\s+/_/g;
    @item=($tmpstr);
  }
  return (@item);
}

sub parseMultiValues {
  my($line,$values,$splitBySpace,$noHead)=@_;
  my(@item)=();
  my($i,$j)=(0,0);
  my($pattern,$tmpstr)=('','');
  if($noHead eq 'NOHEAD'){
    if($splitBySpace eq 'SPACE'){
      $pattern='\\s*';
    }
  }else{
    if($splitBySpace eq 'SPACE'){
      $pattern.='(\S.*)' ;
    }else{
      $pattern.='([^:]+):';
    }
  }
  for ($i=1;$i<=$values;$i++){
    $pattern.='\\s+(-?[\\d,]+\\.?\\d*|-?\\.\\d+)'; 
  }
  $pattern.='[\s|$]';
  if ($line=~/$pattern/){
    @item[0]=$1;
    for($i=1;$i<=$values;$i++){
      $j=$i+1;
      $tmpstr=$$j;
      $tmpstr=~ s/,//g;
      $tmpstr=~ s/^\./0\./;
      $tmpstr=~ s/^-\./-0\./;
      @item[$i]=$tmpstr;
    }
    @item[0]=~s/\s+$//;
    @item[0]=~s/\s+/_/g;
  }
  return(@item);
}

sub parseMultiColumns {
  my($line,$columns)=@_;
  my(@result)=();
  return (@result) if($columns>4);
  my($i,$j,$k)=(0,0,0);
  my($pattern)='\\s*';
  for($i=0;$i<$columns;$i++){
    $pattern.='\s*([^:]*):\\s+(-?[\\d,]+\\.?\\d*|-?\\.\\d+)';
  }
  $pattern.='[\s|$]';
  if ($line=~/$pattern/){
    for($i=1;$i<=$columns;$i++){
      $j=2*$i-1;
      $k=2*$i;
      $tmpName=$$j;
      $tmpValue=$$k;
      $tmpName=~s/\s+$//;
      $tmpName=~s/\s+/_/g;
      $tmpValue=~s/,//g;
      $tmpValue=~ s/^\./0\./;
      $tmpValue=~ s/^-\./-0\./;
      $j=$i-1;
      *itemPointer=@itemSet[$j];
      @itemPointer=($tmpName,$tmpValue);
      @result[$j]=*itemPointer;
    }
  }
  return(@result);
}

# Change to corespondent content mode according to the content block definition
sub contentMode {
  my($line,$mode)=@_;
  if($line=~/^\s?(\S+.*\S+)\s*DB\/Inst:\s+\S+\s+Snaps:\s+\d+-\d+$/
   || $line=~/^\s?(\S+.*\S+)\s*DB\/Inst:\s+\S+\s+Snap:\s+\d+$/
   || $line=~/^\s?(\S+.*\S+)\s*DB\/Inst:\s+\S+\s+Snaps:\s+\d+$/
   || $line=~/^\s?(Load Profile)\s+Per Second\s+Per Transaction\s+Per Exec\s+Per Call$/
   || $line=~/^\s?(Instance Efficiency Percentages)\s+\(Target 100%\)$/
   || $line=~/^\s?(Shared Pool Statistics)\s+Begin\s+End$/
   || $line=~/^\s?(Top 5 Timed Foreground Events)$/
   || $line=~/^\s?(Instance CPU)$/
   || $line=~/^\s?(Instance CPU)$/
   || $line=~/^\s?(Memory Statistics)$/
   || $line=~/^\s?(Cache Sizes)\s+Begin\s+End$/
   || $line=~/^\s*(Snap Id)\s+Snap Time\s+Sessions\s+Curs\/Sess$/
  ){
    $mode=$1;
  }
  return ($mode);
}
