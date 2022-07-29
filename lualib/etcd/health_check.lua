local utils = require("etcd.utils")
local type  = type
local now   = os.time
local conf

local HEALTH_CHECK_MODE_ROUND_ROBIN = "round-robin"
local HEALTH_CHECK_MODE_DISABLED = "disabled"

local _M = {}
_M.ROUND_ROBIN_MODE = HEALTH_CHECK_MODE_ROUND_ROBIN
_M.DISABLED_MODE = HEALTH_CHECK_MODE_DISABLED

local round_robin_unhealthy_target_hosts

local function gen_unhealthy_key(etcd_host)
    return "unhealthy-"..etcd_host
end

local function get_target_status(etcd_host)
    if not conf then
        return nil, "etcd health check uninitialized"
    end

    if conf.disabled then
        return true
    end

    if type(etcd_host) ~= "string" then
        return false, "etcd host invalid"
    end

    local unhealthy_key = gen_unhealthy_key(etcd_host)
    if type(round_robin_unhealthy_target_hosts) ~= "table" then
        round_robin_unhealthy_target_hosts = {}
    end

    local target_fail_expired_time = round_robin_unhealthy_target_hosts[unhealthy_key]
    if target_fail_expired_time and target_fail_expired_time >= now() then
        return false, "endpoint: " .. etcd_host .. " is unhealthy"
    end

    return true
end
_M.get_target_status = get_target_status

local function report_failure(etcd_host)
    if not conf then
        return nil, "etcd health check uninitialized"
    end

    if conf.disabled then
        return
    end

    if type(etcd_host) ~= "string" then
        return nil, "etcd host invalid"
    end

    if type(round_robin_unhealthy_target_hosts) ~= "table" then
        round_robin_unhealthy_target_hosts = {}
    end
    local unhealthy_key = gen_unhealthy_key(etcd_host)
    round_robin_unhealthy_target_hosts[unhealthy_key] = now() + conf.fail_timeout
    utils.log_warn("update endpoint: ", etcd_host, " to unhealthy")
end
_M.report_failure = report_failure

local function get_check_mode()
    if conf then
        if conf.disabled then
            return HEALTH_CHECK_MODE_DISABLED
        end
    end

    return HEALTH_CHECK_MODE_ROUND_ROBIN
end

function _M.disable()
    if not conf then
        conf = {}
    end

    conf.disabled = true
    _M.conf = conf
end

function _M.init(opts)
    opts = opts or {}
    if not conf then
        conf = {}
        utils.log_info("healthy check use round robin")
        conf.fail_timeout = opts.fail_timeout or 10
        conf.max_fails = opts.max_fails or 1
        conf.retry = opts.retry or false
        _M.conf = conf
        return _M, nil
    end
end

return _M
