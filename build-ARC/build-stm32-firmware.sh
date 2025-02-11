echo "building stm32 firmware"

set -e # exit on error

RECIPE_DIR=../meta-lea-arc/recipes-core/application-server-service/files

PSAS_DIR=../../AngelShark/PSAS
PSAS_HEX=$PSAS_DIR/obj/PSAS.hex
pushd $PSAS_DIR
make clean
make
popd
cp $PSAS_HEX $RECIPE_DIR

AMAS_DIR=../../AngelShark/AMAS
AMAS_HEX=$AMAS_DIR/obj/AMAS.hex
pushd $AMAS_DIR
make clean
make
popd
cp $AMAS_HEX $RECIPE_DIR

PSBT_DIR=../../BlackTip/PSBT
PSBT_HEX=$PSBT_DIR/obj/PSBT.hex
pushd $PSBT_DIR
make clean
make
popd
cp $PSBT_HEX $RECIPE_DIR

AMBT_DIR=../../BlackTip/AMBT
AMBT_HEX=$AMBT_DIR/obj/AMBT.hex
pushd $AMBT_DIR
make clean
make
popd
cp $AMBT_HEX $RECIPE_DIR
