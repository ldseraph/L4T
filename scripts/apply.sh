#!/bin/bash
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DIR=$(realpath $SCRIPT_DIR/../)

L4T_HOSTNAME=${L4T_HOSTNAME:-"inno"}
L4T_USERNAME=${L4T_USERNAME:-"inno"}
L4T_PKG=${L4T_PKG:-"k8"}

if [ -z $L4T_PASSWORD ]; then
  echo "L4T_PASSWORD is null"
  exit 1
fi

function parse_args()
{
  if [ -f ${DIR}/l4t_pkg_lists/l4t_${L4T_PKG}.list ]; then
    l4t_package_list=${DIR}/l4t_pkg_lists/l4t_${L4T_PKG}.list
  else
    echo "[ERROR] Specified custom L4T package list(l4t_${L4T_PKG}.list) file does not exists under ./l4t_pkg_lists dir."
    ls -l ${DIR}/l4t_pkg_lists/*.list
    exit 1
  fi
}
parse_args

L4T_DIR=${DIR}/Linux_for_Tegra
L4T_ROOTFS_DIR=${L4T_DIR}/rootfs

echo "| L4T_HOSTNAME:  ${L4T_HOSTNAME}"
echo "| L4T_USERNAME:  ${L4T_USERNAME}"
echo "| L4T_PASSWORD:  ${L4T_PASSWORD}"
echo "| l4t_package_list: ${l4t_package_list}"

sudo -v
while true; do sudo -n true; sleep 120; kill -0 "$$" || exit; done 2>/dev/null &

cd ${L4T_DIR}
fakeroot sh -c "
  mkdir tmp_deb_core
  dpkg-deb -R ${L4T_DIR}/nv_tegra/l4t_deb_packages/nvidia-l4t-core_35.1.0-20220810203728_arm64.deb tmp_deb_core
  sed -i 's|libegl1,||g' tmp_deb_core/DEBIAN/control
  sed -i 's|,libegl1||g' tmp_deb_core/DEBIAN/control
  sed -i 's|libegl1||g' tmp_deb_core/DEBIAN/control
  dpkg-deb -b tmp_deb_core ${L4T_DIR}/nv_tegra/l4t_deb_packages/nvidia-l4t-core_35.1.0-20220810203728_arm64.deb
  rm -rf tmp_deb_core
"

fakeroot sh -c "
  mkdir tmp_deb_cuda
  dpkg-deb -R ${L4T_DIR}/nv_tegra/l4t_deb_packages/nvidia-l4t-cuda_35.1.0-20220810203728_arm64.deb tmp_deb_cuda
  sed -i 's|,\ nvidia-l4t-3d-core\ (.*)||g' tmp_deb_cuda/DEBIAN/control
  echo '################## ${L4T_DIR}/nv_tegra/l4t_deb_packages/nvidia-l4t-cuda_35.1.0-20220810203728_arm64.deb'
  dpkg-deb -b tmp_deb_cuda ${L4T_DIR}/nv_tegra/l4t_deb_packages/nvidia-l4t-cuda_35.1.0-20220810203728_arm64.deb
  rm -rf tmp_deb_cuda
"
sudo cp -v ${l4t_package_list} ${L4T_DIR}/nv_tegra/l4t.list
sudo cp -v ${DIR}/scripts/nv-apply-debs.sh ${L4T_DIR}/nv_tegra/

echo " ############################################################"
echo " #  apply binaries.sh ###"
echo " ############################################################"

sudo docker run --privileged --rm --network host \
                -v ${DIR}:/l4t ubuntu:20.04 \
                /l4t/scripts/apply_binaries.sh $L4T_HOSTNAME ${L4T_USERNAME} ${L4T_PASSWORD} 

# OVERLAY_DIR
