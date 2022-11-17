#!/bin/bash
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DIR=$(realpath $SCRIPT_DIR/../)
DOWNLOADS_DIR=${DIR}/downloads
L4T_DIR=${DIR}/Linux_for_Tegra

sudo -v
while true; do sudo -n true; sleep 120; kill -0 "$$" || exit; done 2>/dev/null &

sudo rm -rf $DOWNLOADS_DIR
sudo rm -rf $L4T_DIR
