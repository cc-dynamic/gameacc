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
    ERR_INVALID_JSON_FORMAT = ERR_BASE_ERROR-7,
    
    ERR_DB_ALLOC = ERR_BASE_ERROR-8,
    ERR_DBINIT = ERR_BASE_ERROR-9,
    ERR_DBDEINIT = ERR_BASE_ERROR-10,

    ERR_MOD_DB_BASE = ERR_BASE_ERROR-100,
    ERR_MOD_GETGAMEBRIEF_BASE = ERR_BASE_ERROR-200,
    ERR_MOD_QUERYACCT_BASE = ERR_BASE_ERROR-300,
}

local mt = { __index = _M}
local cjson = require "cjson"

function _M.new(self)
	return setmetatable({}, mt)
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

function _M.deinit_conn(self,db)
    local ok,err = db:close()
    if not ok then
    	self:returnwithcode(self.ERR_DBDEINIT,nil)
    end
end

return _M
