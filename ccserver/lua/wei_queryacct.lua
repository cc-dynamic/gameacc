require "os"

local wei_global=require "wei_global"
local MOD_ERR_BASE = wei_global.ERR_MOD_QUERYACCT_BASE

local _M = { 
    _VERSION = '1.0.1',
    MOD_ERR_ALLOC = MOD_ERR_BASE-1,
    
    MOD_ERR_INVALID_PARAM = MOD_ERR_BASE-3,
    MOD_ERR_PARAM_TYPE = MOD_ERR_BASE-4,
    MOD_ERR_QUERY_ACCT = MOD_ERR_BASE-5,
}

local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO

local mt = { __index = _M}

function _M.new(self)
	return setmetatable({}, mt)
end

function _M.checkparam(self,userreq)
    local timestart,timeend,uid
    local count=0
    
    if userreq['data']==nil then
        wei_global:returnwithcode(self.MOD_ERR_INVALID_PARAM,nil)
    end
 
    local req_param=userreq['data']
	--log(ERR,req_param['timestart'],req_param['timeend'],req_param['uid'])
    if req_param['timestart'] == nil or req_param['timeend'] == nil or req_param['uid'] == nil then
        wei_global:returnwithcode(self.MOD_ERR_INVALID_PARAM,nil)
    end
    
    timestart=tonumber(req_param['timestart'])
    timeend=tonumber(req_param['timeend'])
    uid=tostring(req_param['uid'])
    
    if timestart == nil or timeend==nil or uid==nil then
        wei_global:returnwithcode(self.MOD_ERR_PARAM_TYPE,nil)
    end
    
    if req_param['count'] ~=nil then
        count=tonumber(req_param['count'])
        if count == nil then
            count=0
        end
    end
    
    self.timestart=timestart
    self.timeend=timeend
    self.count=count
    self.uid=uid
end

function _M.query_acct(self,db)
    local sql
    local acct_info={}
    
    sql="select UNIX_TIMESTAMP(starttime),gameid,gameregionid from game_user_history_tbl where username='" .. self.uid .. "' and starttime>FROM_UNIXTIME("..self.timestart ..") and starttime<FROM_UNIXTIME(" .. self.timeend..")"
    
    if self.count ~= 0 then
        sql = sql .. " limit " .. self.count
    end
    
    --log(ERR,sql)
    local res,err,errcode,sqlstate = db:query(sql)
    if not res then
    	wei_global:returnwithcode(self.MOD_ERR_QUERY_ACCT,nil)
    end
    
    -- starttime(1),gameid(2),gameregion(3)
    for k,v in pairs(res) do
        --log(ERR,"detect ip list: ",v[1]," ",v[2]," ",v[3])
        local acct_item={}
        acct_item['acct_time']=v[1]
        acct_item['acct_gameid']=tonumber(v[2])
        acct_item['acct_gameregionid']=tonumber(v[3])
        
        table.insert(acct_info,acct_item)
    end
    
    return acct_info
end

function _M.process(self,userreq)
    self.uid=nil
    self.timestart=0
    self.timeend=0
    self.count=0
    
    self:checkparam(userreq)

    local db = wei_global:init_conn()
    local acct_info=self:query_acct(db)
    wei_global:deinit_conn(db)
    
    wei_global:returnwithcode(0,acct_info)
end

return _M
