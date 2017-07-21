require "os"

local detect_global=require "detect_global"
local MOD_ERR_BASE = detect_global.ERR_MOD_GETVPNLST_BASE

local _M = { 
    _VERSION = '1.0.1',
    
    MOD_ERR_INVALID_PARAM = MOD_ERR_BASE-1,
    MOD_ERR_GETVPNLST = MOD_ERR_BASE-2,
    
}

local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO

local mt = { __index = _M}

function _M.new(self)
	return setmetatable({}, mt)
end

function _M.getvpnlst(self,db)
    local sql
    local returnlst={}
	local vpn_node_lst={}
    
    sql="select nodeid,nodename,multi_detect_ifacelst,multi_detect_iplst,nodestatus,enabled from vpn_node_tbl order by nodeid"
    
    --log(ERR,sql)
    local res,err,errcode,sqlstate = db:query(sql)
    if not res then
    	detect_global:returnwithcode(self.MOD_ERR_GETVPNLST,nil)
    end
    
    for k,v in pairs(res) do
		-- nodeid, nodename,multi_detect_ifacelst,multi_detect_iplst,nodestatus,enabled
    	local vpn_node={}
		vpn_node['vpnid']=v[1]
		vpn_node['nodename']=v[2]
		vpn_node['multi_detect_ifacelst']=v[3]
		vpn_node['multi_detect_iplst']=v[4]
		vpn_node['nodestatus']=v[5]
		vpn_node['enabled']=v[6]
		table.insert(vpn_node_lst,vpn_node)	
    end
    
    returnlst["vpn_node_lst"]=vpn_node_lst
    return returnlst
end

function _M.process(self,userreq)
    local db = detect_global:init_conn()
    local vpnlst=self:getvpnlst(db)
    detect_global:deinit_conn(db)
    
    detect_global:returnwithcode(0,vpnlst)
end

return _M
