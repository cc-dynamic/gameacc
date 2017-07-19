require "os"

local billing_global=require "billing_global"

local MOD_ERR_BASE = billing_global.ERR_MOD_GETCCLST_BASE

local _M = { 
    _VERSION = '1.0.1',
    
    MOD_ERR_INVALID_PARAM = MOD_ERR_BASE-1,
	MOD_ERR_INVALID_TYPE = MOD_ERR_BASE-2,
	MOD_ERR_SAVE_BILLING = MOD_ERR_BASE-3
    
}

local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO



local mt = { __index = _M}




function _M.new(self)
	return setmetatable({}, mt)
end



function _M.checkparm(self,userreq)
	if userreq['data']==nil then
		billing_global:returnwithcode(self.MOD_ERR_INVALID_PARAM,nil)
	end

	local cjson=require "cjson"
	local infostr
	infostr=cjson.encode(userreq['data'])
	log(ERR,infostr)

	local reqdata=userreq['data']

	if reqdata['orderinfo']==nil then
		billing_global:returnwithcode(self.MOD_ERR_INVALID_PARAM,nil)
	end

	local orderdata=reqdata['orderinfo']



	local billingkeyword= {"orderID","deviceID","userID","userType","orderType","money","startTime","duringTime","refundTime","refundFee"}
	local checkfun={tostring, tostring,  tostring, tostring, tostring,   tonumber,tonumber,   tonumber,   tonumber,    tonumber}
	local checktype={"string","string",  "string", "string", "string",  "number", "number",  "number",   "number",    "number"}


	for k,v in pairs(billingkeyword) do
		if orderdata[v]==nil then
			log(ERR,"keyword " .. v .. " not exist")
			billing_global:returnwithcode(self.MOD_ERR_INVALID_PARAM,nil)
		end

		local checkf=checkfun[k]
		local checkv=checkf(orderdata[v])

		if type(checkv)~=checktype[k] then
			log(ERR,"check keyword " .. v .. " failed")
			billing_global:returnwithcode(self.MOD_ERR_INVALID_TYPE,nil)	
		end

		self.billingdata[v]=checkv

	end

end


function _M.uploadbill(self,db,userreq)
	local sql="insert into game_billing_tbl (orderID,deviceID,userID,userType,orderType,money,startTime,duringTime,refundTime,refundFee) values "
	local billingdata=self.billingdata

	-- local billingkeyword= {"orderID","deviceID","userId","userType","orderType","money","startTime","duringTime","refundTime","refundFee"}
	sql=sql .. "('" .. billingdata['orderID'] .. "','" .. billingdata['deviceID'] .. "','" .. billingdata['userID'] .. "','" .. billingdata['userType'] .. "'," .. billingdata['orderType'] .. "," .. billingdata['money'] .. "," .. billingdata['startTime'] .. "," .. billingdata['duringTime'] .. "," .. billingdata['refundTime'] .. "," .. billingdata['refundFee'] .. ")"
	
	log(ERR,sql)

	local res,err,errcode,sqlstate = db:query(sql)
	if not res then
		billing_global:deinit_conn(db)
        billing_global:returnwithcode(self.MOD_ERR_SAVEBILLING,nil)
    end


end


function _M.process(self,userreq)
	self.billingdata={}

	self:checkparm(userreq)

    local db = billing_global:init_conn()
	self:uploadbill(db,userreq)
    billing_global:deinit_conn(db)
    
    billing_global:returnwithcode(0,nil)
end

return _M
