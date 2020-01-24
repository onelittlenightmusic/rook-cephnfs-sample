mkdir /tmp/registry
mon_endpoints=rook-ceph-mon-a:6789
my_secret="AQCXNCZema/ZBxAAfAHC2yW8LpGlIuJ36oT0Cw=="
mount -t ceph -o mds_namespace=myfs,name=admin,secret=$my_secret $mon_endpoints:/ /tmp/registry
df -h
