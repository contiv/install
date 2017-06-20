#!/bin/sh

set -euo pipefail
# This scripts runs in a container with ansible installed.
. ./install/ansible/install_defaults.sh

# Ignore ansible ssh host key checking by default
export ANSIBLE_HOST_KEY_CHECKING=False

# Scheduler provider can be in kubernetes or swarm mode
scheduler_provider=${CONTIV_SCHEDULER_PROVIDER:-"native-swarm"}

# Specify the etcd or cluster store here
# If an etcd or consul cluster store is not provided, we will start an etcd instance
cluster_store=""

# Should the scheduler stack (docker swarm or k8s be uninstalled)
uninstall_scheduler=false
uninstall_v2plugin=false
reset="false"
reset_images="false"

# This is the netmaster IP that needs to be provided for the installation to proceed
netmaster=""

usage() {
	echo "Usage:"
	echo "./uninstall.sh -n <netmaster IP> -a <ansible options> -i <uninstall scheduler stack> -m <network mode - standalone/aci> -d <fwd mode - routing/bridge> -v <ACI image>  -r <cleanup containers/etcd state> -g <cleanup docker images>"
	echo "This script is to be launched using the uninstall_swarm.sh script. See the documentation for uninstall_swarm.sh for a detailed description of options."
	echo ""
	exit 1
}

# Return printing the error
error_ret() {
	echo ""
	echo "$1"
	exit 1
}

while getopts ":n:a:ipm:d:v:rgs:" opt; do
	case $opt in
		n)
			netmaster=$OPTARG
			;;
		a)
			ans_opts=$OPTARG
			;;
		i)
			uninstall_scheduler=true
			;;
		p)
			uninstall_v2plugin=true
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
			cluster_store=$OPTARG
			;;
		r)
			reset="true"
			;;
		g)
			reset_images="true"
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

./install/genInventoryFile.py "$contiv_config" "$host_inventory" "$node_info" $contiv_network_mode $fwd_mode

if [ "$netmaster" = "" ]; then
	# Use the first master node as netmaster
	netmaster=$(grep -A 5 netplugin-master "$host_inventory" | grep -m 1 ansible_ssh_host | awk '{print $2}' | awk -F "=" '{print $2}' | xargs)
	echo "Using $netmaster as the master node"
fi

if [ "$netmaster" = "" ]; then
	usage
fi

ansible_path=./ansible
env_file=install/ansible/env.json
# Verify ansible can reach all hosts

echo "Verifying ansible reachability"
ansible all -vvv $ans_opts -i $host_inventory -m setup -a 'filter=ansible_distribution*' | tee $inventory_log
if [ egrep 'FAIL|UNREACHABLE' $inventory_log > /dev/null ]; then
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
service_vip=$(ansible $node_name -m setup $ans_opts -i $host_inventory | grep -A 100 ansible_$netmaster_control_if | grep -A 4 ipv4 | grep address | awk -F \" '{print $4}' | xargs)

if [ "$service_vip" == "" ]; then
	service_vip=$netmaster
fi
if [ "$cluster_store" == "" ]; then
	cluster_store="etcd://$service_vip:2379"
fi

sed -i.bak "s#.*service_vip.*#\"service_vip\":\"$service_vip\",#g" "$env_file"
sed -i.bak "s#.*cluster_store.*#\"cluster_store\":\"$cluster_store\",#g" "$env_file"

sed -i.bak "s/.*docker_reset_container_state.*/\"docker_reset_container_state\":$reset,/g" $env_file
sed -i.bak "s/.*docker_reset_image_state.*/\"docker_reset_image_state\":$reset_images,/g" $env_file
sed -i.bak "s/.*etcd_cleanup_state.*/\"etcd_cleanup_state\":$reset,/g" $env_file

if [ "$aci_image" != "" ]; then
	sed -i.bak "s#.*aci_gw_image.*#\"aci_gw_image\":\"$aci_image\",#g" "$env_file"
fi
if [ "$uninstall_v2plugin" == "true" ]; then
	sed -i.bak "s#.*contiv_v2plugin_install.*#\"contiv_v2plugin_install\":\"True\",#g" "$env_file"
else
	sed -i.bak "s#.*contiv_v2plugin_install.*#\"contiv_v2plugin_install\":\"False\",#g" "$env_file"
fi

echo "Uninstalling Contiv"
rm -f $ansible_path/uninstall_plays.yml

# Uninstall contiv & API Proxy
if [ $uninstall_v2plugin == true ]; then
	echo '- include: uninstall_auth_proxy.yml' >$ansible_path/uninstall_plays.yml
	echo '- include: uninstall_v2plugin.yml' >>$ansible_path/uninstall_plays.yml
else
	echo '- include: uninstall_auth_proxy.yml' >$ansible_path/uninstall_plays.yml
	echo '- include: uninstall_contiv.yml' >>$ansible_path/uninstall_plays.yml
fi

if [ $uninstall_scheduler == true ]; then
	echo '- include: uninstall_scheduler.yml' >>$ansible_path/uninstall_plays.yml
	echo '- include: uninstall_etcd.yml' >>$ansible_path/uninstall_plays.yml
	echo '- include: uninstall_docker.yml' >>$ansible_path/uninstall_plays.yml
else
	if [ "$cluster_store" == "" ]; then
		echo '- include: uninstall_etcd.yml' >>$ansible_path/uninstall_plays.yml
	fi
fi
log_file_name="contiv_uninstall_$(date -u +%m-%d-%Y.%H-%M-%S.UTC).log"
log_file="/var/contiv/$log_file_name"

# Ansible needs unquoted booleans but we need quoted booleans for json parsing.
# So remove quotes before sending to ansible and add them back after.
sed -i.bak "s#\"True\"#True#gI" "$env_file"
sed -i.bak "s#\"False\"#False#gI" "$env_file"
ansible-playbook $ans_opts -i "$host_inventory" -e "$(cat $env_file)" $ansible_path/uninstall_plays.yml | tee $log_file
sed -i.bak "s#True#\"True\"#gI" "$env_file"
sed -i.bak "s#False#\"False\"#gI" "$env_file"
rm -rf "$env_file.bak*"

unreachable=$(grep "PLAY RECAP" -A 9999 $log_file | awk -F "unreachable=" '{print $2}' | awk '{print $1}' | grep -v "0" | xargs)
failed=$(grep "PLAY RECAP" -A 9999 $log_file | awk -F "failed=" '{print $2}' | awk '{print $1}' | grep -v "0" | xargs)
chmod 666 $inventory_log
chmod 666 $env_file
chmod 666 $log_file

set +x

if [ "$unreachable" = "" ] && [ "$failed" = "" ]; then
	echo "Uninstallation is complete"
	exit 0
else
	echo "Uninstallation failed"
	echo "========================================================="
	echo " Please check ./config/$log_file_name for errors."
	echo "========================================================="
	exit 1
fi
