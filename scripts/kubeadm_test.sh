ssh_key=${CONTIV_SSH_KEY:-"cluster/export/insecure_private_key"}
user=${CONTIV_SSH_USER:-"vagrant"}
install_version=${CONTIV_RELEASE:-"contiv-devbuild"}
contiv_os=${CONTIV_NODE_OS:-"centos7"}
contiv_master=${CONTIV_MASTER:-"192.168.2.10"}
dest_path=${CONTIV_TARGET:-"/home/vagrant"}
ssh_opts="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

# Copy the installation folder
scp $ssh_opts -i $ssh_key release/$install_version.tgz $user@$contiv_master:$dest_path

# Extract and launch the installer
ssh $ssh_opts -i $ssh_key $user@$contiv_master "sudo rm -rf $dest_path/$install_version"
ssh $ssh_opts -i $ssh_key $user@$contiv_master "cd $dest_path && tar -xvzf $install_version.tgz"
ssh $ssh_opts -i $ssh_key $user@$contiv_master "cd $dest_path/$install_version && chmod +x install/install.sh"
ssh $ssh_opts -i $ssh_key $user@$contiv_master "cd $dest_path/$install_version && chmod +x install/k8s/install.sh"
ssh $ssh_opts -i $ssh_key $user@$contiv_master "cd $dest_path/$install_version && sudo ./install/install.sh"
ssh $ssh_opts -i $ssh_key $user@$contiv_master "cd $dest_path/$install_version && sudo ./install/k8s/install.sh -n $contiv_master"

# Wait for CONTIV to start up
sleep 60
response=`curl -k -H "Content-Type: application/json" -X POST -d '{"username": "admin", "password": "admin"}' https://$contiv_master:10000/api/v1/auth_proxy/login`
echo $response
if  [[ $response == *"token"* ]]; then
  echo "Install SUCCESS"
else
  echo "Install FAILED"
fi
