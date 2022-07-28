#### docker方式启动
~~~
docker build -t skynet-etcd .
docker run --rm -it --name skynet-etcd-test skynet-etcd ./skynet-etcd/skynet examples/config.helloWorld.lua
~~~

#### 本地开发
~~~
docker build -t skynet-etcd .
sh tools/container.sh
~~~
