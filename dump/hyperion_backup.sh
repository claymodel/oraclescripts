#!/usr/bin/bash
export ORACLE_HOME=/homedir/app/oracle/product/10.2.0.1
export ORACLE_BASE=/homedir/app/oracle
export ORACLE_SID=hyperion

LOG=/export/home/oracle/backups/log.file

##id's to be mailed upon success or failure
ADMINS="android.hasnat@gmail.com"

MYNAME="`basename $0`"          ## Name of this Script
MYHOST="`hostname`"             ## Hostname

#Initial message for email content
echo "Oracle $MYHOST Backup" |tee $LOG

## Welcome Message
echo "---------- ---------- ---------- ----------" |tee -a $LOG
date                                               |tee -a $LOG
echo "$MYNAME : $MYHOST"                           |tee -a $LOG
echo "Begining backup of client systems"           |tee -a $LOG
echo "---------- ---------- ---------- ----------" |tee -a $LOG

/homedir/app/oracle/product/10.2.0.1/bin/exp hyphss/hyperion123@hyperion file= /export/home/oracle/backups/dumps/HYPHSS_`date +"%Y%m%d"`.dmp compress=N indexes=Y consistent=Y owner=hyphss;

/homedir/app/oracle/product/10.2.0.1/bin/exp hypeas/hyperion123@hyperion  file=/export/home/oracle/backups/dumps/HYPEAS_`date +"%Y%m%d"`.dmp compress=N indexes=Y consistent=Y owner=hypeas;

/homedir/app/oracle/product/10.2.0.1/bin/exp hypplanapp1/hyperion123@hyperion  file=/export/home/oracle/backups/dumps/HYPPLANAPP1_`date +"%Y%m%d"`.dmp compress=N indexes=Y consistent=Y owner=hypplanapp1;

/homedir/app/oracle/product/10.2.0.1/bin/exp hypplanapp2/hyperion123@hyperion  file=/export/home/oracle/backups/dumps/HYPPLANAPP2_`date +"%Y%m%d"`.dmp compress=N indexes=Y consistent=Y owner=hypplanapp2;

/homedir/app/oracle/product/10.2.0.1/bin/exp hypbiplus/hyperion123@hyperion  file=/export/home/oracle/backups/dumps/HYPBIPLUS_`date +"%Y%m%d"`.dmp compress=N indexes=Y consistent=Y owner=hypbiplus;

/homedir/app/oracle/product/10.2.0.1/bin/exp hypplansys/hyperion123@hyperion  file=/export/home/oracle/backups/dumps/HYPPLANSYS_`date +"%Y%m%d"`.dmp compress=N indexes=Y consistent=Y owner=hypplansys;

/usr/bin/gzip /export/home/oracle/backups/dumps/*_`date +"%Y%m%d"`.dmp |tee -a $LOG

/usr/bin/tar -cvf /export/home/oracle/backups/tars/hyperionschemasdb02_`date +"%Y%m%d"`.tar /export/home/oracle/backups/dumps/*_`date +"%Y%m%d"`.dmp.gz |tee -a $LOG

/usr/bin/scp /export/home/oracle/backups/tars/hyperionschemasdb02_`date +"%Y%m%d"`.tar hyperion@10.50.2.253:/backup/OracleBackup/ |tee -a $LOG

/usr/bin/scp /export/home/oracle/backups/tars/hyperionschemasdb02_`date +"%Y%m%d"`.tar hyperion@10.50.2.254:/backup/OracleBackup/ |tee -a $LOG

/usr/bin/uuencode /export/home/oracle/backups/tars/hyperionschemasdb02_`date +"%Y%m%d"`.tar hyperionschemasdb02_`date +"%Y%m%d"`.tar|mailx -s hyperionschemasdb02_`date +"%Y%m%d"`.tar email@shafiq.in

## FINISH UP
echo "..." |tee -a $LOG
echo "Finishing Up At: " |tee -a $LOG
echo " " |tee -a $LOG
date | tee -a $LOG

#email report
cat $LOG | sed -e "/^## /d" |  mailx -s"Oracle $MYHOST Backup Log" $ADMINS

#mv hyperionschemasdb01_`date +"%Y%m%d"`.tar /export/home/oracle/backups/tars
