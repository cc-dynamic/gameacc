local ccfei_global=require "ccfei_global"
local cjson = require "cjson"

local request_method = ngx.var.request_method

local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO

local function __TRACEBACK__ (errmsg)
    local track_text = debug.traceback(tostring(errmsg),6);
    log(ERR,"----------------------")
    log(ERR,track_text)
    log(ERR,"----------------------")
    return false
end

if "POST"==request_method then
    ngx.req.read_body()
    local body_str=ngx.req.get_body_data()
    
    if body_str==nil then
        ccfei_global:returnwithcode(ccfei_global.ERR_NO_BODYDATA,nil)
    end
    
    local status,userdata=pcall(cjson.decode,body_str)
    if status == false then
        ccfei_global:returnwithcode(ccfei_global.ERR_INVALID_JSON_FORMAT,nil)
    end

    --userdata=cjson.decode(body_str)
    
    if userdata['uid'] == nil or userdata['devicetype'] ==nil or userdata['usertype'] ==nil or userdata['cmdid'] == nil or userdata['version'] == nil or userdata['time'] == nil then
        ccfei_global:returnwithcode(ccfei_global.ERR_INVALID_PARAM,nil)
    end
    
    local uid = tostring(userdata['uid'])
    local devicetype = tonumber(userdata['devicetype'])
    local usertype = tonumber(userdata['usertype'])
    local cmdid = tonumber(userdata['cmdid'])
    local version = tostring(userdata['version'])
    local reqtime = tonumber(userdata['time'])
    
    if uid == nil or devicetype ==nil or usertype==nil or cmdid == nil or version == nil or reqtime == nil then
        ccfei_global:returnwithcode(ccfei_global.ERR_PARAM_TYPE,nil)
    end
    
    if devicetype ~=1101 and devicetype ~= 1102 then
        ccfei_global:returnwithcode(ccfei_global.ERR_UNSUPPORT_DEVICE,nil)
    end
    
    if usertype ~= 2 and usertype ~= 1 then
        ccfei_global:returnwithcode(ccfei_global.ERR_UNSUPPORT_USERTYPE,nil)
    end
    
    if version == "0.1" then
        if cmdid == 1 then
            local cc_getgamelist_obj = require "cc_getgamelist"
			local cc_getgamelist = cc_getgamelist_obj:new()
            cc_getgamelist:process(userdata)
        elseif cmdid == 2 then
            local ccfei_uploadinfo_obj = require "ccfei_uploadinfo"
			local ccfei_uploadinfo = ccfei_uploadinfo_obj:new()
            ccfei_uploadinfo:process(userdata)
        elseif cmdid == 3 then
            local cc_getvpnip_obj = require "cc_getvpnip"
			local cc_getvpnip = cc_getvpnip_obj:new()
            cc_getvpnip:process(userdata)
        elseif cmdid == 4 then
            local cc_getlistversion_obj = require "cc_getlistversion"
			local cc_getlistversion = cc_getlistversion_obj:new()
            cc_getlistversion:process(userdata)
		elseif cmdid == 5 then
			local cc_getvpnlst_obj = require "cc_getvpnlist"
			local cc_getvpnlst = cc_getvpnlst_obj.new()
			cc_getvpnlst:process(userdata)
        elseif cmdid == 6 then
            local cc_getgamelistport_obj = require "cc_getgamelistport"
            local cc_getgamelistport = cc_getgamelistport_obj:new()
            cc_getgamelistport:process(userdata)
		elseif cmdid == 7 then
            local cc_getgamelistporttext_obj = require "cc_getgamelistporttext"
            local cc_getgamelistporttext = cc_getgamelistporttext_obj:new()
            cc_getgamelistporttext:process(userdata)	
        else
            ccfei_global:returnwithcode(ccfei_global.ERR_UNSUPPORT_CMD,nil)
        end
    else
        ccfei_global:returnwithcode(ccfei_global.ERR_UNSUPPORT_VERSION,nil)
    end
    
else
    ccfei_global:returnwithcode(ccfei_global.ERR_INVALID_METHOD,nil)
end
