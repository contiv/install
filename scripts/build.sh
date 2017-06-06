#!/bin/bash

set -euo pipefail

# ensure this script wasn't called from the directory where this script
# lives; it should be called from the repository's top level
script_dir="$(dirname -- "$0")"
if [ "$script_dir" == "." ]; then
	echo "This script must be called from the top level of the repository"
	exit 1
fi

DEV_IMAGE_NAME="devbuild"
VERSION=${BUILD_VERSION-$DEV_IMAGE_NAME}

contiv_version=${CONTIV_VERSION:-"1.0.0"}

aci_gw_version=${CONTIV_ACI_GW_VERSION:-"latest"}
ansible_image_version=${CONTIV_ANSIBLE_IMAGE_VERSION:-$contiv_version}
auth_proxy_version=${CONTIV_API_PROXY_VERSION:-$contiv_version}
docker_version=${CONTIV_DOCKER_VERSION:-1.12.6}
etcd_version=${CONTIV_ETCD_VERSION:-v2.3.8}

# the installer currently pulls the v2plugin image directly from Docker Hub, but
# this will change to being downloaded from the Docker Store in the future.
# because of this, the default value for this variable will become the latest
# version that is available in the Docker Store and should be considered
# independent of $contiv_version above.
v2plugin_version=${CONTIV_V2PLUGIN_VERSION:-"1.0.0"}

function usage() {
	echo "Usage:"
	echo "./release.sh -a <ACI gateway image> -c <contiv version> -e <etcd version> -p <API proxy image version> "
	exit 1
}

function error_ret() {
	echo ""
	echo $1
	exit 1
}

while getopts ":a:p:c:e:v:" opt; do
	case $opt in
		a)
			aci_gw_version=$OPTARG
			;;
		c)
			contiv_version=$OPTARG
			;;
		e)
			etcd_version=$OPTARG
			;;
		p)
			auth_proxy_version=$OPTARG
			;;
		v)
			v2plugin_version=$OPTARG
			;;
		:)
			echo "An argument required for $OPTARG was not passed"
			usage
			;;
		?)
			usage
			;;
	esac
done

release_dir="release"
output_dir="$release_dir/contiv-$VERSION/"
output_file="$release_dir/contiv-$VERSION.tgz"
tmp_output_file="contiv-$VERSION.tgz"
full_output_file="$release_dir/contiv-full-$VERSION.tgz"
tmp_full_output_file="contiv-full-$VERSION.tgz"

# Clean older dist folders and release binaries
rm -rf $output_dir
rm -rf $output_file

# Release files 
# k8s - install.sh to take the args and construct contiv.yaml as required and to launch kubectl
# swarm - install.sh launches the container to do the actual installation
# Top level install.sh which will either take k8s/swarm install params and do the required.
mkdir -p $output_dir
cp -rf install $output_dir
cp README.md $output_dir
cp -rf scripts/generate-certificate.sh $output_dir/install

# Get the ansible support files
chmod +x $output_dir/install/genInventoryFile.py
chmod +x $output_dir/install/generate-certificate.sh

# This is maybe optional - but assume we need it for
curl -sSL https://github.com/contiv/netplugin/releases/download/$contiv_version/netplugin-$contiv_version.tar.bz2 -o $output_dir/netplugin-$contiv_version.tar.bz2
pushd $output_dir
tar oxf netplugin-$contiv_version.tar.bz2 netctl
rm -f netplugin-$contiv_version.tar.bz2
git clone http://github.com/contiv/ansible
popd

# Replace versions
files=$(find $output_dir -type f -name "*.yaml" -or -name "*.sh" -or -name "*.json")
sed -i.bak "s/__ACI_GW_VERSION__/$aci_gw_version/g" $files
sed -i.bak "s/__API_PROXY_VERSION__/$auth_proxy_version/g" $files
sed -i.bak "s/__CONTIV_INSTALL_VERSION__/$ansible_image_version/g" $files
sed -i.bak "s/__CONTIV_VERSION__/$contiv_version/g" $files
sed -i.bak "s/__DOCKER_VERSION__/$docker_version/g" $files
sed -i.bak "s/__ETCD_VERSION__/$etcd_version/g" $files
sed -i.bak "s/__CONTIV_V2PLUGIN_VERSION__/$v2plugin_version/g" $files

# Make all shell script files executable
chmod +x $(find $output_dir -type f -name "*.sh")

# Cleanup the backup files
rm -rf $output_dir/scripts
rm -rf $(find $output_dir -type f -name "*.bak")

# Clean up the Dockerfile, it is not part of the release bits.
rm -f $output_dir/install/ansible/Dockerfile

# Create the binary cache folder
binary_cache=$output_dir/contiv_cache
mkdir -p $binary_cache

# Create the minimal tar bundle
tar czf $tmp_output_file -C $release_dir contiv-$VERSION

mv $tmp_output_file $output_file
rm -rf $output_dir

echo "Success: Contiv Installer version $VERSION is available at $output_file"
