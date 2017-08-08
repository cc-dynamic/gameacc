#coding:utf-8
import sys
reload(sys)
sys.setdefaultencoding('utf-8')

import getopt
import os
import subprocess
import multiprocessing
import time
import urllib2
import json
from log import loginf, logerr, trace_err, PROCESS_PATH
import copy

VERSION='0.1.0'
local_config = {                                                           \
                "detecturl":"http://games.nubesi.com/vpn/detectgame",     \
                #"detecturl":"http://223.202.197.12/vpn/detectgame",       \
		"sleepinterval":28800,                                    \
		#"sleepinterval":1800,                                      \
		"concurrentnum":40,                                        \
		#"concurrentnum":4,                                        \
		"reporturl":"http://223.202.197.12:8181/"                 \
		#"reporturl":"http://127.0.0.1:8181/"                      \
               }
                
if (hasattr(os, "devnull")):
    NULL_DEVICE = os.devnull
else:
    NULL_DEVICE = "/dev/null"
    
p_need_exit = 0;

#存储本机vpn节点的相关信息
local_vpn_info = {}
#存储所有vpn节点的信息
vpnnodes_dict = {}
#存储所有ip的探测数据
ip_detect_data = {}

enable_cc_iplst = []

VPNID = -1    # id of this vpn node
GAMELST = []

AVA_INF = 99999
LOSS_INF = 100

def _redirectFileDescriptors():
    import resource  # POSIX resource information
    maxfd = resource.getrlimit(resource.RLIMIT_NOFILE)[1]
    if maxfd == resource.RLIM_INFINITY:
        maxfd = 1024

    for fd in range(0, maxfd):
        try:
            os.ttyname(fd)
        except:
            continue
        try:
            os.close(fd)
        except OSError:
            pass

    os.open(NULL_DEVICE, os.O_RDWR)
    os.dup2(0, 1)
    os.dup2(0, 2)

def python_daemon():
    ''' 后台运行 '''
    if os.name != 'posix':
        trace_err('Daemon is only supported on Posix-compliant systems.')
        return

    try:
        if(os.fork() > 0):
            os._exit(0)
    except OSError, e:
        trace_err("fork failed ...");
        os._exit(1)

    os.chdir('/');
    os.setsid();
    os.umask(0);

    try:
        if(os.fork() > 0):
            os._exit(0)
        _redirectFileDescriptors()
    except OSError, e:
        trace_err("fork failed ...")
        os._exit(1)

def getgamelst():
    '''
    获取所有游戏的游戏id,区域id 
    数据格式：
    {
      "time":1497262241,
      "code":0,
      "data":
            {
             "gamelist":[{"regionlist":"1","gameid":318},{"regionlist":"1","gameid":218},...]
            }
    }
    '''
    global GAMELST
    cmd = {
        'cmdid':2,
        'version':"0.1",
        'time':int(time.time())
    }
    
    headers = {'Content-Type': 'application/json'}
    loginf("get gameid and regionidlst of all game...")
    try:    
        request = urllib2.Request(local_config['detecturl'],headers=headers,data=json.dumps(cmd))
        response = urllib2.urlopen(request)
        ret = response.read()
        retval = json.loads(ret)

        if retval['code'] != 0:
            trace_err("getgamelst return with code " + str(retval['code']))
            return ret

        GAMELST = retval['data']['gamelist']
        loginf("info of gameid and regionidlst as follows:\n%s" % str(GAMELST))
        return            
    except Exception,e:
        trace_err("getgamelst excption:" + str(e))
        return         

def getregioncfg(gameid, regionid):
    '''
    返回对应游戏id和该游戏对应区域下的游戏列表
    返回数据格式:
    {
       "time":1497264428,
       "code":0,
       "data":
              {
                  "detectregionlst":[{"regionid":1,"iplist":"114.112.66.93\/443\/32,42.236.74.236\/82\/32,47.91.138.64\/6064\/32,140.207.219.164"}]
              }
    }
    '''
    cmd = {
            'cmdid':1,
            'version':"0.1",
            'time':int(time.time())
    }

    headers = {'Content-Type': 'application/json'}

    cmdparm = {}
    cmdparm['gameid'] = gameid
    cmdparm['regionid'] = regionid
    
    cmd['data'] = cmdparm
    
    try:    
        request = urllib2.Request(local_config['detecturl'],headers=headers,data=json.dumps(cmd))
        response = urllib2.urlopen(request)
        ret = response.read()
        retval = json.loads(ret)
        if retval['code'] != 0:
            trace_err("getregioncfg return with code " + str(retval['code']))
            return []
        
        regioncfglst = retval['data']['detectregionlst']
        return regioncfglst
        
    except Exception,e:
        trace_err("getregioncfg excption:" + str(e))
        return []

def filterloss(lineinfo):
    try:
        loss = LOSS_INF
        nr = lineinfo.find('% packet loss')
        if nr > 0:
            tmpstr = lineinfo[0:nr]
            nl = tmpstr.rfind(',')
            if nl > 0:
                tmpstr=lineinfo[nl+1:nr]
                loss=int(tmpstr)
        return loss	
    except Exception, e:
        trace_err("Exception in filterloss: %s" % str(e))	
        return loss	

def filterava(lineinfo):
    try:
        ava = AVA_INF
        n = lineinfo.find('=')
        if n > 0:
            tmpstr = lineinfo[n+1:]
            tmp2 = tmpstr.split('/')
	    ava1 = float(tmp2[1])
        ava = int(ava1)
        return ava
    except Exception, e:
        trace_err("Exception in filterava: %s" % str(e))	
        return ava

def get_ping_ava_loss(cmd, flag = True):
    try:
        ava = AVA_INF
        loss = LOSS_INF
        #loginf(cmd)
        
        sub_p = subprocess.Popen(cmd,shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        cstdout = sub_p.stdout
        cstderr = sub_p.stderr

        while True:
            lineinfo = cstdout.readline()
            if lineinfo:
                n = lineinfo.find('% packet loss')
                if n > 0:
                    loss = filterloss(lineinfo)
                    continue
                if flag:
                    n = lineinfo.find('min/avg/max/mdev')  #ping
                else:
                    n = lineinfo.find('min/avg/max')  #hping
                if n > 0:
                    ava = filterava(lineinfo)
             
                if ava != AVA_INF and loss != LOSS_INF:
                    break
            else:
                break
        loginf("cmd = %s\ncmd ressult( delay: %f\tloss: %d)" % (str(cmd), ava, loss))
        return ava, loss

    except Exception, e:
        trace_err("Exception in get_ping_ava_loss: %s" % str(e))
        return ava, loss

def dopingdetect(cfglst):
    '''探测进程获取数据'''
    global local_vpn_info
    global ip_detect_data
    try:
        ava = AVA_INF
        loss = LOSS_INF

        #如果ip已经探测过，直接从ip_detect_data获取数据
        if cfglst[0] in ip_detect_data:
            ava = ip_detect_data[cfglst[0]].split('/')[3]
            loss = ip_detect_data[cfglst[0]].split('/')[4]
            loginf("对游戏源ip: %s 的探测已完成, 直接复用已经得到的探测数据..." % cfglst[0])
            return ava, loss

        #网络接口为单接口
        #if len(local_vpn_info["multi_detect_iplst"]) == 1:
        if len(local_vpn_info["multi_detect_iplst"]) >= 1:
            cmd = "ping -c 5 -W 2 " + cfglst[0] #cfglst的格式: ip/port/mask
            ava, loss = get_ping_ava_loss(cmd)
            return ava, loss

        #网络接口为多接口
        #elif len(local_vpn_info["multi_detect_iplst"]) > 1:
        elif False:
            min_ava = AVA_INF
            min_loss = LOSS_INF
            min_index = -1
            for index in range(len(local_vpn_info["multi_detect_iplst"])):
                cmd = "ping -c 5 -I %s -W 2 %s" %  (local_vpn_info["multi_detect_iplst"][index], cfglst[0]) #cfglst的格式: ip/port/mask        
                ava, loss = get_ping_ava_loss(cmd)
                if loss == 0 and ava < min_ava:
                    min_ava = ava
                    min_loss = loss
                    min_index = index
            #设置本机路由
            if min_index >= 0:
                dev_interface = local_vpn_info["multi_detect_ifacelst"][min_index]
                os.system("route add -net %s netmask 255.255.255.255 dev %s" % (cfglst[0], dev_interface))
                loginf("route add -net %s netmask 255.255.255.255 dev %s" % (cfglst[0], dev_interface))
            return min_ava, min_loss
        else:
            trace_err("vpnip_lst is null...")
            return ava, loss

    except Exception, e:
        trace_err("read ping cmd out exception: %s" % str(e))
        return ava, loss

def dohpingdetect(cfglst):
    global local_vpn_info
    global ip_detect_data
    try:
        ava = AVA_INF
        loss = LOSS_INF

        #如果ip已经探测过，直接从ip_detect_data获取数据
        if cfglst[0] in ip_detect_data:
            ava = ip_detect_data[cfglst[0]].split('/')[3]
            loss = ip_detect_data[cfglst[0]].split('/')[4]
            loginf("对游戏源ip: %s 的探测已完成, 直接复用已经得到的探测数据..." % cfglst[0])
            return ava, loss

        #网络接口为单接口
        #if len(local_vpn_info["multi_detect_ifacelst"]) == 1:
        if len(local_vpn_info["multi_detect_ifacelst"]):
            cmd = "hping3 -c 5 -S -p " + cfglst[1] +" " + cfglst[0] #cfglst的格式: ip/port/mask
            ava, loss = get_ping_ava_loss(cmd, False)
            return ava, loss

        #网络接口为多接口
        #elif len(local_vpn_info["multi_detect_ifacelst"]) > 1:
        elif False:
            min_ava = AVA_INF
            min_loss = LOSS_INF
            min_index = -1
            for index in range(len(local_vpn_info["multi_detect_ifacelst"])):
                cmd = "hping3 -c 5 -I %s -S -p %s %s" % (local_vpn_info["multi_detect_ifacelst"][index], cfglst[1], cfglst[0]) #cfglst的格式: ip/port/mask
                ava, loss = get_ping_ava_loss(cmd, False)
                if loss == 0 and ava < min_ava:
                    min_ava = ava
                    min_loss = loss
                    min_index = index
            #设置本机路由
            if min_index >= 0:
                dev_interface = local_vpn_info["multi_detect_ifacelst"][min_index]
                os.system("route add -net %s netmask 255.255.255.255 dev %s" % (cfglst[0], dev_interface))
                loginf("route add -net %s netmask 255.255.255.255 dev %s" % (cfglst[0], dev_interface))
            return min_ava, min_loss
        else:
            trace_err("vpninterface_lst is null...")
            return ava, loss
    except Exception,e:
        trace_err("read hping3 cmd out exception:" + str(e))
        return ava,loss

def dodetect(ipstr, queue):
    try:
        temp_ip_delay = {}

        tmplst = ipstr.split('/')
        if len(tmplst) != 3:
            trace_err("invalid ipstr:" + ipstr)
            ipstr = ipstr + "/" + str(AVA_INF) + "/" + str(AVA_LOSS)
            temp_ip_delay[tmplst[0]] = ipstr
            queue.put(temp_ip_delay)
            return
    
        ava, loss = dopingdetect(tmplst)
        if ava == AVA_INF and loss == LOSS_INF:
            ava, loss = dohpingdetect(tmplst)

        ipstr = ipstr + "/" + str(ava) + "/" + str(loss)
        temp_ip_delay[tmplst[0]] = ipstr
        queue.put(temp_ip_delay)
        return

    except Exception, e:
        trace_err("Exception in dodetect: %s" % str(e))

def getdetectvalue(gameid, regionid, regioncfg):
    try:
        pool = multiprocessing.Pool(processes=local_config["concurrentnum"])
        q = multiprocessing.Manager().Queue()
    
        iplst = regioncfg['iplist'].split(',')
    
        for ipstr in iplst:
            pool.apply_async(dodetect, (ipstr,q,))
    
        pool.close()
        pool.join()

        resultdict = {}

        while not q.empty():
            detectdata_dict = q.get()
            resultdict.update(detectdata_dict)
    
        loginf("gameid: %d  regionid: %d, 本次探测字典长度为: %d, 探测结果如下:\n%s" % (gameid, int(regionid), len(resultdict), str(resultdict)))
        return resultdict
    except Exception, e:
        trace_err("Exception in getdetectvalue: %s" % str(e))
        return {}

def regionreport(gameid, regionid, resultdict):
    body = {}
    body['vpnid'] = VPNID
    body['gameid'] = gameid
    body['regionid'] = regionid
    resultlist = resultdict.values()
    detectdatastr = ','.join(resultlist)
    body['detectdata'] = detectdatastr
    
    headers={'Content-Type': 'application/json'}
    
    global enable_cc_iplst
    try:    
        for ip in enable_cc_iplst:
            url = "http://%s:8181/" % ip
            try:
                request = urllib2.Request(url,headers=headers,data=json.dumps(body))
                response = urllib2.urlopen(request)
                loginf("report to %s success..." % ip)
            except Exception, e:
                loginf("report to %s failed..." % ip)
                trace_err("report data failed...")
            #time.sleep(60)
        return True
        
    except Exception,e:
        trace_err("regionreport excption:" + str(e))
        return False

def detectregion(gameid, regionid):
    try:
        ret_region_detect_data = {}
        #获取对应游戏和该游戏对应区域下的游戏列表
        regioncfglst = getregioncfg(gameid, regionid)
        if regioncfglst:
            regioncfg = regioncfglst[0]
        else:
            trace_err("获取对应游戏区域下的游戏ip列表失败...")
            return {}
        #获取gameid, regionid对应游戏ip列表的探测值
        resultdict = getdetectvalue(gameid, regionid, regioncfg)
        if resultdict:
            ret_region_detect_data = copy.deepcopy(resultdict)
        else:
            trace_err("gameid: %d  regionid: %s 本轮游戏ip的探测数据为空...数据不上报" % (gameidd, regionid))
            return {}
        #上报对应游戏和该游戏对应区域的探测数据
        if regionreport(gameid, regionid, resultdict):
            return ret_region_detect_data
        else:
            return {}
    except Exception, e:
        trace_err("Exception in detectregion: %s" % str(e))
        return {}
    
def detectgamelst():
    '''以游戏id和区域id对ip进行探测'''
    global ip_detect_data
    try:
        ip_detect_data = {}
        for gameitem in GAMELST:
            gameid = gameitem['gameid']
            regionidstr = gameitem['regionlist']
            regionidlst = regionidstr.split(',')
        
            #测试gameid为 327,355,145等游戏
            #if gameid != 327 and gameid != 355 and gameid != 145:
            #if gameid != 277 and gameid != 366 and gameid != 386:
            #    continue

            loginf("in detectgamelst,  gameid: %d, regionidlst: %s" % (gameid, str(regionidlst)))

            #以region为单位上报探测数据,即某款游戏的某区域所有ip探测完成，上报该区域的探测数据
            for regionid in regionidlst:
               temp_detect_data_dict = {}
               temp_detect_data_dict = detectregion(gameid, regionid)
               if temp_detect_data_dict:
                   ip_detect_data.update(temp_detect_data_dict)
        
                   loginf("success !!! report for game " + str(gameid) + ",region "+str(regionid))
               else:
                   trace_err("failed !!! report for game " + str(gameid) + ",region "+str(regionid))
            loginf("本轮对所有游戏探测,当前获取探测数据的总长度为: %d, 内容如下:\n%s" % (len(ip_detect_data), str(ip_detect_data)))
    except Exception, e:
        trace_err("Exception in detectgamelst: %s" % str(e))
            
def sys_command(cmd):
    f = os.popen(cmd)
    return f.read()        

def get_eth_ips():
    """获取vpn节点的ip"""
    try:
        iplist = []
        ips_string = sys_command("ip addr | grep 'inet ' | grep -v 'ppp'").strip("\r\n")
        ips_list = ips_string.split("\n")
        for line in ips_list:
            line = line.strip(" \r\n")
            ip_mask = line.split(" ")[1]
            ip = ip_mask.split('/')[0]
            iplist.append(ip)

        return iplist
    except Exception,e:
        trace_err("exception in get_eth_ips: %s" % str(e))
        return []

def get_vpnid():
    '''1) 获取vpn的相关信息，
       2) 处理vpn信息
       3) 确定vpn节点的id'''
    global vpnnodes_dict
    try:
        cmd = {
                'cmdid':3,
                'version':"0.1",
                'time':int(time.time())
        }

        headers = {'Content-Type': 'application/json'}
        cmdparm = {}
        cmd['data'] = cmdparm

        vpnnodes_infolst = []
        #存储所有vpn节点的信息
        vpnnodes_dict = {}

        try:    
            request = urllib2.Request(local_config['detecturl'],headers=headers,data=json.dumps(cmd))
            response = urllib2.urlopen(request)
            ret = response.read()
            retval = json.loads(ret)

            if retval['code'] != 0:
                trace_err("getvpninfo list return with code " + str(retval['code']))
                return -1
        
            '''
            retval['data']['vpn_node_lst']的数据格式：
            [
                {"nodestatus":0, "multi_detect_iplst":"1.2.3.4", "vpnid":1, "nodename":"CHN-BGP-SH-3g1", "enabled":1, "multi_detect_ifacelst":"eth1,eth2,eth3"},
                {"nodestatus":0, "multi_detect_iplst":"1.2.3.4", "vpnid":1, "nodename":"CHN-BGP-SH-3g1", "enabled":1, "multi_detect_ifacelst":"eth1,eth2,eth3"},
            ]
            '''
            vpnnodes_infolst = retval['data']['vpn_node_lst']
        
        except Exception,e:
            trace_err("getvpninfo list excption:" + str(e))
            return -1

        if vpnnodes_infolst:
            for vpnnode_dict in vpnnodes_infolst:
                vpnid = vpnnode_dict["vpnid"]
                vpnnodes_dict[vpnid] = {}
                vpnnodes_dict[vpnid]["nodestatus"] = vpnnode_dict["nodestatus"]
                vpnnodes_dict[vpnid]["nodename"] = vpnnode_dict["nodename"]
                vpnnodes_dict[vpnid]["enabled"] = vpnnode_dict["enabled"]

                multi_ipiflst = []
                tmpiplst = vpnnode_dict["multi_detect_iplst"].strip().split(',')
                for iplst in tmpiplst:
                    multi_ipiflst.append(iplst)
                vpnnodes_dict[vpnid]["multi_detect_iplst"] = multi_ipiflst

                multi_ipiflst = []
                tmpiplst = vpnnode_dict["multi_detect_ifacelst"].strip().split(',')
                for iplst in tmpiplst:
                    multi_ipiflst.append(iplst)
                vpnnodes_dict[vpnid]["multi_detect_ifacelst"] = multi_ipiflst
                
        else:
            trace_err("returned vpn info is null ...")
            return -1

        if vpnnodes_dict:
            vpn_local_iplist = get_eth_ips()
            if vpn_local_iplist:
                for ip in vpn_local_iplist:
                    for key, nodedict in vpnnodes_dict.iteritems():
                        if ip in nodedict["multi_detect_iplst"] and nodedict["enabled"]:
                            return key
            else:
                trace_err("local ip list is null")
                return -1
        else:
            trace_err("after process vpn node info, vpnnodes_dict is null")
            return -1   

        return -1
    except Exception, e:
        trace_err("Exception in get_vpnid: %s" % str(e))
        return -1

def getcclst():
    global enable_cc_iplst
    try:
        cmd = {
                'cmdid':4,
                'version':"0.1",
                'time':int(time.time())
        }

        headers = {'Content-Type': 'application/json'}
        cmdparm = {}
        cmd['data'] = cmdparm

        try:    
            request = urllib2.Request(local_config['detecturl'],headers=headers,data=json.dumps(cmd))
            response = urllib2.urlopen(request)
            ret = response.read()
            retval = json.loads(ret)

            if retval['code'] != 0:
                trace_err("getccinfo list return with code " + str(retval['code']))
                return -1
        
            '''
            retval['data']['cc_node_lst']的数据格式：
            [
              {"nodename":"BGP-SM-1-3f7","enabled":1,"nodeip":"223.202.197.12"},
              {"nodename":"BGP-SM-g-3gk","enabled":1,"nodeip":"223.202.204.196"},
              {"nodename":"BGP-SM-g-3gl","enabled":1,"nodeip":"223.202.204.197"},
              {"nodename":"BGP-SH-9-3g4","enabled":1,"nodeip":"163.53.95.199"}
            ]
            '''
            enable_cc_iplst = []
            ccnodes_infolst = retval['data']['cc_node_lst']
            if ccnodes_infolst:
                for item in ccnodes_infolst:
                    if item["enabled"] == 1:
                        enable_cc_iplst.append(item["nodeip"])
            return 0
        except Exception,e:
            trace_err("getccinfo list excption:" + str(e))
            return -1
    except Exception, e:
        trace_err("Exception in getcclst: %s" % str(e))
        return 0

if __name__ == '__main__':
    try:
        opts,args = getopt.getopt(sys.argv[1:],"vdq")
    except getopt.GetoptError:
        print "illegal option(s) -- " + str(sys.argv[1:])
	sys.exit(0);

    for name, value in opts:
        if name == "-v":
            print VERSION
            sys.exit(0);
        if name == "-d":
            DEBUG = 1
        if name == "-q":
            QUIET = 1
   
    python_daemon()
    VPNID = get_vpnid()
    loginf("该vpn节点的id为: %d" % VPNID)

    if VPNID <= 0:
        trace_err("vpn id invalid,exit...")
        sys.exit(2)    
    else:
        #将多接口的设备ip和接口名整理成list的形式
        local_vpn_info["vpnid"] = VPNID
        local_vpn_info["nodestatus"] = vpnnodes_dict[VPNID]["nodestatus"]
        local_vpn_info["nodename"] = vpnnodes_dict[VPNID]["nodename"]
        local_vpn_info["enabled"] = vpnnodes_dict[VPNID]["enabled"]
        local_vpn_info["multi_detect_iplst"] = vpnnodes_dict[VPNID]["multi_detect_iplst"]
        local_vpn_info["multi_detect_ifacelst"] = vpnnodes_dict[VPNID]["multi_detect_ifacelst"]
        loginf("本VPN节点信息如下:\n%s" % str(local_vpn_info))

    while True:
        if(p_need_exit):
            trace_err("detectagent exit ... ...")
            time.sleep(1)
            sys.exit(0)
        
        ret = getcclst()
        if ret < 0:
            loginf("获取cc服务器ip列表失败...")
        else:
            loginf("cc服务器的ip列表为: %s" % str(enable_cc_iplst))

        getgamelst()
        detectgamelst()    
        time.sleep(local_config['sleepinterval'])
