# This provides paths shared between install.sh and install_swarm.sh
. ./install/ansible/install_defaults.sh

# Ignore ansible ssh host key checking by default
export ANSIBLE_HOST_KEY_CHECKING=False
src_conf_path=""

# Scheduler provider can be in kubernetes or swarm mode
scheduler_provider=${CONTIV_SCHEDULER_PROVIDER:-"native-swarm"}

# Specify the etcd or cluster store here
# If an etcd or consul cluster store is not provided, we will start an etcd instance
cluster_store=""

# Should the scheduler stack (docker swarm or k8s be installed)
install_scheduler=False

# This is the netmaster IP that needs to be provided for the installation to proceed
netmaster=""


usage () {
  echo "Usage:"
  echo "./install.sh -n <netmaster IP> -a <ansible options> -i <install scheduler stack> -m <network mode - standalone/aci> -d <fwd mode - routing/bridge> -v <ACI image>"

  echo ""
  exit 1
}

# Return printing the error
error_ret() {
  echo ""
  echo $1
  exit 1
}

while getopts ":n:a:im:d:v:" opt; do
    case $opt in
       n)
          netmaster=$OPTARG
          ;;
       a)
          ans_opts=$OPTARG
          ;;
       i)
          install_scheduler=True
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

# Copy certs
cp /var/contiv/cert.pem /ansible/roles/auth_proxy/files/
cp /var/contiv/key.pem /ansible/roles/auth_proxy/files/

# Override extra vars file, if one is provided.
if [[ -f $installer_config ]]; then
  mv $env_file $env_file.bak
  cp $installer_config $env_file
fi

if [ "$aci_image" != "" ];then
  sed -i.bak "s#.*aci_gw_image.*#\"aci_gw_image\":\"$aci_image\",#g" $env_file
fi

echo "Installing Contiv"
# TODO: rather than running them separately - merge the playbooks, that makes error tracking simpler
# Always install the base, install the scheduler stack/etcd if required
echo "Installing base packages"
ansible-playbook $ans_opts -i $host_inventory -e "`cat $env_file`" $ansible_path/install_base.yml
if [ $install_scheduler = True ];then
  echo "Installing the scheduler stack"
  ansible-playbook $ans_opts -i $host_inventory -e "`cat $env_file`" $ansible_path/install_docker.yml
  ansible-playbook $ans_opts -i $host_inventory -e "`cat $env_file`" $ansible_path/install_etcd.yml
  ansible-playbook $ans_opts -i $host_inventory -e "`cat $env_file`" $ansible_path/install_scheduler.yml
else
  if [ "$cluster_store" = "" ];then
    echo "Installing etcd"
    ansible-playbook $ans_opts -i $host_inventory -e "`cat $env_file`" $ansible_path/install_etcd.yml
  fi
fi
echo "Installing contiv & auth proxy"
# Install contiv & API Proxy
ansible-playbook $ans_opts -i $host_inventory -e "`cat $env_file`" $ansible_path/install_contiv.yml
ansible-playbook $ans_opts -i $host_inventory -e "`cat $env_file`" $ansible_path/install_auth_proxy.yml
