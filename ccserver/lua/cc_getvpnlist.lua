require "os"

local cc_global=require "cc_global"
local MOD_ERR_BASE = cc_global.ERR_MOD_GETVPNIPLIST_BASE

local _M = { 
    _VERSION = '1.0.1',
    MOD_ERR_ALLOC = MOD_ERR_BASE-1,
    MOD_ERR_DBINIT = MOD_ERR_BASE-2,
    MOD_ERR_GETVPNLIST = MOD_ERR_BASE-3,
    MOD_ERR_DBDEINIT = MOD_ERR_BASE-4,
}

local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO

local mt = { __index = _M}

function _M.new(self)
	return setmetatable({}, mt)
end

function _M.getvpnlist(self,db)
    local serverip={}
    local sql="select vpn_node_ip_tbl.vpnip  from vpn_node_ip_tbl,vpn_node_tbl where vpn_node_ip_tbl.nodeid=vpn_node_tbl.nodeid and vpn_node_tbl.enabled=1"
    
    --log(ERR,sql)
    
    local res,err,errcode,sqlstate = db:query(sql)
    if not res then
    	cc_global:returnwithcode(self.MOD_ERR_GETVPNLIST,nil)
    end
    
    local counter=1
    local ipinfo={}
    
    for k,v in pairs(res) do
        --log(ERR,"iplist:",v[1])
        -- vpnip(1)
        ipinfo[counter]=v[1]
        counter=counter+1
    end
    
    ipstr=table.concat(ipinfo,",")
    serverip['iplist']=ipstr
    return serverip
end


function _M:getvpnlist_redis(red)
	local serverip={}

	local res,err = red:hkeys("vpn_active_ip_to_id")
	if not res then
		--log(ERR,"getvpnlist_redis:"..tostring(err))
		return nil
	end

	local ipinfo={}
	local counter=1

	for k,v in pairs(res) do
		ipinfo[counter]=v
		counter=counter+1
	end
	ipstr=table.concat(ipinfo,",")

	serverip['iplist']=ipstr
	return serverip
end

function _M.process(self,userreq)
	local red = cc_global:init_redis()
	local serverip

    local switch_redis_on = nil
    if red ~= nil then
        hashname = "game_redis_options"
        key = "redis_enable"
        switch_redis_on = cc_global:redis_hash_get(red,hashname,key)
    end

    if tonumber(switch_redis_on) == 1 then
        --log(ERR,"choose redis return vpn list...")
	    serverip=self:getvpnlist_redis(red)
	    cc_global:deinit_redis(red)

	    if serverip==nil then
                --log(ERR,"redis return vpn list failed, choose mysql return vpn list...")
    	        local db = cc_global:init_conn()
    	        serverip=self:getvpnlist(db)
    	        cc_global:deinit_conn(db)
	    end
    else
        --log(ERR,"redis disable, mysql return vpn list...")
	    local db = cc_global:init_conn()
   	    serverip=self:getvpnlist(db)
   	    cc_global:deinit_conn(db)
    end

    cc_global:returnwithcode(0,serverip)
end

return _M
