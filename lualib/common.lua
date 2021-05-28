local core         = require "skynet.core"
local table_concat = table.concat
local table_insert = table.insert
local string_sub   = string.sub
local string_len   = string.len
local string_find  = string.find
local type         = type

function table_dump_line(obj)
    local getIndent, quoteStr, wrapKey, wrapVal, dumpObj
    getIndent = function(level)
        return ""
        -- return string.rep("\t", level)
    end
    quoteStr = function(str)
        return '"' .. string.gsub(str, '"', '\\"') .. '"'
    end
    wrapKey = function(val)
        if type(val) == "number" then
            return "[" .. val .. "]"
        elseif type(val) == "string" then
            return "[" .. quoteStr(val) .. "]"
        else
            return "[" .. tostring(val) .. "]"
        end
    end
    wrapVal = function(val, level)
        if type(val) == "table" then
            return dumpObj(val, level)
        elseif type(val) == "number" then
            return val
        elseif type(val) == "string" then
            return quoteStr(val)
        else
            return tostring(val)
        end
    end
    dumpObj = function(obj, level)
        if type(obj) ~= "table" then
            return wrapVal(obj)
        end
        level = level + 1
        local tokens = {}
        tokens[#tokens + 1] = "{"
        for k, v in pairs(obj) do
            tokens[#tokens + 1] = getIndent(level) .. wrapKey(k) .. " = " .. wrapVal(v, level) .. ","
        end
        tokens[#tokens + 1] = getIndent(level - 1) .. "}"
        return table.concat(tokens, "")
    end
    return dumpObj(obj, 0)
end

-- log implement
function logImp(...)
    local t = {...}
    for i = 1, #t do
        t[i] = tostring(t[i])
    end

    return c.error(table_concat(t, " "))
end

function logInfo(...)
    logImp("INFO", ...)
end

function logError(...)
    logImp("ERROR", ...)
end

function split(str, delim)
	if str == nil or str == "" then
		return {}
	end

	str =  str .. ""
    local delim, fields = delim or ":", {}
	if not str then return fields end
	if delim == "" then
		fields = string.strToArr(str)
		return fields
	end

    if type(delim) ~= "string" or string_len(delim) <= 0 then
        return
    end

    local start = 1
    local t = {}
    while true do
		local pos = string_find(str, delim, start, true) -- plain find
        if not pos then
          break
        end

        table_insert(t, string_sub(str, start, pos - 1))
        start = pos + string_len(delim)
    end
    table_insert(t, string_sub(str, start))

    return t
end

function generateEtcdHosts(etcdHostStr)
	local hosts = split(etcdHostStr, ",")
	return hosts
end
