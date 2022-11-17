#!/bin/bash
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DIR=$(realpath $SCRIPT_DIR/../)
L4T_DIR=${DIR}/Linux_for_Tegra
DOWNLOADS_DIR=${DIR}/downloads
MIRRORS="http://mirrors.tuna.tsinghua.edu.cn"
# MIRRORS="http://mirrors.aliyun.com"

L4T_HOSTNAME=$1
L4T_USERNAME=$2
L4T_PASSWORD=$3

sed -i "s@http://.*archive.ubuntu.com@${MIRRORS}@g" /etc/apt/sources.list
sed -i "s@http://.*security.ubuntu.com@${MIRRORS}@g" /etc/apt/sources.list

apt-get update
apt-get install -y qemu-user-static wget sudo

mkdir -p "${DOWNLOADS_DIR}/userspace"
mkdir -p "${DOWNLOADS_DIR}/kernel"
mkdir -p "${DOWNLOADS_DIR}/bootloader"
mkdir -p "${DOWNLOADS_DIR}/standalone"

cp "${L4T_DIR}/tools"/*.deb "${DOWNLOADS_DIR}/standalone"
cp "${L4T_DIR}/nv_tegra/l4t_deb_packages"/*.deb "${DOWNLOADS_DIR}/userspace"
cp "${L4T_DIR}/kernel"/*.deb "${DOWNLOADS_DIR}/kernel"
cp "${L4T_DIR}/bootloader"/*.deb "${DOWNLOADS_DIR}/bootloader"

cd ${L4T_DIR}
./apply_binaries.sh --debug
${L4T_DIR}/tools/l4t_create_default_user.sh -u ${L4T_USERNAME} -p ${L4T_PASSWORD} -n ${L4T_HOSTNAME} --accept-license --autologin
