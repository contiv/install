if [ "$1" = "-h" ]; then
  echo "Usage: ./install/k8s/uninstall.sh to uninstall contiv"
  echo "       ./install/k8s/uninstall.sh etcd-cleanup to uninstall contiv and cleanup contiv data"
  exit 1
fi

# Delete the ACI secret if it is available
kubectl delete secret aci.key -n kube-system
# Delete Contiv pods
kubectl delete -f .contiv.yaml

if [ "$1" = "etcd-cleanup" ]; then
  rm -rf /var/etcd/contiv-data
fi
