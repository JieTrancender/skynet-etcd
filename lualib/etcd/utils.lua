local c            = require "skynet.core"
local table_concat = table.concat
local table_insert = table.insert
local string_gsub  = string.gsub

local _M = {}

local function clear_tab(t)
    for k in pairs(t) do
        t[k] = nil
    end
end
_M.clear_tab = clear_tab

function split(s, delim)
    local sp = {}
    local pattern = "[^" .. delim .. "]+"
    string_gsub(s, pattern, function(v) table_insert(sp, v) end)
    return sp
end
_M.split = split

local normalize
do
    local items = {}
    local function concat(sep, ...)
        local argc = select('#', ...)
        clear_tab(items)
        local len = 0

        for i = 1, argc do
            local v = select(i, ...)
            if v ~= nil then
                len = len + 1
                items[len] = tostring(v)
            end
        end

        return table_concat(items, sep)
    end

    local segs = {}
    function normalize(...)
        local path = concat('/', ...)
        local names = {}
        local err

        segs = split(path, [[/]])

        local len = 0
        for _, seg in ipairs(segs) do
            if seg == '..' then
                if len > 0 then
                    len = len - 1
                end
            elseif seg == '' or seg == '/' and names[len] == '/' then
            elseif seg ~= '.' then
                len = len + 1
                names[len] = seg
            end
        end

        return '/' .. table_concat(names, '/', 1, len)
    end
end
_M.normalize = normalize

function _M.get_real_key(prefix, key)
    return (type(prefix) == 'string' and prefix or '') .. key
end

function _M.has_value(arr, val)
    for key, value in pairs(arr) do
        if value == val then
            return key
        end
    end

    return false
end

local function logImp(...)
    local t = {...}
    for i = 1, #t do
        t[i] = tostring(t[i])
    end
    return c.error(table_concat(t, " "))
end

local function log_info(...)
    return logImp("INFO", ...)
end
_M.log_info = log_info

local function log_warn(...)
    return logImp("WARN", ...)
end
_M.log_warn = log_warn

local function log_error(...)
    return logImp("ERROR", ...)
end
_M.log_error = log_error

local function verify_key(key)
    if not key or #key == 0 then
        return false, "key should not be empty"
    end
    return true, nil
end

local function is_empty_str(input_str)
    return string.match(input_str or '', "^%s*$")
end
_M.is_empty_str = is_empty_str

return _M
