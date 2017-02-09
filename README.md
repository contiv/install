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

                               ┌─────────────────────────────────────────────────────────────┐         
                               │   #####  #       #     #  #####  ####### ####### ######     │         
                               │  #     # #       #     # #     #    #    #       #     #    │         
                               │  #       #       #     # #          #    #       #     #    │         
                               │  #       #       #     #  #####     #    #####   ######     │         
                               │  #       #       #     #       #    #    #       #   #      │         
                               │  #     # #       #     # #     #    #    #       #    #     │         
                               │   #####  #######  #####   #####     #    ####### #     #    │         
                               │                                                             │         
                               │                                                             │         
                               │                                         ┌───────────────┐   │         
                               │                                         │               │   │         
              ┌──────── SSH  ──┼─────────────────────────────────────────▶  Worker Node  │   │         
              │                │         ┌────────────────────┐          │               │   │         
              │                │         │                    │          └───────────────┘   │         
              │                │  ┌──────▶    Master Node     │                              │         
              │                │  │      │                    │          ┌───────────────┐   │         
              │                │  │      └────────────────────┘          │               │   │         
 ┌────────────┴────────────┐   │  │                                      │  Worker Node  ◀───┼──┐
 │                         │   │  │                                      │               │   │  │
 │      Install Host       │   │  │      ┌────────────────────┐          │               │   │  │
 │(Ansible based installer,│   │         │                    │          └───────────────┘   │  │
 │   running in a docker   │───┼── SSH  ─▶    Master Node     │                              │  │
 │       container)        │   │         │                    │          ┌───────────────┐   │  │
 │                         │   │  │      └────────────────────┘          │               │   │  │
 │                         │   │  │                                      │  Worker Node  │◀──┼──┤
 └────────────┬────────────┘   │  │                                      │               │   │  │
              │                │  │      ┌────────────────────┐          │               │   │  │
              │                │  │      │                    │          └───────────────┘   │  │
              │                │  └──────▶    Master Node     │                              │  │
              │                │         │                    │          ┌───────────────┐   │  │
              │                │         └────────────────────┘          │               │   │  │
              ├───────── SSH  ─┼─────────────────────────────────────────▶  Worker Node  │   │  │
              │                │                                         │               │   │  │
              │                │                                         └───────────────┘   │  │
              │                │                                                             │  │
              │                │                                                             │  │
              │                │                                                             │  │
              │                │                                                             │  │
              │                └─────────────────────────────────────────────────────────────┘  │
              │                                                                                 │
              │                                                                                 │
              └──────────────────────────────────────────── SSH  ───────────────────────────────┘
                                                                                                               

```

* `curl -L -O https://github.com/contiv/install/releases/download/$VERSION/contiv-$VERSION.tgz`
* To use a local installation for Contiv components you may use the larger version of the installer 
 using `curl -L -O https://github.com/contiv/install/releases/download/$VERSION/contiv-full-$VERSION.tgz`.
 This should be used only in cases where accessibility to network is slow.
* `tar xf contiv-$VERSION.tgz`
* `cd contiv-$VERSION`
* Install Contiv with Docker Swarm
* `./install/ansible/install_swarm.sh -f cfg.yml -e <ssh key> -u <username> -i`
* Uninstall Contiv with Docker Swarm and reset install state
* `./install/ansible/uninstall_swarm.sh -f cfg.yml -e <ssh key> -u <username> -i -r`
* Install Contiv with Docker Swarm and ACI
* `./install/ansible/install_swarm.sh -f aci_cfg.yml -e <ssh key> -u <username> -i -m aci`
* Uninstall Contiv with Docker Swarm and ACI, retaining the install state
* `./install/ansible/uninstall_swarm.sh -f aci_cfg.yml -e <ssh key> -u <username> -i -m aci`
* Example host config file is available at install/ansible/cfg.yml and install/ansible/aci_cfg.yml
* To see additional install options and examples, run `./install/ansible/install_swarm.sh -h`.

## Kubernetes 1.4 installation

### Pre-requisites

* Supported operating systems are CentOS 7.x or RHEL 7.x.
* Install kubernetes 1.4 or higher using http://kubernetes.io/docs/getting-started-guides/kubeadm/.
* Contiv service-cidr is currently 10.254.0.0/16. So `kubeadm init` step needs to be called with `--service-cidr 10.254.0.0/16` parameter.
* Step (3/4) in the kubeadm install guide has to be replaced with the Contiv Installation below.
* Contiv Installation can be done before or after (4/4) in the kubeadm install guide.

### Contiv Installation

* `curl -L -O https://github.com/contiv/install/releases/download/$VERSION/contiv-$VERSION.tgz`
* `tar xf contiv-$VERSION.tgz`
* `cd contiv-$VERSION`
* Run `sudo ./install/k8s/install.sh -n $CONTIV_MASTER`,
  where $CONTIV_MASTER is the IP to be used for the Contiv proxy.
* To see additional install options and examples, run `./install/ansible/install.sh -h`.
* Run `sudo ./install/k8s/uninstall.sh` to uninstall Contiv.

