
kubectl create ns rook-ceph
helm install --namespace rook-ceph rook-ceph rook-release/rook-ceph
