#!/usr/bin/env python
# -*- coding=utf-8 -*-
"""
日志

Author: Zhang Xu <xu.zhang@chinacache.com>
"""
import os
import sys
reload(sys)
sys.setdefaultencoding('utf-8')
import time
import shutil
import logging
import datetime
import threading
import traceback

PROCESS_PATH = "/root/detectagent/"

__all__ = ['loginf', 'logwarn', 'logerr', 'logfatal', 'trace_err']

LOG_PATH = PROCESS_PATH + "log"

def log_handle(log_type):
    '''
    获取logging handle
    @params log_type: 日志类型，字符串类型，可选项：'info', 'error'。
    '''
    global LOG_PATH
    logpath = LOG_PATH
    if not os.path.isdir(logpath):
        os.system('rm -rf %s' % logpath)
        os.makedirs(logpath, 0775)
    log_name, path, level, template = {
        'info': (
            'INF', logpath + '/out', logging.INFO,
            '%(asctime)s %(levelname)7s : %(message)s'
        ),
        'error': (
            'ERR', logpath + '/err', logging.WARNING,
            '%(asctime)s %(levelname)8s by %(module)s.%(funcName)s in line %(lineno)d [%(threadName)s] -> %(message)s'
        )
    }[log_type]

    _log = logging.getLogger(log_name)
    hdlr = logging.FileHandler(path)
    formatter = logging.Formatter(template)
    hdlr.setFormatter(formatter)
    _log.addHandler(hdlr)
    _log.setLevel(level)
    return _log


_inf_hdlr = log_handle('info')
_err_hdlr = log_handle('error')

loginf = _inf_hdlr.info
logwarn = _err_hdlr.warning  # 警告
logerr = _err_hdlr.error     # 错误
logfatal = _err_hdlr.fatal   # 致命错误

def trace_err(ext_msg=None):
    '''
    将捕获到的异常信息输出到错误日志(*最好每个 except 后面都加上此函数*)

    直接放到 expect 下即可，E.G.：
        try:
            raise
        except Exception, e:
            output_err()

    @params ext_msg: 补充的异常信息
    '''
    msg = u'' if ext_msg is None else ext_msg
    msg += u'\n------------------- Local Args -------------------\n'
    for k, v in sys._getframe(1).f_locals.iteritems():
        msg += (u' >>> ' + str(k) + u': ' + str(v) + u'\n')
    msg += u'--------------------- Error ----------------------\n'
    exc_info = traceback.format_exception(*sys.exc_info())  # 取出格式化的异常信息
    msg = u"%s %s"%(msg, ''.join(exc_info))
    msg += u'---------------------- End -----------------------\n'
    logfatal(msg)
