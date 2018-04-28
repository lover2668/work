Param(
    [parameter(mandatory=$true)][string]$user,
	[parameter(mandatory=$true)][string]$domain,
	[parameter(mandatory=$true)][string]$password,
	[parameter(mandatory=$true)][string]$store,
	[parameter(mandatory=$true)][string]$resource
    )

Set-StrictMode -version 1 
# Import module
Import-Module -Name "$(Split-Path $script:MyInvocation.MyCommand.Definition)\SessionLaunch.ICAClient.psm1" -Force

$launch = 1
$session_pid = ''
$counter = 0
$log = "logs\\sessionlog_desktop_" + $user + '.txt'
$ResourceByName = $resource
function LaunchSession{
	Param(
           [Parameter(Mandatory=$true)][string]$UserName,
		   [Parameter(Mandatory=$true)][string]$store,
		   [Parameter(Mandatory=$true)][string]$domain,
		   [Parameter(Mandatory=$true)][string]$password
         )
	write-host "$UserName"	
	
	# Launch a session
	$DOMAIN_DNS_NAME = $domain
	$XD_USER1 = $UserName
	$DOMAIN_USER_PASSWORD = $password
	#$sessioninfo = Invoke-ResourceByName -StoreURL ${Store} -Domain ${DOMAIN_DNS_NAME} -UserName ${XD_USER1} -Password ${DOMAIN_USER_PASSWORD} -ResourceName ${ResourceByName} -Verbose -LaunchParams @{Display = 'absolute'; showDesktopViewer = 'true'}
	write-host "Add-LaciWIlaunchersession -site $store -username ${XD_USER1} -Domain ${DOMAIN_DNS_NAME} -Password ${DOMAIN_USER_PASSWORD} -AppFilter ${ResourceByName}"
	$launchstring = Add-LaciWIlaunchersession -site $store -username ${XD_USER1} -Domain ${DOMAIN_DNS_NAME} -Password ${DOMAIN_USER_PASSWORD} -AppFilter ${ResourceByName}
	
	return $launchstring.ProcessId
}


$date_str = ''
$wait=0
while ($true)
{
	if ($launch -eq 1) {
		Try
		{
			$session_pid = LaunchSession -UserName $user -store $store -domain $domain -password $password
		}
		Catch
		{
			$ErrorMessage = $_.Exception.Message
			$date_str = get-date -format F
			$errormsg = $date_str + " : " + $ErrorMessage
			write-host $errormsg
			$errormsg | out-file -append $log
			timeout /T 30
			continue
		}
		#Finally
		#{
		#	continue
		#}
		$counter = $counter + 1
		$date_str = get-date -format F
		$errormsg = $date_str + " : Number $counter Session has been launched"
		write-host $errormsg
		$errormsg | out-file -append $log
		
		# clipboard
		#type C:\Stress\Test\clipboard.txt | clip
		
	}
	timeout /T 30
	#write-host $wait
	#if ($wait -eq 5)
	#{
	#	taskkill /f /t /pid $session_pid
	#}
	
	$tmp = @{}
	get-process wfica32 -ErrorAction silentlycontinue | select-object Id | foreach-object { $tmp.add("wfica32.exe", $_.Id) }
	#$tmp.getenumerator()
	if ($tmp.count -eq 1)
	{
		# session is still active
		#write-host $session_pid
		$launch = 0 
		timeout /T 10
		#taskkill /f /t /pid $tmp['wfica32.exe']
	}
	else {
		# session is inactive
		write-host "session pid disappears..."
		
		$session_file = "Z:\Data\stress\" + $resource + "\" + $user
		#$session_file = "session"
		#New-Item $session_file -type file
		#write-host $session_file
		if (Test-Path $session_file)
		{
			write-host "Remove session file $session_file"
			Remove-Item $session_file
			$str = $session_file + "_file"
			Remove-Item $str -ErrorAction silentlycontinue
			$launch = 1
			$wait = 0
			timeout /T 5
		}
		else
		{
			write-host "session file $session_file doesn't exist"
			if ($wait -eq 10)
			{
				$launch = 1
				$wait = 0
				if (Test-Path ($session_file + "_file"))
				{
					$date_str + " " + $user + " : session cannot be launched successfully..." | out-file -append "Z:\Data\stress\" + $resource + "\" + $user + "_log"
					$str = $session_file + "_file"
					Remove-Item $str -ErrorAction silentlycontinue
				}
			}
			else
			{
				$wait = $wait + 1
				$launch = 0
			}
		}
	}
	
}

