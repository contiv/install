ssh_key=${CONTIV_SSH_KEY:-cluster/insecure_private_key}
user=${CONTIV_SSH_USER:-vagrant}
install_bundle=${CONTIV_RELEASE:-release/contiv-devbuild.tgz}
contiv_os=${CONTIV_NODE_OS:-centos7}

# Copy the installation folder
scp -i $ssh_key $install_bundle $user@contiv-master:/tmp/

# Copy the configuration file
scp -i $ssh_key $config_file $user@contiv-master:/tmp/

# Extract and launch the installer
ssh -i $ssh_key $user@contiv-master "cd /tmp && tar -xvzf $install_bundle && chmod +x contiv/ansible/install_k8s.sh"
ssh -i $ssh_key $user@contiv-master "VAGRANT_USE_KUBEADM=1 CONTIV_NODE_OS=$contiv_os contiv/ansible/install_k8s.sh"
