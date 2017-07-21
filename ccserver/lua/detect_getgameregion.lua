require "os"

local detect_global=require "detect_global"
local MOD_ERR_BASE = detect_global.ERR_MOD_GETGAMEREGION_BASE

local _M = { 
    _VERSION = '1.0.1',
    MOD_ERR_GETGAMEREGION = MOD_ERR_BASE-1,
}

local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO

local mt = { __index = _M}

function _M.new(self)
	return setmetatable({}, mt)
end

function _M.getgameregion(self,db)
    local sql
    local gamelst={}
    local detectgamelst={}
    local returnlst={}
    
    sql="select gameid,regionid from game_region_tbl order by gameid"

    --log(ERR,sql)
    local res,err,errcode,sqlstate = db:query(sql)
    if not res then
    	detect_global:returnwithcode(self.MOD_ERR_GETGAMEREGION,nil)
    end
    
    for k,v in pairs(res) do
        --log(ERR,"regionlist:",v[1]," ",v[2])
    	-- gameid(1),regionid(2)
    	local gameitem={}
    	local gameid
    	
    	gameid=tostring(v[1])
    	
    	if gamelst[gameid]==nil then
    	    gameitem['gameid']=v[1]
    	    gameitem['tmpregionlst']={}
    	    gameitem['regioncounter']=1
    	else
    	    gameitem=gamelst[gameid]
    	end
    	
    	gameitem['tmpregionlst'][gameitem['regioncounter']]=v[2]
    	gameitem['regioncounter']=gameitem['regioncounter']+1
    	
    	gamelst[gameid]=gameitem
    end
    
    for k,v in pairs(gamelst) do
        local gameitem
        gameitem=gamelst[k]
        gameitem['regionlist']=table.concat(gameitem['tmpregionlst'],",")
        gameitem['tmpregionlst']=nil
        gameitem['regioncounter']=nil
        table.insert(detectgamelst,gameitem)
    end
    
    returnlst['gamelist']=detectgamelst
    return returnlst
end

function _M.process(self,userreq)
    local db = detect_global:init_conn()
    local detectgamelst=self:getgameregion(db)
    detect_global:deinit_conn(db)
    
    detect_global:returnwithcode(0,detectgamelst)
end

return _M
