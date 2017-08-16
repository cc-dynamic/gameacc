require "os"

local ERR_BASE_ERROR = -20000
local _M = { 
    _VERSION = '1.0.1',
    ERR_INVALID_METHOD = ERR_BASE_ERROR-1,
    ERR_NO_BODYDATA = ERR_BASE_ERROR-2,
    ERR_INVALID_PARAM = ERR_BASE_ERROR-3,
    ERR_PARAM_TYPE = ERR_BASE_ERROR-4,
    ERR_UNSUPPORT_VERSION = ERR_BASE_ERROR-5,
    ERR_UNSUPPORT_CMD = ERR_BASE_ERROR-6,
    ERR_UNSUPPORT_DEVICE = ERR_BASE_ERROR-7,
    ERR_UNSUPPORT_USERTYPE = ERR_BASE_ERROR-8,
    ERR_INVALID_JSON_FORMAT = ERR_BASE_ERROR-9,
    
    ERR_DB_ALLOC = ERR_BASE_ERROR-10,
    ERR_DBINIT = ERR_BASE_ERROR-11,
    ERR_DBDEINIT = ERR_BASE_ERROR-12,

	ERR_REDIS_ALLOC = ERR_BASE_ERROR-20,
	ERR_REDIS_CONNECT = ERR_BASE_ERROR-21,
	ERR_REDIS_AUTH = ERR_BASE_ERROR-22,
	ERR_REDIS_KEEPALIVE=ERR_BASE_ERROR-23,

    ERR_MOD_GETGAMELIST_BASE = ERR_BASE_ERROR-100,
    ERR_MOD_UPLOADINFO_BASE = ERR_BASE_ERROR-200,
    ERR_MOD_GETVPNIP_BASE = ERR_BASE_ERROR-300,
    ERR_MOD_GETLISTVERSION_BASE = ERR_BASE_ERROR-400,
	ERR_MOD_GETVPNIPLIST_BASE = ERR_BASE_ERROR-500, 
    ERR_MOD_GETGAMELISTPORT_BASE = ERR_BASE_ERROR-600,
}

local mt = { __index = _M}
local cjson = require "cjson"

function _M.new(self)
	return setmetatable({}, mt)
end

function _M.redis_hash_get(self,red,hashname,key)
    local retval = nil
    if red:hexists(hashname,key) == 0 then
        return retval
    end

    retval = red:hget(hashname,key)
    return retval
end

-- error function
function _M.makereturninfo(self,errcode,data)
    local retinfo={}
    local retstr
    retinfo["code"]=errcode
    retinfo["time"]=os.time()
    if data~=nil then
        retinfo["data"]=data
    end
    retstr=cjson.encode(retinfo)
    return retstr
end

function _M.returnwithcode(self,errcode,data)
    local retstr
    retstr=self:makereturninfo(errcode,data)
    ngx.say(retstr)
    if errcode ~= 0 then
        ngx.log(ngx.ERR,"errcode = " .. errcode)
    end
    ngx.exit(200)
end

function _M.init_conn(self)
    local mysql = require "resty.mysql"
    local db,err = mysql.new()
    if not db then
        self:returnwithcode(self.ERR_DB_ALLOC,nil)
    end
    
    db:set_timeout(5000)
    
    local ok,err,errcode,sqlstate = db:connect {
    	host = "127.0.0.1",
    	port = 3306,
    	database = "game1",
    	user = "root",
    	password = "root",
    	max_packet_size= 1024*1024,
    	compact_arrays = true }
    
    if not ok then
    	self:returnwithcode(self.ERR_DBINIT,nil)
    end
    
    return db
end

function _M.init_redis(self)
	local redis = require "resty.redis"
	local red = redis:new()

	if not red then
		--self:returnwithcode(self.ERR_REDIS_ALLOC,nil)
                return nil
	end

	red:set_timeout(1000)	-- 1 sec
	
	local ok,err = red:connect("127.0.0.1",6379)
	if not ok then
		--self:returnwithcode(self.ERR_REDIS_CONNECT,nil)
                return nil
	end	
	
	local res,err = red:auth("cc_chinacache")
	--local res,err = red:auth("chinacache")
	if not res then
                return nil
		--self:returnwithcode(self.ERR_REDIS_AUTH,nil)
	end

	--local ok,err = red:set_keepalive(10000,100)
	--if not ok then
	--	ngx.log(ngx.ERR,tostring(err))
	--	self:returnwithcode(self.ERR_REDIS_AUTH,nil)
	--end
	return red
end

function _M.deinit_redis(self,red)
	local ok,err = red:set_keepalive(10000,100)
	if not ok then
		self:returnwithcode(self.ERR_REDIS_KEEPALIVE,nil)
	end
end

function _M.deinit_conn(self,db)
    local ok,err = db:close()
    if not ok then
    	self:returnwithcode(self.ERR_DBDEINIT,nil)
    end
end

return _M
