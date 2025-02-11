echo "building stm32 firmware"

set -e # exit on error

RECIPE_DIR=$(realpath ../meta-lea-supershark/recipes-core/application-server-service/files)

declare -a arr=("PSSS" "PSOK" "AMSS" "AMOK")

for proj in "${arr[@]}"
do
  pushd ../../SuperShark/$proj
  make clean
  make
  cp obj/$proj.zip $RECIPE_DIR
  popd > /dev/null 2>&1 
done
