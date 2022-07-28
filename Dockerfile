FROM alpine:latest as builder

RUN apk add --update alpine-sdk
RUN apk add readline-dev readline autoconf

COPY . /skynet-etcd
WORKDIR /skynet-etcd
RUN cd skynet && make linux

FROM alpine:latest 

RUN apk add --no-cache libgcc readline autoconf
COPY --from=builder /skynet-etcd /skynet-etcd
WORKDIR /skynet-etcd

CMD ["./skynet/skynet", "./examples/config.helloWorld.lua"]
