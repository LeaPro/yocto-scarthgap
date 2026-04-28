#!/bin/bash
#
# This script creates the yocto-ready docker image.
# The --build-arg options are used to pass data about the current user.
# Also, a tag is used for easy identification of the generated image.
#
DOCKER_IMAGE_TAG=lea-yocto-scarthgap
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
YOCTO_DIR=$(realpath $SCRIPT_DIR/..)

docker build --tag "${DOCKER_IMAGE_TAG}" \
             --build-arg "WORKDIR=$(realpath $YOCTO_DIR)" \
             --build-arg "USER=$(whoami)" \
             --build-arg "host_uid=$(id -u)" \
             --build-arg "host_gid=$(id -g)" \
             $SCRIPT_DIR
