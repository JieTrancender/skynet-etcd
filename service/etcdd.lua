require "common"
local etcd = require "etcd.etcd"

local etcdCli
function init( ... )
    local etcdHosts, user, password, protocol = ...
    local opt = {
        http_host = generateEtcdHosts(etcdHosts),
        user = user,
        password = password,
        protocol = protocol
    }

    local err
    etcdCli, err = etcd.new(opt)
    if not etcdCli then
        logError("etcdd init wrong, ", err)
        return
    end
end

function exit()
    log("etcdd exit success")
end

function response.get( ... )
    return etcdCli:get(...)
end

function response.set( key, value, ttl )
    return etcdCli:set(key, value, ttl)
end

function accept.set( key, value, ttl )
    etcdCli:set(key, value, ttl)
end

function accept.delete( ... )
    etcdCli:delete(...)
end

function response.delete( ... )
    return etcdCli:delete(...)
end

function accept.rmdir( ... )
    etcdCli:rmdir(...)
end

function response.rmdir( ... )
    return etcdCli:rmdir(...)
end

function response.stats_leader()
    return etcdCli:stats_leader()
end

function response.stats_self()
    return etcdCli:stats_self()
end

function response.stats_store()
    return etcdCli:stats_store()
end

function response.version()
    return etcdCli:version()
end

function response.readdir(key, recursive)
    return etcdCli:readdir(key, recursive)
end
