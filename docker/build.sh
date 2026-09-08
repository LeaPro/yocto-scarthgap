#!/bin/bash
#
# This script creates the yocto-ready docker image.
# The --build-arg options are used to pass data about the current user.
# Also, a tag is used for easy identification of the generated image.
#
DOCKER_IMAGE_TAG=lea-yocto-scarthgap
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
YOCTO_DIR=$(realpath "$SCRIPT_DIR/..")

# Keep the normal cached build path fast, but allow an explicit clean rebuild when needed.
# use DOCKER_NO_CACHE=1 DOCKER_PULL_BASE=1 ./build.sh to force a clean rebuild and pull the latest base image.
DOCKER_BUILD_FLAGS=()
if [[ ${DOCKER_NO_CACHE:-0} == 1 ]]; then
    DOCKER_BUILD_FLAGS+=(--no-cache)
fi
if [[ ${DOCKER_PULL_BASE:-0} == 1 ]]; then
    DOCKER_BUILD_FLAGS+=(--pull)
fi

docker build "${DOCKER_BUILD_FLAGS[@]}" --tag "${DOCKER_IMAGE_TAG}" \
             --build-arg "WORKDIR=$(realpath "$YOCTO_DIR")" \
             --build-arg "USER=$(whoami)" \
             --build-arg "host_uid=$(id -u)" \
             --build-arg "host_gid=$(id -g)" \
             "$SCRIPT_DIR"
