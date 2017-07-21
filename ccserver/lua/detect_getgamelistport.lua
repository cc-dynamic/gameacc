require "os"

local detect_global=require "detect_global"
local MOD_ERR_BASE = detect_global.ERR_MOD_GETGAMELISTPORT_BASE

local _M = { 
    _VERSION = '1.0.1',
    MOD_ERR_INVALID_PARAM = MOD_ERR_BASE-1,
    MOD_ERR_PARAM_TYPE = MOD_ERR_BASE-2,
    MOD_ERR_GETGAMELIST = MOD_ERR_BASE-3,
}

local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO

local mt = { __index = _M}

function _M.new(self)
	return setmetatable({}, mt)
end

function _M.checkparm(self,userreq)
    local gameid,regionid
    if userreq['data']==nil then
        detect_global:returnwithcode(self.MOD_ERR_INVALID_PARAM,nil)
    end
    
    local req_param=userreq['data']
    if req_param['gameid'] == nil or req_param['regionid'] == nil then
        detect_global:returnwithcode(self.MOD_ERR_INVALID_PARAM,nil)
    end
    
    gameid=tonumber(req_param['gameid'])
    regionid=tonumber(req_param['regionid'])
    
    if gameid == nil or regionid==nil then
        detect_global:returnwithcode(self.MOD_ERR_PARAM_TYPE,nil)
    end
    
    self.gameid=gameid
    self.regionid=regionid
end

function _M.getdetectipportlist(self,db)
    local sql
    local regionlst={}
    local detectregionlst={}
    local returnlst={}
    
    if self.regionid~= 0 then
        sql="select gameregionid,gameip,gamemask,gameport from game_server_tbl where gameid=" .. self.gameid .. " and gameregionid=" .. self.regionid
    else
        sql="select gameregionid,gameip,gamemask,gameport from game_server_tbl where gameid=" .. self.gameid
    end

    --log(ERR,sql)
    local res,err,errcode,sqlstate = db:query(sql)
    if not res then
    	detect_global:returnwithcode(self.MOD_ERR_GETGAMELIST,nil)
    end
    
    for k,v in pairs(res) do
        --log(ERR,"iplist:",v[1]," ",v[2]," ",v[3]," ",v[4])
    	-- gameregionid(1),gameip(2),gamemask(3),gameport(4)
    	local regionitem={}
    	local regionid
    	
    	regionid=tostring(v[1])
    	
    	if regionlst[regionid]==nil then
    	    regionitem['regionid']=v[1]
    	    regionitem['tmpiplst']={}
    	    regionitem['ipcounter']=1
    	else
    	    regionitem=regionlst[regionid]
    	end
    	
    	regionitem['tmpiplst'][regionitem['ipcounter']]=v[2].."/"..v[4].."/"..v[3]
    	regionitem['ipcounter']=regionitem['ipcounter']+1
    	
    	regionlst[regionid]=regionitem
    end
    
    for k,v in pairs(regionlst) do
        local regionitem
        regionitem=regionlst[k]
        regionitem['iplist']=table.concat(regionitem['tmpiplst'],",")
        regionitem['tmpiplst']=nil
        regionitem['ipcounter']=nil
        table.insert(detectregionlst,regionitem)
    end
    
    returnlst['detectregionlst']=detectregionlst
    return returnlst
end

function _M.process(self,userreq)
    self.gameid=0
    self.regionid=0
    
    self:checkparm(userreq)
    local db = detect_global:init_conn()
    local detectregionlst=self:getdetectipportlist(db)
    detect_global:deinit_conn(db)
    
    detect_global:returnwithcode(0,detectregionlst)
end

return _M
