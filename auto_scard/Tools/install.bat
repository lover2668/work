msiexec /qb /i python-2.7.12.msi
c:\Python27\python.exe -m pip install Pillow
c:\Python27\python.exe -m pip install pyautogui
c:\Python27\Scripts\pip.exe install pywin32-220.1-cp27-cp27m-win32.whl
c:\Python27\python.exe c:\Python27\Scripts\pywin32_postinstall.py -install
copy /Y Microsoft.VC90.MFC.manifest C:\Python27\Lib\site-packages\pythonwin\Microsoft.VC90.MFC.manifest 
pause