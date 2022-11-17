#!/bin/bash
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DIR=$(realpath $SCRIPT_DIR/../)
L4T_DIR="${DIR}/Linux_for_Tegra"

TARGET_BOARD=${TARGET_BOARD:-"jetson-xavier-nx-devkit-emmc"}
TARGET_DEVICE=${TARGET_DEVICE:-"mmcblk0p1"}

cd ${L4T_DIR}
sudo -v
while true; do sudo -n true; sleep 120; kill -0 "$$" || exit; done 2>/dev/null &

./flash.sh $TARGET_BOARD $TARGET_DEVICE
