#!/bin/bash

set -euo pipefail

release="${CONTIV_RELEASE_VER:-1.0.0-alpha}"
svc_ip="${MASTER_IP:-192.168.2.10}"
url="https://${svc_ip}:10000" # master_ip copied from Vagrantfile

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

echo
echo "Contiv Admin Console is available at:"
echo ""
echo "	$url"
echo ""
cat <<EOF
NOTE: Because the Contiv Admin Console is using a self-signed certificate for this demo,
      you will see a security warning when the page loads.  You can safely dismiss it.
EOF
