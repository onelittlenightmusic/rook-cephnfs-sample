# Rook/Ceph on Kind 


## 0. Create Kubernetes cluster

Run a command which creates the following Kubernetes cluster.

- Properties

| Spec | Details|
|---|---|
| Name | `rook` |
| Internal structure | 1 controller + 3 workers (set in `0-kind-config.yaml`) |
| Prerequisites | `kind` 0.17 |

- Command

```sh
kind create cluster --name rook --config 0-kind-config.yaml
```

## 1. Install Rook Operator and tool

Run a command which installs **Rook operator**.

- Properties

| Spec | Details|
|---|---|
| Prerequisites | `kubectl` 1.15, `helm` v3 |

- Command

```sh
kubectl create ns rook-ceph
helm repo add rook-release https://charts.rook.io/release
helm install --namespace rook-ceph rook-ceph rook-release/rook-ceph
```

## 2. Create Ceph cluster

Run a command which creates a **Ceph cluster** and useful tool container `direct-mount`.

- Properties

| Spec | Details|
|---|---|
| Kubernetes namespace | `rook-ceph` |
| Kubernetes resource type | `CephCluster` |
| name | `rook-ceph` |
| dataDirHostPath | `/var/lib/rook` |

- Command

```sh
kubectl create -f 2-cluster.yaml
kubectl create -f 2-direct-mount.yaml
```

* **Attention**: After this command, it will take a few minutes for all containers to start.

## 3. Create Ceph file system on Ceph cluster

Run a command which creates **Ceph file system** using the previous Ceph cluster. 

Additionally, this command creates `storageClass` which enables PV creation in this file system.

- Properties

| Spec | Details|
|---|---|
| Kubernetes namespace | `rook-ceph` |
| Kubernetes resource type | `CephFilesystem` |
| file system name | `myfs` |
| storageClass name | `csi-cephfs` |

- Command

```sh
kubectl create -f 3-file-storageclass.yaml 
```

## 4. Configure Ceph file system export

Run a command which configure **Ceph file system export** in ceph.

- Properties of export

| Spec | Details|
|---|---|
| `Path` | `/`|
| `Pseudo` | `/cephfs` |
| `FSAL` | `Name`: `CEPH`, `User_Id`: `admin`, `Fs_Name`: `myfs` |.

- Command

```sh
./4-insertExport.sh
kubectl create -f 4-cephnfs.yaml 
```

## 5. Mount and test

Run a command so that the `direct-mount` container mounts in both ways of `NFS` and `CephFS`.

- Test command (`NFS` mount and file creation)

```sh
nfsIP=$(kubectl get svc -l instance=a -o jsonpath='{.items[0].spec.clusterIP}')
direct_mount_pod=$(kubectl get po -l app=rook-direct-mount -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $direct_mount_pod -- bash -c "nfsIP=$nfsIP /bin/bash"

[root@rook-worker /]# mkdir -p /mnt/tmp
[root@rook-worker /]# mount -t nfs -o nfsvers=4.1 $nfsIP:/ /mnt/tmp
[root@rook-worker /]# bash -c 'echo "test" > /mnt/tmp/cephfs/test'
[root@rook-worker /]# cat /mnt/tmp/cephfs/test
test
[root@rook-worker /]# umount /mnt/tmp
```

- Test command (`PVC` mount and file creation)

```sh
kubectl create -f csi-cephfs-test-pod.yaml 
kubectl exec -it csi-cephfs-test-pod sh

/ # echo "created by pod" > /mnt/pvc/from-pod
/ # exit
```

- Test command (`CephFS` mount and file read)

```sh
direct_mount_pod=$(kubectl get po -l app=rook-direct-mount -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $direct_mount_pod -- bash

[root@rook-worker /]# mkdir -p /mnt/cephfs
[root@rook-worker /]# mon_endpoints=$(grep mon_host /etc/ceph/ceph.conf | awk '{print $3}')
[root@rook-worker /]# my_secret=$(grep key /etc/ceph/keyring | awk '{print $3}')
[root@rook-worker /]# mount -t ceph -o mds_namespace=myfs,name=admin,secret=$my_secret $mon_endpoints:/ /mnt/cephfs
[root@rook-worker /]# cat /mnt/cephfs/test
test
[root@rook-worker /]# ls /mnt/cephfs/volumes/csi/  
csi-vol-94b216e4-40b3-11ea-856d-22adc7405126
[root@rook-worker /]# cat /mnt/cephfs/volumes/csi/csi-vol-*/from-pod
created by pod

```

- Test command (Read file on `NFS`)

```sh
[root@rook-worker /]# cat /mnt/tmp/cephfs/volumes/csi/csi-vol-*/from-pod
created by pod
```

## 5. Teardown

```sh
kind delete cluster --name rook
```