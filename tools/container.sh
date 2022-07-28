docker run \
    --rm \
    -it \
    --name skynet-etcd-dev \
    -v $PWD/examples:/skynet-etcd/examples \
    -v $PWD/lualib:/skynet-etcd/lualib \
    -v $PWD/service:/skynet-etcd/service \
    -v $PWD/tools:/skynet-etcd/tools \
    skynet-etcd /bin/sh
