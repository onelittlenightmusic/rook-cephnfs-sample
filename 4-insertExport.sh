#!/bin/bash
direct_mount_pod=$(kubectl get po -l app=rook-direct-mount -o jsonpath='{.items[0].metadata.name}')

kubectl cp 4-export $direct_mount_pod:/4-export
kubectl exec $direct_mount_pod -- rados -p myfs-data0 -N nfs-ns put conf-my-nfs.a /4-export