if [ $(id -u) == "0" ] ; then
    echo "script execution as root not supported" >&2
    exit 1
fi

# Absolute path to this script
SCRIPTPATH=$(readlink -f ${BASH_SOURCE[0]})
# Absolute directory this script is in
BUILDDIR=`dirname $SCRIPTPATH`
cd $BUILDDIR

TARGET=SuperDARC
IMAGE=core-image-minimal
YOCTODIR=$(realpath ..)
ENVSETUP=poky/oe-init-build-env
SDKDIR=$YOCTODIR/sdk/$TARGET
