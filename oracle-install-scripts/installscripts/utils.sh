check_not_root() {

	if [ "$USER" == "" ]; then
    	echo Could not determine user identity.
    	exit 1
	elif [ "$USER" == "root" ]; then
    	echo "STOP!"
	    echo "You are supposed to unzip the database installer and install it"
    	echo "either by hand or with this script"
	    exit
	elif [ "$USER" != "$ORA_USER" ]; then
    	echo "STOP!"
	    echo "You should be running this as $ORA_USER"
	fi

}

check_workspace() {
	if [ ! -e $WORKSPACE ]; then
		echo Workspace $WORKSPACE does not exit.
		echo creating
		mkdir $WORKSPACE
	fi
	
	pushd $WORKSPACE > /dev/null
	if [ `pwd` != $WORKSPACE ]; then
    	echo "unable to change to $WORKSPACE"
    	echo PWD: `pwd`
    	echo Workspace: $WORKSPACE
    	exit
	fi

}

look_for_zips() {
	# this is a bit of a funny function.
	
	if [ "" != "$ZIPDIR" ]; then
		#echo Already found. Aborting search
		return
	fi

	THISDIR=$1
	echo Checking directory $THISDIR
	if [ ! -e $THISDIR ]; then
		echo $THISDIR does not exist
	else
		pushd $THISDIR > /dev/null
		COUNT=$(ls $PRODUCTZIPS | wc -l )
		popd > /dev/null

		if [ "$COUNT" == "0" ]; then
			echo "* not found here"
		else
			echo "*** $COUNT files found ***"
			ZIPDIR=$THISDIR
		fi

		unset COUNT
	fi
}

prep_productbits() {
	if [ -e $WORKSPACE/$PRODUCTDIR ]; then
		echo $WORKSPACE/$PRODUCTDIR exists. Assuming bits already unzipped
	else
    	# look for the bits in various locations
		echo Locating product ZIP files matching $PRODUCTZIPS

		look_for_zips $INSTALLER_LOCATION
		look_for_zips ~/
		look_for_zips $INSTALLER_LOCATION/$VERSION_TO_INSTALL
		look_for_zips $INSTALLER_LOCATION/$VERSION_TO_INSTALL/shiphome

		if [ "$ZIPDIR" == "" ]; then
			echo Failed to find product ZIP files
			exit
		fi

		# Otherwise unzip them
		
	    echo Unzipping installer into `pwd`/$PRODUCTDIR
    
	    for ZIPFILE in $ZIPDIR/$PRODUCTZIPS
    	do
        	echo Unzipping $ZIPFILE
        	unzip -q $ZIPFILE
	    done
    
    	echo "Unzipping done."
	fi
}

goto_runinstaller_location() {
	if [ -e $WORKSPACE/$PRODUCTDIR/runInstaller ]; then
		pushd $WORKSPACE/$PRODUCTDIR > /dev/null
	elif [ -e $WORKSPACE/$PRODUCTDIR/Disk1/runInstaller ]; then
		pushd $WORKSPACE/$PRODUCTDIR/Disk1 > /dev/null
	else
		echo runInstaller cannot be found
		exit
	fi
	
	echo runInstaller located at `pwd`
}
