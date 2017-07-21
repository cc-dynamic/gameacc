require "os"

local detect_global=require "detect_global"
local MOD_ERR_BASE = detect_global.ERR_MOD_GETCCLST_BASE

local _M = { 
    _VERSION = '1.0.1',
    MOD_ERR_INVALID_PARAM = MOD_ERR_BASE-1,
	MOD_ERR_GETCCLST = MOD_ERR_BASE-2
}

local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO

local mt = { __index = _M}

function _M.new(self)
	return setmetatable({}, mt)
end

function _M.getcclst(self,db)
    local sql
    local returnlst={}
	local cc_node_lst={}
    
    sql="select nodename,nodeip,enabled from cc_node_tbl order by id"

    --log(ERR,sql)
    local res,err,errcode,sqlstate = db:query(sql)
    if not res then
    	detect_global:returnwithcode(self.MOD_ERR_GETCCLST,nil)
    end
    
    for k,v in pairs(res) do
		-- id, nodename,multi_iplst,multi_ifacelst,nodeiplst,nodestatus,enabled
    	local cc_node={}
		cc_node['nodename']=v[1]
		cc_node['nodeip']=v[2]
		cc_node['enabled']=v[3]
		table.insert(cc_node_lst,cc_node)	
    end
    
    returnlst["cc_node_lst"]=cc_node_lst
    return returnlst
end

function _M.process(self,userreq)
    local db = detect_global:init_conn()
    local cclst=self:getcclst(db)
    detect_global:deinit_conn(db)
    
    detect_global:returnwithcode(0,cclst)
end

return _M
