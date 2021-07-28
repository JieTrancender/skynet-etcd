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

-- test set and get
local function testsetget(etcdd)
	print("------------testsetget begin")
	res, err = etcdd.req.set(etcd_base_path.."hello", {message = "world"})
	if not res then
		print(string.format("etcd set %s fail, err: %s", etcd_base_path.."hello", err))
		return
	end
	print(string.format("set key %s, revision: %s", etcd_base_path.."hello", table_dump_line(res.body.header.revision)))

	res, err = etcdd.req.get(etcd_base_path.."hello")
	if not res then
		print(string.format("etcd get %s fail, err: %s", etcd_base_path.."hello", err))
		return
	end
	print(string.format("key %s is %s", etcd_base_path.."hello", table_dump_line(res.body.kvs[1].value)))
	
	res, err = etcdd.req.delete(etcd_base_path.."hello")
	if not res then
		print(string.format("delete %s fail, err: %s", etcd_base_path.."hello", err))
		return
	end
	print(string.format("delete key %s, deleted: %s", etcd_base_path.."hello", table_dump_line(res.body.deleted)))
	
	res, err = etcdd.req.get(etcd_base_path.."hello")
	print(string.format("key %s is %s", etcd_base_path.."hello", table_dump_line(res.body.kvs)))
	
	print("------------testsetget finished")
end

-- test setx
local function testsetx(etcdd)
	print("------------testsetx begin")
	res, err = etcdd.req.set(etcd_base_path.."hello", {message = "world"})
	print(string.format("set key %s, revision: %s", etcd_base_path.."hello", table_dump_line(res.body.header.revision)))
	
	res, err = etcdd.req.setx(etcd_base_path.."hello", {message = "newWorld"})
	print(string.format("etcd setx %s, res: %s", etcd_base_path.."hello", table_dump_line(res.body.header.revision)))
	
	res, err = etcdd.req.get(etcd_base_path.."hello")
	print(string.format("key %s is %s, create_revision: %s, mod_revision: %s", etcd_base_path.."hello",
		table_dump_line(res.body.kvs[1].value), res.body.kvs[1].create_revision, res.body.kvs[1].mod_revision))

	res, err = etcdd.req.setx(etcd_base_path.."hello2", {message = "newhello"})
	print(string.format("etcd setx %s, res: %s", etcd_base_path.."hello2", table_dump_line(res.body.responses)))

	res, err = etcdd.req.get(etcd_base_path.."hello2")
	print(string.format("key %s is %s", etcd_base_path.."hello2", table_dump_line(res.body.kvs)))

	res, err = etcdd.req.delete(etcd_base_path.."hello")
	res, err = etcdd.req.delete(etcd_base_path.."hello2")
	print("------------testsetx finished")
end

-- test setnx
local function testsetnx(etcdd)
	print("------------testsetnx begin")
	res, err = etcdd.req.set(etcd_base_path.."hello", {message = "world"})
	res, err = etcdd.req.setnx(etcd_base_path.."hello", {message = "newWorld"})
	res, err = etcdd.req.get(etcd_base_path.."hello")
	print(string.format("key %s is %s", etcd_base_path.."hello", table_dump_line(res.body.kvs[1].value)))

	res, err = etcdd.req.delete(etcd_base_path.."hello")
	print("------------testsetnx finished")
end

-- test grant
local function testgrant(etcdd)
	print("------------testgrant begin")
	local res, err = etcdd.req.grant(2)
	if not res then
		print("testgrant fail: ", err)
		return
	end
	print(string.format("grant res: %s %s", res.body.ID, res.body.TTL))
	skynet.sleep(300)
	res, err = etcdd.req.grant(10, res.body.ID)
	print(string.format("grant %s res: %s %s", res.body.ID, res.body.ID, res.body.TTL))
	
	print("------------testgrant finished")
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

	testsetget(etcdd)
	
	testsetx(etcdd)
	
	testsetnx(etcdd)

	testgrant(etcdd)
end)
