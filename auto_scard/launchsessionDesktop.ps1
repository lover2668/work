Set-StrictMode -version 1 


$launch      = 1
$session_pid = ''
$counter     = 0
$ps_logfile  = ''



function log_record{

	Param($log_msg,$date_is_add)

	if ($ps_logfile -eq '')
	{
		return
	}
	
	if ($date_is_add -eq 0)
	{
		$log_msg   | out-file -append $ps_logfile
	}
	else
	{
		$date_str = get-date -format F
		$errormsg = $date_str + " : " + $log_msg
		
		$errormsg   | out-file -append $ps_logfile
	}
}


function del_file{
	Param($filename)
	
	#Write-Host "`n"
	#Write-Host "[del_file]: Start delete old [$filename] file..."

	$flagExist = Test-Path $filename
	if ($flagExist -eq 'true')
	{
		Remove-Item $filename
	}
	else
	{
		#Write-Host "[del_file]: wait delete old [$filename] file is not exist."
	}
	
	#Write-Host "[del_file]: Delete old [$filename] file end."
	#Write-Host "`n"
	
	log_record -log_msg "`n" -date_is_add 0
	log_record -log_msg "[del_file]: Delete old [$filename] file end." -date_is_add 1
	log_record -log_msg "`n" -date_is_add 0
}




if ( 5 > $args.Count)
{
    #Write-Host "Input parameters is not correct.($args.Count)"
	return 1
}
For($i=0;$i -lt $args.Count; $i++)
{
    #Write-Host "parameter $i : $($args[$i])"
}

$confFile     = $args[0]
$testType     = $args[1]
$reTestFlag   = 0
$resourcetype = "desktop"



#Write-Host "`n"
#Write-Host "Read configuration file:"
#Write-Host "***************************************************************************************"

$i = 1
$hashtable = @{}

$payload = Get-Content -Path $confFile |
Where-Object { $_ -like '*=*' } |
ForEach-Object {
    $infos = $_ -split '='
    $key = $infos[0].Trim()
    $value = $infos[1].Trim()
    $hashtable.$key = $value
	
	#Write-Host "[$i] $key = $value"
	##Write-Host $value
	##Write-Host $hashtable.$key
	$i += 1
}

#Write-Host "***************************************************************************************"
#Write-Host "`n"


$workPath       = $hashtable.work_path

#$python_process = $hashtable.python_path
##Write-Host "Python process path is [$python_process]"

$ps_logfile     = $hashtable.work_path + "\" + $hashtable.ps_logfile

$python_logfile = $hashtable.work_path + "\" + $hashtable.py_logfile

$proc_wait_time = $hashtable.proc_wait_time



#Write-Host "`n"
#Write-Host "Start powerShell script and Notes:"
#Write-Host "***************************************************************************************"
#Write-Host "Configuration file is [$confFile]"
#Write-Host "This testing type is [$testType]"
#Write-Host "`n"

#Write-Host "Run and execute script work path is [$workPath]"
#Write-Host "Record executed powerShell script log file is [$ps_logfile]"
#Write-Host "Record executed python script log file is [$python_logfile]"
#Write-Host "process wait time is [$proc_wait_time]"
#Write-Host "`n"


if ( ($testType -le 0) -or ($testType -ge 4))
{
	#Write-Host "***************************************************************************************"
	#Write-Host "`n"
	
	#Write-Host "Input test type is unknown."
	return 2
}


#Write-Host "Test type [2]: Testing incorrect PIN password.(success return is 1001)"
#Write-Host "Test type [1]: Testing normal log on LinuxVDA using smart card.(success return is 2001)"
#Write-Host "Test type [3]: Testing disconnect and reconnect. (success return is 3001)"
#Write-Host "***************************************************************************************"
#Write-Host "`n"



del_file -filename $ps_logfile


log_record -log_msg "`n" -date_is_add 0
log_record -log_msg 'Start powershell script and Notes:' -date_is_add 1
log_record -log_msg "***************************************************************************************" -date_is_add 0
log_record -log_msg "Configuration file is [$confFile]" -date_is_add 0
log_record -log_msg "This testing type is [$testType]" -date_is_add 0
log_record -log_msg "`n" -date_is_add 0

log_record -log_msg "Run and execute script work path is [$workPath]" -date_is_add 0
log_record -log_msg "Record executed powerShell script log file is [$ps_logfile]" -date_is_add 0
log_record -log_msg "Record executed python script log file is [$python_logfile]" -date_is_add 0
log_record -log_msg "process wait time is [$proc_wait_time]" -date_is_add 0
log_record -log_msg "`n" -date_is_add 0

log_record -log_msg "Test type [2]: Testing incorrect PIN password.(success return is 1001)" -date_is_add 0
log_record -log_msg "Test type [1]: Testing normal log on LinuxVDA using smart card.(success return is 2001)" -date_is_add 0
log_record -log_msg "Test type [3]: Testing disconnect and reconnect. (success return is 3001)" -date_is_add 0
log_record -log_msg "***************************************************************************************" -date_is_add 0
log_record -log_msg "`n" -date_is_add 0



function kill_app{
	Param($appname,$processname)
	
	#Write-Host "[kill_app]: Will kill application name is [$appname] and process name is [$processname]"
	
	$tmp = @{}
	get-process $appname -ErrorAction silentlycontinue | select-object Id | foreach-object { $tmp.add($processname, $_.Id) }
	#$tmp.getenumerator()
	
	#Write-Host "[kill_app]: get [$appname] result is : "$tmp.count
	
	log_record -log_msg "kill_app]: get [$appname] result is : $tmp.count" -date_is_add 1
	
	if ($tmp.count -eq 1)
	{
		# session is still active
		##Write-Host $session_pid
		$launch = 0 
		Start-Sleep -Seconds 10
		#taskkill /f /t /pid $tmp['wfica32.exe']
		#taskkill /f /t /pid $tmp['CDViewer.exe']
		taskkill /f /t /pid $tmp[$processname]
		#taskkill /IM /f $processname
		#Write-Host "[kill_app]: Kill $appname"
		
		log_record -log_msg "[kill_app]: Kill $appname." -date_is_add 1
		
		return 0
	}
	else
	{
		return 1
	}
}


function kill_all_apps{
	Param($appname,$processname)
	
	#Write-Host "`n"
	#Write-Host "[kill_all_apps]: Will kill application name is [$appname] and process name is [$processname]"
	
	$i= 0
	$flagEnd = 1
	For($i=1;$i -lt 20; $i++)
	{
		$ret = kill_app -appname $appname -processname $processname
		if($ret -eq 1)
		{
			$flagEnd = 0
			Start-Sleep -Seconds 1
			break
		}
		
		Start-Sleep -Seconds 1
	}
	
	$rst = "kill all success"
	if ($flagEnd -eq 1)
	{
		$rst = "have not kill all"
	}
	
	#Write-Host "[kill_all_apps]:Clear and kill old [$appname] was executed [$i] and result is [$rst]."
	#Write-Host "[kill_all_apps]:Clear and kill old [$processname] application process end."
	#Write-Host "`n"
	
	log_record -log_msg "`n" -date_is_add 0
	log_record -log_msg "[kill_all_apps]:Clear and kill old [$appname] was executed [$i] and result is [$rst]." -date_is_add 1
	log_record -log_msg "`n" -date_is_add 0
	
}


del_file -filename $python_logfile

kill_all_apps -appname iexplorer -processname iexplorer.exe

kill_all_apps -appname CDViewer -processname CDViewer.exe



function LaunchSession($testFlag){
	# Launch a session
	#Write-Host "`n"
	#Write-Host '[LaunchSession]: call python start...'
	#Write-Host $testType
	#Write-Host $testFlag
	
	log_record -log_msg "`n" -date_is_add 0
	log_record -log_msg "[LaunchSession]: call python start..." -date_is_add 1
	log_record -log_msg "[LaunchSession]: Testing type is [$testType] and testing flag is [$testFlag]." -date_is_add 1
	
	C:\Python27\python.exe $workPath\LaunchSession.py $confFile $resourcetype  $testType $testFlag
	
	#Write-Host "[LaunchSession]: call python finished. "
	log_record -log_msg "[LaunchSession]: call python finished." -date_is_add 1
	
	if($LastExitCode -eq 1001)
	{
		#Write-Host "[LaunchSession]: PIN password is not correct."
		#Write-Host "`n"
		
		log_record -log_msg "[LaunchSession]: PIN password is not correct." -date_is_add 1
		log_record -log_msg "`n" -date_is_add 0
		
		return 1001
	}
	elseif($LastExitCode -eq 0)
	{
		#Write-Host "[LaunchSession]: Log on on LinuxVDA is success."
		#Write-Host "`n"
		
		log_record -log_msg "[LaunchSession]: Log on on LinuxVDA is success." -date_is_add 1
		log_record -log_msg "`n" -date_is_add 0
		
		return 0
	}
	else
	{
		#get-date -format F
		#Write-Host "[LaunchSession]: Log on on LinuxVDA is failed."
		#Write-Host "`n"
		
		log_record -log_msg "[LaunchSession]: Log on on LinuxVDA is failed and ErrorCode is [$LastExitCode]." -date_is_add 1
		log_record -log_msg "`n" -date_is_add 0
		
		#return $LastExitCode
		return 6
	}
	
	#Write-Host "`n"
}



$date_str = ''
$wait=0
while ($true)
{
	if ($launch -eq 1) {
		Try
		{
			$date_str = get-date -format F
			
			#Write-Host "`n"
			#Write-Host $date_str
			#Write-Host  '######### start....'
			
			log_record -log_msg "`n" -date_is_add 0
			log_record -log_msg "######### start..." -date_is_add 1
			
			$status = LaunchSession $reTestFlag
			#Write-Host  "######### End...." 
			#Write-Host $status
			#Write-Host "@@@@@"
			
			log_record -log_msg "Callback LaunchSession result is [$status]." -date_is_add 1
			
			$date_str = get-date -format F
			#Write-Host $date_str
			if($status -eq 1001)
			{
				#Write-Host "PIN password is not correct."
				#Write-Host "`n"
				
				log_record -log_msg "PIN password is not correct." -date_is_add 1
				log_record -log_msg "@@@@@@ Result is [$status]" -date_is_add 0
				log_record -log_msg "`n" -date_is_add 0
				
				kill_all_apps -appname iexplorer -processname iexplorer.exe
				
				kill_all_apps -appname CDViewer -processname CDViewer.exe
				
				$launch = 0
				
				return 1001
			}
			elseif($status -eq 0)
			{
				#Write-Host "Log on LinuxVDA is success, start wait a times..."
				
				log_record -log_msg "Log on LinuxVDA is success, start wait a times..." -date_is_add 1
				
				#Start-Sleep -Seconds 30
				Start-Sleep -Seconds $proc_wait_time 
				
				log_record -log_msg "Log on LinuxVDA is success." -date_is_add 1
				
				kill_all_apps -appname CDViewer -processname CDViewer.exe
				#CDViewer.exe logoff
				
				if ($testType -eq 3)
				{
					#Write-Host "Wait a times, then Reconnect."
					
					log_record -log_msg "Wait a times, then Reconnect." -date_is_add 1
					
					$reTestFlag = 1
					
					#Start-Sleep -Seconds 30
					Start-Sleep -Seconds $proc_wait_time 
					
					#Write-Host "Wait time is over, Start reconnect..."
					
					log_record -log_msg "Wait time is over, Start reconnect..." -date_is_add 1
					
					$statusAgain = LaunchSession $reTestFlag
					if($statusAgain -eq 0)
					{
						#Write-Host "Reconnect is success and start wait a time..."
						
						log_record -log_msg "Reconnect is success and start wait a time..." -date_is_add 1
						
						#Start-Sleep -Seconds 30
						Start-Sleep -Seconds $proc_wait_time 
						
						#Write-Host "Reconnect is success wait time is over."
						#Write-Host "`n"
						
						log_record -log_msg "Reconnect is success wait time is over." -date_is_add 1
						log_record -log_msg "@@@@@@ Result again is [$statusAgain] " -date_is_add 0
						log_record -log_msg "`n" -date_is_add 0
						
						kill_all_apps -appname iexplorer -processname iexplorer.exe
						
						kill_all_apps -appname CDViewer -processname CDViewer.exe
						
						$launch = 0
						
						return 3001
					}
					else
					{
						#Write-Host "Reconnect is failed and ErrorCode is [$statusAgain]."
						#Write-Host "`n"
						
						log_record -log_msg "Reconnect is failed and ErrorCode is [$statusAgain]." -date_is_add 1
						log_record -log_msg "@@@@@@ Result again is [$statusAgain] " -date_is_add 0
						log_record -log_msg "`n" -date_is_add 0
						
						$launch = 0
						
						return 3
					}
				}
				
				#Write-Host "`n"
				
				log_record -log_msg "@@@@@@ Result is [$status]" -date_is_add 0
				log_record -log_msg "`n" -date_is_add 0
				
				$launch = 0
				
				return 2001
			}
			elseif ($status -eq 1)
			{
				$errormsg = "Number $counter Session has failed to launch."
				
				log_record -log_msg "Number $counter Session has failed to launch." -date_is_add 1
				log_record -log_msg "@@@@@@ Result is [$status]" -date_is_add 0
				log_record -log_msg "`n" -date_is_add 0
				
				throw $errormsg
				
				$launch = 0
				
				#Write-Host "`n"
				
				return 1
			}
			
		}
		Catch
		{
			$ErrorMessage = $_.Exception.Message
			$date_str = get-date -format F
			$errormsg = $date_str + " : " + $ErrorMessage
			#Write-Host $errormsg
			#Write-Host "`n"
			
			#$errormsg | out-file -append $ps_logfile
			
			log_record -log_msg $ErrorMessage -date_is_add 0
			
			Start-Sleep -Seconds 30
			
			log_record -log_msg "Wait a times is over, then start log on again..." -date_is_add 0
			log_record -log_msg "### catch Exception Message is [$ErrorMessage]." -date_is_add 0
			log_record -log_msg "`n" -date_is_add 0
			
			continue
		}
		#Finally
		#{
		#	continue
		#}
		
		$date_str = get-date -format F
		$errormsg = $date_str + " : Number $counter Session has been launched"
		#Write-Host $errormsg
		#Write-Host "`n"
		
		#$errormsg | out-file -append $ps_logfile
		
		log_record -log_msg $ErrorMessage -date_is_add 0
		log_record -log_msg "### once end message is [$errormsg]." -date_is_add 0
		log_record -log_msg "`n" -date_is_add 0
		
		$counter = $counter + 1
		# clipboard
		#type C:\Stress\Test\clipboard.txt | clip
		
	}
	
	Start-Sleep -Seconds 20
	

	break
	
}


