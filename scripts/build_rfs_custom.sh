#!/bin/bash
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DIR=$(realpath $SCRIPT_DIR/../)
DOWNLOADS_DIR="${DIR}/downloads"
MIRRORS="http://mirrors.tuna.tsinghua.edu.cn"
# MIRRORS="http://mirrors.aliyun.com"

FLAVOR=$1
ARCH=$2
RELEASE=${RELEASE:-"20.04"}

qemu_name="qemu-${ARCH}-static"
target_qemu_path="usr/bin/${qemu_name}"
host_qemu_path="/usr/bin/${qemu_name}"
base_samplefs="${DOWNLOADS_DIR}/base.tar.gz"
output_samplefs="${DOWNLOADS_DIR}/sample_fs.tbz2"

sed -i "s@http://.*archive.ubuntu.com@${MIRRORS}@g" /etc/apt/sources.list
sed -i "s@http://.*security.ubuntu.com@${MIRRORS}@g" /etc/apt/sources.list

apt-get update
apt-get install -y qemu-user-static wget sudo

function check()
{
	ubuntu_arch="$(arch | grep "x86_64")"
	if [ "${ubuntu_arch}" == "" ]; then
		echo "ERROR: This script can be only run on x86-64 system" > /dev/stderr
		exit 1
	fi

	this_user="$(whoami)"
	if [ "${this_user}" != "root" ]; then
		echo "ERROR: This script requires root privilege" > /dev/stderr
		exit 1
	fi
  
  case "${ARCH}" in
  aarch64)
    DOWNLOAD_ARCH="arm64"
    ;;
  *)
    echo "Unknown arch: ${ARCH}"
    exit 1
    ;;
  esac

  case "${RELEASE}" in
  20.04)
    BASE_URL="https://mirror.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/20.04/release/ubuntu-base-20.04.5-base-${DOWNLOAD_ARCH}.tar.gz"
    ;;
  *)
    echo "Unknown release: ${RELEASE}"
    exit 1
    ;;
  esac

  package_list_file="${DIR}/rfs_flavors/nvubuntu-${RELEASE}-${FLAVOR}-${ARCH}-packages"
  if [ ! -f "${package_list_file}" ]; then
    echo "ERROR: package list file - ${package_list_file} not found" > /dev/stderr
    exit 1
  fi

  if [ ! -f "${host_qemu_path}" ]; then
		echo "ERROR: qemu not found. Please run \"sudo apt-get install qemu-user-static\" on your machine" > /dev/stderr
		exit 1
	fi
}
check

echo "********************************************"
echo "     Create ubuntu-${RELEASE}-${FLAVOR}-${ARCH} sample filesystem     "
echo "********************************************"

function download_samplefs()
{
	echo "download samplefs"

	validate_url="$(wget -S --spider "${BASE_URL}" 2>&1 | grep "HTTP/1.1 200 OK" || ret=$?)"
	if [ -z "${validate_url}" ]; then
		echo "ERROR: Cannot download base image, please check internet connection first" > /dev/stderr
		exit 1
	fi

	wget -O "${base_samplefs}" "${BASE_URL}" -q --show-progress > /dev/null 2>&1
}

if [ ! -f "${base_samplefs}" ]; then
	download_samplefs
fi

function extract_samplefs()
{
	echo "extract samplefs"
	tmpdir="$(mktemp -d)"
	chmod 755 "${tmpdir}"
	pushd "${tmpdir}" > /dev/null 2>&1
	tar xpf "${base_samplefs}" --numeric-owner
	popd > /dev/null
}
extract_samplefs

function install_package()
{
	retry=0
	retry_max=5

	echo "Install ${1}"
	while true
	do
		ret=0
		sudo LC_ALL=C DEBIAN_FRONTEND=noninteractive chroot . apt-get -y --no-install-recommends --allow-downgrades install "${1}" || ret=$?
		if [ "${ret}" == "0" ]; then
			return 0
		else
			retry=$( expr $retry + 1 )
			if [ "${retry}" == "${retry_max}" ]; then
				return 1
			else
				sleep 1
				echo "Retrying ${1} package install"
			fi
		fi
	done
}

function create_samplefs()
{
	echo "create samplefs"

	if [ ! -e "${tmpdir}" ]; then
		echo "ERROR: Temporary directory not found" > /dev/srderr
		exit 1
	fi

	pushd "${tmpdir}" > /dev/null 2>&1

	cp "${host_qemu_path}" "${target_qemu_path}"
	chmod 755 "${target_qemu_path}"

	mount /sys ./sys -o bind
	mount /proc ./proc -o bind
	mount /dev ./dev -o bind
	mount /dev/pts ./dev/pts -o bind

	if [ -s etc/resolv.conf ]; then
		sudo mv etc/resolv.conf etc/resolv.conf.saved
	fi
	if [ -e "/run/resolvconf/resolv.conf" ]; then
		sudo cp /run/resolvconf/resolv.conf etc/
	elif [ -e "/etc/resolv.conf" ]; then
		sudo cp /etc/resolv.conf etc/
	fi

  sudo sed -i "s@https://ports.ubuntu.com@${MIRRORS}@g" /etc/apt/sources.list
	sudo LC_ALL=C chroot . apt-get update

	package_list=$(cat "${package_list_file}")

	if [ ! -z "${package_list}" ]; then
		for package in ${package_list}
		do
			if ! install_package "${package}"; then
				package_name="$(echo "${package}" | cut -d'=' -f1)"
				if [ "${package_name}" = "${package}" ]; then
					echo "ERROR: Failed to install ${package}"
				else
					echo "Try to install ${package_name} the latest version"
					if ! install_package "${package_name}"; then
						echo "ERROR: Failed to install ${package_name}"
					fi
				fi
			fi
		done
	fi

	sudo LC_ALL=C chroot . sync
	sudo LC_ALL=C chroot . apt-get clean
	sudo LC_ALL=C chroot . sync

	if [ -s etc/resolv.conf.saved ]; then
		sudo mv etc/resolv.conf.saved etc/resolv.conf
	fi

	umount ./sys
	umount ./proc
	umount ./dev/pts
	umount ./dev

	rm "${target_qemu_path}"

	rm -rf var/lib/apt/lists/*
	rm -rf dev/*
	rm -rf var/log/*
	rm -rf var/cache/apt/archives/*.deb
	rm -rf var/tmp/*
	rm -rf tmp/*

	popd > /dev/null
}
create_samplefs

function save_samplefs()
{
	echo "${script_name} - save_samplefs"

	pushd "${tmpdir}" > /dev/null 2>&1
	sudo tar --numeric-owner -jcpf "${output_samplefs}" *
	sync
	popd > /dev/null
	rm -rf "${tmpdir}"
	tmpdir=""
}
save_samplefs

echo "********************************************"
echo "   samplefs Creation Complete     "
echo "********************************************"
echo "Samplefs - ${output_samplefs} was generated."
