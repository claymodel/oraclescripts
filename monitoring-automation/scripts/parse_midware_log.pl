#?/bin/perl
$params=@ARGV;

$targetTime=time()-2*60;
$year=(localtime $targetTime)[5]+1900;
$month=(localtime $targetTime)[4]+1;
$day=(localtime $targetTime)[3];
$hour=(localtime $targetTime)[2];
$minute=(localtime $targetTime)[1];

if($month<10){$month="0$month";};
if($day<10){$day="0$day";};
if($hour<10){$hour="0$hour";};
if($minute<10){$minute="0$minute";};

$timeStr_Date=$year . $month . $day ;
$timeStr_Time=$hour . ':' . $minute .':';

$lastSecond='';
$phone_in='';
$userid_in='';
$region='';
$region_status='';
$param='';
$phone_param='';
$userid_param='';
$service='';
$service_status='';
$service_return='';
$message_return='';

$recorded=0;

sub print_line {
	$timeStr=$year.$month.$day.$hour.$minute.$lastSecond;
	if($lastSecond eq ""){$timeStr='19000101000000';}
	if($phone_in eq ""){$phone_in='unknown';}
	if($userid_in eq ""){$userid_in='unknown';}
	if($region eq ""){$region='unknown';}
	if($region_status eq ""){$region_status='unknown';}
	if($param eq ""){$param='unknown';}
	if($phone_param eq ""){$phone_param='unknown';}
	if($userid_param eq ""){$userid_param='unknown';}
	if($service eq ""){$service='unknown';}
	if($service_status eq ""){$service_status='unknown';}
	if($service_return eq ""){$service_return='unknown';}
	if($message_return eq ""){$message_return='unknown';}

	print "$timeStr $phone_in $userid_in $region $region_status $param $phone_param $userid_param $service $service_status $service_return $message_return\n";

        $lastSecond='';
        $phone_in='';
        $userid_in='';
        $region='';
        $region_status='';
        $param='';
        $phone_param='';
        $userid_param='';
        $service='';
        $service_status='';
        $service_return='';
        $message_return='';
	
	$recorded=0;

}

if($params>0){
	$filename=@ARGV[0];
	if(-e $filename && -f $filename) {
		if(open(MIDWARE_LOGFILE,$filename)){
			$lastSecond='00';
			$recorded=0;
			while ($line=<MIDWARE_LOGFILE>){
				if($line=~/\/\/-----------+/){
					if($recorded){
						&print_line;
					}
					if( $line=~/$timeStr_Date +$timeStr_Time?(\d+):/){
                                        	$second=$1;
                                        	$lastSecond=$second;
						$recorded=1;
					}
					else{
						$recorded=0;
					}
				}
				if($recorded){
					if($line=~/传入的数据：?(\d+)\W?(\w+)\W/){
						$phone_in=$1;
						$userid_in=$2;
						$recorded=1;
					}
					if($line=~/用Region\s?(\w+)\s?(\S+)\W/){
						$region=$1;
						$region_status=$2;
					}
					if($line=~/输入参数\S+\s=\s?(\w+)\W:?(\d+)\W?(\w+)\W/){
						$param=$1;
						$phone_param=$2;
						$userid_param=$3;
					}
					if($line=~/调用服务?(\w+)/){
						$service=$1;
					}
					if($line=~/调用服务\w+?(\W+),/){
						$service_status=$1;
					}
					elsif($line=~/调用服务?(\S+)/){
						$service_status=$1;
					}
					if($line=~/调用服务\S+返回值Ret=?(\S+)/){
						$service_return=$1;
					}
					if($line=~/据处理完毕,返回消息包为:?(\S+)/){
						$message_return=$1;
					}
				}
			}
			if($recorded){
				&print_line;
			}
			close(MIDWARE_LOGFILE);
		}
	}else{
		print "can't find file $filename";
		exit;
	}
}
else {
	print "please specify the target file name\n";
}
