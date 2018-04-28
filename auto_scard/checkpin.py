#!/usr/bin/env python
# ! -*- coding: utf-8 -*-
# @Time    :2017/8/22 15:31
# @Author  :Zhen Fan
# @File    :client_main.py

import pyautogui
import os
import sys
import time
import subprocess
import argparse


"""
This script is used to launch Session with Chrome Reciever. 

Please provide login username, password, resource type(can be "desktop" or "apps"), resource name and the Chrome App id as the parameters. Then it will launch the ICA session for you.
"""

def cmd_parse(desktopName, pinCode) :
    parser = argparse.ArgumentParser()
    parser.add_argument('-d', action='store', dest='desktopName',  default= desktopName,  help='LinuxVDA desktop name')
    parser.add_argument('-p', action='store', dest='pinCode',      default= pinCode,      help='PIN password of smart card')
    
    results = parser.parse_args()
    desktopName = results.desktopName
    pinCode     = results.pinCode
    
    dict = {'key-desktopname': desktopName, 'key-pincode': pinCode}

    return dict

def checkpin():
	desktopName = ""
	pinCode     = ""
	
	dict = cmd_parse(desktopName, pinCode)
	
	desktopName = dict['key-desktopname']
    pinCode     = dict['key-pincode']
	
	if ( (desktopName == "") or (pinCode == "")):
	    raise Exception("Input desktop name or PIN password is not correct.")
		return -1
	
	print "Desktop name is [%s] and PIN password is [%s]." % (desktopName, pinCode)
	
	#win = pyautogui.getWindow('rh73demo - Desktop Viewer')
	win = pyautogui.getWindow(desktopName)
	win.set_foreground()
	time.sleep(2)
	loc = pyautogui.locateOnScreen('pin.png')
	if loc == None:
		raise Exception("Cannot find icon for pin.")
	else:
		x, y = pyautogui.center(loc)
		pyautogui.click(x, y)
		time.sleep(2)
		#pyautogui.typewrite('000000')
		pyautogui.typewrite(pinCode)
		time.sleep(0.1)
		pyautogui.press('tab')
		time.sleep(0.1)
		pyautogui.press('enter')
	return 0

if __name__ == "__main__":
	checkpin()
