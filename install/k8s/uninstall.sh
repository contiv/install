#!/bin/bash

set -euo pipefail

if [ "$#" -eq 1 ] && [ "$1" = "-h" ]; then
  echo "Usage: ./install/k8s/uninstall.sh to uninstall contiv"
  echo "       ./install/k8s/uninstall.sh etcd-cleanup to uninstall contiv and cleanup contiv data"
  exit 1
fi

# Delete the ACI secret if it is available
kubectl delete secret aci.key -n kube-system || true

# Delete Contiv pods
kubectl delete -f .contiv.yaml

if [ "$#" -eq 1 ] && [ "$1" = "etcd-cleanup" ]; then
  rm -rf /var/etcd/contiv-data
fi

kubectl create -f install/k8s/cleanup.yaml
sleep 60
kubectl delete -f install/k8s/cleanup.yaml

# Re-creating the kube-dns deployment
kubectl create -f kube-dns.yaml
