local skynet       = require("skynet")
local typeof       = require("etcd.core.typeof")
local utils        = require("etcd.core.utils")
local cjson        = require("cjson.safe")
local setmetatable = setmetatable
local random       = math.random
local string_match = string.match
local table_insert = table.insert

local _M = {}

local mt = {__index = _M}

local table_exist_keys = function (t)
    return next(t)
end

-- define local refresh function variable
local refresh_jwt_token

local function _request(self, endpoint, method, uri, opts, timeout, ignore_auth)
    utils.logInfo("v3 request uri: ", uri, ", timeout: ", timeout)

    local body
    if opts and opts.body and table_exist_keys(opts.body) then
        body = encode_json(opts.body)
    end

    if opts and opts.query and table_exist_keys(opts.query) then
        uri = uri .. '?' .. encode_args(opts.query)
    end

    local recvheader = {}
    local headers = {}
    local keepalive = true
    if self.is_auth then
        if not ignore_auth then
            -- authentication request not need auth request
            local _, err = refresh_jwt_token(self, timeout)
            if err then
                return nil, err
            end

            headers.Authentication = self.jwt_token
        else
            keepalive = false  -- jwt_token not keepalive
        end
    end

    local http_cli, err = utils.http.new()
    
end

local function serialize_and_encode_base64(serialize_fn, data)
    local err
    data, err = serialize_fn(data)
    if not data then
        return nil, err
    end

    return encode_base64(data)
end

function _M.new(opts)
    local timeout    = opts.timeout
    local ttl        = opts.ttl
    local api_prefix = opts.api_prefix
    local key_prefix = opts.key_prefix or ""
    local http_host  = opts.http_host
    local user       = opts.user
    local password   = opts.password
    local ssl_verify = opts.ssl_verify
    if ssl_verify == nil then
        ssl_verify = true
    end
    local serializer = opts.serializer

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
    if type(http_host) == 'string' then
        http_hosts = {http_host}
    else
        http_hosts = http_host
    end

    for _, host in ipairs(http_hosts) do
        local m, err = string_match(host,
            [[[a-zA-z]+://[^\s]*]])
        if not m then
            return nil, "inalid http_host: " .. host .. ", err: " .. (err or "not matched")
        end

        table_insert(endpoints, {
            full_prefix = host .. utils.normalize(api_prefix),
            http_host   = host,
            scheme      = m[1],
            host        = m[2] or "127.0.0.1",
            port        = m[3] or "2379",
            api_prefix  = api_prefix,
        })
    end

    -- local sema, err = semaphore.new()
    -- if not sema then
    --     return nil, err
    -- end

    return setmetatable({
        last_auth_time = skynet.now(),  -- save last Authentication time
        last_refresh_jwt_err = nil,
        -- sema = sema,
        jwt_token = nil,  -- last Authentication token
        is_auth = not not (user and password),
        user = user,
        password = password,
        timeout = timeout,
        ttl = ttl,
        is_cluster = #endpoints > 1,
        endpoints = endpoints,
        key_prefix = key_prefix,
        ssl_verify = ssl_verify,
        serializer = serializer,

        ssl_cert_path = opts.ssl_cert_path,
        ssl_key_path = opts.ssl_key_path,
    },
    mt)
end

local function choose_endpoint(self)
    local endpoints = self.endpoints
    local endpoints_len = #endpoints
    if endpoints_len == 1 then
        return endpoints[1]
    end

    if health_check.conf ~= nil then
        for _, endpoint in ipairs(endpoints) do
            if health_check.get_target_status(endpoint.http_host) then
                return endpoint
            end
        end

        utils.logWarn("has no healthy etcd endpoint available")
        return nil, "has"
    end

    self.init_count = (self.init_count or 0) + 1
    local pos = self.init_count % endpoints_len + 1
    if self.init_count >= INIT_COUNT_RESIZE then
        self.init_count = 0
    end

    return endpoints[pos]
end

function _M.version(self)
    local endpoint, err = choose_endpoint(self)
    if not endpoint then
        return nil, err
    end

    return _request(self, endpoint, "GET", endpoint.http_host .. "/version", nil, self.timeout)
end

return _M
