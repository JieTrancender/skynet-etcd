# !/bin/bash

etcd --config-file ./etcd1.conf 2>&1 >/dev/null &
etcd --config-file ./etcd2.conf 2>&1 >/dev/null &
etcd --config-file ./etcd3.conf 2>&1 >/dev/null &
