echo "copying outfile to JenkinsBuilds folder"

#get current date
DATE=`date +%m-%d-%Y`
#extract version number from version.h
VERSION=`python3 getVersionNumber.py`
#store outfile name
OUTFILE=postBuild/images/Pilotfish-${VERSION}-LEA-pilotfish-${DATE}.tar.xz.enc
CPYDIR=~/engineering/Firmware/JenkinsBuilds/Pilotfish/Scarthgap/Pilotfish/${VERSION}
#echo "$CPYDIR"
#copy outfile to M:Engineering drive
mkdir -p $CPYDIR
cp $OUTFILE $CPYDIR
