# This is the installation script for Cisco Unified Container Networking platform.

. ./install/ansible/install_defaults.sh

# Ansible options. By default, this specifies a private key to be used and the vagrant user
def_ans_opts="--private-key $def_ans_key -u vagrant"

# Check for docker version and status
check_for_prereqs() {
  echo "Checking for pre-requisites"
  success=True
  docker_version=${DOCKER_VERSION:-"1.12.6"}
  echo "Check that docker $docker_version is installed"
  docker_status=`docker --version | grep "Docker version $docker_version" -o`
  if [ "$docker_status" != "Docker version $docker_version" ]; then
    echo "Expected $docker_version, but found $docker_status."
    success=False
  fi

  docker_status=`systemctl status docker-tcp.socket | grep 'Active.*active' -o`
  if [ "$docker_status" != "Active: active" ]; then
    echo "docker-tcp.socket is not active."
    success=False
  fi
  if [ $success = False ]; then 
    echo "This can cause problems installing docker if the script is being run from a node in the cluster."
    echo "If you are running the script from a node not being used for the installation, you may continue with the installation."
    echo "Otherwise install $docker_version with docker-tcp.socket active and retry the installation."
    echo "Press Ctrl+C to cancel the installation"
    sleep 5
  fi
}

usage() {
  echo "Usage:"
  echo "./install_swarm.sh -f <host configuration file> -n <netmaster IP> -a <ansible options> -e <ansible key> -i <install scheduler stack> -z <installer config file>"

  echo ""
  exit 1
}

mkdir -p $src_conf_path
# Check for docker only when requested to install the scheduler stack
# Else there are no pre-requisites on the host
install_scheduler=""
while getopts ":f:z:c:k:n:a:e:i" opt; do
  case $opt in
    f)
      cp $OPTARG $host_contiv_config
      ;;
    z)
      cp $OPTARG $host_installer_config
      ;;
    c)
      cp $OPTARG $host_tls_cert
      ;;
    k)
      cp $OPTARG $host_tls_key
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
    i) 
      check_for_prereqs
      install_scheduler="-i"
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

if [[ ! -f $host_installer_config ]]; then
	touch $host_installer_config
  echo "Created host_installer_config"
fi

if [[ "$netmaster" = ""  ]]; then
	echo "Netmaster IP/name is missing"
  usage
fi

if [[ "$ans_opts" = "" ]]; then
	echo "Attempting to install with default Ansible SSH options $def_ans_opts"
  ans_opts=$def_ans_opts
fi

if [[ -f $ans_key ]]; then
  cp $ans_key $host_ans_key
  ans_opts="$ans_opts --private-key $def_ans_key "
fi

if [[ ! -f $host_tls_cert || ! -f $host_tls_key ]]; then
  echo "Generating local certs for Contiv Proxy"
  openssl genrsa -out $host_tls_key 2048 >/dev/null 2>&1
  openssl req -new -x509 -sha256 -days 3650 \
      -key $host_tls_key \
      -out $host_tls_cert \
      -subj "/C=US/ST=CA/L=San Jose/O=CPSG/OU=IT Department/CN=auth-local.cisco.com"
fi 

echo "Starting the ansible container"
docker run --rm -v $src_conf_path:$container_conf_path contiv/install:__CONTIV_INSTALL_VERSION__ sh -c "./install/ansible/install.sh -n $netmaster -a \"$ans_opts\" $install_scheduler"
rm -rf $src_conf_path
