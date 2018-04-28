#!/usr/bin/env python
# ! -*- coding: utf-8 -*-
# @Time    :2018/01/22 15:31
# @Author  :Jason cao
# @File    :scard.py

import pyautogui
import os
import sys
import time
import subprocess
import logging
import logging.handlers
import ConfigParser


logger = ""


citrix_receiver_desktops_x = 1025
citrix_receiver_desktops_y =92

vda_pin_center_x = 781
vda_pin_center_y = 502

vda_pin_passwd_x = 924
vda_pin_passwd_y = 485

vda_pin_ok_button_x = 860
vda_pin_ok_button_y = 555

proc_wait_time = 30
opt_wait_time  = 5


def launch_session(resourcetype, app_name, ddc_url, VDA_name, PIN_passwd):

	global citrix_receiver_desktops_x, citrix_receiver_desktops_y
	global vda_pin_center_x, vda_pin_center_y
	global vda_pin_passwd_x, vda_pin_passwd_y
	global vda_pin_ok_button_x, vda_pin_ok_button_y
	global proc_wait_time, opt_wait_time
	
	logger.info("")
	logger.info("[launch_session]:")
	logger.info("********************************************************************************************")
	logger.info('citrix_receiver_desktops_x  : %d' % (citrix_receiver_desktops_x))
	logger.info('citrix_receiver_desktops_y  : %d' % (citrix_receiver_desktops_y))
	logger.info('vda_pin_center_x            : %d' % (vda_pin_center_x))
	logger.info('vda_pin_center_y            : %d' % (vda_pin_center_y))
	logger.info('vda_pin_passwd_x            : %d' % (vda_pin_passwd_x))
	logger.info('vda_pin_passwd_y            : %d' % (vda_pin_passwd_y))
	logger.info('vda_pin_ok_button_x         : %d' % (vda_pin_ok_button_x))
	logger.info('vda_pin_ok_button_y         : %d' % (vda_pin_ok_button_y))
	logger.info("")
	
	logger.info('proc_wait_time : %d' % (proc_wait_time))
	logger.info('opt_wait_time  : %d' % (opt_wait_time))
	logger.info("********************************************************************************************")
	logger.info("")
	
	#os.chdir('D:\\Tools\smartcard')
	status = 0
	
	logger.info('Resource type is [%s] and app name is [%s].' % (resourcetype, app_name))  
	logger.info('@@@@@@@@@@@@@@@ start ...')  
	try:
		#o = subprocess.check_output("start iexplore.exe https://sf.zhusl.com/Citrix/storeWeb/", shell=True)
		check_cmd = "start iexplore.exe " + ddc_url
		o = subprocess.check_output(check_cmd, shell=True)
		
		logger.info('call iexplore [%s]' % (o))  
		
	except Exception as e:
		#print "Can not start citrix receiver due to %s." % (e)
		logger.info('Can not start citrix receiver due to [%s]' % (e))  
		return 2
	
	logger.info("")
	
	time.sleep(5)
	
	win = None
	for i in range(0, 61):
		win = pyautogui.getWindow('Windows Security')
		
		logger.info('getWindow result is [%s]' % (win))
		
		if win == None:
			#print "cannot find Windows Security dialog"
			logger.info('can not find Windows Security dialog.')
			time.sleep(1)
			continue
		elif win != None:
			#print "Find Windows Security dialog"
			logger.info('Find Windows Security dialog.')
			break
			
	if ( win == None ):
		#print "Can not find PIN password dialog."
		logger.info('Can not find PIN password dialog.')
		return 4
		
	win.set_foreground()
	time.sleep(1)
	#pyautogui.typewrite('000000')
	pyautogui.typewrite(PIN_passwd)
	time.sleep(1)
	pyautogui.press('enter')
	
	logger.info("")
	
	logger.info('PIN password input success, start sleep...')
	time.sleep(10)
	logger.info('PIN password input success, sleep end.')
	
	win = None
	for i in range(0, 10):
		win = pyautogui.getWindow('Windows Security')
		
		logger.info('Check PIN password whether is correct ? [%s]' % (win))
		
		if win == None:
			#print "cannot find Windows Security dialog"
			logger.info('PIN password is correct.')
			time.sleep(1)
			continue
		elif win != None:
			os.system("taskkill /F /IM iexplorer.exe")
			time.sleep(1)
			logger.info('PIN password is not correct.')
			return 1001
	
	logger.info("")
	
	d1,h1=pyautogui.position()
	logger.info('current mouse w-d is [%d - %d].' % (d1, h1))
	
	#print resourcetype
	resourcex = citrix_receiver_desktops_x
	resourcey = citrix_receiver_desktops_y
	logger.info('resourcetype is [%s] and x-y is [%d - %d].' % (resourcetype, resourcex, resourcey))
	
	pyautogui.click(resourcex,resourcey)
	
	if resourcetype == 'desktop':
		logger.info('start screen search...')
		loc = pyautogui.locateOnScreen('desktops.png')
		logger.info('screen search result is [%s]' % (loc))
		if loc == None:
			#print "Can not find icon for desktops."
			logger.info('Can not find icon for desktops.')
			if resourcex != 0:
				#print "click desktop when fail to find desktop"
				logger.info('click desktop when fail to find desktop.')
				pyautogui.click(resourcex,resourcey)
				
				d2,h2=pyautogui.position()
				logger.info('click after, mouse w-d is [%d - %d].' % (d2, h2))
		else:
			x, y = pyautogui.center(loc)
			#print x, y
			logger.info('desktops x and y is [%d - %d].' %(x, Y))
			#print "click desktop"
			logger.info('click desktop.')
			pyautogui.click(x, y)
	elif resourcetype == 'apps':
		loc = pyautogui.locateOnScreen('apps.png')
		if loc == None:
			#print "Cannot find icon for apps."
			logger.info('Cannot find icon for apps.')
			if resourcex != 0:
				pyautogui.click(resourcex,resourcey)
		else:
			x, y = pyautogui.center(loc)
			#print x,y
			logger.info('apps x and y is [%d - %d].' %(x, Y))
			pyautogui.click(x, y)
	else:
		logger.info('Please enter desktop or apps as the resource type.')
		raise Exception("Please enter desktop or apps as the resource type.")
		
	logger.info('Change to Destops or favorites success, start sleep...')
	time.sleep(5)
	logger.info('Change to Destops or favorites success, sleep end.')
	
	# launch the app_name
	logger.info('type app name is [%s].' % (app_name))
	pyautogui.typewrite(app_name, interval=0.5)
	for i in range(2):
		logger.info('press tab.')
		pyautogui.press('tab')
		time.sleep(0.1)
	logger.info('press enter.')
	pyautogui.press('enter')
	time.sleep(10)
	
	logger.info("")
	
	if testType != 3:
		#print "set receiver to foreground"
		logger.info('set receiver to foreground.')
		#win.set_foreground()
		time.sleep(2)
		win = pyautogui.getWindow('Citrix Receiver')
		if win != None:
			logger.info('getWindow Citrix Receiver success.')
			win.set_foreground()
			time.sleep(1)
			pyautogui.keyDown('alt')
			pyautogui.press('f4')
			pyautogui.keyUp('alt')
	else:
		logger.info('Do not close IE, because of need testing reconnect.')
		
	time.sleep(proc_wait_time)
	
	logger.info("")
	
	ret = 2000
	win = None
	for i in range(0, 10):
		#win = pyautogui.getWindow('rh73demo - Desktop Viewer')
		win = pyautogui.getWindow(VDA_name)
		if win == None:
			#print "can not find desktop session"
			logger.info('can not find [%s] session.' % (VDA_name))
			ret += 1
			time.sleep(1)
			continue
		elif win != None:
			#print "find desktop session"
			logger.info('find desktop session.')
			
			win.set_foreground()
			
			time.sleep(5)
			
			logger.info('set foucus desktop session finished.')
			
			xn = vda_pin_center_x
			yn = vda_pin_center_y
			logger.info('center X-Y of  windows is [%d - %d].' %(int(xn), int(yn)))
			
			#pyautogui.click(xn,yn)
			
			d1,h1=pyautogui.position()
			logger.info('current mouse w-d is [%d - %d].' % (d1, h1))
		
			#d5,h5 = pyautogui.position()
			#logger.info('new mouse X-Y is [%d - %d].' %(d5, h5))
		
			time.sleep(0.1)
			
			#pyautogui.press('tab')
			logger.info('press tab keyboard change to PIN.')
			time.sleep(0.1)
			
			xn = vda_pin_passwd_x
			yn = vda_pin_passwd_y
			pyautogui.click(xn,yn)
			
			
			pyautogui.typewrite(PIN_passwd)
			logger.info('input PIN password.')
			time.sleep(0.1)
			
			xn = vda_pin_ok_button_x
			yn = vda_pin_ok_button_y
			pyautogui.click(xn,yn)
			
			#pyautogui.keyDown('tab')
			pyautogui.keyUp('tab')
			logger.info('press tab keyboard change to OK.')
			time.sleep(0.1)
			
			#pyautogui.press('enter')
			logger.info('press enter keyboard change to finish.')
			
			logger.info('current result is [%d].' % (ret))
			
			ret = 0
			
			time.sleep(proc_wait_time)
			
			logger.info("")
			
			return ret
	
	logger.info("")
	
	return 0
	
	
	

def reconnect_session(resourcetype, app_name, ddc_url, VDA_name, PIN_passwd):

	global citrix_receiver_desktops_x, citrix_receiver_desktops_y
	global vda_pin_center_x, vda_pin_center_y
	global vda_pin_passwd_x, vda_pin_passwd_y
	global vda_pin_ok_button_x, vda_pin_ok_button_y
	global proc_wait_time, opt_wait_time
	
	logger.info("")
	logger.info("[Reconnect_session]:")
	logger.info("********************************************************************************************")
	logger.info('citrix_receiver_desktops_x  : %d' % (citrix_receiver_desktops_x))
	logger.info('citrix_receiver_desktops_y  : %d' % (citrix_receiver_desktops_y))
	logger.info('vda_pin_center_x            : %d' % (vda_pin_center_x))
	logger.info('vda_pin_center_y            : %d' % (vda_pin_center_y))
	logger.info('vda_pin_passwd_x            : %d' % (vda_pin_passwd_x))
	logger.info('vda_pin_passwd_y            : %d' % (vda_pin_passwd_y))
	logger.info('vda_pin_ok_button_x         : %d' % (vda_pin_ok_button_x))
	logger.info('vda_pin_ok_button_y         : %d' % (vda_pin_ok_button_y))
	logger.info("")
	
	logger.info('proc_wait_time : %d' % (proc_wait_time))
	logger.info('opt_wait_time  : %d' % (opt_wait_time))
	logger.info("********************************************************************************************")
	logger.info("")
	
	
	status = 0
	
	logger.info('Resource type is [%s] and app_name is [%s].' % (resourcetype, app_name))  
	logger.info('##### reconnect start ...')  
	
	win = None
	win = pyautogui.getWindow('Citrix Receiver')
	if win != None:
		logger.info('getWindow Citrix Receiver success.')
		win.set_foreground()
	else:
		logger.info('getWindow Citrix Receiver failed.')
		return 5
	
	logger.info("")
	
	#print resourcetype
	resourcex=citrix_receiver_desktops_x
	resourcey=citrix_receiver_desktops_y
	logger.info('resourcetype is [%s] and x-y is [%d - %d].' % (resourcetype, resourcex, resourcey))
	
	pyautogui.click(resourcex,resourcey)
	
	if resourcetype == 'desktop':
		logger.info('start screen search...')
		loc = pyautogui.locateOnScreen('desktops.png')
		logger.info('screen search result is [%s]' % (loc))
		if loc == None:
			#print "Can not find icon for desktops."
			logger.info('Can not find icon for desktops.')
			if resourcex != 0:
				#print "click desktop when fail to find desktop"
				logger.info('click desktop when fail to find desktop.')
				pyautogui.click(resourcex,resourcey)
				
				d2,h2=pyautogui.position()
				logger.info('click after, mouse w-d is [%d - %d].' % (d2, h2))
		else:
			x, y = pyautogui.center(loc)
			#print x, y
			logger.info('desktops x and y is [%d - %d].' %(x, Y))
			#print "click desktop"
			logger.info('click desktop.')
			pyautogui.click(x, y)
	elif resourcetype == 'apps':
		loc = pyautogui.locateOnScreen('apps.png')
		if loc == None:
			#print "Cannot find icon for apps."
			logger.info('Cannot find icon for apps.')
			if resourcex != 0:
				pyautogui.click(resourcex,resourcey)
		else:
			x, y = pyautogui.center(loc)
			#print x,y
			logger.info('apps x and y is [%d - %d].' %(x, Y))
			pyautogui.click(x, y)
	else:
		logger.info('Please enter desktop or apps as the resource type.')
		raise Exception("Please enter desktop or apps as the resource type.")
		
	logger.info('Change to Destops or favorites success, start sleep...')
	time.sleep(5)
	logger.info('Change to Destops or favorites success, sleep end.')
	
	logger.info("")
	
	# launch the app_name
	logger.info('type app_name is [%s].' % (app_name))
	pyautogui.typewrite(app_name, interval=0.5)
	for i in range(2):
		#print "press tab"
		logger.info('press tab.')
		pyautogui.press('tab')
		time.sleep(0.1)
	#print "press enter"
	logger.info('press enter.')
	pyautogui.press('enter')
	time.sleep(10)
	
	logger.info("")
	
	win1 = None
	for i in range(0, 20):
		#win = pyautogui.getWindow('rh73demo - Desktop Viewer')
		win1 = pyautogui.getWindow(VDA_name)
		if win1 == None:
			#print "can not find desktop session"
			logger.info('Reconnect can not find [%s] session.' % (VDA_name))
			win2 = None
			win2 = pyautogui.getWindow('Cannot start destop')
			if win2 != None:
				win2.set_foreground()
				pyautogui.press('enter')
				logger.info("")
				logger.info("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
				logger.info("")
				
			#pyautogui.press('enter')
			time.sleep(0.1)
			win.set_foreground()
			pyautogui.click(resourcex,resourcey)
			pyautogui.typewrite(app_name, interval=0.5)
			for j in range(2):
				#print "press tab"
				logger.info('press tab.')
				pyautogui.press('tab')
				time.sleep(0.2)
			pyautogui.press('enter')
			time.sleep(5)
			continue
		elif win1 != None:
			break
	
	logger.info("")
	
	if win1 == None:
		logger.info('reconnet and re-open [%s] session linuxVDA is failed.' % (VDA_name))
		return 4
	
	logger.info("")
	
	#print "set receiver to foreground"
	logger.info('set receiver to foreground.')
	win.set_foreground()
	time.sleep(2)
	win = pyautogui.getWindow('Citrix Receiver')
	if win != None:
		logger.info('getWindow Citrix Receiver success.')
		win.set_foreground()
		time.sleep(1)
		pyautogui.keyDown('alt')
		pyautogui.press('f4')
		pyautogui.keyUp('alt')

	time.sleep(proc_wait_time)
	
	logger.info("")
	
	ret = 2000
	win = None
	for i in range(0, 10):
		#win = pyautogui.getWindow('rh73demo - Desktop Viewer')
		win = pyautogui.getWindow(VDA_name)
		if win == None:
			#print "can not find desktop session"
			logger.info('can not find [%s] session.' % (VDA_name))
			ret += 1
			time.sleep(1)
			continue
		elif win != None:
			#print "find desktop session"
			logger.info('find desktop session.')
			
			win.set_foreground()
			
			time.sleep(5)
			
			logger.info('set foucus desktop session finished.')
			
			xn = vda_pin_center_x
			yn = vda_pin_center_y
			logger.info('center X-Y of  windows is [%d - %d].' %(int(xn), int(yn)))
			
			time.sleep(0.1)
			
			#pyautogui.press('tab')
			logger.info('press tab keyboard change to PIN.')
			time.sleep(0.1)
			
			xn = vda_pin_passwd_x
			yn = vda_pin_passwd_y
			pyautogui.click(xn,yn)
			
			
			pyautogui.typewrite(PIN_passwd)
			logger.info('input PIN password.')
			time.sleep(0.1)
			
			xn = vda_pin_ok_button_x
			yn = vda_pin_ok_button_y
			pyautogui.click(xn,yn)
			
			#pyautogui.keyDown('tab')
			pyautogui.keyUp('tab')
			logger.info('press tab keyboard change to OK.')
			time.sleep(0.1)
			
			#pyautogui.press('enter')
			logger.info('press enter keyboard change to finish.')
			
			logger.info('current result is [%d].' % (ret))
			
			ret = 0
			
			logger.info("")
			
			return ret
	
	logger.info("")
	
	return 0
	
	
	
if __name__ == "__main__":
	
	res = -1
	
	resourcetype = ""
	
	confFile     = sys.argv[1]
	resourcetype = sys.argv[2]
	testType     = sys.argv[3]
	testExt      = sys.argv[4]
	
	testType = int(testType)
	testExt  = int(testExt)
	
	
	cf = ConfigParser.ConfigParser()

	cf.read(confFile)
	
	#read by type
	user_name        = cf.get("setting", "user_name")
	app_name         = cf.get("setting", "app_name")
	VDA_name         = cf.get("setting", "VDA_name")
	ddc_url          = cf.get("setting", "ddc_url")
	PIN_passwd       = cf.get("setting", "PIN_passwd")
	Incorrect_passwd = cf.get("setting", "Incorrect_passwd")
	
	citrix_receiver_desktops_x = cf.getint("cood", "citrix_receiver_desktops_x")
	citrix_receiver_desktops_y = cf.getint("cood", "citrix_receiver_desktops_y")
	vda_pin_center_x           = cf.getint("cood", "vda_pin_center_x")
	vda_pin_center_y           = cf.getint("cood", "vda_pin_center_y")
	vda_pin_passwd_x           = cf.getint("cood", "vda_pin_passwd_x")
	vda_pin_passwd_y           = cf.getint("cood", "vda_pin_passwd_y")
	vda_pin_ok_button_x        = cf.getint("cood", "vda_pin_ok_button_x")
	vda_pin_ok_button_y        = cf.getint("cood", "vda_pin_ok_button_y")
	
	proc_wait_time = cf.getint("times", "proc_wait_time")
	opt_wait_time  = cf.getint("times", "opt_wait_time")
	
	work_path   = cf.get("default", "work_path")
	ps_logfile  = cf.get("default", "ps_logfile")
	py_logfile  = cf.get("default", "py_logfile")

	
	#if os.path.exists(py_logfile):
	#    os.remove(py_logfile)
	
	logfile= '%s/%s' % (work_path, py_logfile)
	
	handler = logging.handlers.RotatingFileHandler(logfile, maxBytes = 1024*1024, backupCount = 5)
	fmt = '%(asctime)s - %(filename)s:%(lineno)s - %(name)s - %(message)s'

	formatter = logging.Formatter(fmt)   # 实例化formatter
	handler.setFormatter(formatter)      # 为handler添加formatter

	logger = logging.getLogger('test')    # 获取名为tst的logger
	logger.addHandler(handler)           # 为logger添加handler
	logger.setLevel(logging.DEBUG)
	
	
	logger.info("")
	logger.info("********************************************************************************************")
	logger.info("Read configuration file result is:")
	logger.info("********************************************************************************************")
	logger.info('user_name        : %s' % (user_name))
	logger.info('app_name         : %s' % (app_name))
	logger.info('VDA_name         : %s' % (VDA_name))
	logger.info('ddc_url          : %s' % (ddc_url))
	logger.info('PIN_passwd       : %s' % (PIN_passwd))
	logger.info('Incorrect_passwd : %s' % (Incorrect_passwd))
	logger.info("")
	
	logger.info('citrix_receiver_desktops_x  : %d' % (citrix_receiver_desktops_x))
	logger.info('citrix_receiver_desktops_y  : %d' % (citrix_receiver_desktops_y))
	logger.info('vda_pin_center_x            : %d' % (vda_pin_center_x))
	logger.info('vda_pin_center_y            : %d' % (vda_pin_center_y))
	logger.info('vda_pin_passwd_x            : %d' % (vda_pin_passwd_x))
	logger.info('vda_pin_passwd_y            : %d' % (vda_pin_passwd_y))
	logger.info('vda_pin_ok_button_x         : %d' % (vda_pin_ok_button_x))
	logger.info('vda_pin_ok_button_y         : %d' % (vda_pin_ok_button_y))
	logger.info("")
	
	logger.info('proc_wait_time : %d' % (proc_wait_time))
	logger.info('opt_wait_time  : %d' % (opt_wait_time))
	logger.info("")
	
	logger.info('work_path   : %s' % (work_path))
	logger.info('ps_logfile  : %s' % (ps_logfile))
	logger.info('py_logfile  : %s' % (py_logfile))
	logger.info("********************************************************************************************")
	logger.info("")
	
	logger.info("Input parameters:")
	logger.info("********************************************************************************************")
	logger.info('Resource type  : [%s].' % (resourcetype))
	logger.info('Test type      : [%d].' % (testType))  
	logger.info('Reconnect flag : [%d].' % (testExt))
	logger.info("********************************************************************************************")
	logger.info("")
	
	logger.info('No reset before, work path is [%s].' % (os.getcwd()))
	logger.info('No reset before, abs path is [%s].' % (os.path.abspath(os.path.dirname(__file__))))
	logger.info("")
	
	os.chdir(work_path)
	
	
	w,d = pyautogui.size()
	logger.info('this client screen width and height is [%d - %d].' % (w, d))
	logger.info("")
	
	logger.info('work path is [%s].' % (os.getcwd()))
	logger.info('abs path is [%s].' % (os.path.abspath(os.path.dirname(__file__))))
	logger.info("")
	
	
	if os.path.exists('desktops.png'):
		logger.info('desktops is exist')
	else:
		logger.info('desktops is not exist')
	
	if ( (resourcetype == "") or (app_name == "") or (ddc_url == "") or (VDA_name == "") or (PIN_passwd == "")):
		logger.info('Input desktop name or PIN password is not correct.')
		raise Exception("Input desktop name or PIN password is not correct.")
		#sys.exit()
	
	
	if ((testType == 3) and (testExt > 0)):
		reRes = reconnect_session(resourcetype,app_name, ddc_url, VDA_name, PIN_passwd)
		logger.info('call reconnect_session result is [%d].' % (reRes))
		if (reRes == 0):
			logger.info('Reconnect is success...')
			logger.info("")
		os._exit(reRes)
		
	
	#while( res != 0 and res != 1 ):
	while( res != 0 ):
		
		logger.info("")
		
		try:
			subprocess.check_output('powershell "get-process iexplore -ErrorAction silentlycontinue | select-object Id | foreach-object { taskkill /t /f /pid $_.Id}"', shell=True)
		except:
			#print "no iexplore"
			logger.info('no iexplore [%d].' % (res))
		
		if (testType == 2):
			res = launch_session(resourcetype,app_name, ddc_url, VDA_name, Incorrect_passwd)
		else:
			res = launch_session(resourcetype,app_name, ddc_url, VDA_name, PIN_passwd)
		#print res
		logger.info('call launch_session result is [%d].' % (res))
		
		if (res == 1001):
			logger.info('PIN password is not correct and end autotest.')
			logger.info("")
			
			os._exit(res)
		elif (res == 0):
			#time.sleep(30)
			#os.system("taskkill /F /IM CDViewer.exe")
			logger.info('Log on and open LinuxVDA success, return.')
			logger.info("")
			
			os._exit(res)
		break
	
	logger.info("")
	
	os._exit(res)
