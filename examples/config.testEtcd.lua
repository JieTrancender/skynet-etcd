root = "./"

DEBUG = true
project_name = "examples"
thread = 8
logger = nil
harbor = 0
start = "testEtcd2"
bootstrap = "snlua bootstrap"
luaservice = root.."service/?.lua;"..root.."skynet/service/?.lua;"..root..project_name.."/?.lua"
lualoader = root.."skynet/lualib/loader.lua"
cpath = root.."skynet/cservice/?.so;"..root.."cservice/?.so"
lua_cpath = root.."luaclib/?.so;"..root.."skynet/luaclib/?.so"
lua_path = root.."lualib/?.lua;"..root..project_name.."/?.lua;"..root.."skynet/lualib/?.lua;"..root.."skynet/lualib/skynet/?.lua"
snax = root.."service/?.lua;"..root.."skynet/service/?.lua"

etcd_hosts = "http://127.0.0.1:2379"
etcd_user = "root"
etcd_pass = "123456"
etcd_protocol = "v3"
etcd_base_path = "/config/dev/"
