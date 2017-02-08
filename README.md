# Contiv Installation for Docker Swarm & Kubernetes 1.4+

## Docker Swarm installation

### Pre-requisites
* Supported operating systems are CentOS 7.x or RHEL 7.x.
* Docker needs to be installed on the host where the installer is being run.
* Install a docker swarm cluster (or)
  Use the Contiv installer to install the scheduler stack after installing docker
  on a node external to the cluster where the scheduler stack is being installed.

### Contiv Installation

Contiv swarm installer is launched from a host external to the cluster.
Here is the reference layout. All the nodes need to be accessible to the installer host.
```

                                 ┌─────────────────────────────────────────────────────────────────────┐         
                                 │        #####  #       #     #  #####  ####### ####### ######        │         
                                 │       #     # #       #     # #     #    #    #       #     #       │         
                                 │       #       #       #     # #          #    #       #     #       │         
                                 │       #       #       #     #  #####     #    #####   ######        │         
                                 │       #       #       #     #       #    #    #       #   #         │         
                                 │       #     # #       #     # #     #    #    #       #    #        │         
                                 │        #####  #######  #####   #####     #    ####### #     #       │         
                                 │                                                                     │         
                                 │                                                                     │         
                                 │                                         ┌────────────────────┐      │         
                                 │                                         │                    │      │         
                ┌──────── SSH  ──┼─────────────────────────────────────────▶    Worker Node     │      │         
                │                │         ┌────────────────────┐          │                    │      │         
                │                │         │                    │          └────────────────────┘      │         
                │                │  ┌──────▶    Master Node     │                                      │         
                │                │  │      │                    │          ┌────────────────────┐      │         
                │                │  │      └────────────────────┘          │                    │      │         
   ┌────────────┴────────────┐   │  │                                      │    Worker Node     ◀──────┼────────┐
   │                         │   │  │                                      │                    │      │        │
   │      Install Host       │   │  │      ┌────────────────────┐          │                    │      │        │
   │(Ansible based installer,│   │         │                    │          └────────────────────┘      │        │
   │   running in a docker   │───┼── SSH  ─▶    Master Node     │                                      │        │
   │       container)        │   │         │                    │          ┌────────────────────┐      │        │
   │                         │   │  │      └────────────────────┘          │                    │      │        │
   │                         │   │  │                                      │    Worker Node     │◀─────┼────────┤
   └────────────┬────────────┘   │  │                                      │                    │      │        │
                │                │  │      ┌────────────────────┐          │                    │      │        │
                │                │  │      │                    │          └────────────────────┘      │        │
                │                │  └──────▶    Master Node     │                                      │        │
                │                │         │                    │          ┌────────────────────┐      │        │
                │                │         └────────────────────┘          │                    │      │        │
                ├───────── SSH  ─┼─────────────────────────────────────────▶    Worker Node     │      │        │
                │                │                                         │                    │      │        │
                │                │                                         └────────────────────┘      │        │
                │                │                                                                     │        │
                │                │                                                                     │        │
                │                │                                                                     │        │
                │                │                                                                     │        │
                │                └─────────────────────────────────────────────────────────────────────┘        │
                │                                                                                               │
                │                                                                                               │
                └─────────────────────────────────────────────── SSH  ──────────────────────────────────────────┘
                                                                                                                 

## How to use Installer :

To get installer please refer : https://github.com/contiv/install/releases

Download the install bundle, save it and extract it on Install host.

### Installer Usage:

`./install/ansible/install_swarm.sh -f <host configuration file>  -e <ssh key> -u <ssh user> OPTIONS`

Options:
```
-f   string                 Configuration file listing the hostnames with the control and data interfaces and optionally ACI parameters
-e  string                  SSH key to connect to the hosts
-u  string                  SSH User
-i                          Install the swarm scheduler stack

Options:
-m  string                  Network Mode for the Contiv installation (“standalone” or “aci”). Default mode is “standalone” and should be used for non ACI-based setups
-d   string                 Forwarding mode (“routing” or “bridge”). Default mode is “bridge”

Advanced Options:
-v   string                 ACI Image (default is contiv/aci-gw:latest). Use this to specify a specific version of the ACI Image.
-n   string                 DNS name/IP address of the host to be used as the net master  service VIP.

```

Additional parameters can also be updated in install/ansible/env.json file.

### Examples:

```
1. Install Contiv with Docker Swarm on hosts specified by cfg.yml.
./install/ansible/install_swarm.sh -f cfg.yml -e ~/ssh_key -u admin -i

2. Install Contiv on hosts specified by cfg.yml. Docker should be pre-installed on the hosts.
./install/ansible/install_swarm.sh -f cfg.yml -e ~/ssh_key -u admin

3. Install Contiv with Docker Swarm on hosts specified by cfg.yml in ACI mode.
./install/ansible/install_swarm.sh -f cfg.yml -e ~/ssh_key -u admin -i -m aci

4. Install Contiv with Docker Swarm on hosts specified by cfg.yml in ACI mode, using routing as the forwarding mode.
./install/ansible/install_swarm.sh -f cfg.yml -e ~/ssh_key -u admin -i -m aci -d routing

```

### Uninstaller Usage: 

` ./install/ansible/uninstall_swarm.sh -f <host configuration file>  -e <ssh key> -u <ssh user> OPTIONS`

Options: 
```
-f   string            Configuration file listing the hostnames with the control and data interfaces and optionally ACI parameters
-e  string             SSH key to connect to the hosts
-u  string             SSH User
-i                     Uninstall the scheduler stack

Options:
-r                     Reset etcd state and remove docker containers
-g                     Remove docker images
```

Additional parameters can also be updated in install/ansible/env.json file.

```
Examples:
1. Uninstall Contiv and Docker Swarm on hosts specified by cfg.yml.
./install/ansible/uninstall_swarm.sh -f cfg.yml -e ~/ssh_key -u admin -i
2. Uninstall Contiv and Docker Swarm on hosts specified by cfg.yml for an ACI setup.
./install/ansible/uninstall_swarm.sh -f cfg.yml -e ~/ssh_key -u admin -i -m aci
3. Uninstall Contiv and Docker Swarm on hosts specified by cfg.yml for an ACI setup, remove all containers and Contiv etcd state
./install/ansible/uninstall_swarm.sh -f cfg.yml -e ~/ssh_key -u admin -i -m aci -r
```

## Kubernetes 1.4 installation

### Pre-requisites

* Supported operating systems are CentOS 7.x or RHEL 7.x.
* Install kubernetes 1.4 or higher using http://kubernetes.io/docs/getting-started-guides/kubeadm/.

### Contiv Installation

* Download the install bundle  `<TODO add a location here>`.
* Extract the install bundle.
* Run `sudo ./install/k8s/install.sh -n $contiv_master`.
  where $contiv_master is the IP to be used for the Contiv proxy.
* To see additional install options run `./install/ansible/install.sh`.
