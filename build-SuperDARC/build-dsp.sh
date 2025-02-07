echo "Building SuperDARC dsp code"
source build-setup.sh
cd ~/LEA/SuperDARC/dspCode
./build.sh 
cp ~/LEA/SuperDARC/dspCode/SuperDARC/Release-Linux/SuperDARC.dxe $YOCTODIR/meta-lea-superdarc/recipes-core/application-server-service/files/
cp ~/LEA/SuperDARC/dspCode/SuperDARC/Release-Linux/SuperDARC.ldr $YOCTODIR/meta-lea-superdarc/recipes-core/application-server-service/files/
