local httpc             = require("http.httpc")
local typeof            = require("etcd.core.typeof")
local utils             = require("etcd.core.utils")
local cjson             = require("cjson.safe")
local encode_args       = require("etcd.core.encode_args")
local crypt             = require "skynet.crypt"
local encode_base64     = crypt.base64encode
local setmetatable      = setmetatable
local tostring          = tostring
local ipairs            = ipairs
local type              = type
local next              = next
local table             = table
local INIT_COUNT_RESIZE = 2e8

local _M = {
    decode_json = cjson.decode,
    encode_json = cjson.encode
}

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

local content_type = {
    ['Content-Type'] = "application/x-www-form-urlencoded"
}

local function choose_endpoint(self)
    local endpoints = self.endpoints
    local endpoints_len = #endpoints
    if endpoints_len == 1 then
        return endpoints[1]
    end

    self.init_count = (self.init_count or 0) + 1
    local pos = self.init_count % endpoints_len + 1
    if self.init_count >= INIT_COUNT_RESIZE then
        self.init_count = 0
    end

    return endpoints[pos]
end

local function create_basicauth(user, password)
    local userPwd = user .. ':' .. password
    local base64Str = encode_base64(userPwd)
    return 'Authorization', 'Basic ' .. base64Str
end

local function _request(self, host, method, uri, opts, timeout)
    local body
    if opts and opts.body and table_exist_keys(opts.body) then
        body = encode_args(opts.body)
    end

    if opts and opts.query and table_exist_keys(opts.query) then
        uri = uri .. '?' .. encode_args(opts.query)
    end

    local recvheader = {}
    local headers = {
        ['Content-Type'] = content_type['Content-Type']
    }
    if self.user and self.password then
        local bauth_key, bauth_val = create_basicauth(self.user, self.password)
        headers[bauth_key] = bauth_val
    end

    local status, body = httpc.request(method, host, uri, recvheader, headers, body)
    if status >= 500 then
        return nil, "invalid response code: " .. status
    end

    if status == 401 then
        return nil, "insufficient credentials code: " .. status
    end

    if not typeof.string(body) then
        return {status = status, body = body}
    end

    return {body = self.decode_json(body), status = status, headers = recvheader}
end

function _M.version(self)
    local endpoint = choose_endpoint(self)
    return _request(self, endpoint.http_host, "GET", endpoint.version, nil, self.timeout)
end

return _M
