require "os"

local cc_global=require "cc_global"
local MOD_ERR_BASE = cc_global.ERR_MOD_GETVPNIP_BASE

local _M = { 
    _VERSION = '1.0.1',
    MOD_ERR_ALLOC = MOD_ERR_BASE-1,
    MOD_ERR_DBINIT = MOD_ERR_BASE-2,
    MOD_ERR_DBDEINIT = MOD_ERR_BASE-3,
	MOD_ERR_INVALID_PARAM = MOD_ERR_BASE-4,
	MOD_ERR_GETVPNIP = MOD_ERR_BASE-5,
	MOD_ERR_SAVEUSERRTT = MOD_ERR_BASE-6
}

local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO

local AVA_INF=99999
local MAX_AVA_DIFF=5

local mt = { __index = _M}

function _M.new(self)
	return setmetatable({}, mt)
end

function _M.saveuserrtt(self,userreq,serverip)
	local cjson=require "cjson"
    local infostr=cjson.encode(self.qoslst)
	local nowstr=os.date("%Y-%m-%d %H:%M:%S")

	local db = cc_global:init_conn()
	local sql="insert into game_user_rtt_tbl(clientip,username,rttinfo,vpnserver,updatetime) values "
	
	sql=sql .. "('" .. ngx.var.remote_addr .. "','" .. tostring(userreq['uid']) .. "','" .. infostr .. "','" .. serverip['serverip'] .. "','" .. nowstr .."')"
	
	--log(ERR,sql)

	local res,err,errcode,sqlstate = db:query(sql)
	if not res then
		cc_global:deinit_conn(db)
		cc_global:returnwithcode(self.MOD_ERR_SAVEUSERRTT,nil)
	end

	cc_global:deinit_conn(db)
end

function _M.loadvalidvpnip(self)
    local validvpn={}

    local db = cc_global:init_conn()
	local sql="select vpn_node_ip_tbl.vpnip from vpn_node_ip_tbl, vpn_node_tbl where vpn_node_ip_tbl.nodeid = vpn_node_tbl.nodeid and vpn_node_tbl.enabled = 1;"
	
	local res,err,errcode,sqlstate = db:query(sql)
    if not res then
		cc_global:deinit_conn(db)
        return validvpn
    end
    
    for k,v in pairs(res) do
        validvpn[v[1]] = "enabled"
    end

	cc_global:deinit_conn(db)
    --self:dumptbl(validvpn)
	return validvpn
end

function _M.getvpnip(self,userreq)
    local serverip={}

	local id=0
	local rttmin=99999
	local item
    
    local validvpn 
    validvpn = self:loadvalidvpnip()

	for k,v in pairs(self.qoslst) do

		while true do
			if v['rtt']==nil or v['lose']==nil or v['ip']==nil then
				break
			end
            
            if validvpn[v['ip']] == nil then 
                break
            end

			if tonumber(v['rtt'])<tonumber(rttmin)  and tonumber(v['lose'])==0 then
				rttmin=v['rtt']	
				id=k
			end

			break
		end
	end

	if id==0 then
		serverip['serverip']=''
		-- self:saveuserrtt(userreq,serverip)
	else
		item=self.qoslst[id]
		serverip['serverip']=item['ip']
		
		if tonumber(item['rtt'])>50 then
			-- self:saveuserrtt(userreq,serverip)
		end

	end

    return serverip
end

function _M.filteractivevpn(self,red)
	local filtervpnlst={}
	local vpnid
	
	for k,v in pairs(self.qoslst) do
        while true do
            local filteritem={}
            if v['rtt']==nil or v['lose']==nil then
                break
            end

            vpnid=cc_global:redis_hash_get(red,"vpn_active_ip_to_id",v['ip'])
            
            if vpnid ~= nil then
                filteritem['rtt']=v['rtt']
                filteritem['ip']=v['ip']
                filteritem['vpnid']=vpnid
                if v['lose']~= nil then
                    filteritem['loss']=v['lose']
                end
                filteritem['valid']=1
                table.insert(filtervpnlst,filteritem)
                break
            else
                --log(ERR,"not exist...")
                break
            end
        end
	end

	return filtervpnlst

end

function _M.filterqosredis(self,red)
	local filterqos	
	local vpnid

	if red:sismember("active_game_id",self.gameid)==0 then
		cc_global:returnwithcode(self.MOD_ERR_INVALID_PARAM,nil)
	end

	if self.regionid ~=0 then
		game_region_key="game_"..tostring(self.gameid).."_region"
		if red:sismember(game_region_key,self.regionid)==0 then
			cc_global:returnwithcode(self.MOD_ERR_INVALID_PARAM,nil)
		end
	end

	filterqos=self:filteractivevpn(red)	
	return filterqos
end


function _M.updateqosredis(self,red,filterqos)
	local k,v
	local ava_key,ava_field,ava_rtt

	for k,v in pairs(filterqos) do
		ava_key="vpn_"..v['vpnid'].."_ava_rtt"
		ava_field="game_"..tostring(self.gameid).."_region_"..tostring(self.regionid).."_rtt"
		ava_rtt=red:hget(ava_key,ava_field)
		if tonumber(ava_rtt)==0 or tonumber(ava_rtt)==AVA_INF then
			v['rtt']=AVA_INF
			v['valid']=0
		else
            local rtt = tonumber(v['rtt'])
            if rtt == nil then
                v['rtt'] = AVA_INF
                v['valid'] = 0
            else
			    v['rtt']= rtt + tonumber(ava_rtt)
            end
		end
	end
end

function _M.updatesortqosredis(self,red,filterqos)
	local minrtt=0
	local filtervpnip={}

	for k,v in pairs(filterqos) do
		while true do
			if v['valid']==0 then
				break
			end

            local loss = tonumber(v['loss'])
			if loss ~= 0 then
				break
			end

            local rtt
            rtt = tonumber(v['rtt'])

            if rtt == nil then
                break
            end

			if minrtt==0 then
				minrtt = rtt
				table.insert(filtervpnip,v['ip'])
				break
			end

			if rtt-minrtt<=MAX_AVA_DIFF then
				table.insert(filtervpnip,v['ip'])
			end

			break
		end
	end
	return filtervpnip
end

function _M.getrandomvpnip(self,filtervpnip)
	local n=0
	local p
    local serveriptbl = {}

	n=table.getn(filtervpnip)
	math.randomseed(os.time())
	p=math.random(1,n)
    serveriptbl["serverip"] = filtervpnip[p]
	return serveriptbl
end

function _M.getvpnipredis(self,red,userreq)

	if self.gameid~=nil and self.regionid~=nil then
		-- new version
		local filterqos
		local filtervpnip
		local n

		-- 1. validate gameid,regionid,vpnip
		filterqos=self:filterqosredis(red)
	
		-- 2. update game region ava rtt in filterqos
		self:updateqosredis(red,filterqos)

		-- 3. sort qos
		table.sort(filterqos,function(a,b) return tonumber(a['rtt'])<tonumber(b['rtt']) end)
		--self:dumptbl(filterqos)

		-- 4. filter result	
		filtervpnip=self:updatesortqosredis(red,filterqos)
		--self:dumptbl(filtervpnip)

		n=table.getn(filtervpnip)
		if n==0 then
			return nil
		end

		return self:getrandomvpnip(filtervpnip)
	else
		-- old version
		-- 1. validate vpnip
		local filterqos
		local filtervpnip
		local n
		
		filterqos=self:filteractivevpn(red)

		--2. sort qos
		table.sort(filterqos,function(a,b) return tonumber(a['rtt'])<tonumber(b['rtt']) end)
		--self:dumptbl(filterqos)

		--3. filter result
		filtervpnip=self:updatesortqosredis(red,filterqos)
		--self:dumptbl(filtervpnip)

		n=table.getn(filtervpnip)
        if n==0 then
            return nil
        end

        return self:getrandomvpnip(filtervpnip)
	end
end

function _M.dumptbl(self,filtertbl)
	local cjson = require "cjson"
	retstr=cjson.encode(filtertbl)
	log(ERR,retstr)	
end

-- checkparm fill qoslst,fill gameid,regionid if exist
function _M.checkparm(self,userreq)
    local gameid,regionid
	
    if userreq['data']==nil then
        cc_global:returnwithcode(self.MOD_ERR_INVALID_PARAM,nil)
    end

    local req_param=userreq['data']
    if req_param['info'] == nil then
        cc_global:returnwithcode(self.MOD_ERR_INVALID_PARAM,nil)
    end

	gameid=tonumber(req_param['gameid']) or nil
	regionid=tonumber(req_param['regionid']) or nil

	self.gameid=gameid
	self.regionid=regionid
	self.qoslst=req_param['info']
		
end

function _M.process(self,userreq)
	self.qoslst=nil
	self.gameid=nil
	self.regionid=nil
	
	self:checkparm(userreq)
	local serverip = {}

    local switch_redis_on = nil

	local red = cc_global:init_redis()
    if red ~= nil then
        hashname = "game_redis_options"
        key = "redis_enable"
        switch_redis_on = cc_global:redis_hash_get(red,hashname,key)
    end

    --for test
    --switch_redis_on = 1
    --red = nil

    --redis switch on, access to redis
    if tonumber(switch_redis_on) == 1 then
        if red == nil then
            --log(ERR,"redis init failed, choose mysql return vpn ip...")
		    serverip=self:getvpnip(userreq)
        else
            hashname = "spec_user_to_spec_vpnip"
            key = userreq['uid']
            local temp_serverip = cc_global:redis_hash_get(red,hashname,key)
            
            --not specific user
            if temp_serverip == nil then
                --log(ERR,"choose redis return vpn ip...")
	            serverip=self:getvpnipredis(red,userreq)
	            cc_global:deinit_redis(red)
            --specific user return specific user
            else
                --log(ERR,"specific user, return vpnip: " .. temp_serverip)
                serverip['serverip'] = temp_serverip
	            cc_global:deinit_redis(red)
            end
        end
    --redis switch off, switch to mysql
    else
        --log(ERR,"redis disabled, choose mysql return vpn ip...")
		serverip=self:getvpnip(userreq)
	end

    if serverip == nil or serverip['serverip'] == '' then
        log(ERR,serverip)
    end
    cc_global:returnwithcode(0,serverip)
end

return _M
