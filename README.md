# Deep Ops Deployment Notes

## Overview

Deepops can be install using the latest Centos 7 distribution. I used plain vnailla server media installed via usb and not over the network. Deepops has options for installing via MAAS, pxe or Foreman and I tried pxe but couldn't get it to work correctly.

I ran the provisioning from my mac pointing at the management server ip address. Addresses were automatically configured using dhcp from my router. I also installed [Zerotier](https://www.zerotier.com) so that I could ssh and kubectl the centos server using a virtual network ip. On the router, ipv6 was enabled.

#### Dependencies

After installing the os I had to install necessary dependencies in order to get the deepops install controller to communicate with my server. These included:
- [ssh](https://phoenixnap.com/kb/how-to-enable-ssh-centos-7)
- [ufw](https://linuxconfig.org/how-to-install-and-use-ufw-firewall-on-linux)
- [nfs](https://www.thegeekdiary.com/centos-rhel-7-configuring-an-nfs-server-and-nfs-client/)


After installing **nfs-utils** and configured deepops to use the nfs server share at `/srv/nfs/kubedata/`, I used ansible to [provision the nfs server](https://github.com/supertetelman/deepops/tree/nfs-client-provisioner/docs/k8s-cluster#nfs-client-provisioner). This happened after initially provisioning the cluster with deepops but can be included.

#### Deepops

Deepops is software maintained by Nvidia at this github project: https://github.com/NVIDIA/deepops.git

**Important** First clone deepops to this repo root before running the controller.

I configured my server using the 20.10 release but later reinstalled/updated just the nfs-client-provisioner using the project here: https://github.com/supertetelman/deepops/tree/nfs-client-provisioner

## Control

To control the provisioning from my mac I created this [Dockerfile](./Dockerfile) Before running the container in interactive mode, we have to build the image.


```
docker build -t deepops-setup .
```

During provisioning a file is created to kubectl the cluster. In order to use that file so that I can use kubectl from my mac terminal, I mount the ~/.kube directory as a volume. I also bind mount the deepops directory in the target workspace so that I may save the configuration files for source control.

Use the following command to run our provisioning container interactively (ensure you are running from repo root):

```
docker run -v $HOME/.kube:/root/.kube \
           --mount src="$(pwd)/deepops",target=/workspace/deepops,type=bind \
           -it deepops-setup:latest
```





the following command on the control system, making sure to modify your path to match your setup:

```
docker run -v /Users/gmacmillan/.kube:/root/.kube \
           -v $(pwd)deepops:/workspace/deepops \
           -it deepops-setup:latest \
           /bin/bash
```

You should see a terminal that looks something like:
```
root@7977eae54cc4:/workspace#
```

cd to the `deepops` directory [Optional] checkout the latest branch with YY.MM refering to a release. e.g. 20.10

```
cd deepops
git checkout YY.MM
```

and run `./scripts/setup.sh`

#### Configure the inventory

First you must change the `config/inventory` file. For my setup using a single node, I uncommented the first line under **[all]**, **[kube-master]**, **[etcd]**, and **[kube-node]**. Under the **[all]** section, change the ansible_host to be whatever ip is being used from your provisioner.

If you are going to use an existing nfs-server, be sure to update the __k8s_nfs_server__ and __k8s_nfs_export_path__ variables in config/group_vars/k8s-cluster.yml

#### Test the ansible host connection

```
ansible all -m raw -a "hostname"
```

#### Run the installation

Run with `--skip-tags=nfs_server` if the nfs server is already setup; `nfs_mkdir` if the share directory is created.

```
ansible-playbook -l k8s-cluster playbooks/k8s-cluster.yml
```

## Kubeflow install notes

For more info see instructions here: https://github.com/supertetelman/deepops/blob/nfs-client-provisioner/docs/k8s-cluster/kubeflow.md#kubeflow-admin

Kubeflow app installed to: /workspace/deepops/scripts/k8s/../../config/kubeflow-install

It may take several minutes for all services to start. Run `kubectl get pods -n kubeflow` to verify

To remove (excluding CRDs, istio, auth, and cert-manager), run: ```./scripts/k8s/deploy_kubeflow.sh -d```

To perform a full uninstall : ```./scripts/k8s/deploy_kubeflow.sh -D```

Kubeflow Dashboard (HTTP NodePort): http://192.168.50.191:31380


## Old Notes
The following are older notes and not necessarily up to date. I haven't tried rook/ceph since nfs is working.


#### Deploy dashboard

```
root@827a859971f9:/workspace/deepops# ./scripts/k8s/deploy_dashboard_user.sh
service/kubernetes-dashboard patched
serviceaccount/admin-user created
clusterrolebinding.rbac.authorization.k8s.io/admin-user created

Dashboard is available at: https://192.168.50.8:31443

More on dashboard here:
https://tjth.co/setting-up-externally-available-kubernetes-dashboard/


Access token:```
###
```

#### Connection not private screen workaround

https://www.technipages.com/google-chrome-bypass-your-connection-is-not-private-message

  1. Click a blank section of the denial page.
  2. Using your keyboard, type thisisunsafe. This will add the website to a safe list, where you should not be prompted again.


#### Rook/Ceph

NOTES:
The Rook Operator has been installed. Check its status by running:
  kubectl --namespace rook-ceph get pods -l "app=rook-ceph-operator"

Visit https://rook.io/docs/rook/master for instructions on how to create and configure Rook clusters

Note: You cannot just create a CephCluster resource, you need to also create a namespace and
install suitable RBAC roles and role bindings for the cluster. The Rook Operator will not do
this for you. Sample CephCluster manifest templates that include RBAC resources are available:

- https://rook.github.io/docs/rook/master/ceph-quickstart.html
- https://github.com/rook/rook/blob/master/cluster/examples/kubernetes/ceph/cluster.yaml

Important Notes:
- The links above are for the unreleased master version, if you deploy a different release you must find matching manifests.
- You must customise the 'CephCluster' resource at the bottom of the sample manifests to met your situation.
- Each CephCluster must be deployed to its own namespace, the samples use `rook-ceph` for the cluster.
- The sample manifests assume you also installed the rook-ceph operator in the `rook-ceph` namespace.
- The helm chart includes all the RBAC required to create a CephCluster CRD in the same namespace.
- Any disk devices you add to the cluster in the 'CephCluster' must be empty (no filesystem and no partitions).
- In the 'CephCluster' you must refer to disk devices by their '/dev/something' name, e.g. 'sdb' or 'xvde'.
cephcluster.ceph.rook.io/rook-ceph created
cephblockpool.ceph.rook.io/replicapool created
storageclass.storage.k8s.io/rook-ceph-block created
deployment.apps/rook-ceph-tools created
cephfilesystem.ceph.rook.io/cephfs created
service/rook-ceph-mgr-dashboard-external-https created

Ceph deployed, it may take up to 10 minutes for storage to be ready
If install takes more than 30 minutes be sure you have cleaned up any previous Rook installs by running this script with the delete flag (-d) and have installed the required libraries using the bootstrap-rook.yml playbook
Monitor readiness with:
kubectl -n rook-ceph exec -ti rook-ceph-tools-8d9d7c8f4-vl9r2 -- ceph status | grep up:active

Ceph dashboard: https://192.168.50.8:31141

Create dashboard user with: kubectl -n rook-ceph exec -ti rook-ceph-tools-8d9d7c8f4-vl9r2 -- ceph dashboard set-login-credentials <username> <password>
