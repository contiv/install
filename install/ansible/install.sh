#!/bin/bash

set -xeuo pipefail

# This scripts runs in a container with ansible installed.
. ./install/ansible/install_defaults.sh

# Ignore ansible ssh host key checking by default
export ANSIBLE_HOST_KEY_CHECKING=False

# Scheduler provider can be in kubernetes or swarm mode
scheduler_provider=${CONTIV_SCHEDULER_PROVIDER:-"native-swarm"}

# Specify the etcd or cluster store here
# If an etcd or consul cluster store is not provided, we will start an etcd instance
cluster_store=""
install_etcd=true

# Should the scheduler stack (docker swarm or k8s be installed)
install_scheduler=false

# This is the netmaster IP that needs to be provided for the installation to proceed
netmaster=""
contiv_v2plugin_install=""

usage() {
	echo "Usage:"
	echo "./install.sh -n <netmaster IP> -a <ansible options> -i <install scheduler stack> -m <network mode - standalone/aci> -d <fwd mode - routing/bridge> -v <ACI image>"
	echo "This script is to be launched using the install_swarm.sh script. See the documentation for install_swarm.sh for a detailed description of options."
	exit 1
}

# Return printing the error
error_ret() {
	echo ""
	echo "$1"
	exit 1
}

while getopts ":n:a:im:d:v:pe:c:s:" opt; do
	case $opt in
	n)
		netmaster=$OPTARG
		;;
	a)
		# make a bash array from the ansible argument
		# it interprets single and double quotes from CLI as you might expect
		# creating proper bash "words" for eventually passing to ansible
		# by letting the array declaration do all the interpreting
		# note: ans_opts=($OPTARG) and ans_opts("$OPTARG") do not work
		# Example:
		#   "-v --ssh-common-args=\"-o ProxyCommand='nc -x 192.168.2.1 %h %p'\"
		declare -a 'ans_opts=('"$OPTARG"')'
		;;
	i)
		install_scheduler=true
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
	p)
		contiv_v2plugin_install=true
		;;
	e)
		# etcd endpoint option
		cluster_store_type=etcd
		cluster_store_urls=$OPTARG
		install_etcd=false
		;;
	c)
		# consul endpoint option
		cluster_store_type=consul
		cluster_store_urls=$OPTARG
		install_etcd=false
		;;
	s)
		# backward compatibility
		echo "-s option has been deprecated, use -e or -c instead"
		local cluster_store=$OPTARG
		if [[ "$cluster_store" =~ ^etcd://.+ ]]; then
			cluster_store_type=etcd
			cluster_store_urls=$(echo $cluster_store | sed s/etcd/http/)
		elif [[ "$cluster_store" =~ ^consul://.+ ]]; then
			cluster_store_type=consul
			cluster_store_urls=$(echo $cluster_store | sed s/consul/http/)
		fi
		install_etcd=false
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

echo "Generating Ansible configuration"
inventory="/.gen"
inventory_log="/var/contiv/host_inventory.log"
mkdir -p "$inventory"
host_inventory="$inventory/contiv_hosts"
node_info="$inventory/contiv_nodes"

# TODO: use python to generate the inventory
# This python generated inventory contains
# 1. groups and host
# 2. ssh info for each host
# 3. control interface for each host
# 4. data interface for each host
# 5. aci info
# 6. fwd_mode(bridge/routing), net_mode(vlan/vxlan), contiv_network_mode(standalone/aci)
# then below sed against env_file set rest of them, they should be combined as one
./install/genInventoryFile.py "$contiv_config" "$host_inventory" "$node_info" $contiv_network_mode $fwd_mode

if [ "$netmaster" = "" ]; then
	# Use the first master node as netmaster
	netmaster=$(grep -A 5 netplugin-master "$host_inventory" | grep -m 1 ansible_ssh_host | awk '{print $2}' | awk -F "=" '{print $2}' | xargs)
	echo "Using $netmaster as the master node"
fi

if [ "$netmaster" = "" ]; then
	usage
fi

if [ "$install_scheduler" = "true" ] && [ "$contiv_v2plugin_install" = "true" ]; then
	echo "ERROR: -p and -i are mutually exclusive"
	usage
fi

ansible_path=./ansible
env_file=install/ansible/env.json
# Verify ansible can reach all hosts

echo "Verifying ansible reachability"
ansible all "${ans_opts[@]}" -i $host_inventory -m setup -a 'filter=ansible_distribution*' | tee $inventory_log
if egrep -q 'FAIL|UNREACHABLE' $inventory_log; then
	echo "WARNING Some of the hosts are not accessible via passwordless SSH"
	echo " "
	echo "This means either the host is unreachable or passwordless SSH is not"
	echo "set up for it. Please resolve this before proceeding."

	exit 1
fi

# Get the netmaster control interface
netmaster_control_if=$(grep -A10 $netmaster $contiv_config | grep -m 1 control | awk -F ":" '{print $2}' | xargs)
# Get the ansible node
node_name=$(grep $netmaster $host_inventory | awk '{print $1}' | xargs)
# Get the service VIP for netmaster for the control interface
service_vip=$(ansible $node_name -m setup "${ans_opts[@]}" -i $host_inventory | grep -A 100 ansible_$netmaster_control_if | grep -A 4 ipv4 | grep address | awk -F \" '{print $4}' | xargs)

if [ "$service_vip" == "" ]; then
	service_vip=$netmaster
fi

if [ "$cluster_store" = "" ]; then
	cluster_store_type="etcd"
	cluster_store_urls="http://localhost:2379"
fi

# variables already replaced by build.sh will not pattern match
sed -i.bak 's#__NETMASTER_IP__#'"$service_vip"'#g' "$env_file"
sed -i.bak 's#__CLUSTER_STORE_TYPE__#'"$cluster_store_type"'#g' "$env_file"
sed -i.bak 's#__CLUSTER_STORE_URLS__#'"$cluster_store_urls"'#g' "$env_file"
sed -i.bak 's#__DOCKER_RESET_CONTAINER_STATE__#false#g' "$env_file"
sed -i.bak 's#__DOCKER_RESET_IMAGE_STATE__#false#g' "$env_file"
sed -i.bak 's#__ETCD_CLEANUP_STATE__#false#g' "$env_file"
sed -i.bak 's#__AUTH_PROXY_LOCAL_INSTALL__#false#g' "$env_file"
sed -i.bak 's#__CONTIV_NETWORK_LOCAL_INSTALL__#false#g' "$env_file"

# Copy certs
cp /var/contiv/cert.pem /ansible/roles/auth_proxy/files/
cp /var/contiv/key.pem /ansible/roles/auth_proxy/files/

if [ "$aci_image" != "" ]; then
	sed -i.bak 's#__ACI_GW_VERSION__#'"$aci_image"'#g' "$env_file"
fi
if [ "$contiv_v2plugin_install" == "true" ]; then
	# docker uses 4789 port for container ingress network, uses 8472 by default to avoid conflicting
	# https://docs.docker.com/engine/swarm/ingress/
	sed -i.bak 's#__VXLAN_PORT__#8472#g' "$env_file"
	sed -i.bak 's#__CONTIV_V2PLUGIN_INSTALL__#true#g' "$env_file"
else
	sed -i.bak 's#__VXLAN_PORT__#4789#g' "$env_file"
	sed -i.bak 's#__CONTIV_V2PLUGIN_INSTALL__#false#g' "$env_file"
fi

echo "Installing Contiv"
# Always install the base, install the scheduler stack/etcd if required

rm -f $ansible_path/install_plays.yml
touch $ansible_path/install_plays.yml

if [ "$install_scheduler" == "true" ]; then
	echo '- include: install_base.yml' >$ansible_path/install_plays.yml
	echo '- include: install_docker.yml' >>$ansible_path/install_plays.yml
	echo '- include: install_etcd.yml' >>$ansible_path/install_plays.yml
	echo '- include: install_scheduler.yml' >>$ansible_path/install_plays.yml
else
	if [ "$install_etcd" == "true" ]; then
		echo '- include: install_etcd.yml' >$ansible_path/install_plays.yml
	fi
fi
# Install contiv & API Proxy
echo '- include: install_contiv.yml' >>$ansible_path/install_plays.yml
echo '- include: install_auth_proxy.yml' >>$ansible_path/install_plays.yml

log_file_name="contiv_install_$(date -u +%m-%d-%Y.%H-%M-%S.UTC).log"
log_file="/var/contiv/$log_file_name"

echo "Ansible extra vars from env.json:"
cat "$env_file"
# run playbook
ansible-playbook "${ans_opts[@]}" -i "$host_inventory" -e@"$env_file" $ansible_path/install_plays.yml | tee $log_file
rm -rf "$env_file.bak"

unreachable=$(grep "PLAY RECAP" -A 9999 $log_file | awk -F "unreachable=" '{print $2}' | awk '{print $1}' | grep -v "0" | xargs)
failed=$(grep "PLAY RECAP" -A 9999 $log_file | awk -F "failed=" '{print $2}' | awk '{print $1}' | grep -v "0" | xargs)
chmod 666 $inventory_log
chmod 666 $env_file
chmod 666 $log_file

set +x

if [ "$unreachable" = "" ] && [ "$failed" = "" ]; then
	echo "Installation is complete"
	echo "========================================================="
	echo " "
	echo "Please export DOCKER_HOST=tcp://$netmaster:2375 in your shell before proceeding"
	echo "Contiv UI is available at https://$netmaster:10000"
	echo "Please use the first run wizard or configure the setup as follows:"
	echo " Configure ACI mode (optional)"
	echo " netctl global set --fabric-mode aci --vlan-range <start>-<end>"
	echo " Create a default network"
	echo " netctl net create -t default --subnet=<CIDR> default-net"
	echo " For example, netctl net create -t default --subnet=20.1.1.0/24 default-net"
	echo " "
	echo "========================================================="
	exit 0
else
	echo "Installation failed"
	echo "========================================================="
	echo " Please check ./config/$log_file_name for errors."
	echo "========================================================="
	exit 1
fi
