kubeadm init --token=$1 --api-advertise-addresses=$2 --skip-preflight-checks=true --use-kubernetes-version $3 --service-cidr 10.254.0.0/16
