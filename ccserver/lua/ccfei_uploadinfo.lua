require "os"

local ccfei_global=require "ccfei_global"
local MOD_ERR_BASE = ccfei_global.ERR_MOD_UPLOADINFO_BASE

local _M = { 
    _VERSION = '1.0.1',
    MOD_ERR_ALLOC = MOD_ERR_BASE-1,
    MOD_ERR_DBINIT = MOD_ERR_BASE-2,
    MOD_ERR_UPLOADINFO = MOD_ERR_BASE-3,
    MOD_ERR_DBDEINIT = MOD_ERR_BASE-4
}

local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO

local mt = { __index = _M}

function _M.new(self)
	return setmetatable({}, mt)
end

function _M.uploadinfo(self,db,userreq)
    local cjson=require "cjson"
    local infostr=cjson.encode(userreq)
	local nowstr=os.date("%Y-%m-%d %H:%M:%S")
	local sql="insert into game_sdk_upload_tbl (clientip,uploadtime,content,customerid) values ('" .. ngx.var.remote_addr .."','" .. nowstr .. "','" .. infostr .. "',2)"

    --log(ERR,sql)
    
    local res,err,errcode,sqlstate = db:query(sql)
    if not res then
    	ccfei_global:returnwithcode(self.MOD_ERR_UPLOADINFO,nil)
    end
end

function _M.process(self,userreq)
    local db = ccfei_global:init_conn()
    self:uploadinfo(db,userreq)
    ccfei_global:deinit_conn(db)
    ccfei_global:returnwithcode(0,nil)

end

return _M
