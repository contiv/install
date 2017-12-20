kubeadm init --token-ttl 0 --token=$1 --apiserver-advertise-address=$2 --skip-preflight-checks=true --kubernetes-version $3
if [ "$#" -eq 4 ]; then
	cp /etc/kubernetes/admin.conf /home/$4
	chown $(id -u $4):$(id -g $4) /home/$4/admin.conf
	echo "export KUBECONFIG=/home/$4/admin.conf" >>/home/$4/.$(basename $SHELL)rc
	echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >>~/.$(basename $SHELL)rc
fi
