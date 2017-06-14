#!/bin/bash
# This is the install script for Contiv.

set -euo pipefail

if [ $EUID -ne 0 ]; then
	echo "Please run this script as root user"
	exit 1
fi

kubectl="kubectl --kubeconfig /etc/kubernetes/admin.conf"
k8sversion=$($kubectl version --short | grep "Server Version")
if [[ "$k8sversion" == *"v1.4"* ]] || [[ "$k8sversion" == *"v1.5"* ]]; then
	k8sfolder="k8s1.4"
else
	k8sfolder="k8s1.6"
fi

#
# The following parameters are user defined - and vary for each installation
#

# If an etcd or consul cluster store is not provided, we will start an etcd instance
cluster_store=""

# Netmaster address
netmaster=""

# Dataplane interface
vlan_if=""

# Contiv configuration can be specified through a config file and/or parameters
contiv_config=""

# Specify TLS certs to be used for API server
tls_cert=""
tls_key=""
fwd_mode="routing"
# ACI parameters
apic_url=""
apic_username=""
apic_password=""
apic_leaf_node=""
apic_phys_domain=""
apic_epg_bridge_domain="not_specified"
apic_contracts_unrestricted_mode="no"
aci_key=""
apic_cert_dn=""

infra_gateway="132.1.1.1"
infra_subnet="132.1.1.0/24"

usage() {
	echo "Usage:"
	cat <<EOF
Contiv Installer for Kubeadm based setups.

Installer:
Usage: ./install/k8s/install.sh OPTIONS

Mandatory Options:
-n   string     DNS name/IP address of the host to be used as the net master service VIP.

Additional Options:
-s   string     External cluster store to be used to store contiv data. This can be an etcd or consul server.
-v   string     Data plane interface
-w   string     Forwarding mode (“routing” or “bridge”). Default mode is “bridge”
-c   string     Configuration file for netplugin
-t   string     Certificate to use for auth proxy https endpoint
-k   string     Key to use for auth proxy https endpoint
-g   string     Gateway to use for the infrastructure network
-i   string     The subnet to use for the infrastructure network

Additional Options for ACI:
-a   string     APIC URL to use for ACI mode
-u   string     Username to connect to the APIC
-p   string     Password to connect to the APIC
-l   string     APIC leaf node
-d   string     APIC physical domain
-e   string     APIC EPG bridge domain
-m   string     APIC contracts unrestricted mode

Examples:

1. Install Contiv on Kubeadm master host using the specified DNS/IP for netmaster.
./install/k8s/install.sh -n <netmaster DNS/IP>

2. Install Contiv on Kubeadm master host using the specified DNS/IP for netmaster and specified ACI configuration.
./install/k8s/install.sh -n <netmaster DNS/IP> -a https://apic_host:443 -u apic_user -p apic_password -l topology/pod-xxx/node-xxx -d phys_domain -e not_specified -m no

Advanced Usage:

This installer creates a Kubernetes application specification in a file named .contiv.yaml.
For further customization, you can edit this file manually and run the following to re-install Contiv.

$kubectl delete -f .contiv.yaml
$kubectl apply -f .contiv.yaml (This .contiv.yaml contains the new changes.)

EOF
	exit 1
}

error_ret() {
	echo ""
	echo "$1"
	exit 1
}

while getopts ":s:n:v:w:c:t:k:a:u:p:l:d:e:m:y:z:g:i:" opt; do
	case $opt in
		s)
			cluster_store=$OPTARG
			;;
		n)
			netmaster=$OPTARG
			;;
		v)
			vlan_if=$OPTARG
			;;
		w)
			fwd_mode=$OPTARG
			;;
		c)
			contiv_config=$OPTARG
			;;
		t)
			tls_cert=$OPTARG
			;;
		k)
			tls_key=$OPTARG
			;;
		a)
			apic_url=$OPTARG
			;;
		u)
			apic_username=$OPTARG
			;;
		p)
			apic_password=$OPTARG
			;;
		l)
			apic_leaf_node=$OPTARG
			;;
		d)
			apic_phys_domain=$OPTARG
			;;
		e)
			apic_epg_bridge_domain=$OPTARG
			;;
		m)
			apic_contracts_unrestricted_mode=$OPTARG
			;;
		y)
			aci_key=$OPTARG
			;;
		z)
			apic_cert_dn=$OPTARG
			;;
		g)
			infra_gateway=$OPTARG
			;;
		i)
			infra_subnet=$OPTARG
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

if [[ "$apic_url" != "" && "$apic_password" == "" && "$aci_key" == "" ]]; then
	read -s -p "Enter the APIC password: ", apic_password
	if [ "$apic_password" = "" ]; then
		usage
	fi
fi

if [[ "$apic_url" != "" ]]; then
	if [[ "$apic_username" == "" || "$apic_phys_domain" == "" || "$apic_leaf_node" == "" ]]; then
		usage
	fi
fi

echo "Installing Contiv for Kubernetes"
# Cleanup any older config files
contiv_yaml="./.contiv.yaml"
rm -f $contiv_yaml

# Create the new config file from the templates
contiv_yaml_template="./install/k8s/$k8sfolder/contiv.yaml"
contiv_etcd_template="./install/k8s/$k8sfolder/etcd.yaml"
contiv_aci_gw_template="./install/k8s/$k8sfolder/aci_gw.yaml"

cat $contiv_yaml_template >>$contiv_yaml

if [ "$cluster_store" = "" ]; then
	cat $contiv_etcd_template >>$contiv_yaml
fi

if [ "$apic_url" != "" ]; then
	cat $contiv_aci_gw_template >>$contiv_yaml
	# We do not support routing in ACI mode
	fwd_mode="bridge"
fi

# We will store the ACI key in a k8s secret.
# The name of the file should be aci.key
if [ "$aci_key" = "" ]; then
	aci_key=./aci.key
	echo "dummy" >$aci_key
else
	cp $aci_key ./aci.key
	aci_key=./aci.key
fi

$kubectl create secret generic aci.key --from-file=$aci_key -n kube-system

mkdir -p /var/contiv

if [ "$tls_cert" = "" ]; then
	echo "Generating local certs for Contiv Proxy"
	mkdir -p ./local_certs

	chmod +x ./install/generate-certificate.sh
	./install/generate-certificate.sh
	tls_cert=./local_certs/cert.pem
	tls_key=./local_certs/local.key
fi
cp $tls_cert /var/contiv/auth_proxy_cert.pem
cp $tls_key /var/contiv/auth_proxy_key.pem

echo "Setting installation parameters"
sed -i.bak "s/__NETMASTER_IP__/$netmaster/g" $contiv_yaml
sed -i.bak "s/__VLAN_IF__/$vlan_if/g" $contiv_yaml

if [ "$apic_url" != "" ]; then
	sed -i.bak "s#__APIC_URL__#$apic_url#g" $contiv_yaml
	sed -i.bak "s/__APIC_USERNAME__/$apic_username/g" $contiv_yaml
	sed -i.bak "s/__APIC_PASSWORD__/$apic_password/g" $contiv_yaml
	sed -i.bak "s#__APIC_LEAF_NODE__#$apic_leaf_node#g" $contiv_yaml
	sed -i.bak "s/__APIC_PHYS_DOMAIN__/$apic_phys_domain/g" $contiv_yaml
	sed -i.bak "s/__APIC_EPG_BRIDGE_DOMAIN__/$apic_epg_bridge_domain/g" $contiv_yaml
	sed -i.bak "s/__APIC_CONTRACTS_UNRESTRICTED_MODE__/$apic_contracts_unrestricted_mode/g" $contiv_yaml
fi
if [ "$apic_cert_dn" = "" ]; then
	sed -i.bak "/APIC_CERT_DN/d" $contiv_yaml
else
	sed -i.bak "s#__APIC_CERT_DN__#$apic_cert_dn#g" $contiv_yaml
fi

echo "Applying contiv installation"
grep -q -F "netmaster" /etc/hosts || echo "$netmaster netmaster" >>/etc/hosts
echo "To customize the installation press Ctrl+C and edit $contiv_yaml."
sleep 5
chmod +x ./netctl
rm -f /usr/bin/netctl
cp ./netctl /usr/bin/
# Install Contiv
$kubectl apply -f $contiv_yaml

sleep 10
set +e
for i in {0..30}; do
	netctl tenant ls >/dev/null 2>&1
	if [ "$?" -eq "0" ]; then
		break
	fi
	sleep 10
done
set -e

if [ "$fwd_mode" == "routing" ]; then
	netctl global set --fwd-mode $fwd_mode
	netctl net create -n infra -s $infra_subnet -g $infra_gateway contivh1
fi

echo "Installation is complete"
echo "========================================================="
echo " "
echo "Contiv UI is available at https://$netmaster:10000"
echo "Please use the first run wizard or configure the setup as follows:"
echo " Configure forwarding mode (optional, default is routing)."
echo " netctl global set --fwd-mode routing"
echo " Configure ACI mode (optional)"
echo " netctl global set --fabric-mode aci --vlan-range <start>-<end>"
echo " Create a default network"
echo " netctl net create -t default --subnet=<CIDR> default-net"
echo " For example, netctl net create -t default --subnet=20.1.1.0/24 -g 20.1.1.1 default-net"
echo " "
echo "========================================================="
