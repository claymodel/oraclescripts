# this script is intended to be used by the other ones.
# don't run it directly!

# new better (but not perfect) way
OSVERNUM=`lsb_release -r | awk '{print $NF}'`

# the string should be MAJOR.MINOR
# the next couple of lines assume it's formatted correctly
# I *SHOULD* add a test to make sure
OS_VER=`echo $OSVERNUM | sed -e 's/\..*//'`
OS_UPDATE=`echo $OSVERNUM | sed -e 's/.*\.//'`

echo "Running on version $OS_VER update $OS_UPDATE"

# it was silly to do it this way:
#
#if [ "$OSVERNUM" == "5.6" ]; then
#    echo "Running on version 5 update 6"
#    OS_VER=5
#    OS_UPDATE=6
#elif [ "$OSVERNUM" == "6.2" ]; then
#    echo "Running on version 6 update 2"
#    OS_VER=6
#    OS_UPDATE=2
#elif [ "$OSVERNUM" == "6.3" ]; then
#    echo "Running on version 6 update 3"
#    OS_VER=6
#    OS_UPDATE=3
#else
#  echo "Update the osver.sh script please."
#  exit
#fi
