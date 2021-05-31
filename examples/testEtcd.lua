require "common"

local skynet         = require "skynet"
local snax           = require "skynet.snax"
local crypt          = require "skynet.crypt"
local encode_base64  = crypt.base64encode

local etcd_base_path = "/config/dev"
local etcd_hosts = "http://127.0.0.1:2379"
local etcd_user = "root"
local etcd_pass = "123456"
local etcd_protocol = "v3"

local function create_basicauth(user, password)
    local userPwd = user .. ':' .. password
    local base64Str = encode_base64(userPwd)
    return 'Authorization', 'Basic ' .. base64Str
end

skynet.start(function()
	etcd_base_path = "kbm-site-etcd"
	print("token:", create_basicauth(etcd_user, etcd_pass))
	local etcdd = snax.uniqueservice("etcdd", etcd_hosts, etcd_user, etcd_pass, etcd_protocol)
	print("etcd version:", table_dump_line(etcdd.req.version().body))
	-- print("etcd stats_leader:", table_dump_line(etcdd.req.stats_leader().body))
	-- print("etcd stats_self:", table_dump_line(etcdd.req.stats_self().body))
end)
