echo "copying outfile to JenkinsBuilds folder"

#get current date
DATE=`date +%m-%d-%Y`
#extract version number from version.h
VERSION=`python3 getVersionNumber.py`
#store outfile name
OUTFILE=postBuild/images/BS-${VERSION}-LEA-SuperDARC-${DATE}.tar.xz.enc
CPYDIR=~/engineering/Firmware/JenkinsBuilds/BullShark/Kirkstone/SuperDARC/${VERSION}
#echo "$CPYDIR"
#copy outfile to M:Engineering drive
mkdir -p $CPYDIR
cp $OUTFILE $CPYDIR
