# This is the installation script for Cisco Unified Container Networking platform.

. ./install/ansible/install_defaults.sh

# Ansible options. By default, this specifies a private key to be used and the vagrant user
ans_opts=""
ans_user="vagrant"
ans_key=$src_conf_path/insecure_private_key

# Check for docker
if [ ! docker version > /dev/null 2>&1 ]; then
  echo "docker not found. Please retry after installing docker."
  exit 1
fi
usage() {
  echo "Usage:"
  echo "./uninstall_swarm.sh -f <host configuration file> -n <netmaster IP> -a <ansible options> -e <ssh key> -u <ssh user> -i <uninstall scheduler stack> -z <installer config file> -m <network mode - standalone/aci> -d <fwd mode - routing/bridge>  -v <ACI image> -r <cleanup containers/etcd state> -g <cleanup docker images>"

  echo ""
  exit 1
}

mkdir -p $src_conf_path
uninstall_scheduler=""
reset_params=""
while getopts ":f:z:n:a:e:im:d:v:u:rg" opt; do
  case $opt in
    f)
      cp $OPTARG $host_contiv_config
      ;;
    z)
      cp $OPTARG $host_installer_config
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
    r)
      reset_params="-r $reset_params"
      ;;
    g)
      reset_params="-g $reset_params"
      ;;
    i) 
      echo "Uninstalling docker will fail if the uninstallation is being run from a node in the cluster."
      echo "Press Ctrl+C to cancel the uininstall and start it from a host outside the cluster."
      echo "Uninstalling Contiv, Docker and Swarm in 20 seconds"
      sleep 20
      uninstall_scheduler="-i"
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

if [ "$netmaster" != ""  ]; then
  netmaster_param="-n $netmaster"
else
  netmaster_param=""
fi

if [[ -f $ans_key ]]; then
  cp $ans_key $host_ans_key
fi
ans_opts="$ans_opts --private-key $def_ans_key -u $ans_user"

if [ "$aci_image" != "" ];then
  aci_param="-v $aci_image"
else
  aci_param=""
fi

echo "Starting the ansible container"
image_name="contiv/install:__CONTIV_INSTALL_VERSION__"
install_mount="-v $(pwd)/install:/install"
ansible_mount="-v $(pwd)/ansible:/ansible"
cache_mount="-v $(pwd)/contiv_cache:/var/contiv_cache"
mounts="$install_mount $ansible_mount $cache_mount"
docker run --rm -v $src_conf_path:$container_conf_path $mounts $image_name sh -c "./install/ansible/uninstall.sh $netmaster_param -a \"$ans_opts\" $uninstall_scheduler -m $contiv_network_mode -d $fwd_mode $aci_param $reset_params"
rm -rf $src_conf_path

echo "Uninstallation is complete"
