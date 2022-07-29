local skynet = require "skynet"
local etcd   = require "etcd"
local utils  = require "etcd.utils"

skynet.start(function()
    local etcd_host = "127.0.0.1:2379"
    local etcd_user = "root"
    local etcd_password = "123456"
    local opt = {
        http_host = etcd_host,
        user = etcd_user,
        password = etcd_password,
    }

    local etcd_cli, err = etcd.new(opt)
    if not etcd_cli then
        utils.log_error("new etcd client fail: ", err)
        return
    end
end)
