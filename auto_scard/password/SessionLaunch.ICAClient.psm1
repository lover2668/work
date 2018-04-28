<#
.SYNOPSIS
    This module provide necessary functions to Launch/Disconnect a resource/session on ICA Client.

    Copyright (c) Citrix Systems, Inc. All Rights Reserved.
.DESCRIPTION
    + Utilized the Store Service API 2.5 to 
        - Enumerate resources
        - Get ICA file
        - Get available sessions
        - Disconnect/Logoff sessions
    + Provide functions to validate the launched session   

.EXAMPLE
    #An example about mostly used functions

    $getResParam = @{
        #Note: http/https should match with the Storefront config. And currently, StoreWeb url is not supported.
        'StoreURL' = 'https://go.citrite.net/Citrix/Store';    
        'UserName' = 'username';
        'Password' = 'password';
        'Domain' = 'citrite';
    }
    Write-Host 'This function get all resources available into reses (as an xml object)'
    $reses = Get-Resources @getResParam
    
    Write-Host 'This function list all resource names in the xml'
    Get-ResourcesNames -Xml $reses
    
    Write-Host  'This function get resource details of resource name like "GoTo*"'
    
    Get-ResourceByName -Xml $reses -Name 'GoTo*'
    
    Write-Host  'This function invoke the resource "Citrix Desktop"(if you have one)'
    
    $getResParam['ResourceName'] = 'Citrix Desktop'
    $resInfo = Invoke-ResourceByNameCore @getResParam
    
    Write-Host 'Waiting for logoff...'
    Start-Sleep 60
    
    Write-Host  'This function will logoff the previous session...'
    $getResParam.Remove('ResourceName')
    $getResParam['Ticket'] = $resInfo.Ticket
    Stop-Session @getResParam
    
    Write-Host 'Done.'
#>

function Initialize-Assemblies{
    <#
    .SYNOPSIS
        Load the required assemblies.
    .DESCRIPTION
        Internal function load assemblies required for this module.
    #>
    $null = [System.Reflection.Assembly]::LoadWithPartialName("System.Web")
    $null = [System.Reflection.Assembly]::LoadWithPartialName("System.Net")
    $null = [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Stream")
}

#region Token functions
function Add-TokenToCache{
    <#
    .SYNOPSIS
        Add a token object into token cache
    .DESCRIPTION
        This module manages a token cache which stores tokens by username and url.
        This function will build the key of the input token and save it into the cache for later use with Get-TokenFromCache.   
    .PARAMETER Token
        A token object(hashtable) returned from Request-Token function  
    .EXAMPLE
        Save a token into token cache
        $tok = Request-Token @TokenRequestParams 
        Add-TokenToCache -Token $tok
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][hashtable]$Token          
    )
    $key = $Token['url'] + '_' + $Token['username']
    $Script:Tokens[$key] = $Token
}

function Get-TokenFromCache{
    <#
    .SYNOPSIS
        Fetch the token object back from the token cache with given URL and Username.
    .DESCRIPTION
        This module manages a token cache which stores tokens by username and url.
        This function will build the token cache key with given URL and Username parameters and try to find the corresponding token.
        If:
            1.The token does not exist yet, or
            2.the token is expired 
        then $null will be returned.
        Else the token object will be returned, in which you can find the token string inside.
    .PARAMETER URL
        The 'for-service' url of a token. E.g.https:\\go.citrix.com\Citrix\Store\resources\v2
    .PARAMETER Username
        The username which indicates who owns the token
    .EXAMPLE 
    Get the Token for resources services of user0
        $URL = 'http:\test\Citrix\Store\resources\v2'
        $resourceToken = Get-TokenFromCache -URL $URL -Username user0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][String]$URL,
        [Parameter(Mandatory=$true)][String]$Username
    )
    $key = $URL + '_' + $Username
    if($Script:Tokens.ContainsKey($key)){
        $token = $Script:Tokens[$key]
        $currTime = Get-Date
        $expTime = $token.expiry
        #Expired 1 minutes earlier 
        if($expTime -gt $currTime.AddMinutes(1)){
            Write-Verbose 'Valid token, return'
            return $token.token
        }
        #Otherwise, remove the expired token and return $null
        Write-Verbose 'Removed expired token...'
        $Script:Tokens.Remove($key)        
    }
    return $null
}

function Get-TokenCache{
    #TO-DO: Remove this function after token cache function being added
    <#
    .SYNOPSIS
        Return the token cache object for debug use.
    .DESCRIPTION
        Internal function to check the content of $Script:Tokens
    #>
    return $Script:Tokens
}
#region Request-Token functions

function Request-Token{
    <#
    .SYNOPSIS
        Follow the "Security Token Service API v1.2" to get the token for a certain service
    .DESCRIPTION
        Use the CitrixAuth string passed in and follow the authentication chain until a success authenticateresponse-1 received.
        Then use the provided credential to get the token.Before being returned, token will be saved into the token cache with Add-TokenToCache
                
    .PARAMETER CitrixAuthString
        The string extracted from a 404 header when try to process an Store service without token. Which contains information about the requested service and target authentication service URL
    .PARAMETER Domain
        The domain used for authentication, e.g.xd.local
    .PARAMETER UserName
        The username used for authentication, e.g. User0
    .PARAMETER Password
        The password used for authentication
    .EXAMPLE
        $RTparams = @{
            'Domain'='citrix';
            'UserName'='User0';
            'Password'='abcdefg123'            
            'CitrixAuthString'=$authString
        }
        Request-Token @RTparams
    .NOTES
        *Attention* Currently only explicity forms authentication is support in this function
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$CitrixAuthString,
        [Parameter(Mandatory=$true)][String]$Domain,
        [Parameter(Mandatory=$true)][String]$UserName,
        [Parameter(Mandatory=$true)][String]$Password
    #TO-DO: Add token life time parameter
    #   [Parameter(Mandatory=$false)][String]$TokenLifeTime
    )
    #Build authentication info object with the string
    $authInfo = Read-CitrixAuth -CitrixAuthString $CitrixAuthString        
    $xmlBody = New-RequestTokenMessage -ForService $authInfo['for-service'] -ForServiceURL $authInfo['for-service-url'] 
    $Urls = $authInfo['url-list']      
    #There could be multiple URLS in the Auth string, try each url in the url-list until token got  
    foreach($url in $Urls){        
        $requestParams = @{
            'URL'=$url;
            'Method' = 'POST';
            'Accept' = 'application/vnd.citrix.requesttokenresponse+xml, application/vnd.citrix.requesttokenchoices+xml' ;
            'ContentType' = 'application/vnd.citrix.requesttoken+xml';
            'StringBody' = $xmlBody.OuterXml;
        }
        #Send token request
        $resp = Invoke-HttpRequest @requestParams    
        if ($resp.StatusCode -eq [System.Net.HttpStatusCode]::Unauthorized){
            #There's another authenticate step 
            #Close the previous response object to release resources
            $resp.Close()
            $newParams = @{
                'CitrixAuthString' = $resp.Headers['WWW-Authenticate'] ;
                'Domain'=$Domain;
                'UserName'=$UserName;
                'Password'=$Password
            }
            #Get the token for current service, then use the token to get origin token for requested service
            $parentToken = Request-Token @newParams
            #Embed the token in header
            $requestParams['Headers']=@{'Authorization'="CitrixAuth $($parentToken.token)"}
            $subResp = Invoke-HttpRequest @requestParams            
            $subTokenBody = Read-ResponseBodyAsString -Response $subResp
            $subResp.Close()
            $xmlAuthed = [xml]$subTokenBody  
            #If token got, build the token hashtable, return
            if($xmlAuthed.LastChild.xmlns -eq 'http://citrix.com/delivery-services/1-0/auth/requesttokenresponse'){                
                $tokenObj = Read-TokenResponse -Xml $xmlAuthed   
                $tokenObj['url']  = $authInfo['for-service-url']
                $tokenObj['username'] = $UserName
                Add-TokenToCache -token $tokenObj
                Write-Verbose "Request-Token:Got Token for Service $($authInfo['for-service-url'])"
                return $tokenObj                                                                                                                        
            }         
            #else try other url
            #continue
        }
        
        if($resp.StatusCode -eq [System.Net.HttpStatusCode]::MultipleChoices){
            #Status code 300 got. Try each choices           
            $bodyString = Read-ResponseBodyAsString -Response $resp            
            $resp.Close()
            $xmlChoices = [xml]$bodyString            
            $authChoices = Get-RequestTokenChoices -Xml $xmlChoices
            foreach($choice in $authChoices){
                $requestAuthParams = @{
                    'URL' = $choice['location'];
                    'Method' = 'POST';
                    'Accept' = 'application/vnd.citrix.requesttokenresponse+xml, text/xml, application/vnd.citrix.authenticateresponse-1+xml'
                    'ContentType' = 'application/vnd.citrix.requesttoken+xml'
                    'StringBody' = $xmlBody.OuterXml
                }
                $authResp = Invoke-HttpRequest @requestAuthParams                
                if ($authResp.StatusCode -ne [System.Net.HttpStatusCode]::OK){
                    Write-Verbose "Request-Token:Not applicable protocol.Continue..."
                    $authResp.Close()
                    continue
                }
                #Read the PostBack URL from body
                $bodyString = Read-ResponseBodyAsString -Response $authResp
                $authResp.Close()                                
                $xmlFormAuth = [xml]$bodyString                   
                $authForm = Read-RequestTokenResponse -Xml $xmlFormAuth
                $hostUri = Get-HostUri $choice['location']
                
                $postbackUrl = $hostUri + $authForm['PostBackURL']                
                $postCredentialParams=@{
                    'URL' = $postbackUrl;
                    'Method' = 'POST';
                    'Accept' = 'application/vnd.citrix.authenticateresponse-1+xml, application/vnd.citrix.requesttokenresponse+xml';
                    'ContentType' = 'application/x-www-form-urlencoded';
                    #TO-DO:Rename the StateContext to ContextStatus
                    'StringBody' = New-CredentialMessage -UserName $UserName -Password $Password -Domain $Domain -ContextStatus $authForm['StateContext'] -AuthFormXml $xmlFormAuth
                    'Cookie' = $authResp.Headers['Set-Cookie']
                }                
                $tokenResp = Invoke-HttpRequest @postCredentialParams
                if($tokenResp.StatusCode -eq [System.Net.HttpStatusCode]::OK){
                    $tokenBody = Read-ResponseBodyAsString -Response $tokenResp 
                    $tokenResp.Close()                                                                               
                    $xmlAuthed = [xml]$tokenBody                                          
                    if($xmlAuthed.LastChild.xmlns -eq 'http://citrix.com/delivery-services/1-0/auth/requesttokenresponse'){                        
                        $tokenObj = Read-TokenResponse -Xml $xmlAuthed                                                                                        
                        $tokenObj['url']  = $authInfo['for-service-url']
                        $tokenObj['username'] = $UserName
                        Add-TokenToCache -token $tokenObj
                        Write-Verbose "Request-Token:Got Token for Service $($authInfo['for-service-url'])"
                        return $tokenObj                                                                                                                        
                    }
                    else{                            
                        $errors = Get-ErrorLable -Xml $xmlAuthed
                        if($errors -eq $null){
                            throw "Failed to authenticate: $($xmlAuthed.OuterXml)"
                        }
                        $errMsg = $errors | foreach {"Failed to pass credential validation due to [$($_['Text'])]"} | out-string                        
                        throw $errMsg
                    }
                }
                throw "Request-Token: Unexpected response:$($tokenResp.StatusCode)"
            }
        }      
    } #end of foreach urls
}

function Get-RequestTokenChoices{
    <#
    .SYNOPSIS
        Read the RequestTokenChoices XML and return the choices as an list(array)
    .DESCRIPTION
        Internal function
    .PARAMETER Xml
        The xml get from function RequestTokenChoices
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][xml]$Xml
    )    
    if ($Xml.LastChild.xmlns -ne 'http://citrix.com/delivery-services/1-0/auth/requesttokenchoices'){
        throw "Read-RequestTokenResponse: XML Namespace $($Xml.LastChild.xmlns) does not match with 'http://citrix.com/delivery-services/1-0/auth/requesttokenchoices'."
    }    
    $choices = @()
    foreach($choice in $Xml.requesttokenchoices.choices.choice){
        $choices += @{ 'protocol'=$choice['protocol'].InnerText; 'location'=$choice['location'].InnerText }
    }
    return $choices
}
#endregion Request-Token functions
#endregion Token functions

#region Helper functions
function Get-HostUri{
    <#
    .SYNOPSIS
        Extract the host part of an URI
    .DESCRIPTION
        Internal function
    .PARAMETER Uri
        The Uri to be processed
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][String]$Uri
    )
    $tempUri = New-Object -TypeName 'Uri' -ArgumentList $Uri
    $hostUri = $tempUri.AbsoluteUri.Substring(0,$tempUri.AbsoluteUri.IndexOf($tempUri.AbsolutePath))
    return $hostUri
}

function Get-UrlEncodedString{
    <#
    .SYNOPSIS
        URL encoding helper function    
    .DESCRIPTION
        Internal function. Maybe move to some common library in SAL later.
    .PARAMETER String
        The string to be processed
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][String]$String
    )    
    return [system.web.httputility]::UrlEncode($String)
}

function Get-UTF8Byptes{
    <#
    .SYNOPSIS
        String to UTF-8 bytes helper function    
    .DESCRIPTION
        Internal function. Maybe move to some common library in SAL later.
    .PARAMETER String
        The string to be processed
    #>
    param(
        [Parameter(Mandatory=$true)][String]$String
    )
    $UTF8 = New-Object "System.Text.UTF8Encoding"
    return $UTF8.GetBytes($String)
}

function Get-MyIPv4Address{    
    <#
    .SYNOPSIS
        Get first IPv4 address in NIC list.
    .DESCRIPTION
        Internal function. Maybe move to some common library in SAL later.
    #>
    $CurrentIPs = @();  
    $adpts = Get-WmiObject win32_networkadapterconfiguration | ? { $_.IPAddress -ne $null } | Sort-Object IPAddress -Unique 
    
    if($adpts -isnot [Array]){
        $adpts = ,$adpts
    }
    foreach($adpt in $adpts){
        if($adpt.IPAddress -is [Array]){
            foreach($ip in $adpt.IPAddress){
                if ($ip -match '((\d{1,3}\.){3}\d{1,3})'){
                    return $ip
                }
            }
        }
        if($adpt.IPAddress -match '((\d{1,3}\.){3}\d{1,3})'){
            return $adpt.IPAddress
        }
    }    
}
#endregion Helper functions

function Invoke-HttpRequest{
    <#
    .SYNOPSIS
        Return the response
    .PARAMETER URL
        The url request going to be sent to
    .PARAMETER Method
        The HTTP method,e.g. GET/POST/etc.
    .PARAMETER Accept
        The header field 'Accept'
    .PARAMETER ContentType
        The header field 'Content'
    .PARAMETER Cookie
        The header field 'Cookie'
    .PARAMETER Body
        The body of web request. Should be byte[] type.  
    .PARAMETER StringBody
        The body of web request. Should be string type.
    .PARAMETER Headers
        Other header fields in key-value format.
    .OUTPUTS
        HttpWebResponse.
        *Attention* The response object must be closed with method Close().
    .EXAMPLE        
        $resp = Invoke-HttpRequest `
            -URL 'https://ddc.host/Citrix/Store/resources/v2' `
            -Method GET -Accept 'application/vnd.citrix.resources+xml' `
            -ContentType 'application/x-www-form-urlencoded' `
            -Headers @{'Authorization'="CitrixAuth 'xxxxx...'"}

    #>
    [CmdletBinding(DefaultParameterSetName='ByString')]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$URL,        
        [Parameter(Mandatory=$false)][String]$Method='GET',
        [Parameter(Mandatory=$false)][String[]]$Accept,
        [Parameter(Mandatory=$false)][String]$ContentType,
        [Parameter(Mandatory=$false)][String]$Cookie,                
        [Parameter(Mandatory=$false,ParameterSetName='ByString')][String]$StringBody,
        [Parameter(Mandatory=$false)][Hashtable]$Headers
    )
    Write-Verbose "Invoke-HttpRequest:Building request to $URL"
    $req =[System.Net.HttpWebRequest] [System.Net.WebRequest]::Create($url)             
    $noCacheNoStore = [System.Net.Cache.HttpRequestCacheLevel]::NoCacheNoStore 
    $noCachePolicy = ([type]"Net.Cache.HttpRequestCachePolicy").GetConstructor([System.Net.Cache.HttpRequestCacheLevel]).Invoke($noCacheNoStore)
    $req.CachePolicy = $noCachePolicy
    Write-Verbose $req.CachePolicy
    #region Setup Request 
    #region Validate&Set Headers
    if($Headers -ne $null){        
        $UnacceptableHeadersHere = @(            
            'Accept'           ,
            'Connection'       ,
            'Content-Length'   ,
            'Content-Type'     ,
            'Expect'           ,
            'Date'             ,
            'Host'             ,
            'If-Modified-Since',
            'Range'            ,
            'Referer'          ,
            'Transfer-Encoding',
            'User-Agent'        
        )        
        foreach($key in $Headers.Keys){
            if(-not ($UnacceptableHeadersHere -contains $key)) {                            
                $req.Headers.Add("$key`:$($Headers[$key])")
            }
            else{
                Write-Verbose "Invoke-HttpRequest:Header field $key could not be added with Headers.Please set by the system or set by properties or methods."
            }
            $req.PreAuthenticate = $true
        }
    }
    #endregion Validate&Set Headers   
    $req.Method = $Method
    if((Test-Path Variable:Accept) -and ($Accept)){
        $req.Accept = $Accept -join ','
    }

    if(-not [String]::IsNullOrEmpty($ContentType)){
        $req.ContentType = $ContentType
    }    
    if(-not [String]::IsNullOrEmpty($Cookie)){        
        $req.Headers.Add('Cookie',$Cookie)             
    }
        
    #if((Test-Path Variable:Body) -and ($Body)){        
    if((Test-Path Varaible:Body) -and ($Body -ne $null)){        
        $req.ContentLength = $Body.Length
        $stream = $req.GetRequestStream()
        $stream.Write($Body,0,$Body.Length)
        $stream.Close();        
    }

    if(-not [String]::IsNullOrEmpty($StringBody)){
        [byte[]] $utf8body = Get-UTF8Byptes($StringBody)
        $req.ContentLength = $utf8body.Length
        $stream = $req.GetRequestStream()
        $stream.Write($utf8body,0,$utf8body.Length)
        $stream.Close();        
    }
    $req.KeepAlive = $false
    #endregion Setup Request      
    Write-Verbose "Invoke-HttpRequest:Request bulit. Sending for response." 
    if($req.CookieContainer -ne $null){
        foreach($cookie in $req.CookieContainer.GetCookies()){
            Write-Verbose $cooke 
        }
    }    
    try{
        $resp = [System.Net.HttpWebResponse] $req.GetResponse();
        Write-Verbose "Ok"
    }catch [Net.WebException]{
    #Return response even when encounter an status code of 401/404 etc.        
        if($_.Exception.Response -eq $null){
           throw $_.Exception
        }        
        $resp = [System.Net.HttpWebResponse] $_.Exception.Response
    }
    return $resp        
}
#region Messages functions
function New-CredentialMessage{
    <#
        .SYNOPSIS
            Used for the form authentication
        .DESCRIPTION
            Internal function to build the credential message for 
        .PARAMETER ContextStatus
            ContextStatus field from the form xml
        .PARAMETER Domain
            Domain of the user
        .PARAMETER UserName
            Username 
        .PARAMETER Password
            Password
        .PARAMETER AuthFormXml
            The AuthForm xml, used to determine the message type            
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][String]$ContextStatus,
        [Parameter(Mandatory=$true)][String]$Domain,
        [Parameter(Mandatory=$true)][String]$UserName,
        [Parameter(Mandatory=$true)][String]$Password,
        [Parameter(Mandatory=$true)][xml]$AuthFormXml
    )
    #Process non-url characters in username/password/domain
    #System.Web should have been loaded in Initialization    
    $Domain = [System.Web.HttpUtility]::UrlEncode($Domain)
    $UserName = [System.Web.HttpUtility]::UrlEncode($UserName)
    $Password = [System.Web.HttpUtility]::UrlEncode($Password)

    #TO-DO:Handle different auth forms automatically
    if($AuthFormXml.OuterXml.IndexOf("<ID>domain</ID>") -ge 0){
        $msg = "StateContext=$ContextStatus&loginBtn=Log+On&password=$Password&saveCredentials=false&username=$UserName&domain=$Domain"                    
    }
    else{    
        $msg = "StateContext=$ContextStatus&loginBtn=Log+On&password=$Password&saveCredentials=false&username=$Domain%5C$UserName"        
    }
    Write-Verbose "New-CredentialMessage:$msg"
    return $msg
}

function New-RequestTokenMessage{
    <#
    .SYNOPSIS
        Create a new RequestTokenMessage as XML format
    .DESCRIPTION
        Internal function.
    .PARAMETER ForService
        ForService field.
    .PARAMETER ForServiceURL
        ForServiceURL field.
    .PARAMETER ReqTokenTemplate
        ReqTokenTemplate field.
    .PARAMETER RequestedLifetime
        Specify the life time of token with a format 'hh:mm:ss'
        Default to 1 hour '01:00:00'
            
    #>
    param(
        [Parameter(Mandatory=$true)][String]$ForService,
        [Parameter(Mandatory=$true)][String]$ForServiceURL,
        [Parameter(Mandatory=$false)][String]$ReqTokenTemplate,
        [Parameter(Mandatory=$false)][String]$RequestedLifetime = '01:00:00'
    )
    $baseXmlStr = @"
<?xml version="1.0" encoding="utf-8" ?>
<requesttoken xmlns="http://citrix.com/delivery-services/1-0/auth/requesttoken">
    <for-service>[ServiceID]</for-service>
    <for-service-url>
      [ServiceURL]
    </for-service-url>
    <reqtokentemplate></reqtokentemplate>
    <requested-lifetime>01:00:00</requested-lifetime>
</requesttoken>
"@
    $xml = [xml]$baseXmlStr;
    Write-Verbose "Build message for $ForService |  URL:$ForServiceURL"
    $xml.requesttoken['for-service'].InnerText = $ForService
    $xml.requesttoken['for-service-url'].InnerText = $ForServiceURL
    if(-not [String]::IsNullOrEmpty($ReqTokenTemplate)){
        $xml.requesttoken['reqtokentemplate'].InnerText = $ReqTokenTemplate
    }
    $xml.requesttoken['requested-lifetime'].InnerText = $RequestedLifetime
    return $xml
}

function New-LaunchParamsMessage{
    <#
    .SYNOPSIS
        A launchparams template
    .DESCRIPTION
        Internal function.
    .PARAMETER ClientName
        A string identifying the client (any characters except null (0) or newline characters. It is the client's responsibility to use a value that will behave appropriately 
    .PARAMETER ClientAddress
        The IPv4 or IPv6 address of the client, as claimed by the client
    .PARAMETER DeviceID
        A string identifying the client device
    .PARAMETER Audio
        The audio settings for the session, one of the following:
        [ high | medium | low | off ]
    .PARAMETER ColorDepth
        The colour depth for the session, one of the following:
        [16 | 256 | high | truecolor ]
    .PARAMETER Display
        The display type for the session, one of the following:
        [seamless |  percent | absolute | fullscreen]
    .PARAMETER DisplayPercent
        Only if display=percent
        The percentage of the screen to be used for the session
        [ 0 < percent ≤ 100]
    .PARAMETER TransparentKeyPassthrough
        Set the behavior of the windows keys etc., one of the following:
        [local | remote | fullscreenonly ]
    .PARAMETER SpecialFolderRedirection
        Are the special folders directed, one of the following:
        [true | false ]
    .PARAMETER ClearTypeRemoting
        Are ClearType fonts remoted, one of the following:
        [true | false ]
    .PARAMETER ShowDesktopViewer
        Should the desktop viewer be used as the ICA client.
        [true | false ]
    .REMARKS
        For more details, please refer to Store Services API mannual
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][String]$ClientName = $env:COMPUTERNAME,
        [Parameter(Mandatory=$false)][String]$ClientAddress = (Get-MyIPv4Address),
        [Parameter(Mandatory=$false)][String]$DeviceID = $ClientName,
        [Parameter(Mandatory=$false)]
        [ValidateSet('high','medium','low','off',IgnoreCase=$false)]
        [String]$Audio = 'high',
        [Parameter(Mandatory=$false)]
        [ValidateSet('16','256','high','truecolor',IgnoreCase=$false)]
        [String]$ColourDepth='16',
        [Parameter(Mandatory=$false)]
        [ValidateSet('seamless','percent','absolute','fullscreen',IgnoreCase=$false)]
        [String]$Display='seamless',
        [Parameter(Mandatory=$false)]
        [ValidateScript({($_ -gt 0) -and( $_ -le 100)})]
        [double]$DisplayPercent=100,
        [Parameter(Mandatory=$false)]
        [ValidateSet('local','remote','fullscreenonly',IgnoreCase=$false)]
        [string]$TransparentKeyPassthrough='fullscreenonly',
        [Parameter(Mandatory=$false)]
        [string]$SpecialFolderRedirection='false',
        [Parameter(Mandatory=$false)]
        [string]$ClearTypeRemoting='false',
        [Parameter(Mandatory=$false)]
        [string]$ShowDesktopViewer='false'        
    )    
    #Attention:Device name seems could not contain symbols like "."
    $SpecialFolderRedirection=$SpecialFolderRedirection.ToLower()
    $ClearTypeRemoting=$ClearTypeRemoting.ToLower()
    $ShowDesktopViewer=$ShowDesktopViewer.ToLower()
    $xmlText = 
@"
<?xml version="1.0" encoding="utf-16"?>
<launchparams xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns="http://citrix.com/delivery-services/1-0/launchparams">
    <deviceId>$ClientName</deviceId>
    <clientName>$ClientName</clientName>
    <clientAddress>$ClientAddress</clientAddress>    
    <audio>$Audio</audio>
    <display>$Display</display>
    <displayPercent>$DisplayPercent</displayPercent>
    <transparentKeyPassthrough>$TransparentKeyPassthrough</transparentKeyPassthrough>
    <specialFolderRedirection>$SpecialFolderRedirection</specialFolderRedirection>
    <clearTypeRemoting>$ClearTypeRemoting</clearTypeRemoting>
    <showDesktopViewer>$ShowDesktopViewer</showDesktopViewer>
    <colourDepth>$ColourDepth</colourDepth>
</launchparams>
"@
    Write-Verbose "Build LaunchParam Message as $xmlText"
    return [xml]$xmlText
}

function New-SessionParameterMessage{  
    <#
    .SYNOPSIS
        Create a SessionParameters message
    .DESCRIPTION
        Internal function.
    .PARAMETER Ticket
        The ticket field from get from the launched result xml.
    .PARAMETER IncludeActive
        Include active sessions or not
    .AppsOnly
        Include app sessions only.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][String[]]$Ticket,
        [Parameter(Mandatory=$false)][Switch]$IncludeActive,
        [Parameter(Mandatory=$false)][Switch]$AppsOnly        
    )
    $ClientName = $env:COMPUTERNAME
    $DeviceID = $ClientName   
    $xmlText=
@"
<?xml version="1.0"?>
<sessionParams xmlns="http://citrix.com/delivery-services/1-0/sessionparams">
<clientName>$ClientName</clientName>
<deviceId>$DeviceID</deviceId>
"@    

    if ($Ticket){
        $xmlText += "<tickets>"
        foreach($tick in $Ticket){
            $xmlText += "<ticket>$tick</ticket>"
        }
        $xmlText += "</tickets>"
    }
    else{
        $xmlText += 
@"
<includeActiveSessions>$($IncludeActive.ToString().ToLower())</includeActiveSessions>
<appSessionsOnly>$($AppsOnly.ToString().ToLower())</appSessionsOnly>
"@

    }
    $xmlText += "</sessionParams>" 
    Write-Verbose 'SessionParameterMessage created:'           
    Write-Verbose $xmlText 
    return [xml]$xmlText    
}
#endregion Messages functions
#region Read functions
function Read-TokenResponse{
    <#
    .SYNOPSIS
        Parse the token response message and return the hashtable
    .DESCRIPTION
        Internal function to process token messages
    .PARAMETER XML
        The xml object contains token message.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][xml]$Xml
    )    
    if ($Xml.LastChild.xmlns -ne 'http://citrix.com/delivery-services/1-0/auth/requesttokenresponse'){
        throw "Read-RequestTokenResponse: XML Namespace $($Xml.LastChild.xmlns) does not match with 'http://citrix.com/delivery-services/1-0/auth/requesttokenresponse'."
    }
    $TokenResponse = @{
        'for-service' = $Xml.requesttokenresponse['for-service'].InnerText;
        'issued' = $Xml.requesttokenresponse.issued;
        'expiry' = [DateTime]::Parse($Xml.requesttokenresponse.expiry);
        'lifetime' = $Xml.requesttokenresponse.lifetime;
        'token-template' = $Xml.requesttokenresponse['token-template'];
        'token' = $Xml.requesttokenresponse.token                
    }
    return $TokenResponse
}

function Read-CitrixAuth{
    <#
    .SYNOPSIS
        Return a hash table from CitrixAuth string
    .Description
        Internal function.
    .PARAMETER CitrixAuthString
        The auth string returned after authenticate chanllenge
    .NOTES
        Please reference the Security Token Service API v1.2 for details.

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]$CitrixAuthString
    )
    $Reg = 'CitrixAuth realm="(.*?(?#ServiceID))"\, reqtokentemplate="(.*?(?#Template))"\, reason="(.*?(?#Reason Description))"\, locations="(.*?(?#URL List))", serviceroot-hint="(.*?(?#ServiceRoot))"$'
    #                                    1                                    2                                3                                        4                                   5                                    
    if($CitrixAuthString -match $Reg){
        [hashtable]$challengeInfo = @{
            'for-service'         = $Matches[1];
            'template'            = $Matches[2];
            'reason-description' = $Matches[3];
            'url-list'           = $Matches[4]  -split '\|';
            'for-service-url'       = $Matches[5];
        }
        Write-Verbose "Read-AuthChallengeString: Parsed successfully."
        return $challengeInfo        
    }    
    throw "Read-AuthChallengeString: The challenge string could not be parsed correctly. Please confirm its format:$CitrixAuthString."
    
}

function Read-RequestTokenResponse{
    <#
    .SYNOPSIS
        Read the RequestTokenResponse-1 XML which contains authenticate form to be filled in. Return as an hash table
    .DESCRIPTION
        Internal function
    .PARAMETER Xml
        The xml returned after token request sent
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][xml]$Xml
    )    
    if ($Xml.AuthenticateResponse.xmlns -ne 'http://citrix.com/authentication/response/1'){
        throw "Read-RequestTokenResponse: XML Namespace:$($Xml.AuthenticateResponse.xmlns) does not match 'http://citrix.com/authentication/response/1'."
    }
    $authResp = @{
        'Status'       = $Xml.AuthenticateResponse.Status;
        'Result'       = $Xml.AuthenticateResponse.Result;
        'StateContext' = $Xml.AuthenticateResponse.StateContext;                                   
    }
    if($Xml.AuthenticateResponse['AuthenticationRequirements'] -ne $null){
            $authResp['PostBackURL'] = $Xml.AuthenticateResponse.AuthenticationRequirements.PostBack
    }
    
    return $authResp
}

function Read-ResponseBodyAsString{
    <#
    .SYNOPSIS
        Read a HttpWebResponse body as string        
    .DESCRIPTION
        Internal function
    .PARAMETER Response 
        The response object.
    #>
    param(
        [Parameter(Mandatory=$true)][System.Net.HttpWebResponse]$Response
    )
    [System.IO.Stream] $receiveStream = $Response.GetResponseStream()
    [System.Text.Encoding] $encode = [System.Text.Encoding]::GetEncoding('utf-8')
    [System.IO.StreamReader] $readStream = New-Object "System.IO.StreamReader" -ArgumentList $receiveStream,$encode
    [string] $s = $readStream.ReadToEnd()
    $receiveStream.Close()
    return $s
}
function Read-LaunchData{
    <#
    .SYNOPSIS
        Extract info from launchdata xml file into a hashtable
    .DESCRIPTION
        Internal function.
    PARAMETER Xml
        The launch request response xml.
    #>
    param(
        [Parameter(Mandatory=$true)][xml]$Xml
    )
    $dataObj = @{}
    $dataObj['status'] = $Xml.launch.status
    $dataObj['resultType'] = $Xml.launch.result.type
    $dataObj['result'] = $Xml.launch.result[$dataObj['resultType']]
    Write-Verbose "Read-LaunchData:Status [$($Xml.launch.status)]"

    return $dataObj
}
#endregion Read functions
function Get-ErrorLable{
<#
    .SYNOPSIS
        Function to check error field from AuthenticateResponse xml.
    .DESCRIPTION
        Internal function.
    .PARAMETER Xml
        Result xml.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][xml]$Xml
    )
    $mng = [System.Xml.XmlNamespaceManager] $Xml.NameTable
    
    $mng.AddNamespace('e',$Xml.AuthenticateResponse.xmlns)
        
    $ErrorNodes = $Xml.SelectNodes("//e:Label[e:Type='error']",$mng)    
    $ErrorLabels = @()
    foreach($node in $ErrorNodes){
        $ErrorLabels += @{            
            'Text' = $node.Text;            
        }
    }
    return $ErrorLabels
}
#region Resources 
function Get-Resources{
    <#
    .SYNOPSIS
        Try to get resources enumeration 
    .DESCRIPTION
        This function utilizes the Resource service of StoreFront and enumerate all resources accessable to the user
    .PARAMETER StoreURL
        The store URL, which should end with '\Citrix\Store'
        *Attention* Please note the protocol your Store service is using, if Https is enabled, the url should start with https, otherwize http.
        **Attention** Currently this module does not support Web Proxy(Web Receiver), so do not pass in the URL end with '\Citrix\StoreWeb'
    .PARAMETER Domain
        The login domain of user
    .PARAMETER UserName
        The username to login
    .PARAMETER Password
        Credential password for the user.        
    .OUTPUTS
        XML
    #>
    [CmdletBinding(DefaultParameterSetName='ByToken')]
    param(        
        [Parameter(Mandatory=$true)][String]$StoreURL,
        [Parameter(Mandatory=$true,ParameterSetName='ByToken')][String]$Token,
        [Parameter(Mandatory=$true,ParameterSetName='ByCredential')][String]$Domain,
        [Parameter(Mandatory=$true,ParameterSetName='ByCredential')][String]$UserName,
        [Parameter(Mandatory=$true,ParameterSetName='ByCredential')][String]$Password
    )

    $StoreURL = $StoreURL.TrimEnd('/ ')
    switch($PSCmdlet.ParameterSetName){
        'ByToken' {
            $requestParams = @{
                'URL' = "$StoreURL/resources/v2";
                'Method' = 'GET';
                'Accept' = 'application/vnd.citrix.resources+xml' ;
                'ContentType' = 'application/x-www-form-urlencoded';            
                'Headers' = @{'Authorization'="CitrixAuth $Token";}
            }                      
            $resp = Invoke-HttpRequest @requestParams                              
            if($resp.StatusCode -eq  [System.Net.HttpStatusCode]::OK){
                Write-Verbose "Get-Resources:Success."
                $respBody = Read-ResponseBodyAsString -Response $resp  
                $resp.Close()              
                $xmlResources = [xml]$respBody
                return $xmlResources
            }            
            throw "Get-Resources: HTTP Error Status: $($resp.StatusCode) .Please check whether the StoreURL should start with http or https."
        }
        'ByCredential' {
            $resp = Invoke-HttpRequest -URL "$StoreURL/resources/v2" -Method 'GET'             
            if ($resp.StatusCode -eq [System.Net.HttpStatusCode]::Unauthorized){
                #Authorize procedure with Domain, UserName and Password
                $params = @{
                    'Domain'=$Domain;
                    'UserName'=$UserName;
                    'Password'=$Password;
                    'CitrixAuthString'= $resp.Headers['WWW-Authenticate'] 
                }
                $resp.Close()
                $serviceToken = Request-Token @params                
                Add-TokenToCache -token $serviceToken               
                return (Get-Resources -StoreURL $StoreURL -Token $serviceToken.Token)
            }
            else{                                
                if ($resp.StatusCode -eq 'NotFound'){
                    throw "Get-Resources: HTTP Error Status: $($resp.StatusCode). Please confirm the StoreURL parameter.`n **Note**:StoreFront Web URL is NOT supported yet.`n If your URL ends with \xxxWeb then try to remove the 'Web' from it"
                }                
                throw "Get-Resources: HTTP Error Status: $($resp.StatusCode)."
            }
        }
    }                
}

function Get-ResourceByName{
<#
    .SYNOPSIS
        Find resources based on 'title' field from resources xml
    .DESCRIPTION
        This function read resource names from the xml object returned by Get-Resources
    .PARAMETER Name
        The name of resources. Support wildcard.
    .PARAMETER Xml
        The xml object to be parsed.
    .OUTPUTS
        String[]
        An string array of matched resource name (s)
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][xml]$Xml,
        [Parameter(Mandatory=$true)][String]$Name
    )        
    
    $mng = [System.Xml.XmlNamespaceManager] $Xml.NameTable
    $mng.AddNamespace('e',$Xml.resources.xmlns)
    $mng.AddNamespace('a',$Xml.resources.a)
    
    $xmlNames = Get-ResourcesNames -Xml $Xml 
    Write-Verbose "------------------------------"
    Write-Verbose "List all resources: `n$xmlNames"
    Write-Verbose "-------------------------------"
    $exactNames = @($xmlNames | Where-Object {$_ -like $Name})

    $resNodes = @()
    foreach($ename in $exactNames){
        $resNodes += $Xml.SelectNodes("/e:resources/e:resource[e:title='$ename']",$mng)
    }
    return ,$resNodes
}

function Get-ResourcesNames{
<#
    .SYNOPSIS
        Return a list of resource names           
    .DESCRIPTION
        This function read all resource names from the xml object returned by Get-Resources    
    .PARAMETER Xml
        The xml object to be parsed.
#>   
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][xml]$Xml
    )
    return $Xml.resources.resource | %{$_.title}
}

function Get-ICAFileResource{
    <#
    .SYNOPSIS
        Request ICA file from the URL with launch parameters, then return the path ICA file saved into.    
    .DESCRIPTION
        Internal function
    .PARAMETER ICAURL
        The ICA request URL.
    .PARAMETER Token
        The token string get from Request-Token
    .PARAMETER LaunchParams
        A hashtable of launch parameters.
        Please refer to Store Service API manual for details.
    .PARAMETER ExpectLaunchFailure
        Specified if we expect the ICA request to StoreFront to fail
	.PARAMETER Retry
		Retry times if the response status is 'retry'. Default to 30 times.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$ICAURL,
        [Parameter(Mandatory=$true)][String]$Token,
        [Parameter(Mandatory=$false)][hashtable]$LaunchParams = @{},
        [Switch]$ExpectLaunchFailure,
		[Parameter(Mandatory=$false)][int]$Retry=30
    )
    $xmlBody = New-LaunchParamsMessage @LaunchParams
    $icaLaunchParams = @{
        'URL'    = $ICAURL
        'Method' = 'POST';
        'Accept' = 'application/vnd.citrix.launchdata+xml';
        'ContentType' = 'application/vnd.citrix.launchparams+xml';                         
        'Headers' = @{'Authorization'="CitrixAuth $Token"}
        'StringBody'  = $xmlBody.OuterXml
    }
    $resp = Invoke-HttpRequest @icaLaunchParams
    if($resp.StatusCode -ne [System.Net.HttpStatusCode]::OK){
        $Script:Temp = $resp.Headers
        throw "Get-ICAFileResource:Unexpected response.$($resp.StatusCode)" 
    }
    [xml]$icaBody = Read-ResponseBodyAsString -Response $resp
    $resp.Close()
    $launchResult = Read-LaunchData -Xml $icaBody

    if ($ExpectLaunchFailure)
    {
        if ($launchResult.status -ne "failure")
        {
            throw "Expected launch status to be 'failure' but was '$($launchResult.status)'"
        }
        else
        {
            return
        }
    }
	
    $Script:Temp = $launchResult
    switch($launchResult.status){
        'success'{
            Write-Verbose "Creating ica file..."    
            $icaFilePath = New-IcaFile -Xml $icaBody
            return $icaFilePath
            break;
            }
        'retry'{                                                         
                if(($launchResult.result | Get-Member -MemberType Property -Name 'reason') -ne $null){
                    Write-Verbose "Retrying due to: $($launchResult.result.reason)"
                }
                else{
                    Write-Verbose "Need retry..."
                }
                if(($launchResult.result | Get-Member -MemberType Property -Name 'after') -ne $null){
                    #Wait before retry
                    Write-Verbose "Retry after $($launchResult.result.after)"
                    Start-Sleep $launchResult.result.after
                }
                $ICAURL = $launchResult.result.url
				if ($Retry -eq 0) {
					throw "Retry reached maximum times, abandon..."
				}
				$Retry -= 1
                return Get-ICAFileResource -ICAURL $ICAURL -Token $Token -LaunchParams $LaunchParams -Retry $Retry                              
            }
        'failure'{    
            switch($launchResult.resultType){
                'error'{
                    throw "Get-ICAFileResource: Error encountered getting ICA - $($launchResult.result.id + ':' + $launchResult.result['text'] )"
                    break;
                }
                'other'{
                    throw "Get-ICAFileResource: Failed get ICA file due to 'Other' reasons"
                }
                'default'{
                    throw "Unsupport resultType `"$($launchResult.resultType)`""
                }
            }                
        }
    }        
}

function Invoke-ResourceByNameCore{
    <#
        .SYNOPSIS
            Request and invoke a resource(Application/Desktop) from given StoreFront URL
        .DESCRIPTION
            Utilize the launch service provided by Store Services API 2.5_V1
        .PARAMETER StoreURL
            The store URL, which should end with '\Citrix\Store'
            *Attention* Please note the protocol your Store service is using, if Https is enabled, the url should start with https, otherwize http.
            **Attention** Currently this module does not support Web Proxy(Web Receiver), so do not pass in the URL end with '\Citrix\StoreWeb'
        .PARAMETER Domain
            The login domain of user
        .PARAMETER UserName
            The username to login
        .PARAMETER Password
            Credential password for the user.
        .PARAMETER ResourceName
            The resource's name(Application/Desktop)
		.PARAMETER ClientType
            The type of client which accepts only 'IcaClient' and 'OnlinePlugin'
			The default value of this parameter is 'IcaClient'
			You can ignore this parameter unless you are using OnlinePlugin as a client,
			.e.g Launch a second hop from VDA(or TSVDA) in a scenario of session passthrough.
        .PARAMETER ExpectLaunchFailure
            Specified when the callers expects the ICA launch request to fail. Specifically, this when the ICA file is requested from StoreFront
        .OUTPUTS
            Hashtable
            The output of this function is an hashtable which contains two items:
                - Process 
                    The process info of wfica32.exe 
                - Ticket
                    The session ticket, which could be used for logoff/disconnect the session later
        .EXAMPLE
            Invoke "Citrix Desktop" from go.citrite.net                        
            $ResInfo = Invoke-ResourceByNameCore `
                -StoreURL     'Https://go.citrite.net/Citrix/Store'; `
                -Domain       'citrite';                             `
                -UserName     'user0';                               `
                -Password     'password01' ;                         `
                -ResourceName 'Citrix Desktop'
    #>
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory=$true)]$StoreURL,        
        [Parameter(Mandatory=$true)][String]$Domain,
        [Parameter(Mandatory=$true)][String]$UserName,
        [Parameter(Mandatory=$true)][String]$Password,
        [Parameter(Mandatory=$true)][String]$ResourceName,
        [Parameter(Mandatory=$false)][Hashtable]$LaunchParams=@{},
		[Parameter(Mandatory=$false)][string][ValidateSet('IcaClient', 'OnlinePlugin')]$ClientType='IcaClient',
        [Switch]$ExpectLaunchFailure

    )        
	write-host $LaunchParams
    $StoreURL = $StoreURL.TrimEnd('/ ')
    Write-Verbose "---$StoreURL---"
    $resParams=@{
        'StoreURL' = $StoreURL;
        'Domain' = $Domain;
        'UserName' = $UserName;
        'Password' = $Password;
    }
    $resourceXml = Get-Resources @resParams       
    $resourceNodes = Get-ResourceByName -Xml $resourceXml -Name $ResourceName 

    if($resourceNodes.count -eq 1){
        if(($resourceNodes[0] | Get-Member -Name 'launchica' )-ne $null){
            $icaUrl = $resourceNodes[0].launchica.url            
            Write-Verbose "$StoreURL/resources/v2_$UserName"
            $token = Get-TokenFromCache -URL "$StoreURL/resources/v2" -Username $UserName     
            if($token -eq $null){
                throw 'Invoke-ResourceByNameCore:Cannot find token in cache.'
            }       
        }
        else{
            #Could not launch session of a Citrix.MPS.Document type application
            throw "Invoke-ResourceByNameCore: The resource [$ResourceName] does not support ica launch"
        }
    }
    else{
        if($resourceNodes.count -lt 1){
            throw "No resources named $ResourceName"
        }                
        throw "Multiple resources match $ResourceName"
    }

    if ($ExpectLaunchFailure)
    {
        Get-ICAFileResource -ICAURL $icaUrl -Token $token -LaunchParams $LaunchParams -ExpectLaunchFailure

        # Launch request will have failed so we have no ICA file to actually launch. Test was successful
        Write-Verbose "ICA launch request failed as expected."
        return
    }
    else
    {
	write-host $launchParams
    $icaFile = Get-ICAFileResource -ICAURL $icaUrl -Token $token -LaunchParams $LaunchParams
    }

    #return $icaFile
	if($ClientType -eq 'OnlinePlugin')
	{
		$exePath = Get-DefaultOnlinePluginExePath
		$sessionInfo = Invoke-ICAFile -IcaFilePath $icaFile -ICAClientPath $exePath
	}
    else
	{
		$sessionInfo = Invoke-ICAFile -IcaFilePath $icaFile
	}
    return $sessionInfo
}
#endregion Resources 
#region ICA 
function Invoke-ICAFile{
    <#
    .SYNOPSIS
        Start a new process for ICA session. Return the session info object.
    .PARAMETER IcaFilePath
        The file location of ICA file to be launched.
    .PARAMETER ICAClientPath
        The file location of ICAClient exe program
    .OUTPUTS
            Hashtable
            The output of this function is an hashtable which contains two items:
                - Process 
                    The process info of wfica32.exe 
                - Ticket
                    The session ticke, which could be used for logoff/disconnect the session later
    
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][String]$IcaFilePath,
        [Parameter(Mandatory=$false)][String]$ICAClientPath = (Get-DefaultIcaClientExePath)
    )
    if (-not [System.IO.File]::Exists($IcaFilePath)){
        throw "Invoke-ICAFile: Could not found ica file at $IcaFilePath"
    }
    $ticket = Get-TicketFromICAFile -IcaFilePath $IcaFilePath
    $proc = Start-Process -FilePath $ICAClientPath -ArgumentList $IcaFilePath -PassThru
    
    $sessInfo = @{
        'Process' = $proc;
        'Ticket' = $ticket
    }
    return $sessInfo
}

function Get-TicketFromICAFile{
    <#
    .SYNOPSIS
        Read the ICA file to get the Logon Ticket
    .DESCRIPTION
        This function read ticket string from ICA file which could be used for disconnect/logoff session
        Internal function
    .PARAMETER IcaFilePath
        The file location of ICA file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][String]$IcaFilePath
    )
    if (-not [System.IO.File]::Exists($IcaFilePath)){
        throw "Get-TicketFromICAFile: Could not found ica file at $IcaFilePath"
    }
    $null,$ticket = (Get-Content -Path $IcaFilePath | ?{$_.StartsWith('LogonTicket=')}) -split '='
    return $ticket.Trim()
}

function Invoke-ICAResourceLaunch{
    <#
        .SYNOPSIS
            Invoke a request to launch a resouce via ICA protocol
        .DESCRIPTION
            Internal function
        .PARAMETER ICAURL
            The url to request ICA.
        .PARAMETER Token
            The token string 
        .PARAMETER LaunchParam
            The launch parameters described in Store Service API manual
        .PARAMETER ICAClientPath
            Path of the ICAClient exe program.
            
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$ICAURL,
        [Parameter(Mandatory=$true)][String]$Token,
        [Parameter(Mandatory=$false)][hashtable]$LaunchParams = @{},
        [Parameter(Mandatory=$false)][String]$ICAClientPath = (Get-DefaultIcaClientExePath)        
    )  
    $icaFilePath = Get-ICAFileResource @PSBoundparameters
    Write-Verbose 'Launching...'  
    return (Invoke-ICAFile -IcaFilePath $icaFilePath)
}

function New-IcaFile{
    <#
    .SYNOPSIS
        Create ica file from launch response message[xml]
    .DESCRIPTION
        Internal function
    .PARAMETER Xml
        The xml object to be parsed
    .PARAMETER Path
        The folder path at where .ica file be generated
	.PARAMETER BackupPath
        The folder path at where .xml(backup of .ica file for debug) be generated
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][xml]$Xml,
        [Parameter(Mandatory=$false)][String]$Path = $env:temp,
		[Parameter(Mandatory=$false)][String]$BackupPath = "c:\IcaFile"
    )
    if (-Not(Test-Path $BackupPath))
	{
		New-Item -Path $BackupPath -ItemType Directory > $null
	}
    $Xml.Save("$BackupPath\ICA$((Get-Date).Ticks).xml")
    $mng = [System.Xml.XmlNamespaceManager] $Xml.NameTable
    
    $mng.AddNamespace('e',$Xml.launch.xmlns)
        
    $icaNode = $Xml.SelectNodes("//e:ica",$mng)   
    $icaContent = $icaNode.Item(0).'#text'
    $icaTitle = Get-ICAField -IcaContent $icaContent -FieldNames 'Title'

    $icaName = $Path.TrimEnd('\') + '\' + (ConvertTo-ValidFileName -FileName $icaTitle) + "-$((Get-Random).ToString())" 
    $mainIcaName = $icaName + '.ica'

    $icaContent | Out-File -FilePath $mainIcaName -Encoding utf8 -Force
    #Create a backup ica 
    $icaContent | Out-File -FilePath "$icaName-bk.ica" -Encoding utf8 -Force
    Write-Verbose "New-IcaFile: ICA file has been created at $mainIcaName"
    return $mainIcaName
}

function ConvertTo-ValidFileName{
    <#
    .SYNOPSIS
        Covert a string into valid file name by removing invalid characters
    .PARAMETER FileName
        The file name string    
    .PARAMETER FillBlanksWith
        Specifies string to fill the blank characters with. Default is '_'
    #>
    param(
        [Parameter(Mandatory=$true)][String]$FileName,
        [Parameter(Mandatory=$false)][String]$FillBlanksWith='_'
    )    
    if(-not [String]::IsNullOrEmpty($FillBlanksWith)){
        $FileName = $FileName -replace ' ',$FillBlanksWith
    }
    return [RegEx]::Replace($FileName, "[{0}]" -f ([RegEx]::Escape([String][System.IO.Path]::GetInvalidFileNameChars())), '') 

}

function Get-ICAField{
    <#
    .SYNOPSIS
        Get field value from a ICA file content
    .PARAMETER IcaContent
        The string content of ICA file
    .PARAMETER FieldNames
        An array of field names
    #>
    param(
        [Parameter(Mandatory=$true)][String]$IcaContent,
        [Parameter(Mandatory=$true)][String[]]$FieldNames
    )
    $IcaContentLines = $IcaContent -split "`n"
    
    $results = @()
    foreach($field in $FieldNames){
        $fieldValues = @()
        foreach($line in $IcaContentLines){
            $key,$value = $line -split '='
            if($key -eq $field){
                $fieldValues += $value
            }
        }
        $results += $fieldValues
    }
    return $results
}

function Get-DefaultOnlinePluginExePath{
    <#
    .SYNOPSIS
        Check the default location of wfica32.exe and return valid path
    .DESCRIPTION
        Internal function.    
    #>
    $paths = @(
                "$env:ProgramFiles\Citrix\Online Plugin\wfica32.exe",
                "${env:ProgramFiles(x86)}\Citrix\Online Plugin\wfica32.exe"
                )    
    $exePath = $paths | ForEach-Object{
                         if (Test-Path $_){
                            return $_
                            }
                        }
    if ($exePath -eq $null){
        throw 'Could not find "Online Plugin" under ProgramFiles folder, please confirm it is installed or specify the path manually.'
    }
    return $exePath
}

function Get-DefaultIcaClientExePath{
    <#
    .SYNOPSIS
        Check the default location of wfica32.exe and return valid path
    .DESCRIPTION
        Internal function.    
    #>
    $paths = @(
                "$env:ProgramFiles\Citrix\ICA Client\wfica32.exe",
                "${env:ProgramFiles(x86)}\Citrix\ICA Client\wfica32.exe"
                )    
    $exePath = $paths | ForEach-Object{
                         if (Test-Path $_){
                            return $_
                            }
                        }
    if ($exePath -eq $null){
        throw 'Could not find "ICA Client" under ProgramFiles folder, please confirm it is installed or specify the path manually.'
    }
    return $exePath
}
#endregion ICA
function Get-EndPoints{
<#
.SYNOPSIS
    Get end points services of the store
.PARAMETER StoreURL
    The store URL of the site(e.g https://xxx/Citrix/Store)
.OUTPUTS
    An array of end point services hashtable objects        
#>
    param(
        [Parameter(Mandatory=$true)]$StoreURL
    )
    $StoreURL = $StoreURL.TrimEnd('/ ')
    $requestParams = @{
        'URL' = $StoreURL + '/endpoints/v1'     
        'Method' = 'GET'
        'Accept' = 'application/vnd.citrix.endpoints+xml'        
    }
    $resp = Invoke-HttpRequest @requestParams
    if($resp.StatusCode -eq [System.Net.HttpStatusCode]::OK){
        Write-Verbose "Get endpoints success."
        $respBody = Read-ResponseBodyAsString -Response $resp 
        $resp.Close()
        $endPoints = [xml]$respBody
        $points = @()
        foreach($point in $endPoints.endpoints.endpoint){
            $currPoint = @{
                'id' = $point.id
                'url' = $point.url                
            }
            if ((Get-Member -InputObject $point -MemberType Properties -Name 'capabilities') -ne $null){
                $currPoint['capabilities'] = $point.capabilities
            }
            else{
                $currPoint['capabilities'] = $null
            }
            $points += $currPoint
        }
        return $points
    }
    throw "Get-EndPoints:HTTP Error Code $($resp.StatusCode)"    
}

#region Session
function Get-AvailableSessions{
    <#
    .SYNOPSIS
        Enumerate all available sessions for current user            
    .PARAMETER StoreURL
        The store URL, which should end with '\Citrix\Store'
        *Attention* Please note the protocol your Store service is using, if Https is enabled, the url should start with https, otherwize http.
        **Attention** Currently this module does not support Web Proxy(Web Receiver), so do not pass in the URL end with '\Citrix\StoreWeb'
    .PARAMETER Domain
        The login domain of user
    .PARAMETER UserName
        The username to login
    .PARAMETER Password
        Credential password for the user.
    .PARAMETER ResourceName
        The resource's name(Application/Desktop)
    .PARAMETER IncludeActiveSessions
        A switch specifying whether to include active sessions.
    .PARAMETER AppSessionsOnly 
        A switch specifying whether to only return only application sessions.
        A value of true will list app sessions from any XD7 farm and preXD7 XenApp app hosting farm. Pre XD7 XenDesktop hosting farms will not be queried so as not to disconnect active desktops (a side effect of querying sessions).
        Where a XenApp hosts both apps and desktops the session queries will continue to disconnect a users active desktop.
        Farm exclusion based on version can be overridden to list all farm application sessions by setting the LegacyWorkspaceControl value to on (off is the default) in the Store <farm/> element.        
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][String]$StoreURL,                
        [Parameter(Mandatory=$true,ParameterSetName='ByToken')][String]$Token,
        [Parameter(Mandatory=$true,ParameterSetName='ByCredential')][String]$Domain,
        [Parameter(Mandatory=$true,ParameterSetName='ByCredential')][String]$UserName,
        [Parameter(Mandatory=$true,ParameterSetName='ByCredential')][String]$Password,
        [Parameter(Mandatory=$false)][Switch]$IncludeActiveSessions,
        [Parameter(Mandatory=$false)][Switch]$AppSessionsOnly
    )
    $StoreURL = $StoreURL.TrimEnd('/')
    $strBody = (New-SessionParameterMessage -IncludeActive:$IncludeActiveSessions -AppsOnly:$AppSessionsOnly).OuterXml
    $requestParams = @{
        'URL' = "$StoreURL/sessions/v1/available";
        'Method' = 'POST';
        'Accept' = 'application/vnd.citrix.sessionstate+xml' ;
        'ContentType' = 'application/vnd.citrix.sessionparams+xml;charset=utf-8';        
        'StringBody' = $strBody;    
    }
    switch($PSCmdlet.ParameterSetName){
        'ByToken' {           
            $requestParams['Headers'] = @{'Authorization'="CitrixAuth $Token"}                                  
            $resp = Invoke-HttpRequest @requestParams                                   
            if($resp.StatusCode -eq  [System.Net.HttpStatusCode]::OK){
                Write-Verbose "Get-AvailableSessions: HTTP Status Code: Success."
                $respBody = Read-ResponseBodyAsString -Response $resp                
                $resp.Close()
                $xmlSessions = [xml]$respBody
                return $xmlSessions
            }                        
            throw "Get-AvailableSessions:HTTP Error Code: $($resp.StatusCode)"
        }
        'ByCredential'{           
            $resp = Invoke-HttpRequest @requestParams           
            if ($resp.StatusCode -eq [System.Net.HttpStatusCode]::Unauthorized){
               #Authorize procedure with Domain, UserName and Password
               $params = @{
                   'Domain'=$Domain;
                   'UserName'=$UserName;
                   'Password'=$Password;
                   'CitrixAuthString'= $resp.Headers['WWW-Authenticate'] 
                }
                $resp.Close()
                $serviceToken = Request-Token @params                                         
                #TO-DO: Cache token                                
                return Get-AvailableSessions -StoreURL $StoreURL -Token $serviceToken.token
            }
            else{
                Write-Verbose 'Get-AvailableSessions:Unexpected Response.'                
                throw "Get-AvailableSessions:HTTP Error Code: $($resp.StatusCode)"
            }
        }
    }
}

function Resume-Session{
<#
    .SYNOPSIS
        Reconnect to a session that has been disconnected before
    .PARAMETER StoreURL
        The store URL, which should end with '\Citrix\Store'
        *Attention* Please note the protocol your Store service is using, if Https is enabled, the url should start with https, otherwize http.
        **Attention** Currently this module does not support Web Proxy(Web Receiver), so do not pass in the URL end with '\Citrix\StoreWeb'
    .PARAMETER Domain
        The login domain of user
    .PARAMETER UserName
        The username to login
    .PARAMETER Password
        Credential password for the user.    
    .PARAMETER SessionAppName
        The name of session's initial app.It's the InitialProgram field in ICA file with the pound prefix removed.
        *Wildcard is support.
#>
    param(
        [Parameter(Mandatory=$true)][String]$StoreURL,        
        [Parameter(Mandatory=$true)][String]$Domain,
        [Parameter(Mandatory=$true)][String]$UserName,
        [Parameter(Mandatory=$true)][String]$Password,
        [Parameter(Mandatory=$true)][String]$SessionAppName,
        [Parameter(Mandatory=$false)][Hashtable]$LaunchParams=@{}
    )
    Write-Verbose "Resume-Session:Trying to reconnect to session $SessionAppName"
    $StoreURL = $StoreURL.TrimEnd('/')
    $sessParams = $PSBoundParameters
    $null= $sessParams.Remove('SessionAppName')
    $sessXml = Get-AvailableSessions @sessParams
    $session = Get-SessionByName -Xml $sessXml -SessionAppName $SessionAppName
    if(($session -is [Array]) -and ($session.Count -gt 1)){
        throw "More than one session with the $SessionAppName found. Please confirm the name"
    }
    if($session -eq $null){
        throw "No sessions found with name matches $SessionAppName "
    }
    Write-Verbose "$StoreURL/sessions/v1_$UserName"   
    $token = Get-TokenFromCache -URL "$StoreURL/sessions/v1" -Username $UserName  
    if($token -eq $null){
        throw 'Resume-Session:Cannot find token in cache.'
    }       
    $icaUrl = $session.launchica.url
    $icaFile = Get-ICAFileResource -ICAURL $icaUrl -Token $token -LaunchParams $LaunchParams      
    #return $icaFile
    $sessionInfo = Invoke-ICAFile -IcaFilePath $icaFile
    Write-Verbose 'Resume-Session:Done'
    return $sessionInfo    
}

function Get-SessionByName{
<#
    .SYNOPSIS
        Find session based on 'initialapp' field from sessions xml
    .DESCRIPTION
        This function is used to find session from the xml returned by Get-AvailableSessions
    .PARAMETER Xml
        The xml get from Get-AvailableSessions
    .PARAMETER SessionAppName
        The name of session's initialapp
    .OUTPUTS
        String[]
        An string array of matched resource name (s)
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][xml]$Xml,
        [Parameter(Mandatory=$true)][String]$SessionAppName
    )       
    $sessions = @() 
    foreach($sess in $Xml.sessionState.sessions.session){
        if($sess.initialapp -like $SessionAppName){
        Write-Verbose "Get-SessionByName: Found session $($sess.initialapp) match $SessionAppName "
            $sessions += $sess
        }
    }
    return $sessions
}
function Stop-Session{
    <#
    .SYNOPSIS
        Disconnect or log off a session on current machine by Logon Ticket
    .DESCRIPTION
        If Logoff parameter appears or is $true, logoff operation will be done. Otherwize, simply disconnect
    .PARAMETER StoreURL
        The store URL, which should end with '\Citrix\Store'
        *Attention* Please note the protocol your Store service is using, if Https is enabled, the url should start with https, otherwize http.
        **Attention** Currently this module does not support Web Proxy(Web Receiver), so do not pass in the URL end with '\Citrix\StoreWeb'
    .PARAMETER Domain
        The login domain of user
    .PARAMETER UserName
        The username to login
    .PARAMETER Password
        Credential password for the user.
    .PARAMETER Ticket
        The ticket[s] which identified the session to be operated on
    .PARAMETER Action
        Specify the way to stop session, it could be either disconnect or log off.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][String]$StoreURL,                
        [Parameter(Mandatory=$true,ParameterSetName='ByToken')][String]$Token,
        [Parameter(Mandatory=$true,ParameterSetName='ByCredential')][String]$Domain,
        [Parameter(Mandatory=$true,ParameterSetName='ByCredential')][String]$UserName,
        [Parameter(Mandatory=$true,ParameterSetName='ByCredential')][String]$Password,
        [Parameter(Mandatory=$true)][String[]]$Ticket,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Logoff','Disconnect')][String]$Action
    )
    $StoreURL = $StoreURL.TrimEnd('/')
    $strBody = (New-SessionParameterMessage -Ticket $Ticket).OuterXml
    if($Action -ne 'Logoff'){
        $url = "$StoreURL/sessions/v1/disconnect"
    }
    else{
        $url = "$StoreURL/sessions/v1/logoff"
    }
    $requestParams = @{
        'URL' = $url;
        'Method' = 'POST';
        'Accept' = 'application/vnd.citrix.sessionresults+xml' ;
        'ContentType' = 'application/vnd.citrix.sessionparams+xml;charset=utf-8';        
        'StringBody' = $strBody;    
    }
    switch($PSCmdlet.ParameterSetName){
        'ByToken' {           
            $requestParams['Headers'] = @{'Authorization'="CitrixAuth $Token"}                                  
            $resp = Invoke-HttpRequest @requestParams                                   
            if($resp.StatusCode -eq  [System.Net.HttpStatusCode]::OK){
                Write-Verbose "Stop-Session:HTTP Status code: Success."
                $respBody = Read-ResponseBodyAsString -Response $resp                
                $resp.Close()
                $xmlSessions = [xml]$respBody                
                return $xmlSessions.sessionResult.status -eq 'success'
            }                                      
            throw "Stop-Session: HTTP Error Status: $($resp.StatusCode)."
        }
        'ByCredential'{           
            $resp = Invoke-HttpRequest @requestParams           
            if ($resp.StatusCode -eq [System.Net.HttpStatusCode]::Unauthorized){
               #Authorize procedure with Domain, UserName and Password
               $params = @{
                   'Domain'=$Domain;
                   'UserName'=$UserName;
                   'Password'=$Password;
                   'CitrixAuthString'= $resp.Headers['WWW-Authenticate'] 
                }
                $resp.Close()
                $serviceToken = Request-Token @params                         
                #TO-DO:Cache token                        
                return Stop-Session -StoreURL $StoreURL -Token $serviceToken.token -Ticket $Ticket -Action $Action
            }
            else{                                
                throw "Stop-Session: HTTP Error Code: $($resp.StatusCode)"
            }
        }
    }
}
function Invoke-ResourceByName{
       <#
        .SYNOPSIS
            Request and invoke a resource(Application/Desktop) from given StoreFront URL WITH RETRY
            **Note**: Before calling this please make sure no other sessions(no wfica32 processes) 
        .DESCRIPTION
            Utilize the launch service provided by Store Services API 2.5_V1
        .PARAMETER StoreURL
            The store URL, which should end with '\Citrix\Store'
            *Attention* Please note the protocol your Store service is using, if Https is enabled, the url should start with https, otherwize http.
            **Attention** Currently this module does not support Web Proxy(Web Receiver), so do not pass in the URL end with '\Citrix\StoreWeb'
        .PARAMETER Domain
            The login domain of user
        .PARAMETER UserName
            The username to login
        .PARAMETER Password
            Credential password for the user.
        .PARAMETER ResourceName
            The resource's name(Application/Desktop)
		.PARAMETER ClientType
            The type of client which accepts only 'IcaClient' and 'OnlinePlugin'
			The default value of this parameter is 'IcaClient'
			You can ignore this parameter unless you are using OnlinePlugin as a client,
			.e.g Launch a second hop from VDA(or TSVDA) in a scenario of session passthrough.
        .PARAMETER AwaitTime
            The seconds wait after the resource invoke request being sent, default to 60 seconds
        .PARAMETER RetryTime
            The max retry time. Default to 5
        .OUTPUTS
            Hashtable
            The output of this function is an hashtable which contains two items:
                - Process 
                    The process info of wfica32.exe 
                - Ticket
                    The session ticket, which could be used for logoff/disconnect the session later
    #>
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory=$true)]$StoreURL,        
        [Parameter(Mandatory=$true)][String]$Domain,
        [Parameter(Mandatory=$true)][String]$UserName,
        [Parameter(Mandatory=$true)][String]$Password,
        [Parameter(Mandatory=$true)][String]$ResourceName,
        [Parameter(Mandatory=$false)][Hashtable]$LaunchParams=@{},
		[Parameter(Mandatory=$false)][string][ValidateSet('IcaClient', 'OnlinePlugin')]$ClientType='IcaClient',
        [Parameter(Mandatory=$false)]$AwaitTime=5,
        [Parameter(Mandatory=$false)]$RetryTime=5
    )     
    $InvokeParams = @{} + $PSBoundParameters;
    $InvokeParams.Remove('AwaitTime');
    $InvokeParams.Remove('RetryTime');    
    $cnt = 0;
    if(Test-WFICA32ProcessExists){
        Write-Warning "Found wfica32.exe process(es), retry function could not work properly under this scenario."
    }
    while($cnt -le $RetryTime){
        try{
			write-host @InvokeParams
            $sessInfo = Invoke-ResourceByNameCore @InvokeParams
        }
        catch{        
            Write-Warning "Launch faild due to: $_"    
            $cnt +=1;
            if($cnt -le $RetryTime ){
                Write-Verbose "Wait $AwaitTime to start another retry"                            
                Start-Sleep -Seconds $AwaitTime
                Write-Verbose "Invoke-ResourceByName: Retry for the $cnt time"
                continue;
            } 
            else{
                break;
            }       
        }
        Write-Verbose "No exception throwed during launching. Wait 15 seconds to check session status on client."
        Start-Sleep -Seconds 15
        Write-Verbose "Test if Wfica32 process exits..."
        if(Test-WFICA32ProcessExists){
            Write-Verbose "Wfica32 process detected. Abort invoke retry."
            return $sessInfo
        }        
        $cnt +=1;
        if($cnt -le $RetryTime ){
            Write-Verbose "Wait $AwaitTime seconds to start another retry."                            
            Start-Sleep -Seconds $AwaitTime
            Write-Verbose "Invoke-ResourceByName: Retry for the $cnt time"
        }        
    }
    throw "Invoke Session Retried timeout..."   
}

#endregion Session
#region ICA Client Validatoin   


function Test-WFICA32ProcessExists{
<#
.SYNOPSIS
    This function check if the process Wfica32 is running
#>
    [CmdletBinding()]
    param()
    $appExists = ( Get-Process | Where-Object { $_.ProcessName -eq "wfica32"} ) -ne $null
    return $appExists
}

function Initialize-UIAssemblies{
    <#
    .SYNOPSIS
        Initialize the assemblies used for UI automation        
    .DESCRIPTION
        Internal function.
    #>
    [void] [Reflection.Assembly]::Load('UIAutomationClient, ' +
        'Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35')
    [void] [Reflection.Assembly]::Load('UIAutomationTypes, ' +
        'Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35')
    $Script:PropertyTypeDict = @{
        'type' = [System.Windows.Automation.AutomationElement]::LocalizedControlTypeProperty;
        'name' = [System.Windows.Automation.AutomationElement]::NameProperty;        
        'enabled'=[System.Windows.Automation.AutomationElement]::IsEnabledProperty;
        'processid' = [System.Windows.Automation.AutomationElement]::ProcessIdProperty;
        'rect' = [System.Windows.Automation.AutomationElement]::BoundingRectangleProperty
    }
}

Initialize-UIAssemblies
function Get-Root{
    <#
    .SYNOPSIS
        Get root UI element
    .DESCRIPTION
        Internal function.
    #>
    $root = [Windows.Automation.AutomationElement]::RootElement
    return $root
}

function Get-UIProperty{
    <#
    .SYNOPSIS
        Return the property specified for an element
    .DESCRIPTION
        Internal function
    .PARAMETER Element
        Target element
    .PARAMETER Property
        Name of the property. The support properties are defined in $Script:PropertyTypeDict
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false,ValueFromPipeline=$true)][System.Windows.Automation.AutomationElement]$Element=(Get-Root),
        [Parameter(Mandatory=$true)][String]$Property
    )    
    if ($Script:PropertyTypeDict.ContainsKey($Property)){
        $Element.GetCurrentPropertyValue($Script:PropertyTypeDict[$Property])
    }
    else{
        throw "Get-UIProperty:Could not found property $Property defined in PropertyTypeDict."        
    }        
}

function Get-DescendentElementByProperty{
<#
    .SYNOPSIS
        Return the elements match certain property condition
    .DESCRIPTION
        Get descent elements by property.
    .PARAMETER Root
        The root element to search down
    .PARAMETER PropertyMatch
        A hashtable of properties and values.e.g.@{'type'= 'window';'name'='Lync'}
    .EXAMPLE
        Get a window named Lync
        $target = @{'type'= 'window';'name'='Lync'}
        Get-UIElementByProperty -PropertyMatch $target
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][System.Windows.Automation.AutomationElement]$Root=(Get-Root),
        [Parameter(Mandatory=$true)][Hashtable]$PropertyMatch
    )
    $lastCondition = $null
    $currCondition = $null
    foreach($propertyType in $PropertyMatch.Keys){
        if($lastCondition -eq $null)
        {
            $currCondition = $lastCondition = New-Object Windows.Automation.PropertyCondition($Script:PropertyTypeDict[$propertyType],$PropertyMatch[$propertyType])
        }
        else{
            $currCondition = New-Object -TypeName 'Windows.Automation.PropertyCondition' -ArgumentList $Script:PropertyTypeDict[$propertyType],$PropertyMatch[$propertyType]
            $lastCondition = New-Object -TypeName 'System.Windows.Automation.AndCondition' -ArgumentList $lastCondition, $currCondition
        }
    }
    return $Root.FindAll([Windows.Automation.TreeScope]::Descendants,$lastCondition)
}

function Get-CDViewerErrorDialogText{
    <#
    .SYNOPSIS
        Check if there's any error dialog after Citrix Desktop session being launched.
    .DESCRIPTION
        If there's an error message prompted, this function will return the content of error message.
        **Attention** The error message usually appears after several seconds after DesktopViewer being started, so please wait enough time before testing this or use a loop to track.
    .PARAMETER ProcessID
        The processID number
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][Int32]$ProcessID
    )
    #To-DO: This currently could only be used for CDViewer, not wfica32. 
   
    $CDVDialog = Get-DescendentElementByProperty -PropertyMatch @{'processid'=$ProcessID;'type'='window';'name'='Desktop Viewer'}
    if ($CDVDialog -ne $null){                        
        $dialogText = Get-DescendentElementByProperty -Root $CDVDialog -PropertyMatch @{'type'='pane'} | Get-UIProperty -Property 'name'
            return $dialogText        
    }
}

#endregion ICA Client Validatoin

function Invoke-AnonymousSession
{
    <#
    .SYNOPSIS
        Launch a Anonymous session
    .DESCRIPTION
        Using Laci to launch a anonymous session
        Running this function need to install the component of laci
    .PARAMETER AnonSite
        The site where anonymous store in
    .PARAMETER ResourceName
        The name of the Desktop or App resource which has been deliveried
    .EXAMPLE
        Invoke-AnonymousSession -AnonSite "DDC.bvt.local/Citrix/AnonStoreweb" -ResourceName "Notepad_TSVDA"
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)][string] 
        $AnonSite,
        [Parameter(Mandatory=$true)][string] 
        $ResourceName 
    )
    if ( (Get-Command 'Get-LaciCGApps').Parameters.Keys.Contains('All') ) {
        $apps =  Get-LaciCGApps -Anonymous -Site $AnonSite -All
    }
    else {
        $apps =  Get-LaciCGApps -Anonymous -Site $AnonSite
    }  
    $apps = $apps | Where-Object -FilterScript {$_.ApplicationName -eq $ResourceName}
    $ica = Resolve-LaciCGApp $apps
    Send-LaciWILauncherSessionLaunch -IcaFile $ica 
}
#region Initialize
$ErrorActionPreference ='stop'
Set-StrictMode -Version 2.0
$Script:Tokens = @{}
Initialize-Assemblies
#endregion Initialize

Export-ModuleMember -Function Get-ResourcesNames, Get-Resources, Invoke-HttpRequest, Read-ResponseBodyAsString, Get-ResourceByName, Invoke-ICAResourceLaunch, `
Get-AvailableSessions,Invoke-ICAFile,Get-TokenCache,Get-TempDebug,Stop-Session,Get-CDViewerErrorDialogText,Get-EndPoints,Resume-Session,Get-SessionByName,Invoke-ResourcebyNameCore,Invoke-ResourceByName,Invoke-AnonymousSession
