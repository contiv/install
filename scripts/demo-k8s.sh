#!/bin/bash

set -euo pipefail

release="${CONTIV_RELEASE_VER:-1.0.0-beta.2}"
svc_ip="${MASTER_IP:-192.168.2.10}"
url="https://${svc_ip}:10000" # master_ip copied from Vagrantfile
default_net_cidr="${DEFAULT_NET:-20.1.1.0/24}"

VAGRANT_USE_KUBEADM=1 make cluster

set +e # read returns 1 when it succeeds
read -r -d '' COMMANDS <<-EOF
    # github redirects you to a signed AWS URL, so we need to follow redirects with -L \\
    curl -L -O https://github.com/contiv/install/releases/download/${release}/contiv-${release}.tgz && \\
    tar xf contiv-${release}.tgz && \\
    cd contiv-${release} && \\
    sudo ./install/k8s/install.sh -n ${svc_ip}
EOF
set -e

cd cluster
vagrant ssh contiv-master -- "$COMMANDS"

set +e
read -r -d '' SETUP_DEFAULT_NET <<-EOF
    cd contiv-${release} && \\
    sudo netctl net create -s ${default_net_cidr} default-net
EOF
set -e

echo
echo "Waiting 30 seconds ..."
sleep 30
echo
echo "Creating default network"
vagrant ssh contiv-master -- "${SETUP_DEFAULT_NET}"

echo
echo "Contiv Admin Console is available at:"
echo ""
echo "	$url"
echo ""
cat <<EOF
NOTE: Because the Contiv Admin Console is using a self-signed certificate for this demo,
      you will see a security warning when the page loads.  You can safely dismiss it.
EOF

