require "os"

local cc_global=require "cc_global"
local MOD_ERR_BASE = cc_global.ERR_MOD_GETGAMELISTPORT_BASE

local _M = { 
    _VERSION = '1.0.1',
    MOD_ERR_INVALID_PARAM = MOD_ERR_BASE-1,
    MOD_ERR_PARAM_TYPE = MOD_ERR_BASE-2,
    MOD_ERR_ALLOC = MOD_ERR_BASE-3,
    MOD_ERR_DBINIT = MOD_ERR_BASE-4,
    MOD_ERR_GETGAMELIST = MOD_ERR_BASE-5,
    MOD_ERR_SAVEUSERHISTORY = MOD_ERR_BASE-6,
    MOD_ERR_DBDEINIT = MOD_ERR_BASE-7
}

local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO

local mt = { __index = _M}

local MINVPNRTT=30	-- vpn rtt below MINVPNRTT will not return iplst
local MAXTRANSRTT=100	-- total rtt more than MAXTRANSRTT not return iplst

function _M.new(self)
	return setmetatable({}, mt)
end

function _M.checkparm(self,userreq)
    local gameid,regionid
	local svpninfo

    if userreq['data']==nil then
        cc_global:returnwithcode(self.MOD_ERR_INVALID_PARAM,nil)
    end
    
    local req_param=userreq['data']
    if req_param['gameid'] == nil or req_param['regionid'] == nil then
        cc_global:returnwithcode(self.MOD_ERR_INVALID_PARAM,nil)
    end
    
    gameid=tonumber(req_param['gameid'])
    regionid=tonumber(req_param['regionid'])
    if gameid == nil or regionid==nil then
        cc_global:returnwithcode(self.MOD_ERR_PARAM_TYPE,nil)
    end

	svpninfo=req_param['svpninfo']
	if svpninfo ~= nil then
		if svpninfo['ip']~=nil and svpninfo['rtt']~=nil then
			self.svpninfo=svpninfo
		end
	end

    self.gameid=gameid
    self.regionid=regionid
    self.uid=tostring(userreq['uid'])
end

function _M.getgameiplist(self,db)
    local sql
    local gameiplist={}
    local percent=0
    local counter
    local maxreturn=0
    
    sql = "select game_list_percent from game_name_tbl where game_id=" .. self.gameid
    --log(ERR,sql)
    local res,err,errcode,sqlstate = db:query(sql)
    if not res then
    	cc_global:returnwithcode(self.MOD_ERR_GETGAMELIST,nil)
    end
    
    -- game_list_percent(1)
    for k,v in pairs(res) do
        --log(ERR,"game_list_percent:",v[1])
        percent=tonumber(v[1])
        break
    end
    
    if percent==0 then
        return ""
    end
    
    if self.regionid~= 0 then
        sql="select distinct gameip,gamemask,gameport from game_server_tbl where gameid=" .. self.gameid .. " and gameregionid=" .. self.regionid
    else
        sql="select distinct gameip,gamemask,gameport from game_server_tbl where gameid=" .. self.gameid
    end

    --log(ERR,sql)
    
    local res,err,errcode,sqlstate = db:query(sql)
    if not res then
    	cc_global:returnwithcode(self.MOD_ERR_GETGAMELIST,nil)
    end
    
    maxreturn=table.getn(res)*percent/100
    --log(ERR,"len(res)="..table.getn(res)..",maxreturn="..maxreturn)
    
    counter=1

    -- gameip(1),gamemask(2),gameport(3)
    local ipstr=""
    local ipinfo={}
    
    for k,v in pairs(res) do
        --log(ERR,"iplist:",v[1]," ",v[2]," ",v[3])
    	ipinfo[counter]=v[1]..":"..tostring(v[3]).."/"..tostring(v[2])
    	counter=counter+1
    	if counter>maxreturn then
    	    break
    	end
    end
    
    ipstr=table.concat(ipinfo,",")
    return ipstr
end

function _M.saveuserhistory(self,db)
    local nowstr
    nowstr=os.date("%Y-%m-%d %H:%M:%S")

    local sql = "insert into game_user_history_tbl(username,starttime,gameid,gameregionid) values ('" .. self.uid .."','".. nowstr.."',"..self.gameid..","..self.regionid..")"
    
    --log(ERR,sql)
    local res,err,errcode,sqlstate = db:query(sql)
    if not res then
    	cc_global:returnwithcode(self.MOD_ERR_SAVEUSERHISTORY,nil)
    end
    
end

function _M.validategameregion(self,red,userreq)
	local game_region_key
	if red:sismember("active_game_id",self.gameid)==0 then
        cc_global:returnwithcode(self.MOD_ERR_INVALID_PARAM,nil)
    end

    if self.regionid ~=0 then
        game_region_key="game_"..tostring(self.gameid).."_region"
        if red:sismember(game_region_key,self.regionid)==0 then
            cc_global:returnwithcode(self.MOD_ERR_INVALID_PARAM,nil)
        end
    end
end

function _M.getgameiplistbysvpninfo(self,red,userreq)
	local vpnid,vpnidkey,vpnidfield
	local activeid,detectactiveidkey,detectactiveidfield
	local gamedetectkey
	local gameiplst=""
	local gameiplsttbl={}
	local threshold

	local regionid

	--1. validate gameid,regionid
	self:validategameregion(red,userreq)

	regionid=1		-- for current region 0 equals to region 1
	
	--2. getvpnid
	vpnidkey="vpn_active_ip_to_id"
	vpnidfield=self.svpninfo['ip']

    vpnid = cc_global:redis_hash_get(red,vpnidkey,vpnidfield)
	if vpnid == nil then
		return nil
	end

	--3. checkvpnrtt, less than MINVPNRTT, no need access vpn node ,return ""
	if tonumber(self.svpninfo['rtt'])<MINVPNRTT then
		return gameiplst		-- return empty list,not need use accelerate
	end

	--4. get vpn_x_detect_activeid
	detectactiveidkey="vpn_"..vpnid.."_detect_activeid"
	detectactiveidfield="game_"..self.gameid.."_region_"..regionid.."_activeid"

    activeid = cc_global:redis_hash_get(red,detectactiveidkey, detectactiveidfield)

	if activeid == nil or (tonumber(activeid)~=0 and tonumber(activeid)~=1) then
		return nil
	end
	
	--5. get gamelist
	threshold=MAXTRANSRTT-tonumber(self.svpninfo['rtt'])
	gamedetectkey="vpn_"..vpnid.."_game_"..self.gameid.."_region_"..regionid.."_detect_data_"..activeid

	gameiplsttbl=red:zrangebyscore(gamedetectkey,0,threshold)

	if table.getn(gameiplsttbl)==0 then
		return gameiplst		
	end
    --log(ERR,"return iplist length: " .. table.getn(gameiplsttbl))

	gameiplst=table.concat(gameiplsttbl,",")
	return gameiplst	
end

function _M.getgameiplistwithoutsvpninfo(self,red,userreq)
	local activeid,activeidkey,activeidfield
	local gameiplst,gameiplstkey,gameiplstfield
	-- 1. validate gameid,regionid
	self:validategameregion(red,userreq)

	-- 2. get activeid
	activeidkey="game_"..self.gameid.."_iplst_activeid"
	activeidfield="region_"..self.regionid.."_activeid"
    
    activeid = cc_global:redis_hash_get(red,activeidkey,activeidfield)
	if activeid == nil or (tonumber(activeid)~=0 and tonumber(activeid)~=1) then
		return nil
	end

	--3. get gameiplst
	gameiplstkey="game_"..self.gameid.."_iplst"
	gameiplstfield="region_"..self.regionid.."_iplst_"..activeid

    gameiplst = cc_global:redis_hash_get(red,gameiplstkey,gameiplstfield)
    if gameiplst == nil then
        return nil
    end
	return gameiplst
end

function _M.getgameiplistredis(self,red,userreq)
	local gameiplist=nil

	if self.svpninfo~=nil then
		-- new version
		gameiplist=self:getgameiplistbysvpninfo(red,userreq)
	end

	if gameiplist==nil then
		-- old version
		gameiplist=self:getgameiplistwithoutsvpninfo(red,userreq)
	end

	return gameiplist
end

function _M.process(self,userreq)
    self.uid=nil
    self.gameid=0
    self.regionid=0
	self.svpninfo=nil 
	local gameiplist
    
    self:checkparm(userreq)

    local switch_redis_on = nil
	local red = cc_global:init_redis()
    if red ~= nil then
        hashname = "game_redis_options"
        key = "redis_enable"
        switch_redis_on = cc_global:redis_hash_get(red,hashname,key)
    end

    --for test
    --red = nil
    --switch_redis_on = 1

    if tonumber(switch_redis_on) == 1 then
        if red ~= nil then
            --log(ERR,"redis enable, choose redis return gamelist")
	        gameiplist=self:getgameiplistredis(red,userreq)
	        cc_global:deinit_redis(red)
        end

	    local db = cc_global:init_conn()	
	    if gameiplist==nil then
            --log(ERR,"redis return gamelist failed, choose mysql return gamelist...")
    	    gameiplist=self:getgameiplist(db)
	    end

        self:saveuserhistory(db)
	    cc_global:deinit_conn(db)
    else
        --log(ERR,"redis disable, choose mysql return gamelist")
	    local db = cc_global:init_conn()	
    	gameiplist=self:getgameiplist(db)

        self:saveuserhistory(db)
	    cc_global:deinit_conn(db)
    end

    local retstr = ''
    if gameiplist ~= nil then
        retstr="\"" .. gameiplist .. "\""
    end

    ngx.say(retstr)
    ngx.exit(200)
end

return _M
