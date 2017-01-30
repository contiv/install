# This provides paths shared between (un)install.sh and (un)install_swarm.sh
. ./install/ansible/install_defaults.sh

# Ignore ansible ssh host key checking by default
export ANSIBLE_HOST_KEY_CHECKING=False
src_conf_path=""

# Scheduler provider can be in kubernetes or swarm mode
scheduler_provider=${CONTIV_SCHEDULER_PROVIDER:-"native-swarm"}

# Specify the etcd or cluster store here
# If an etcd or consul cluster store is not provided, we will start an etcd instance
cluster_store=""

# Should the scheduler stack (docker swarm or k8s be uninstalled)
uninstall_scheduler=False

# This is the netmaster IP that needs to be provided for the installation to proceed
netmaster=""


usage () {
  echo "Usage:"
  echo "./uninstall.sh -n <netmaster IP> -a <ansible options> -i <uninstall scheduler stack> -m <network mode - standalone/aci> -f <fwd mode - routing/bridge>"

  echo ""
  exit 1
}

# Return printing the error
error_ret() {
  echo ""
  echo $1
  exit 1
}

while getopts ":n:a:im:d:" opt; do
    case $opt in
       n)
          netmaster=$OPTARG
          ;;
       a)
          ans_opts=$OPTARG
          ;;
       i)
          uninstall_scheduler=True
          ;;
       m)
          contiv_network_mode=$OPTARG
          ;;
       d)
          fwd_mode=$OPTARG
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

if [ "$netmaster" = "" ]; then
  usage
fi

echo "Generating Ansible configuration"
inventory=".gen"
mkdir -p $inventory
host_inventory="$inventory/contiv_hosts"
node_info="$inventory/contiv_nodes"

./genInventoryFile.py $contiv_config $host_inventory $node_info $contiv_network_mode $fwd_mode

cluster="etcd://$netmaster:2379"
if [ "$cluster_store" != "" ];then
  cluster=$cluster_store
fi

ansible_path=./ansible
env_file=install/ansible/env.json
sed -i.bak "s/__NETMASTER_IP__/$netmaster/g" $env_file
sed -i.bak "s#__CLUSTER_STORE__#$cluster#g" $env_file

# Override extra vars file, if one is provided.
if [[ -f $installer_config ]]; then
  mv $env_file $env_file.bak
  cp $installer_config $env_file
fi

echo "Uninstalling Contiv"

# Uninstall contiv & API Proxy
ansible-playbook $ans_opts -i $host_inventory -e "`cat $env_file`" $ansible_path/uninstall_auth_proxy.yml
ansible-playbook $ans_opts -i $host_inventory -e "`cat $env_file`" $ansible_path/uninstall_contiv.yml

if [ $uninstall_scheduler = True ];then
  echo "Uninstalling the scheduler stack"
  ansible-playbook $ans_opts -i $host_inventory -e "`cat $env_file`" $ansible_path/uninstall_scheduler.yml
  ansible-playbook $ans_opts -i $host_inventory -e "`cat $env_file`" $ansible_path/uninstall_etcd.yml
  ansible-playbook $ans_opts -i $host_inventory -e "`cat $env_file`" $ansible_path/uninstall_docker.yml
else
  if [ "$cluster_store" = "" ];then
    echo "Uninstalling etcd"
    ansible-playbook $ans_opts -i $host_inventory -e "`cat $env_file`" $ansible_path/uninstall_etcd.yml
  fi
fi
