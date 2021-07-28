require "common"

local skynet         = require "skynet"
local snax           = require "skynet.snax"
local crypt          = require "skynet.crypt"
local encode_base64  = crypt.base64encode

local etcd_base_path = "/config/dev/"
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
	print("token:", create_basicauth(etcd_user, etcd_pass))
	local etcdd = snax.uniqueservice("etcdd", etcd_hosts, etcd_user, etcd_pass, etcd_protocol)
	local res, err = etcdd.req.version()
	if not res then
		print("etcd version fail, err: ", err)
		return
	end
	print("etcd version: ", table_dump_line(res.body))

	res, err = etcdd.req.set(etcd_base_path.."hello", {message = "world"})
	if not res then
		print(string.format("etcd set %s fail, err: %s", etcd_base_path.."hello", err))
		return
	end
	print(string.format("set key %s, res: %s", etcd_base_path.."hello", table_dump_line(res)))

	res, err = etcdd.req.setnx(etcd_base_path.."hello", {message = "hello"})
	if not res then
		print(string.format("etcd setnx %s fail, err: %s", etcd_base_path.."hello", err))
		return
	end
	print(string.format("etcd setnx %s, res: %s", etcd_base_path.."hello", table_dump_line(res)))
	
	res, err = etcdd.req.setnx(etcd_base_path.."hello2", {message = "hello"})
	if not res then
		print(string.format("etcd setnx %s fail, err: %s", etcd_base_path.."hello2", err))
		return
	end
	print(string.format("etcd setnx %s, res: %s", etcd_base_path.."hello2", table_dump_line(res)))
	
	res, err = etcdd.req.get(etcd_base_path.."hello")
	if not res then
		print(string.format("etcd get %s fail, err: %s", etcd_base_path.."hello", err))
		return
	end
	print(string.format("key %s is %s", etcd_base_path.."hello", table_dump_line(res.body)))

	res, err = etcdd.req.delete(etcd_base_path.."hello")
	if not res then
		print(string.format("delete %s fail, err: %s", etcd_base_path.."hello", err))
		return
	end
	print(string.format("delete key %s, res: %s", etcd_base_path.."hello", table_dump_line(res)))

end)
