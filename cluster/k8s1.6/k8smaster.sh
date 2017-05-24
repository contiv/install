kubeadm init --token=$1 --apiserver-advertise-address=$2 --skip-preflight-checks=true --kubernetes-version $3
