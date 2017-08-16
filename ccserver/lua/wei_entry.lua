local wei_global=require "wei_global"
local cjson = require "cjson"

local request_method = ngx.var.request_method

if "POST"==request_method then
    ngx.req.read_body()
    local body_str=ngx.req.get_body_data()
    
    if body_str==nil then
        wei_global:returnwithcode(wei_global.ERR_NO_BODYDATA,nil)
    end
    
    local status,userdata=pcall(cjson.decode,body_str)
    if status == false then
        wei_global:returnwithcode(wei_global.ERR_INVALID_JSON_FORMAT,nil)
    end
    
    if userdata['cmdid'] == nil or userdata['version'] == nil or userdata['time'] == nil then
        wei_global:returnwithcode(wei_global.ERR_INVALID_PARAM,nil)
    end
    
    local cmdid = tonumber(userdata['cmdid'])
    local version = tostring(userdata['version'])
    local reqtime = tonumber(userdata['time'])
    if cmdid == nil or version == nil or reqtime == nil then
        wei_global:returnwithcode(wei_global.ERR_PARAM_TYPE,nil)
    end
    
    if version == "0.1" then
        if cmdid == 1 then
            local wei_getgamebrief_obj = require "wei_getgamebriefinfo"
			local wei_getgamebrief = wei_getgamebrief_obj:new()
            wei_getgamebrief:process(userdata)
        elseif cmdid ==2 then
            local wei_queryacct_obj = require "wei_queryacct"
			local wei_queryacct = wei_queryacct_obj:new()
            wei_queryacct:process(userdata)
        else
            wei_global:returnwithcode(wei_global.ERR_UNSUPPORT_CMD,nil)
        end
    else
        wei_global:returnwithcode(wei_global.ERR_UNSUPPORT_VERSION,nil)
    end
    
else
    wei_global:returnwithcode(wei_global.ERR_INVALID_METHOD,nil)
end
