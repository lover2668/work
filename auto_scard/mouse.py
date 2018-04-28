#!/usr/bin/env python
# ! -*- coding: utf-8 -*-

'''
Created on 201
@author: junshengc
'''


import pyautogui
import os
import sys
import time
import subprocess
import logging
import logging.handlers
#import pygtk
import Tkinter


def get_line():
    lineNumber = sys._getframe().f_back.f_lineno
    return lineNumber

def get_fun():
    funcName = sys._getframe().f_back.f_code.co_name
    return funcName


def creat_win():
        
    w,h = pyautogui.size()
    print "[%s][%s]: The current computer's window size is [%d - %d]." % (get_line(), get_fun(), w, h)
    print ""
    
    rule = str(w)+"x"+str(h)
    root = Tkinter.Tk()  #创建窗口
    root.overrideredirect(True)
    #root.attributes("-alpha", 0.3)窗口透明度70 %
    root.attributes("-alpha", 0.4)#窗口透明度60 %
    root.geometry(rule)
    canvas = Tkinter.Canvas(root)
    canvas.configure(width = w) # 标签长宽
    canvas.configure(height = h) # 背景颜色
    canvas.configure(bg = "blue")
    canvas.configure(highlightthickness = 0)
    canvas.pack()   # 固定窗口位置
    root.resizable(w, h) #不允许改变窗口大小
    
    x, y = 0, 0
    def move(event):
        global x,y
        new_x = (event.x-x)+root.winfo_x()
        new_y = (event.y-y)+root.winfo_y()
        s = "300x200+" + str(new_x)+"+" + str(new_y)
        root.geometry(s)
        print("s = ",s)
        print(root.winfo_x(),root.winfo_y())
        print(event.x,event.y)
        print()
    def button_1(event):
        global x,y
        x,y = event.x,event.y
        print("The current mouse coordinate value is x-y = ",event.x,event.y)
        print ""
        
    def close_3(event):
        root.destroy()


    #1.　　安装 pip install pyinstaller
    #2.　　到指定目录下使用pyinstaller来讲py文件编译成exe
    #使用如下命令进行编译成exe文件
    #pyinstaller -F -w yourfilename.py

    #<B1-Motion> 当Button 1被按下的时候移动鼠标（B2代表中键，B3代表右键），鼠标指针的当前位置将会以event对象的x y 成员的形式传递给callback。
    #<ButtonRelease-1> Button 1被释放。鼠标指针的当前位置将会以event对象的x y 成员的形式传递给callback。
    #<Double-Button-1> Button 1被双击。可以使用Double 或者 Triple前缀。注意：如果你同时映射了一个单击和一个双击，两个映射都会被调用。
    #canvas.bind("<B1-Motion>",move)
    canvas.bind("<Button-1>",button_1)
    canvas.bind("<Double-Button-1>",close_3)
    root.mainloop()
    
if __name__ == '__main__':
    print "[%s][%s]: start..." % (get_line(), get_fun())
    
    creat_win()
    