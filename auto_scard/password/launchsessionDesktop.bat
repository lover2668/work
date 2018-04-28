set user_prefix=user
set start_user=2
set end_user=2
set domain_name=zhusl.com
set user_password=citrix
set store=https://sf.zhusl.com/Citrix/StoreWeb
set resource_name=rh73demo

REM start "Restart" "powershell.exe" ".\shutdown_client.ps1"
set scriptname=.\launchsessionDesktop
for /l %%i in (%start_user%,1,%end_user%) do (
	start "%user_prefix%%%i" "cmd.exe" "/K Powershell.exe -ExecutionPolicy Bypass -File %scriptname%.ps1 -user %user_prefix%%%i -domain %domain_name% -password %user_password% -store %store% -resource %resource_name%"
	timeout /T 5
)

REG ADD "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d 1 /f
REG ADD "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultDomainName /t REG_SZ /d %COMPUTERNAME% /f
REG ADD "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /t REG_SZ /d Administrator /f
REG ADD "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /t REG_SZ /d citrix /f

set startupscript="C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\launchsession.bat"
echo cd /d %cd% > %startupscript%
echo %scriptname%.bat >> %startupscript%