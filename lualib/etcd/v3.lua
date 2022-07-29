local typeof            = require("typeof")
local utils             = require("etcd.utils")
local health_check      = require("etcd.health_check")
local cjson             = require("cjson.safe")
local random            = math.random
local string_match      = string.match
local table_insert      = table.insert
local decode_json       = cjson.decode
local encode_json       = cjson.encode
local now               = os.time
local crypt             = require "skynet.crypt"
local encode_base64     = crypt.base64encode
local decode_base64     = crypt.base64decode

local INIT_COUNT_RESIZE = 2e8

local _M = {}

local mt = {__index = _M}


local unmodifiable_headers = {
    ["authorization"] = true,
    ["content-length"] = true,
    ["transfer-encoding"] = true,
    ["connection"] = true,
    ["upgrade"] = true,
}

local refresh_jwt_token

local table_nkeys = function (t)
    local num = 0
    for k, _ in pairs(t) do
        num = num + 1
    end
    return num
end

local function ring_balancer(self)
    local endpoints = self.endpoints
    local endpoints_len = #endpoints
    
    self.init_count = self.init_count + 1
    local pos = slef.init_count % endpoints_len + 1
    if self.init_count >= INIT_COUNT_RESIZE then
        self.init_count = 0
    end

    return endpoints[pos]
end

local function choose_endpoint(self)
    for _ in ipairs(self.endpoints) do
        local endpoint = ring_balancer(self)
        if health_check.get_target_status(endpoint.http_host) then
            utils.log_info("choose endpoint: ", endpoint.http_host)
            return endpoint
        end
    end

    return nil, "has no healthy etcd endpoint available"
end

local function prepare_host(host)
    local protocol = host:match("^[Hh][Tt][Tt][Pp][Ss]?://")
    if not protocol then
        return "http://" .. host
    end

    host = string.gsub(host, "^"..protocol, "")
    protocol = string.lower(protocol)
    return protocol .. host
end

local function _request_uri(self, method, uri, opts, timeout, ignore_auth)
    utils.log_info("v3 request uri: ", uri, ", timeout: ", timeout)
    local body
    if opts and opts.body and table_nkeys(opts.body) > 0 then
        body = encode_json(opts.body)
    end

    if opts and opts.query and table_nkeys(opts.query) > 0 then
        uri = uri .. "?" .. encode_args(opts.query)
    end

    local headers = {}
    local keepalive = true
    if self.is_auth then
        if not ignore_auth then
            local _, err = refresh_jwt_token(self, timeout)
            if err then
                return nil, err
            end
            headers.Authorization = self.jwt_token
        else
            keepalive = false
        end
    end

    if self.extra_headers and type(self.extra_headers) == "table" then
        for key, value in pairs(self.extra_headers) do
            if not unmodifiable_headers[string_lower(key)] then
                headers[key] = value
            end
        end
        utils.log_info("request uri headers: ", encode_json(headers))
    end

    local status, body = httpc.request(method, host, uri, recvheader, headers, body)
end

function _M.new(opts)
    local timeout           = opts.timeout
    local ttl               = opts.ttl
    local api_prefix        = opts.api_prefix
    local key_prefix        = opts.key_prefix or ""
    local http_host         = opts.http_host
    local user              = opts.user
    local password          = opts.password
    local ssl_verify        = (opts.ssl_verify ~= nil and {opts.ssl_verify} or {true})[1]
    local serializer        = opts.serializer
    local extra_headers     = opts.extra_headers
    local sni               = opts.sni
    local init_count        = opts.init_count

    if not typeof.uint(timeout) then
        return nil, 'opts.timeout must be unsigned integer'
    end
    
    if not typeof.string(http_host) and not typeof.table(http_host) then
        return nil, 'opts.http_must be string or string array'
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

    if not typeof.number(init_count) then
        init_count = random(100)
    end

    local endpoints = {}
    local http_hosts
    if type(http_host) == 'string' then
        http_hosts = utils.split(http_host, ',')
    else
        http_hosts = http_host
    end

    for _, host in ipairs(http_hosts) do
        utils.log_info("prepare_host", host, prepare_host(host))
        host = prepare_host(host)
        local scheme, addr, port = host:match("([^%/]+):%/%/([%da-zA-Z.-]+[%da-zA-Z]+):?(%d*)$")
        addr = addr or "127.0.0.1"
        port = port or "2379"
        utils.log_info("scheme, addr, port", scheme, addr, port, host)
        table_insert(endpoints, {
            full_prefix = host .. utils.normalize(api_prefix),
            http_host   = host,
            scheme      = scheme,
            host        = addr,
            address     = addr,
            port        = port,
            api_prefix  = api_prefix,
        })
    end
    
    if health_check.conf == nil then
        health_check.init()
    end

    return setmetatable({
        last_auth_time       = now(),
        last_refresh_jwt_err = nil,
        jwt_token            = nil,
        is_auth              = not not (user and password),
        user                 = user,
        password             = password,
        timeout              = timeout,
        ttl                  = ttl,
        is_cluster           = #endpoints > 1,
        endpoints            = endpoints,
        key_prefix           = key_prefix,
        ssl_verify           = ssl_verify,
        serializer           = serializer,

        ssl_cert_path = opts.ssl_cert_path,
        ssl_key_path  = opts.ssl_key_path,
        extra_headers = extra_headers,
        sni           = sni,
        init_count    = init_count,
    },
    mt)
end

local function get(self, key, attr)
    local _, err = utils.verify_key(key)
    if err then
        return nil, err
    end

    attr = attr or {}

    local range_end
    if attr.range_end then
        range_end = encode_base64(attr.range_end)
    end

    local limit = attr.limit or 0
    local revision = attr.revision or 0
    local sort_order = attr.sort_order or 0
    local sort_target = attr.sort_target or 0
    local serializable = attr.serializable or false
    local keys_only = attr.keys_only or false
    local count_only = attr.count_only or false
    local min_mod_revision = attr.min_mod_revision or 0
    local max_mod_revision = attr.max_mod_revision or 0
    local min_create_revision = attr.min_create_revision or 0
    local max_create_revision = attr.max_create_revision or 0

    key = encode_base64(key)

    local opts = {
        body = {
            key                 = key,
            range_end           = range_end,
            limit               = limit,
            revision            = revision,
            sort_order          = sort_order,
            sort_target         = sort_target,
            serializable        = serializable,
            keys_only           = keys_only,
            count_only          = count_only,
            min_mod_revision    = min_mod_revision,
            max_mod_revision    = max_mod_revision,
            min_create_revision = min_create_revision,
            max_create_revision = max_create_revision,
        }
    }

    local res
    res, err = _request_uri(self, "POST", "/kv/range", opts, attr and attr.timeout or self.timeout)
    if res and res.status == 200 then
        if res.body.kvs and table_nkeys(res.body.kvs) > 0 then
            for _, kv in ipairs(res.body.kvs) do
                kv.key = decode_base64(kv.key)
                kv.value = decode_base64(kv.value or "")
                kv.value = self.serializer.deserialize(kv.value)
            end
        end
    end

    return res, err
end

return _M
