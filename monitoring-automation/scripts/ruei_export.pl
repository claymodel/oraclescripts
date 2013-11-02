#!/usr/bin/perl

  use Encode;

  $url_target=$ARGV[0];
  $url_base="http://" . $url_target . "/export.php?id=";
  $url_id=$ARGV[1];
  $url_date=$ARGV[2];
  $url = $url_base . $url_id . "&date=" . $url_date;

  use LWP::Simple;
  $content=get $url;
  die "Can't get $url" unless defined $content ;

  $_=$content;
  /<rows>.+<\/rows>/s;
  $content=$&;

  $content=~s/<rows>|<\/rows>//gs;
  $content=~s/[\n\r]+//g;
  @rows=split(/<row>|<\/row>/, $content);
  $row_cnt=@rows;

  for ($i=0;$i<$row_cnt;++$i){
    $l=length($rows[$i]);
    if($l>0){
      $row=$rows[$i];
      @columns=split(/<column>|<\/column>/,$row);
      $c=@columns;
      for($j=0;$j<$c;$j++){
        if(length($columns[$j])>0){
          $column=$columns[$j];
          $column=~s/<value>|<\/value>|<name>.*<\/name>//g;
          if($column=~/^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/){
            print $column * 1;
          }else{
            if(length($column)>0){
              $column=~s/ » /=>/g;
              $column=~ s/ /_/g;
	      $column=encode("gb2312",decode("utf8",$column));
              print "$column";
            }else{
              print "0";
            }
          }
          if($j+1==$c){
            print "\n";
          }else{
            print " ";
          }
        }
      }
    }
  }
