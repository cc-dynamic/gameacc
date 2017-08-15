require "os"

local fei_global=require "fei_global"
local MOD_ERR_BASE = fei_global.ERR_MOD_GETGAMEBRIEF_BASE

local _M = { 
    _VERSION = '1.0.1',
    MOD_ERR_ALLOC = MOD_ERR_BASE-1,

    MOD_ERR_GETREGION = MOD_ERR_BASE-3,
    MOD_ERR_GETBRIEFLIST = MOD_ERR_BASE-4,
    MOD_ERR_GETDETECTLIST = MOD_ERR_BASE-5,

}

local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO

local mt = { __index = _M}

function _M.new(self)
	return setmetatable({}, mt)
end

function _M.get_all_region(self,db)
    local tmpgamelist={}

    local sql_game_all_region="select game_name_tbl.game_id,game_name_tbl.game_name,game_name_tbl.game_icon_url,game_region_tbl.regionid,game_region_tbl.regionname,game_region_tbl.ispname from game_name_tbl,game_region_tbl where game_name_tbl.game_id=game_region_tbl.gameid and game_name_tbl.admin_enable=1 order by game_name_tbl.game_id"
    
    local res,err,errcode,sqlstate = db:query(sql_game_all_region)
    if not res then
    	fei_global:returnwithcode(self.MOD_ERR_GETREGION,nil)
    end
    
    -- game_id(1),game_name(2),icon_url(3),regionid(4),regionname(5),ispname(6)
    for k,v in pairs(res) do
        --log(ERR,"game region:",v[1]," ",v[2]," ",v[3]," ",v[4]," ",v[5]," ",v[6])
        local gameitem={}
        local regionitem={}
        local regionlist,gameindex,regionindex
        
        gameindex=tostring(v[1])
    
        if tmpgamelist[gameindex]== nil then      -- new game
            gameitem['game_id']=v[1]
            gameitem['game_name']=v[2]
            gameitem['game_icon_url']=v[3]
            gameitem['regionlist']={}
        else
            gameitem=tmpgamelist[gameindex]
        end
        
        regionlist=gameitem['regionlist']
        regionindex=tostring(v[4])
        
        regionitem['region_id']=regionindex
        regionitem['region_name']=v[5]
        regionitem['isp_name']=v[6]
        regionitem['detect_ip_list']={}
        regionitem['brief_ip_list']={}
        
        regionlist[regionindex]=regionitem		    -- add region    
        gameitem['regionlist']=regionlist           -- update gameitem
        tmpgamelist[gameindex]=gameitem                -- update tmpgamelist
    end
    return tmpgamelist
end

-- require self.tmpgamelist
function _M.getbrieflist(self,db)
    local sql_brief_ip = "select game_server_brief_tbl.gameid,game_server_brief_tbl.gameregionid,game_server_brief_tbl.gameip,game_server_brief_tbl.gamemask from game_server_brief_tbl,game_name_tbl where game_name_tbl.game_id=game_server_brief_tbl.gameid and game_name_tbl.admin_enable=1 order by game_server_brief_tbl.gameid"
    
    local res,err,errcode,sqlstate = db:query(sql_brief_ip)
    
    if not res then
    	fei_global:returnwithcode(self.MOD_ERR_GETBRIEFLIST,nil)
    end
    
    -- gameid(1),gameregionid(2),gameip(3),gamemask(4)
    for k,v in pairs(res) do
        --log(ERR,"brief ip list: ",v[1]," ",v[2]," ",v[3]," ",v[4])
        
        local gameitem={}
        local regionitem={}
        local ipitem={}
        local regionlist,gameindex,regionindex
        gameindex=tostring(v[1])
        
        if self.tmpgamelist[gameindex] ~= nil then
            gameitem=self.tmpgamelist[gameindex]
            
            regionindex=tostring(v[2])
    	    regionlist=gameitem['regionlist']
            
            if regionlist[regionindex] ~= nil then
                regionitem=regionlist[regionindex]
                
                ipitem['brief_ip']=v[3]
                ipitem['brief_mask']=v[4]
    
                table.insert(regionitem['brief_ip_list'],ipitem)
                
                regionlist[regionindex]=regionitem		    -- update region    
                gameitem['regionlist']=regionlist           -- update gameitem
                self.tmpgamelist[gameindex]=gameitem                -- update tmpgamelist
            
            end    
        end
    end
end

-- require self.tmpgamelist
function _M.getdetectlist(self,db)
    local sql_detect_ip = "select game_server_tbl.gameid,game_server_tbl.gameregionid,game_server_tbl.gameip,game_server_tbl.gamemask,game_server_tbl.gameport from game_server_tbl,game_name_tbl where game_name_tbl.game_id=game_server_tbl.gameid and game_name_tbl.admin_enable=1 and game_server_tbl.gamedetect=1 order by game_server_tbl.gameid"
    
    local res,err,errcode,sqlstate = db:query(sql_detect_ip)
    
    if not res then
    	fei_global:returnwithcode(self.MOD_ERR_GETDETECTLIST,nil)
    end
    
    -- gameid(1),gameregionid(2),gameip(3),gamemask(4),gameport(5)
    for k,v in pairs(res) do
        --log(ERR,"detect ip list: ",v[1]," ",v[2]," ",v[3]," ",v[4]," ",v[5])
        local gameitem={}
        local regionitem={}
        local ipitem={}
        local regionlist,gameindex,regionindex
        gameindex=tostring(v[1])
        
        if self.tmpgamelist[gameindex] ~= nil then
            gameitem=self.tmpgamelist[gameindex]
            
            regionindex=tostring(v[2])
            regionlist=gameitem['regionlist']
            
            if regionlist[regionindex] ~= nil then
                regionitem=regionlist[regionindex]
                
                ipitem['detect_ip']=v[3]
                ipitem['detect_mask']=v[4]
                ipitem['detect_port']=v[5]
    
                table.insert(regionitem['detect_ip_list'],ipitem)
                
                regionlist[regionindex]=regionitem		    -- update region    
                gameitem['regionlist']=regionlist           -- update gameitem
                self.tmpgamelist[gameindex]=gameitem                -- update tmpgamelist
            end    
        end
    end
end

-- require self.tmpgamelist
function _M.filtergamelist(self)
    local gamelist={}
    
    for k,v in pairs(self.tmpgamelist) do
        local gameitem
        local regionlist
        
        gameitem=self.tmpgamelist[k]
        gameitem['game_regionlist']={}
        
        regionlist=gameitem['regionlist']
        for k1,v1 in pairs(regionlist) do
            table.insert(gameitem['game_regionlist'],v1)
        end
        
        gameitem['regionlist']=nil
        table.insert(gamelist,gameitem)
    end
    return gamelist
end

function _M.process(self,userreq)
    self.tmpgamelist=nil
    local db = fei_global:init_conn()
    self.tmpgamelist = self:get_all_region(db)
    self:getbrieflist(db)
    self:getdetectlist(db)
    fei_global:deinit_conn(db)
    
    local gamelist=self:filtergamelist()
    fei_global:returnwithcode(0,gamelist)
end

return _M
