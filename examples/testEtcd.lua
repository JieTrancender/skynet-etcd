require "common"
local skynet = require "skynet"
local snax   = require "skynet.snax"

local etcd_base_path = "/config/bhsg/dev_inner_4/"
local etcd_hosts = "http://10.18.18.85:2379,http://10.18.18.85:2381,http://10.18.18.85:2383,http://10.18.18.85:2385,http://10.18.18.85:2387,http://10.18.18.85:2389"
local etcd_user = "root"
local etcd_pass = "123456"

skynet.start(function()
	local etcdd = snax.uniqueservice("etcdd", etcd_hosts, etcd_user, etcd_pass)
	print("etcd version:", table_dump_line(etcdd.req.version().body))
end)
