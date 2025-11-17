echo "building stm32 firmware"

set -e # exit on error

RECIPE_DIR=$(realpath ../meta-lea-pilotfish/recipes-core/application-server-service/files)

pushd ../../DwarfLanternSharkStm32
make clean
make
cp obj/Pilotfish.zip $RECIPE_DIR
popd > /dev/null 2>&1 
