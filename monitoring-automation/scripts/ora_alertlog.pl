#!/bin/perl
$seekminites=$ARGV[0];
$seekdistance=-1024000*$seekminites;
$filename=$ARGV[1];

@months{qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)} = (1..12);
@start_time=split(' ',scalar localtime (time()-$seekminites*60));
$s_yy=$start_time[4];
$s_mm=$months{$start_time[1]};
$s_dd=$start_time[2];
@tmpt=split(':',$start_time[3]);
$s_hh=$tmpt[0];
$s_mi=$tmpt[1];
$s_ss=$tmpt[2];

if ( -e $filename ) {
        open(myfile , $filename) || die("Can't open file " . $filename );
	$segment_begin=0;
	$line_no=0;
	$timestr="";

	seek(myfile,$seekdistance,2);
	
	$logtime="";
	$process=0;
        while ( $mystr=<myfile>){
                if ($mystr =~ /(.*)([A-z][a-z]{2}\s+[A-Z][a-z]{2}\s+\d{1,2}\s+\d{1,2}:\d{1,2}:\d{1,2}\s+\d{4})(.*)/ ){
                	$timestr="$2";

			$timestr=~/[A-z][a-z]{2}\s+([A-z][a-z]{2})\s+(\d{1,2})\s+(\d{1,2}):(\d{1,2}):(\d{1,2})\s+(\d{4})/;
			$yy=$6;
			$mm=$months{$1};
			$dd=$2;
			$hh=$3;
			$mi=$4;
			$ss=$5;	

			if(!$process && ($yy>$s_yy ||
			   $yy==$s_yy && $mm>$s_mm ||
			   $yy==$s_yy && $mm==$s_mm && $dd>$s_dd ||
			   $yy==$s_yy && $mm==$s_mm && $dd==$s_dd && $hh>$s_hh ||
			   $yy==$s_yy && $mm==$s_mm && $dd==$s_dd && $hh==$s_hh && $mi>$s_mi||
			   $yy==$s_yy && $mm==$s_mm && $dd==$s_dd && $hh==$s_hh && $mi==$s_mi && $ss>=$s_ss)) {

				$process=1;
			}
			if($process){
				if($mm<10){
					$mm="0$mm";
				}
				if($dd<10){
					$dd="0$dd";
				}
				$logtime="$yy$mm$dd$hh$mi$ss";
				$line_no=0;
			}
		}elsif ($process) {
			$line_no++;
			print "$logtime $line_no $mystr"
		}
        }
}
