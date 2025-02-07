# create symlinks to the yocto sdk toolchain in all the places that need one

if [[ -z "$1" ]] ; then
  echo "no input arg; using ARC SDK"
  TARGET=ARC
elif [[ "$1" == "ARC" ]] ; then
  echo "using ARC SDK"
  TARGET=ARC
elif [[ "$1" == "DLS" ]] ; then
  echo "using DLS SDK"
  TARGET=DLS
elif [[ "$1" == "SuperDARC" ]] ; then
  echo "using SuperDARC SDK"
  TARGET=SuperDARC
elif [[ "$1" == "SuperShark" ]] ; then
  echo "using SuperShark SDK"
  TARGET=SuperShark
else
  echo "unsupported SDK - $1"
  exit 1
fi

# Absolute path to this script
SCRIPTPATH=$(readlink -f $0)
# Absolute directory this script is in
YOCTODIR=`dirname $SCRIPTPATH`
pushd $YOCTODIR > /dev/null 2>&1
TOOLCHAINSETUP=$YOCTODIR/sdk/$TARGET/environment-setup-cortexa8hf-neon-oe-linux-gnueabi

declare -a arr=("../u-boot"
                "../AngelShark/Linux/application-server" 
                "../AngelShark/Linux/fwUpdate"
                "../DwarfLanternShark/Linux/application-server" 
                "../SuperDARC/application-server"
                "../SuperShark/application-server"
                "../WebsocketAPI/cloud-proxy"
                "../WebsocketAPI/leatcp-proxy"
                "../WebsocketAPI/ipcTool"
                "../WebsocketAPI/kvsTool"
                "../WebsocketAPI/stm32flash"
                )
for i in "${arr[@]}"
do
   pushd $i
   ln -sf $TOOLCHAINSETUP toolchainSetup
   popd > /dev/null 2>&1 
done

# display all the symlinks
# cd ..
# find . -name toolchainSetup -execdir pwd \; -execdir ls -la {} \;

popd > /dev/null 2>&1 
