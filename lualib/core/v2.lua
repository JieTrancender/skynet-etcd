local httpc        = require("http.httpc")
local typeof       = require("etcd.core.typeof")
local utils        = require("etcd.core.utils")
local cjson        = require("cjson.safe")
local encode_args  = require("etcd.core.encode_args")
local setmetatable = setmetatable
local tostring     = tostring
local ipairs       = ipairs
local type         = type
local next         = next
local table        = table

local _M = {}

local mt = {__index = _M}

local clear_tab = utils.clear_tab

local table_exist_keys = function(t)
    return next(t)
end

function _M.new(opts)
    local timeout = opts.timeout
    local ttl = opts.ttl
    local api_prefix = opts.api_prefix or ""
    local key_prefix = opts.key_prefix or ""
    local http_host = opts.http_host
    local user = opts.user
    local password = opts.password
    local serializer = opts.serializer
    local ssl_verify = opts.ssl_verify

    if not typeof.uint(timeout) then
        return nil, 'opts.timeout must be unsigned integer'
    end

    if not typeof.string(http_host) and not typeof.table(http_host) then
        return nil, 'opts.http_host must be string or string array'
    end

    if not typeof.int(ttl) then
        return nil, 'opts.ttl must be integer'
    end

    if not typeof.string(api_prefix) then
        return nil, 'opts.api_prefix must be string'
    end

    if not typeof.string(key_prefix) then
        return nil, 'opts.key_prefix must be string'
    end

    if user and not typeof.string(user) then
        return nil, 'opts.user must be string or ignore'
    end

    if password and not typeof.string(password) then
        return nil, 'opts.password must be string or ignore'
    end

    local endpoints = {}
    local http_hosts
    if type(http_host) == 'string' then  -- single node
        http_hosts = {http_host}
    else
        http_hosts = http_host
    end

    for _, host in ipairs(http_hosts) do
        table.insert(endpoints, {
            full_prefix = host .. utils.normalize(api_prefix),
            http_host = host,
            api_prefix = api_prefix,
            version = host .. '/version',
            stats_leader = host .. '/v2/stats/leader',
            stats_self = host .. '/v2/stats/self',
            stats_store = host .. '/v2/stats/store',
            keys = host .. '/v2/keys',
        })
    end

    return setmetatable({
        init_count = 0,
        timeout = timeout,
        ttl = ttl,
        key_prefix = key_prefix,
        is_cluster = #endpoints > 1,
        user = user,
        password = password,
        endpoints = endpoints,
        serializer = serializer,
        ssl_verify = ssl_verify,
    },
    mt)
end
