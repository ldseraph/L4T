#!/bin/bash
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DIR=$(realpath $SCRIPT_DIR/../)
DOWNLOADS_DIR=${DIR}/downloads

L4T_BOARD=${L4T_BOARD:-"avier-nx"}
L4T_VERSION=${L4T_VERSION:-"5.0.2"}
L4T_PKG=${L4T_PKG:-"k8"}

function parse_args()
{
  case "${L4T_BOARD}" in
  agx-orin)
    boardid="3701"
    target="jetson-agx-orin-devkit"
    tgt="jao"
    tnum="T234"
    ;;
  agx-xavier)
    boardid="2822"
    target="jetson-agx-xavier-devkit"
    tgt="jax"
    tnum="T194"
    ;;
  xavier-nx)
    boardid="3668"
    target="jetson-xavier-nx-devkit"
    tgt="xnx"
    tnum="T194"
    ;;
  *)
    echo "Unknown board: ${board}"
    exit 1
    ;;
  esac

  case "${L4T_VERSION}" in
  5.0.2)
    jetpack="5.0.2"
    MAJOR="35"
    MINOR="1"
    PATCH="0"
    ARCH="aarch64"
    L4T_VER="${MAJOR}.${MINOR}.${PATCH}"
    RELEASE="20.04"
    ;;
  *)
    echo "Unknown/Non-supported JetPack version: ${L4T_VERSION}"
    exit 1
    ;;
  esac

  L4T_RELEASE_PACKAGE_NAME="Jetson_Linux_R"${L4T_VER}"_"${ARCH}".tbz2" 
  SAMPLE_FS_PACKAGE_NAME="Tegra_Linux_Sample-Root-Filesystem_R"${L4T_VER}"_"${ARCH}".tbz2" 

  if [ -z ${FLAVOR+x} ]; then
    FLAVOR="sample-root"
    RFS_PACKAGE=${DOWNLOADS_DIR}/${SAMPLE_FS_PACKAGE_NAME}
    rfs_name="-gui"
  else
    if [ -f $DIR/rfs_flavors/nvubuntu-${RELEASE}-${FLAVOR}-${ARCH}-packages ]; then
      RFS_PACKAGE="(to-be-generated)"
      rfs_name="-${FLAVOR}"
    else
      echo "[ERROR] Specified custom flavor package file does not exists"
      echo "    '${DIR}/rfs_flavors/nvubuntu-${RELEASE}-${FLAVOR}-${ARCH}-packages'"
      exit 1
    fi
  fi
}
parse_args

L4T_DIR=${DIR}/Linux_for_Tegra
L4T_ROOTFS_DIR=${L4T_DIR}/rootfs

echo "| JetPack version is ${jetpack}"
echo "| L4T version is ${L4T_VER}"
echo "| Specified board is ${L4T_BOARD} ('$tgt')"
echo "| DIR:     ${DIR}"
echo "| L4T_DIR: ${L4T_DIR}"
echo "|"
echo "| RFS flavor: ${FLAVOR}"
echo "| rfs_name:   ${rfs_name}"
echo "| RFS_pkg:    ${RFS_PACKAGE}"
echo "|"

cd ${DIR}
sudo -v
while true; do sudo -n true; sleep 120; kill -0 "$$" || exit; done 2>/dev/null &

###########################################
###   Step 1.  Download package files   ###
###########################################
echo " "
echo " ############################################################"
echo " # Step 1. Download L4T package files "
echo " ############################################################"

mkdir -p ${DOWNLOADS_DIR} > /dev/null 2>&1

if [[ ! -f ${DOWNLOADS_DIR}/${L4T_RELEASE_PACKAGE_NAME} ]]; then
  wget https://developer.download.nvidia.com/embedded/L4T/r"${MAJOR}"_Release_v"${MINOR}"."${PATCH}"/Release/${L4T_RELEASE_PACKAGE_NAME} -P ${DOWNLOADS_DIR} -q --show-progress
fi

if [ "${RFS_PACKAGE}" != "(to-be-generated)" ] && [[ ! -f ${DOWNLOADS_DIR}/${SAMPLE_FS_PACKAGE_NAME} ]]; then
  wget https://developer.download.nvidia.com/embedded/L4T/r"${MAJOR}"_Release_v"${MINOR}"."${PATCH}"/Release/${SAMPLE_FS_PACKAGE_NAME} -P ${DOWNLOADS_DIR} -q --show-progress
fi

################################################################################
###   Step 2.  Create ./Linux_for_Tegra/ and ./Linux_for_Tegra/rootfs dir    ###
################################################################################
echo " "
echo " ############################################################ "
echo " # Step 2. Creating 'Linux_for_Tegra' directory "
echo " ############################################################ "

if [[ ! -d ${L4T_DIR} ]]; then
  echo "Extracting ${L4T_RELEASE_PACKAGE_NAME}"
  tar xpvf ${DOWNLOADS_DIR}/${L4T_RELEASE_PACKAGE_NAME} -C ${DIR}
fi

if [[ `ls -l ${L4T_ROOTFS_DIR} | wc -l` -lt 3 ]]; then
  if [ "${RFS_PACKAGE}" != "(to-be-generated)" ]; then
    echo "Extracting ${SAMPLE_FS_PACKAGE_NAME}"
    tar xpvf ${DOWNLOADS_DIR}/${SAMPLE_FS_PACKAGE_NAME} -C ${L4T_ROOTFS_DIR}
  else
    RFS_PACKAGE=${DOWNLOADS_DIR}/sample_fs.tbz2
    if [[ ! -f ${RFS_PACKAGE} ]]; then
      echo " "
      echo " ********************************************************** "
      echo " * Going to rebuilt rootfs using nv_build_samplefs.sh ..."
      echo " ********************************************************** "
      sudo docker run --privileged --rm --network host \
                      -v ${DIR}:/l4t ubuntu:20.04 \
                      /l4t/scripts/build_rfs_custom.sh ${FLAVOR} ${ARCH} ${RELEASE}
    fi
    cd ${L4T_ROOTFS_DIR}
    sudo rm -rf ./*
    sudo tar xpf ${RFS_PACKAGE}
  fi
fi
