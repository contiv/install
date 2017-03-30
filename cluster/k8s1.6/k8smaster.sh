kubeadm init --token=$1 --apiserver-advertise-address=$2 --skip-preflight-checks=true --kubernetes-version $3 --service-cidr 10.254.0.0/16
