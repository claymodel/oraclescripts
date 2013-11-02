#!/bin/bash

. `dirname $0`/settings.sh

umask 077

if [ "$JAVA_HOME" == "" ]; then
    echo JAVA_HOME not set. Log out and back in?
    exit
fi

cd $USER_HOME

if [ ! -e rcuHome ]; then
    echo rcuHome does not exist!
    exit
fi

cd $USER_HOME/rcuHome/bin

echo ConnectString is $CONNECT_STRING
echo using Database password "$ORA_PASS" for all schemas


TEMPFILE=/tmp/$$.pwd

# which component schemas do you want created
COMPONENTS=(MDS SOAINFRA OID OIF OIM OPAM OAM OAAM APM IAU OPSS ORASDPM)

# the number of passwords is larger than the number of components
# when in doubt run the script, then increment this by one if you get an error
NUMPASSWORDS=14


# OK, good to go

NUMCOMPONENTS=${#COMPONENTS[@]}
#echo Operating on $NUMCOMPONENTS schemas

for (( i=0; i<${NUMCOMPONENTS}; i++ ));
do
    RCUARG="$RCUARG -component ${COMPONENTS[$i]}"
done


# should we drop the existing schema?
echo Drop the existing schemas?
#echo  Y or N and press return
read -p "Press Y or N" -n 1 DROPSCHEMAS
if [ "Y" == "$DROPSCHEMAS" ] || [ "y" == "$DROPSCHEMAS" ]; then
    # drop
    echo Dropping existing repositories.
    echo If those repositories do not exist, you will have an error message, but that\'s OK.
    echo $ORA_PASS > $TEMPFILE
    ./rcu -silent -dropRepository -connectString $CONNECT_STRING -dbUser sys -dbRole sysdba -lockSchemas false -schemaPrefix $SCHEMA_PREFIX -f $TEMPFILE $RCUARG < $TEMPFILE
    rm -rf $TEMPFILE
fi

for (( i=0; i<${NUMPASSWORDS}; i++ ));
do
    echo $ORA_PASS >> $TEMPFILE
done
wc -l $TEMPFILE

#echo RCU component arg: $RCUARG

echo Running RCU to create schemas
# create
./rcu -silent -createRepository -connectString $CONNECT_STRING -dbUser sys -dbRole sysdba -lockSchemas false -schemaPrefix $SCHEMA_PREFIX -f $TEMPFILE $RCUARG < $TEMPFILE
#./rcu -silent -createRepository -connectString $CONNECT_STRING -dbUser sys -dbRole sysdba -lockSchemas false -schemaPrefix $SCHEMA_PREFIX $RCUARG < $TEMPFILE

rm -f $TEMPFILE
