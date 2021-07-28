local skynet        = require("skynet")
local typeof        = require("etcd.core.typeof")
local utils         = require("etcd.core.utils")
local cjson         = require("cjson.safe")
local httpc         = require("http.httpc")
local setmetatable  = setmetatable
local random        = math.random
local string_match  = string.match
local table_insert  = table.insert
local decode_json   = cjson.decode
local encode_json   = cjson.encode
local now           = os.time
local crypt         = require "skynet.crypt"
local encode_base64 = crypt.base64encode
local decode_base64 = crypt.base64decode

local _M = {}

local mt = {__index = _M}

local clear_tab = function (t)
    t = {}
end

local table_exist_keys = function (t)
    return next(t)
end

local tab_nkeys = function (t)
    local num = 0
    for k, _ in pairs(t) do
        num = num + 1
    end
    return num
end

-- define local refresh function variable
local refresh_jwt_token

local function _request_uri(self, host, method, uri, opts, timeout, ignore_auth)
    utils.log_info("v3 request uri: ", uri, ", timeout: ", timeout)

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

            headers.Authorization = self.jwt_token
        else
            keepalive = false  -- jwt_token not keepalive
        end
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

    return {status = status, headers = recvheader, body = decode_json(body)}
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

-- return refresh_is_ok, error
function refresh_jwt_token(self, timeout)
    -- token exist and not expire
    -- default is 5min, we use 3min plus random seconds to smooth the refresh across workers
    -- https://github.com/etcd-io/etcd/issues/8287
    if self.jwt_token and now() - self.last_auth_time < 60 * 3 + random(0, 60) then
        return true, nil
    end

    if self.requesting_token then
        self.sema:wait(timeout)
        if self.jwt_token and now() - self.last_auth_time < 60 * 3 + random(0, 60) then
            return true, nil
        end

        if self.last_refresh_jwt_err then
            utils.log_info("v3 refresh jwt last err: ", self.last_refresh_jwt_err)
            return nil, self.last_refresh_jwt_err
        end

        -- something unexpected happened, try again
        utils.log_info("v3 try auth after waiting, timeout: ", timeout)
    end

    self.last_refresh_jwt_err = nil
    self.requesting_token = true

    local opts = {
        body = {
            name         = self.user,
            password     = self.password,
        }
    }

    local endpoint, err = choose_endpoint(self)
    if not endpoint then
        return nil, err
    end

    local res
    res, err = _request_uri(self, endpoint.http_host, 'POST',
                                  endpoint.full_prefix .. "/auth/authenticate",
                                  opts, timeout, true)
    self.requesting_token = false

    if err then
        self.last_refresh_jwt_err = err
        -- wake_up_everyone(self)
        return nil, err
    end

    if not res or not res.body or not res.body.token then
        err = 'authenticate refresh token fail'
        self.last_refresh_jwt_err = err
        -- wake_up_everyone(self)
        return nil, err
    end

    self.jwt_token = res.body.token
    self.last_auth_time = now()
    -- wake_up_everyone(self)

    return true, nil
end

local function get(self, key, attr)
    -- verify key
    local _, err = utils.verify_key(key)
    if err then
        return nil, err
    end

    attr = attr or {}
    
    local range_end
    if attr.range_end then
        range_end = encode_base64(attr.range_end)
    end
    
    local limit
    if attr.limit then
        limit = attr.limit
    end

    local revision
    if attr.revision then
        revision = attr.revision
    end

    local sort_order
    if attr.sort_order then
        sort_order = attr.sort_order
    end

    local sort_target
    if attr.sort_target then
        sort_target = attr.sort_target
    end

    local serializable
    if attr.serializable then
        serializable = true
    end

    local keys_only
    if attr.keys_only then
        keys_only = true
    end

    local count_only
    if attr.count_only then
        count_only = true
    end

    local min_mod_revision
    if attr.min_mod_revision then
        min_mod_revision = attr.min_mod_revision
    end

    local max_mod_revision
    if attr.max_mod_revision then
        max_mod_revision = attr.max_mod_revision
    end

    local min_create_revision
    if attr.min_create_revision then
        min_create_revision = attr.min_create_revision
    end

    local max_create_revision
    if attr.max_create_revision then
        max_create_revision = attr.max_create_revision
    end

    key = encode_base64(key)

    local opts = {
        body = {
            key = key,
            range_end = range_end,
            limit = limit,
            revision = revision,
            sort_order = sort_order,
            sort_target = sort_target,
            serializable = serializable,
            keys_only = keys_only,
            count_only = count_only,
            min_mod_revision = min_mod_revision,
            max_mod_revision = max_mod_revision,
            min_create_revision = min_create_revision,
            max_create_revision = max_create_revision
        }
    }

    local endpoint
    endpoint, err = choose_endpoint(self)
    if not endpoint then
        return nil, err
    end

    local res
    res, err = _request_uri(self, endpoint.http_host, "POST", endpoint.full_prefix.."/kv/range", opts,
        attr and attr.timeout or self.timeout)
    if res and res.status == 200 then
        if res.body.kvs and next(res.body.kvs) then
            for _, kv in ipairs(res.body.kvs) do
                kv.key = decode_base64(kv.key)
                kv.value = decode_base64(kv.value or "")
                kv.value = self.serializer.deserialize(kv.value)
            end
        end
    end

    return res, err
end

do
    local attr = {}
function _M.get(self, key, opts)
    if not typeof.string(key) then
        return nil, 'key must be string'
    end

    key = utils.get_real_key(self.key_prefix, key)

    clear_tab(attr)
    attr.timeout = opts and opts.timeout
    attr.revision = opts and opts.revision

    return get(self, key, attr)
end

end

function _M.version(self)
    local endpoint, err = choose_endpoint(self)
    if not endpoint then
        return nil, err
    end

    return _request_uri(self, endpoint.http_host, "GET", endpoint.http_host .. "/version", nil, self.timeout)
end

return _M
