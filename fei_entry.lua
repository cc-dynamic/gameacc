local fei_global=require "fei_global"
local cjson = require "cjson"

local request_method = ngx.var.request_method

if "POST"==request_method then
    ngx.req.read_body()
    local body_str=ngx.req.get_body_data()
    
    if body_str==nil then
        fei_global:returnwithcode(fei_global.ERR_NO_BODYDATA,nil)
    end
    
    local status,userdata=pcall(cjson.decode,body_str)
    if status == false then
        fei_global:returnwithcode(fei_global.ERR_INVALID_JSON_FORMAT,nil)
    end
    
    if userdata['cmdid'] == nil or userdata['version'] == nil or userdata['time'] == nil then
        fei_global:returnwithcode(fei_global.ERR_INVALID_PARAM,nil)
    end
    
    local cmdid = tonumber(userdata['cmdid'])
    local version = tostring(userdata['version'])
    local reqtime = tonumber(userdata['time'])
    if cmdid == nil or version == nil or reqtime == nil then
        fei_global:returnwithcode(fei_global.ERR_PARAM_TYPE,nil)
    end
    
    if version == "0.1" then
        if cmdid == 1 then
            local fei_getgamebrief_obj = require "fei_getgamebriefinfo"
			local fei_getgamebrief = fei_getgamebrief_obj:new()
            fei_getgamebrief:process(userdata)
        elseif cmdid ==2 then
            local fei_queryacct_obj = require "fei_queryacct"
			local fei_queryacct = fei_queryacct_obj:new()
            fei_queryacct:process(userdata)
        else
            fei_global:returnwithcode(fei_global.ERR_UNSUPPORT_CMD,nil)
        end
    else
        fei_global:returnwithcode(fei_global.ERR_UNSUPPORT_VERSION,nil)
    end
    
else
    fei_global:returnwithcode(fei_global.ERR_INVALID_METHOD,nil)
end
