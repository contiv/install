#!/bin/bash

if [ $EUID -ne 0 ]; then
	echo "Please run this script as root user"
	exit 1
fi

kubectl="kubectl --kubeconfig /etc/kubernetes/admin.conf"
k8sversion=$($kubectl version --short | grep "Server Version")
if [ "$#" -eq 1 ] && [ "$1" = "-h" ]; then
	echo "Usage: ./install/k8s/uninstall.sh to uninstall contiv"
	echo "       ./install/k8s/uninstall.sh etcd-cleanup to uninstall contiv and cleanup contiv data"
	exit 1
fi

# Delete the ACI secret if it is available
$kubectl delete secret aci.key -n kube-system

# Delete Contiv pods
$kubectl delete -f .contiv.yaml

if [ "$#" -eq 1 ] && [ "$1" = "etcd-cleanup" ]; then
	rm -rf /var/etcd/contiv-data
fi

$kubectl create -f install/k8s/configs/cleanup.yaml
sleep 60
$kubectl delete -f install/k8s/configs/cleanup.yaml
