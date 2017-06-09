#!/bin/bash

set -euo pipefail

# This is the installation script for Contiv.

. ./install/ansible/install_defaults.sh

# Ansible options. By default, this specifies a private key to be used and the vagrant user
ans_opts=""
ans_user="root"
ans_key=$src_conf_path/insecure_private_key
install_scheduler=""
netmaster=""
v2plugin_param=""
contiv_v2plugin_install=""

# Check for docker

if ! docker version >/dev/null 2>&1; then
	echo "docker not found. Please retry after installing docker."
	exit 1
fi

usage() {
	cat <<EOF
Contiv Installer for Docker/Swarm based setups.

Installer:
Usage: ./install/ansible/install_swarm.sh OPTIONS

Mandatory Options:
-f   string     Configuration file (cfg.yml) listing the hostnames with the control and data interfaces and optionally ACI parameters
-e   string     SSH key to connect to the hosts
-u   string     SSH User
-i              Install the scheduler stack 
-p              Install v2plugin

Additional Options:
-m   string     Network Mode for the Contiv installation (“standalone” or “aci”). Default mode is “standalone” and should be used for non ACI-based setups
-d   string     Forwarding mode (“routing” or “bridge”). Default mode is “bridge”
-c   string
-k   string

Advanced Options:
-v   string     ACI Image (default is contiv/aci-gw:latest). Use this to specify a specific version of the ACI Image.
-n   string     DNS name/IP address of the host to be used as the net master service VIP. This must be a host present in the cfg.yml file.
-s   string     URL of the cluster store to be used (for example etcd://etcd master or netmaster IP:2379)
Additional parameters can also be updated in install/ansible/env.json file.

Examples:

1. Install Contiv with Docker Swarm on hosts specified by cfg.yml. 
./install/ansible/install_swarm.sh -f cfg.yml -e ~/ssh_key -u admin -i

2. Install Contiv on hosts specified by cfg.yml. Docker should be pre-installed on the hosts.
./install/ansible/install_swarm.sh -f cfg.yml -e ~/ssh_key -u admin

3. Install Contiv with Docker Swarm on hosts specified by cfg.yml in ACI mode.
./install/ansible/install_swarm.sh -f cfg.yml -e ~/ssh_key -u admin -i -m aci

4. Install Contiv with Docker Swarm on hosts specified by cfg.yml in ACI mode, using routing as the forwarding mode.
./install/ansible/install_swarm.sh -f cfg.yml -e ~/ssh_key -u admin -i -m aci -d routing

EOF
	exit 1
}

# Create the config folder to be shared with the install container.
mkdir -p "$src_conf_path"
cluster_param=""
while getopts ":f:n:a:e:ipm:d:v:u:c:k:s:" opt; do
	case $opt in
		f)
			cp "$OPTARG" "$host_contiv_config"
			;;
		n)
			netmaster=$OPTARG
			;;
		a)
			ans_opts=$OPTARG
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
			install_scheduler="-i"
			;;
		p)
			v2plugin_param="-p"
			;;
		c)
			cp "$OPTARG" "$host_tls_cert"
			;;
		k)
			cp "$OPTARG" "$host_tls_key"
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
	ans_opts=" --private-key $def_ans_key -u $ans_user"
else
	ans_opts=$(printf '%q', $ans_opts)" --private-key $def_ans_key -u $ans_user"
fi

# Generate SSL certs for auth proxy
if [[ ! -f "$host_tls_cert" || ! -f "$host_tls_key" ]]; then
	echo "Generating local certs for Contiv Proxy"
	openssl genrsa -out "$host_tls_key" 2048 >/dev/null 2>&1
	openssl req -new -x509 -sha256 -days 3650 \
		-key "$host_tls_key" \
		-out "$host_tls_cert" \
		-subj "/C=US/ST=CA/L=San Jose/O=CPSG/OU=IT Department/CN=auth-local.cisco.com"
fi

echo "Starting the installer container"
image_name="contiv/install:__CONTIV_INSTALL_VERSION__"
install_mount="-v $(pwd)/install:/install:Z"
ansible_mount="-v $(pwd)/ansible:/ansible:Z"
config_mount="-v $src_conf_path:$container_conf_path:Z"
cache_mount="-v $(pwd)/contiv_cache:/var/contiv_cache:Z"
mounts="$install_mount $ansible_mount $cache_mount $config_mount"
docker run --rm --net=host $mounts $image_name sh -c "./install/ansible/install.sh $netmaster_param -a \"$ans_opts\" $install_scheduler -m $contiv_network_mode -d $fwd_mode $aci_param $cluster_param $v2plugin_param"
