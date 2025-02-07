echo "building stm32 firmware"

set -e # exit on error

RECIPE_DIR=$(realpath ../meta-lea-superdarc/recipes-core/application-server-service/files)

declare -a arr=("PSBS" "PSOK" "AMBS" "AMOK")

for proj in "${arr[@]}"
do
  pushd ../../BullShark/$proj
  make clean
  make
  cp obj/$proj.zip $RECIPE_DIR
  popd > /dev/null 2>&1 
done
