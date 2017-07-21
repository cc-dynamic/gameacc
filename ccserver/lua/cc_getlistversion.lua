require "os"

local cc_global=require "cc_global"
local MOD_ERR_BASE = cc_global.ERR_MOD_GETLISTVERSION_BASE

local _M = { 
    _VERSION = '1.0.1',
    MOD_ERR_ALLOC = MOD_ERR_BASE-1,
    MOD_ERR_DBINIT = MOD_ERR_BASE-2,
    MOD_ERR_INVALID_PARAM = MOD_ERR_BASE-3,
    MOD_ERR_PARAM_TYPE = MOD_ERR_BASE-4,
    MOD_ERR_QUERY_LISTVERSION = MOD_ERR_BASE-5,
    MOD_ERR_DBDEINIT = MOD_ERR_BASE-6
}

local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO

local mt = { __index = _M}

function _M.new(self)
	return setmetatable({}, mt)
end

function _M.checkparam(self,userreq)
    if userreq['data']==nil then
        cc_global:returnwithcode(self.MOD_ERR_INVALID_PARAM,nil)
    end
    
    local req_param=userreq['data']
    if req_param['gameid'] == nil then
        cc_global:returnwithcode(self.MOD_ERR_INVALID_PARAM,nil)
    end
    
    --log(ERR,req_param['gameid'])
    gameid=tonumber(req_param['gameid'])
    if gameid == nil then
        cc_global:returnwithcode(self.MOD_ERR_PARAM_TYPE,nil)
    end
    self.gameid=gameid
end

function _M.getlistversion(self,db)
    local gamelistversion={}
    local sql
    local version
    
    sql = "select gameversion from game_server_version_tbl where gameid=" .. self.gameid
    --log(ERR,sql)
    
    local res,err,errcode,sqlstate = db:query(sql)
    if not res then
    	cc_global:returnwithcode(self.MOD_ERR_QUERY_LISTVERSION,nil)
    end
    
    -- gameversion(1)
    for k,v in pairs(res) do
        --log(ERR,"list version: ",v[1])
        version=v[1]
    end
    gamelistversion['version']=version
    
    return gamelistversion
end

function _M.process(self,userreq)
    self.gameid=0

    self:checkparam(userreq)
    
    local db = cc_global:init_conn()
    local gamelistversion=self:getlistversion(db)
    cc_global:deinit_conn(db)
    cc_global:returnwithcode(0,gamelistversion)
end

return _M
