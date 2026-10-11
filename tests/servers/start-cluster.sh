#!/bin/sh
# Starts six cluster nodes on 7000-7005 in one container and joins them.
set -e
for p in 7000 7001 7002 7003 7004 7005; do
  mkdir -p /tmp/$p
  valkey-server --port $p --cluster-enabled yes --cluster-config-file nodes.conf \
    --dir /tmp/$p --appendonly no --save "" --daemonize yes
done
sleep 1
yes yes | valkey-cli --cluster create 127.0.0.1:7000 127.0.0.1:7001 127.0.0.1:7002 \
  127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005 --cluster-replicas 1
exec tail -f /dev/null
