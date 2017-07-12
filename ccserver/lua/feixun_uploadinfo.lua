require "os"

local cc_global=require "cc_global"

local MOD_ERR_BASE = cc_global.ERR_MOD_UPLOADINFO_BASE

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
local CUSTOMERID=2



function _M.new(self)
	return setmetatable({}, mt)
end



function _M.uploadinfo(self,db,userreq)
    local cjson=require "cjson"
    local infostr=cjson.encode(userreq)

	local nowstr=os.date("%Y-%m-%d %H:%M:%S")

	local sql="insert into game_sdk_upload_tbl (clientip,customerid,uploadtime,content) values ('" .. ngx.var.remote_addr .."'," .. CUSTOMERID .."'" .. nowstr .. "','" .. infostr .. "')"

    --log(ERR,sql)
    
    local res,err,errcode,sqlstate = db:query(sql)
    
    
    if not res then
    	cc_global:returnwithcode(self.MOD_ERR_UPLOADINFO,nil)
    end
    
    
end

function _M.process(self,userreq)
    local db = cc_global:init_conn()
    self:uploadinfo(db,userreq)
    cc_global:deinit_conn(db)
    cc_global:returnwithcode(0,nil)

end

return _M
