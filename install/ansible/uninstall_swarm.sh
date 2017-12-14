#!/bin/bash

set -euo pipefail

# This is the uninstall script for Contiv.

. ./install/ansible/install_defaults.sh

# Ansible options. By default, this specifies a private key to be used and the vagrant user
ans_opts=""
ans_user="root"
ans_key=$src_conf_path/insecure_private_key
uninstall_scheduler=""
netmaster=""
uninstall_v2plugin=""
reset_params=""

# Check for docker

if ! docker version >/dev/null 2>&1; then
	echo "docker not found. Please retry after installing docker."
	exit 1
fi

usage() {
	cat <<EOF
Uninstaller:
Usage: ./install/ansible/uninstall_swarm.sh OPTIONS

Mandatory Options:
-f   string     Configuration file (cfg.yml) listing the hostnames with the control and data interfaces and optionally ACI parameters
-e   string     SSH key to connect to the hosts
-u   string     SSH User
-i              Uninstall the scheduler stack 
-p              Uninstall v2plugin

Additional Options:
-m   string     Network Mode for the Contiv installation (“standalone” or “aci”). Default mode is “standalone” and should be used for non ACI-based setups
-d   string     Forwarding mode (“routing” or “bridge”). Default mode is “bridge”
Advanced Options:
-v   string     ACI Image (default is contiv/aci-gw:latest). Use this to specify a specific version of the ACI Image.
-n   string     DNS name/IP address of the host to be used as the net master service VIP. This must be a host present in the cfg.yml file.
-r              Reset etcd state and remove docker containers
-g              Remove docker images
-s   string     URL of the cluster store to be used (for example etcd://etcd master or netmaster IP:2379)
Additional parameters can also be updated in install/ansible/env.json file.
-a   string     Additonal ansible arguments such as "-v --ssh-common-args=\"-o ProxyCommand='nc -x 192.168.2.1 %h %p'\""

Examples:
1. Uninstall Contiv and Docker Swarm on hosts specified by cfg.yml. 
./install/ansible/uninstall_swarm.sh -f cfg.yml -e ~/ssh_key -u admin -i

2. Uninstall Contiv and Docker Swarm on hosts specified by cfg.yml for an ACI setup.
./install/ansible/uninstall_swarm.sh -f cfg.yml -e ~/ssh_key -u admin -i -m aci

3. Uninstall Contiv and Docker Swarm on hosts specified by cfg.yml for an ACI setup, remove all containers and Contiv etcd state
./install/ansible/uninstall_swarm.sh -f cfg.yml -e ~/ssh_key -u admin -i -m aci -r

EOF
	exit 1
}

# Create the config folder to be shared with the install container.
mkdir -p "$src_conf_path"
cluster_param=""
while getopts ":f:n:a:e:ipm:d:v:u:rgs:" opt; do
	case $opt in
	f)
		cp "$OPTARG" "$host_contiv_config"
		;;
	n)
		netmaster=$OPTARG
		;;
	a)
		ans_opts="$OPTARG"
		;;
	e)
		ans_key=$OPTARG
		;;
	u)
		ans_user=$OPTARG
		;;
	m)
		contiv_network_mode=$OPTARG
		;;
	d)
		fwd_mode=$OPTARG
		;;
	v)
		aci_image=$OPTARG
		;;
	s)
		cluster_param="-s $OPTARG"
		;;

	i)
		echo "Uninstalling docker will fail if the uninstallation is being run from a node in the cluster."
		echo "Press Ctrl+C to cancel the uininstall and start it from a host outside the cluster."
		echo "Uninstalling Contiv, Docker and Swarm in 20 seconds"
		sleep 20
		uninstall_scheduler="-i"
		;;
	p)
		uninstall_v2plugin="-p"
		;;
	r)
		reset_params="-r $reset_params"
		;;
	g)
		reset_params="-g $reset_params"
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

if [[ ! -f $host_contiv_config ]]; then
	echo "Host configuration file missing"
	usage
fi

if [ "$netmaster" != "" ]; then
	netmaster_param="-n $netmaster"
else
	netmaster_param=""
fi

if [ "$aci_image" != "" ]; then
	aci_param="-v $aci_image"
else
	aci_param=""
fi

# Copy the key to config folder
if [[ -f $ans_key ]]; then
	cp "$ans_key" "$host_ans_key"
fi

if [ "$ans_opts" == "" ]; then
	ans_opts="--private-key $def_ans_key -u $ans_user"
else
	# escape each word in the array and put spaces between the words
	ans_opts+=" --private-key $def_ans_key -u $ans_user"
fi
echo "Starting the uninstaller container"
image_name="__CONTIV_INSTALL_VERSION__"
install_mount="-v $(pwd)/install:/install:Z"
ansible_mount="-v $(pwd)/ansible:/ansible:Z"
config_mount="-v $src_conf_path:$container_conf_path:Z"
cache_mount="-v $(pwd)/contiv_cache:/var/contiv_cache:Z"
mounts="$install_mount $ansible_mount $cache_mount $config_mount"
docker run --rm --net=host $mounts $image_name ./install/ansible/uninstall.sh $netmaster_param -a "$ans_opts" $uninstall_scheduler $uninstall_v2plugin -m $contiv_network_mode -d $fwd_mode $aci_param $reset_params $cluster_param
