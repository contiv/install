#!/bin/bash

# Required environment variables:
# * CONTIV_INSTALLER_VERSION - sets the tarball artifact filenames
# * CONTIV_NETPLUGIN_VERSION - updates config files to locate contiv tarball
# * CONTIV_V2PLUGIN_VERSION - which v2plugin version to download during install
# * CONTIV_ACI_GW_VERSION - which aci_gw version to download during install

set -xeuo pipefail

# ensure this script wasn't called from the directory where this script
# lives; it should be called from the repository's top level
script_dir="$(dirname -- "$0")"
if [ "$script_dir" == "." ]; then
	echo "This script must be called from the top level of the repository"
	exit 1
fi

pull_images=${CONTIV_CI_HOST:-"false"}
aci_gw_version=${CONTIV_ACI_GW_VERSION:-"latest"}
ansible_image_version=${CONTIV_ANSIBLE_IMAGE:-contiv/install:$DEFAULT_DOWNLOAD_CONTIV_VERSION}
auth_proxy_version=${CONTIV_API_PROXY_VERSION:-$DEFAULT_DOWNLOAD_CONTIV_VERSION}
docker_version=${CONTIV_DOCKER_VERSION:-1.12.6}
etcd_version=${CONTIV_ETCD_VERSION:-v3.2.4}
v2plugin_version=${CONTIV_V2PLUGIN_VERSION}

# where everything is assembled, always start with a clean dir and clean it up
output_tmp_dir="$(mktemp -d)"
output_dir="${output_tmp_dir}/contiv-${CONTIV_INSTALLER_VERSION}"
mkdir -p "${output_dir}"
trap 'rm -rf "${output_tmp_dir}"' EXIT

release_dir=release
mkdir -p $release_dir
output_file="${release_dir}/contiv-${CONTIV_INSTALLER_VERSION}.tgz"
full_output_file="$release_dir/contiv-full-${CONTIV_INSTALLER_VERSION}.tgz"

# Release files
# k8s - install.sh to take the args and construct contiv.yaml as required and to launch kubectl
# swarm - install.sh launches the container to do the actual installation
# Top level install.sh which will either take k8s/swarm install params and do the required.
cp -rf install README.md $output_dir
cp -rf scripts/generate-certificate.sh $output_dir/install

# Get the ansible support files
chmod +x $output_dir/install/genInventoryFile.py
chmod +x $output_dir/install/generate-certificate.sh

if [ -d ${CONTIV_ARTIFACT_STAGING}/ansible ]; then
	cp -a "${CONTIV_ARTIFACT_STAGING}/ansible" ${output_dir}/
fi

# Replace versions
files=$(find $output_dir -type f -name "*.yaml" -or -name "*.sh" -or -name "*.json")
sed -i.bak 's/__ACI_GW_VERSION__/'"$aci_gw_version"'/g' $files
sed -i.bak 's/__API_PROXY_VERSION__/'"$auth_proxy_version"'/g' $files
sed -i.bak 's#__CONTIV_INSTALL_VERSION__#'"$ansible_image_version"'#g' $files
sed -i.bak 's/__CONTIV_VERSION__/'"$CONTIV_NETPLUGIN_VERSION"'/g' $files
sed -i.bak 's/__DOCKER_VERSION__/'"$docker_version"'/g' $files
sed -i.bak 's/__ETCD_VERSION__/'"$etcd_version"'/g' $files
sed -i.bak 's/__CONTIV_V2PLUGIN_VERSION__/'"$v2plugin_version"'/g' $files

# Make all shell script files executable
chmod +x $(find $output_dir -type f -name "*.sh")

# Clean up the Dockerfile, it is not part of the release bits.
rm -f $output_dir/install/ansible/Dockerfile

# Create the binary cache folder
binary_cache=$output_dir/contiv_cache
mkdir -p $binary_cache

# only build installer that pulls artifacts over internet if not building
# a specific commit of netplugin
if [ -z "${NETPLUGIN_BRANCH:-}" ]; then
	# Create the minimal tar bundle
	tar czf $output_file -C $output_tmp_dir contiv-${CONTIV_INSTALLER_VERSION}
	echo -n "Contiv Installer version '$CONTIV_INSTALLER_VERSION' with "
	echo "netplugin version '$CONTIV_NETPLUGIN_VERSION' is available "
	echo "at '$output_file'"
fi

# Save the auth proxy & aci-gw images for packaging the full docker images with contiv install binaries
if [[ "$(docker images -q contiv/auth_proxy:$auth_proxy_version 2>/dev/null)" == "" || "$pull_images" == "true" ]]; then
	docker pull contiv/auth_proxy:$auth_proxy_version
fi
docker save contiv/auth_proxy:$auth_proxy_version -o $binary_cache/auth-proxy-image.tar

if [[ "$(docker images -q contiv/aci-gw:$aci_gw_version 2>/dev/null)" == "" || "$pull_images" == "true" ]]; then
	docker pull contiv/aci-gw:$aci_gw_version
fi
docker save contiv/aci-gw:$aci_gw_version -o $binary_cache/aci-gw-image.tar

if [ -f $CONTIV_ARTIFACT_STAGING/netplugin-image-${CONTIV_NETPLUGIN_VERSION}.tar ]; then
	cp $CONTIV_ARTIFACT_STAGING/netplugin-image-${CONTIV_NETPLUGIN_VERSION}.tar $binary_cache/
fi

curl --fail -sL -o $binary_cache/openvswitch-2.5.0-2.el7.x86_64.rpm http://cbs.centos.org/kojifiles/packages/openvswitch/2.5.0/2.el7/x86_64/openvswitch-2.5.0-2.el7.x86_64.rpm
curl --fail -sL -o $binary_cache/ovs-common.deb http://mirrors.kernel.org/ubuntu/pool/main/o/openvswitch/openvswitch-common_2.5.2-0ubuntu0.16.04.3_amd64.deb
curl --fail -sL -o $binary_cache/ovs-switch.deb http://mirrors.kernel.org/ubuntu/pool/main/o/openvswitch/openvswitch-switch_2.5.2-0ubuntu0.16.04.3_amd64.deb

# Copy the netplugin release into the binary cache for "full" installer
# Netplugin releases built locally based on a branch are named by their SHA,
# but there is a symlink to point to the SHA named tarball by it's branch name
plugin_tball="${CONTIV_ARTIFACT_STAGING}/$CONTIV_NETPLUGIN_TARBALL_NAME"
if [[ -L "${plugin_tball}" ]]; then
	# copy the link (so other processes can find the tarball) and the tarball
	target_plugin_tball="$(readlink "${plugin_tball}")"
	cp -a "${plugin_tball}" "${binary_cache}/"
	plugin_tball="${CONTIV_ARTIFACT_STAGING}/${target_plugin_tball}"
fi
if [ -f "${plugin_tball}" ]; then
	cp "${plugin_tball}" "${binary_cache}/"
fi

# copy v2plugin assets if built locally on branch
if [ -n "${NETPLUGIN_BRANCH:-}" ]; then
	if [ -L "${CONTIV_ARTIFACT_STAGING}/$CONTIV_V2PLUGIN_TARBALL_NAME" ]; then
		cp "${CONTIV_ARTIFACT_STAGING}/${CONTIV_V2PLUGIN_TARBALL_NAME}" "${binary_cache}/"
		v2plugin_tball="$(readlink ${CONTIV_ARTIFACT_STAGING}/${CONTIV_V2PLUGIN_TARBALL_NAME})"
		if [ -f "$v2plugin_tball" ]; then
			cp -a "$v2plugin_tball" "${binary_cache}/"
		fi
	fi

	if [ -f "${CONTIV_ARTIFACT_STAGING}/config.json" ]; then
		cp "${CONTIV_ARTIFACT_STAGING}/config.json" "${binary_cache}/"
	fi

fi

env_file=$output_dir/install/ansible/env.json
sed -i.bak 's#__AUTH_PROXY_LOCAL_INSTALL__#true#g' "$env_file"
sed -i.bak 's#__CONTIV_NETWORK_LOCAL_INSTALL__#true#g' "$env_file"

echo "Ansible extra vars from env.json:"
cat $env_file
# Create the full tar bundle
tar czf $full_output_file -C $output_tmp_dir contiv-${CONTIV_INSTALLER_VERSION}
echo -n "Contiv Installer version '$CONTIV_INSTALLER_VERSION' with "
echo "netplugin version '$CONTIV_NETPLUGIN_VERSION' is available "
echo "at '$full_output_file', it includes all contiv assets "
echo "required for installation"
echo
echo -e "\nSuccess"
