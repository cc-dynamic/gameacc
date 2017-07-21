# coding:utf-8
import MySQLdb
import redis


VPN_ACTIVE_IP_TO_ID_DIC="vpn_active_ip_to_id"
ACTIVE_GAMEID_SET="active_game_id"
SPEC_USER_TO_SPEC_VPNIP = "spec_user_to_spec_vpnip"
GAME_REDIS_OPTIONS = "game_redis_options"
	
# dic: vpn_acitve_ip_to_id: vpn ip to id ,field:vpnip,value:id
# hash: spec_user_to_spec_vpnip: field:uid,value:vpnip
# hash: game_redis_options field:redis_enable,value:0 or 1

# dic: vpn_x_ava_rtt: 
#	game y region z average rtt value field:game_y_region_z_ava_rtt,value:rttvalue 
#	game y region z average rtt cnt value field: game_y_region_z_ava_rtt_cnt value: rtt count to help caculate ava rtt
# dic: vpn_x_detect_activeid: game y region z activeid field:game_y_region_z_activeid,value:-1,0,1

# set: active_game_id: active game id in game_name_tbl value: gameid
# set: game_y_region: game regionid set  value: regionid
# dic: game_y_iplst: game y static ip list  field: region_z_iplst value: string all ip list
# dic: game_y_iplst_activeid: game y region z ip list acitve id  field: region_z_iplst_activeid,value:-1,0,1


# init dic vpn_active_ip_to_id
def init_vpn_info(conn,cur,r):
	try:
		sql="select vpn_node_ip_tbl.vpnip,vpn_node_tbl.nodeid from vpn_node_ip_tbl,vpn_node_tbl where vpn_node_tbl.nodeid=vpn_node_ip_tbl.nodeid and vpn_node_tbl.enabled=1"
		ncnt=cur.execute(sql)
		vpnresult=cur.fetchall()

		for vpninfo in vpnresult:
			r.hset(VPN_ACTIVE_IP_TO_ID_DIC,vpninfo[0],vpninfo[1])	# vpn_active_ip_to_id

		
	except Exception,e:
		print ("exception init_vpn_info:" + str(e))


# init dic vpn_x_ava_rtt,dic vpn_x_detect_activeid
def init_vpn_detect_info(conn,cur,r):
	try:
		sql="select nodeid from vpn_node_tbl order by nodeid"
		ncnt1=cur.execute(sql)
		idresult=cur.fetchall()

		sql="select distinct(gameid) from game_region_tbl order by gameid"
		ncnt2=cur.execute(sql)
		gameidresult=cur.fetchall()

		for vpnid in idresult:
			vpn_ava_rtt_key="vpn_"+str(vpnid[0])+"_ava_rtt"
			vpn_detect_active_id_key="vpn_"+str(vpnid[0])+"_detect_activeid"

			for gameid in gameidresult:
				field="game_"+str(gameid[0])+"_region_0_rtt"
				r.hset(vpn_ava_rtt_key,field,0)			# set ava rtt region 0, vpn_x_ava_rtt

				sql="select regionid from game_region_tbl where gameid=" + str(gameid[0]) + " order by regionid"
				ncnt3=cur.execute(sql)
				regionresult=cur.fetchall()

				game_region_key="game_" + str(gameid[0]) + "_region"

				for regionid in regionresult:
					field="game_"+str(gameid[0])+"_region_" + str(regionid[0]) + "_rtt"
					r.hset(vpn_ava_rtt_key,field,0)		# set ava rtt region, vpn_x_ava_rtt

					field="game_" + str(gameid[0]) + "_region_" + str(regionid[0]) + "_rtt_cnt"
					r.hset(vpn_ava_rtt_key,field,0)		# vpn_x_ava_rtt

					field="game_"+str(gameid[0])+"_region_" + str(regionid[0]) + "_activeid"
					r.hset(vpn_detect_active_id_key,field,-1)	# set active id, vpn_x_detect_activeid

	except Exception,e:
		print ("exception in init_vpn_detect_info:" + str(e))




# init set game_y_region,set active_game_id
# set: active_game_id: active game id in game_name_tbl value: gameid
# set: game_y_region: game regionid set  value: regionid
# dic: game_y_iplst: game y static ip list  field: region_z_iplst value: string all ip list
# dic: game_y_iplst_activeid: game y region z ip list acitve id  field: region_z_iplst_activeid,value:-1,0,1

def init_game_region_iplst(conn,cur,r):
	try:
		init_iplst_activeid=0		

		sql="select game_id,admin_enable from game_name_tbl order by game_id"
		ncnt1=cur.execute(sql)
		gameidresult=cur.fetchall()

		for gameid in gameidresult:
			print("init game "+str(gameid[0]))

			ngameid=int(gameid[0])
				
			if int(gameid[1])==1:
				r.sadd(ACTIVE_GAMEID_SET,ngameid)	# active_game_id

			sql="select regionid from game_region_tbl where gameid=" + str(ngameid)
			ncnt2=cur.execute(sql)
			regionresult=cur.fetchall()

			game_region_key="game_"+str(ngameid)+"_region"
			game_iplst_key="game_"+str(ngameid)+"_iplst"
			game_iplst_activeid_key="game_"+str(ngameid)+"_iplst_activeid"

			region0_iplststr=''

		
			for regionid in regionresult:
				nregionid=int(regionid[0])
				r.sadd(game_region_key,nregionid)	# game_y_region

				sql="select gameip,gamemask,gameport from game_server_tbl where gameid=" + str(ngameid) + " and gameregionid=" + str(nregionid)
				ncnt3=cur.execute(sql)
				iplstresult=cur.fetchall()
				
				iplstinfo=[]

				for ipinfo in iplstresult:
					ipstr=ipinfo[0]+":"+str(ipinfo[2])+"/"+str(ipinfo[1])
					iplstinfo.append(ipstr)

				iplststr=','.join(iplstinfo)
				
				game_iplst_key_field="region_"+str(nregionid)+"_iplst_"+str(init_iplst_activeid)
				r.hset(game_iplst_key,game_iplst_key_field,iplststr)	# game_y_iplst

				game_iplst_activeid_key_field="region_"+str(nregionid)+"_activeid"
				r.hset(game_iplst_activeid_key,game_iplst_activeid_key_field,init_iplst_activeid)   # game_y_iplst_activeid

				region0_iplststr=region0_iplststr+iplststr+","

			region0_iplststr=region0_iplststr.strip(',')
			game_iplst_key_field="region_0_iplst_"+str(init_iplst_activeid)
			r.hset(game_iplst_key,game_iplst_key_field,region0_iplststr)	# game_y_iplst

			game_iplst_activeid_key_field="region_0_activeid"
			r.hset(game_iplst_activeid_key,game_iplst_activeid_key_field,init_iplst_activeid)	# game_y_iplst_activeid

					
	except Exception,e:
		print("exception in init_game_region_iplst:" + str(e))
		
	
# init hash SPEC_USER_TO_SPEC_VPNIP
def init_redis_options(r):
    global GAME_REDIS_OPTIONS
    try:
        redis_enable = "redis_enable"
        r.hset(GAME_REDIS_OPTIONS,redis_enable,0)
    except Exception, e:
        print("exception init_redis_options: " + str(e))

# init hash SPEC_USER_TO_SPEC_VPNIP
def init_spec_user_to_spec_vpnip(r):
    try:
        conn=MySQLdb.connect(host='localhost', port=3306, user='root', passwd='root', db='game1',charset="utf8")
        cur=conn.cursor()

        sql = "select username, vpnip from game_spec_user_vpn_tbl;"
        ncnt = cur.execute(sql)
        user_vpn_result = cur.fetchall()

        for user_vpn_info in user_vpn_result:
            r.hset(SPEC_USER_TO_SPEC_VPNIP,user_vpn_info[0],user_vpn_info[1])

        cur.close()
        conn.close()
	
    except Exception, e:
        print("exception init_spec_user_to_spec_vpnip: " + str(e))


def deleteallkeys(r):
	try:
		r.flushdb()

	except Exception,e:
		print("exception in deleteallkey:" + str(e))

if __name__ == '__main__':
    try:
		conn=MySQLdb.connect(host='localhost', port=3306, user='root', passwd='root', db='game2',charset="utf8")
		cur=conn.cursor()
        
		r = redis.StrictRedis(host='127.0.0.1', port=6379, db=0,password='cc_chinacache',encoding='utf-8')
		
		deleteallkeys(r)
        print("init redis switch ...")
        init_redis_options(r)
        print("init spec_user_to_spec_vpnip ...")
        init_spec_user_to_spec_vpnip(r)

		print("init_vpn_info")
		init_vpn_info(conn,cur,r)
		print("init_vpn_detect_info")
		init_vpn_detect_info(conn,cur,r)
		init_game_region_iplst(conn,cur,r)
		print("done.")
       
    except Exception,e:
        print("exception in main:"+str(e))
