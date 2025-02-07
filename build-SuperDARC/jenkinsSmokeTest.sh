#get current date
DATE=`date +%m-%d-%Y`

#extract version number from version.h
VERSION=`python3 getVersionNumber.py`

#store outfile name
OUTFILE=/home/jenkins/LEA/yocto-kirkstone/build-SuperDARC/postBuild/images/BS-${VERSION}-LEA-SuperDARC-${DATE}.tar.xz.enc

BULLSHARK_IP=10.8.2.130

cd /home/jenkins/LEA/Jenkins/jenkinsSmokeTest/src

echo ""
echo "Running firmware smoke test on Bullshark Amp: ${BULLSHARK_IP}"
python3 main.py ${BULLSHARK_IP} ${OUTFILE}

RETURN=$?

if [ $RETURN -eq 0 ];
then
    echo "Firmware smoke test successful on Bullshark Amp: ${BULLSHARK_IP}"
else
    echo "Firmware smoke test failed on Bullshark Amp: ${BULLSHARK_IP}"
    echo "Returning with exit code ${RETURN}"
    exit $RETURN
fi
