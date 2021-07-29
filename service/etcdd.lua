require "common"
local etcd = require "etcd.etcd"

local etcdCli
function init( ... )
    local etcdHosts, user, password, protocol = ...
    local opt = {
        http_host = generateEtcdHosts(etcdHosts),
        user = user,
        password = password,
        protocol = protocol,
        serializer = "json"  -- 默认使用json格式配置
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

-- v3 support
function response.setnx(key, value, ttl)
    return etcdCli:setnx(key, value, ttl)
end

function accept.setnx(key, value, ttl)
    etcdCli:setnx(key, value, ttl)
end

-- v3 support
function response.setx(key, value, ttl)
    return etcdCli:setx(key, value, ttl)
end

function accept.setx(key, value, ttl)
    etcdCli:setx(key, value, ttl)
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

-- v3 support
function response.grant(ttl, id)
    return etcdCli:grant(ttl, id)
end

function accept.grant(ttl, id)
    etcdCli:grant(ttl, id)
end

-- v3 support
function response.revoke(id)
    return etcdCli:revoke(id)
end

function accept.revoke(id)
    etcdCli:revoke(id)
end

-- v3 support
function response.keepalive(id)
    return etcdCli:keepalive(id)
end

function accept.keepalive(id)
    etcdCli:keepalive(id)
end

-- v3 support
function response.timetolive(id, keys)
    return etcdCli:timetolive(id, keys)
end

function accept.timetolive(id, keys)
    etcdCli:timetolive(id, keys)
end

-- v3 support
function response.leases()
    return etcdCli:leases()
end

function response.exec(cmd, ...)
    return etcdCli[cmd](etcdCli, ...)
end

function accept.exec(cmd, ...)
    etcdCli[cmd](etcdCli, ...)
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
