#!/usr/bin/python

import sys
import yaml

NW_MODE_STANDALONE = 'standalone'
NW_MODE_ACI = 'aci'

class SafeDict(dict):
    'Provide a default value for missing keys'
    def __missing__(self, key):
        return 'missing'

class Inventory:
    groupName = "netplugin-node"
    masterGroupName = "netplugin-master"
    workerGroupName = "netplugin-worker"

    def __init__(self, args):
        self.cfgFile = args[0]
        self.inventoryFile = args[1]
        self.nodeInfoFile = args[2]
        self.networkMode = args[3].lower()
        self.fwdMode = args[4]
    def parseConfigFile(self):
        with open(self.cfgFile) as inFd:
            config = yaml.load(inFd)
        self.configInfo = SafeDict(config)

    def handleMissing(self, item, holder, fd):
        print "ERROR No entry for {} in {}".format(item, holder)
        fd.close()
        sys.exit(1)

    def writeInventoryEntry(self, outFd, config):
        if self.configInfo[config] is 'missing':
            self.handleMissing(config, self.cfgFile, outFd);
        else:
            cfg_entry = "{}={}\n".format(config.lower(), self.configInfo[config])
            outFd.write(cfg_entry)

    def writeInventory(self, outFd, groupName, groupRole):
        outFd.write("[" + groupName + "]\n")
        connInfo = SafeDict(self.configInfo['CONNECTION_INFO'])

        # Add host entries in the inventory file
        for node in connInfo:
            role = connInfo[node].get('role', 'worker')
            if role != groupRole:
                continue
            var_line = "node{} ".format(self.nodeCount)
            outFd.write(var_line)
            var_line = "ansible_ssh_host={} ".format(node)
            outFd.write(var_line)
            var_line = "control_interface={} ".format(connInfo[node]['control'])
            outFd.write(var_line)
            var_line = "netplugin_if={} \n".format(connInfo[node]['data'])
            outFd.write(var_line)

            self.nodeCount += 1

        outFd.write("\n")

    def writeGlobalVars(self, outFd):
        outFd.write("[" + "all:vars]\n")
        var_line = "fwd_mode={}\n".format(self.fwdMode)
        net_mode = "vlan" if self.fwdMode == "bridge" else "vxlan"
        var_line += "net_mode=%s\n" % net_mode
        outFd.write(var_line)
        var_line = "contiv_network_mode={}\n".format(self.networkMode)
        outFd.write(var_line)

        # write group vars if network mode is ACI
        if self.networkMode == NW_MODE_ACI:
            self.writeInventoryEntry(outFd, 'APIC_URL')
            self.writeInventoryEntry(outFd, 'APIC_USERNAME')
            self.writeInventoryEntry(outFd, 'APIC_PASSWORD')
            self.writeInventoryEntry(outFd, 'APIC_PHYS_DOMAIN')
            self.writeInventoryEntry(outFd, 'APIC_EPG_BRIDGE_DOMAIN')
            self.writeInventoryEntry(outFd, 'APIC_CONTRACTS_UNRESTRICTED_MODE')

            if self.configInfo['APIC_LEAF_NODES'] is 'missing':
                self.handleMissing("APIC_LEAF_NODES", self.cfgFile, outFd);

            if self.configInfo['APIC_LEAF_NODES'] is None:
                self.handleMissing("APIC_LEAF_NODES", self.cfgFile, outFd);
            else:
                leafCount = 0
                leafStr = "apic_leaf_nodes="
                for leaf in self.configInfo['APIC_LEAF_NODES']:
                    if leafCount > 0:
                        leafStr += ","

                    leafStr += leaf
                    leafCount += 1

                # if no leaf was found, treat as error
                if leafCount == 0:
                    self.handleMissing("APIC_LEAF_NODES", self.cfgFile, outFd);

                leafStr += "\n"
                outFd.write(leafStr)

    def writeNodeInfo(self):
        with open(self.nodeInfoFile, "w+") as nodeInfoFd:
            # Node count starts from 1 and is incremented for
            # each node. So the actual number of nodes is nodeCount -1
            node_info = "{}".format(self.nodeCount - 1)
            nodeInfoFd.write(node_info)

    def writeInventoryFile(self):
        with open(self.inventoryFile, "w+") as outFd:
            self.nodeCount = 1
            self.writeInventory(outFd, Inventory.masterGroupName, "master")
            self.writeInventory(outFd, Inventory.workerGroupName, "worker")
            # The main group containing both the master and worker nodes
            outFd.write("[" + Inventory.groupName + ":children]\n")
            outFd.write(Inventory.masterGroupName + "\n")
            outFd.write(Inventory.workerGroupName + "\n\n")
            self.writeGlobalVars(outFd)

if __name__ == "__main__":
    inv = Inventory(sys.argv[1:])

    inv.parseConfigFile()

    inv.writeInventoryFile()

    inv.writeNodeInfo()
