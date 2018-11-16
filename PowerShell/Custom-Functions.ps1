
#Display friendly console information
Function Write-Info{
    param([string]$Text,[switch]$Progress=$false,[switch]$Return=$false,[string]$Logfile="")
    if($Return)
    {
        Write-Host -NoNewline ("`r")
    }
    Write-Host -NoNewline "[ "
    Write-Host -NoNewline -ForegroundColor Cyan "INFO"
    Write-Host -NoNewline " ] "
    if($Progress)
    {
        Write-Host -NoNewline $Text
    }
    else
    {
        Write-Host $Text
    }
    if($Logfile){
        Write-Log "<WI:$($MyInvocation.ScriptLineNumber)> $Text" $Logfile
    }
}

#Display friendly console failure messages
Function Write-Fail{
    param([string]$Text,[switch]$Progress=$false,[string]$Logfile="")    
    if($Progress)
    {
        Write-Host -NoNewline ("`r")
    }
    Write-Host -NoNewline "[ "
    Write-Host -NoNewline -ForegroundColor Red "FAIL"
    Write-Host -NoNewline " ] "
    Write-Host $Text
    if($Logfile){
        Write-Log "<WF:$($MyInvocation.ScriptLineNumber)> $($Text)" $Logfile
    }
}

#Display friendly console completion message
Function Write-Done{
    param([string]$Text,[switch]$Progress=$false,[string]$Logfile="")    
    if($Progress)
    {
        Write-Host -NoNewline ("`r")
    }
    Write-Host -NoNewline "[ "
    Write-Host -NoNewline -ForegroundColor Green "DONE"
    Write-Host -NoNewline " ] "
    Write-Host $Text
    if($Logfile){
        Write-Log "<WD:$($MyInvocation.ScriptLineNumber)> $Text" $Logfile
    }
}

#Display waiting animation for a job to complete
Function Write-ProgressJob {
    param([string]$job)  
    $saveY = [console]::CursorTop
    $saveX = 2   
    $str = '||||','////','----','\\\\'     
    do {
        $str | %{         
            [console]::setcursorposition($saveX,$saveY)
            Write-Host -Object $_ -NoNewline
            Start-Sleep -Milliseconds 100
        } 
        if ((Get-Job -Name $job).state -eq 'Running') 
        {
            $running = $true
        }
        else 
        {
            $running = $false
        }
    } while ($running)
}

#Display waiting animation for a set amount of time
Function Write-Progress{
    param([int]$seconds = 1) 
    $saveY = [console]::CursorTop
    $saveX = 2   
    $str = '||||','////','----','\\\\'
    $spinner = 0   
    if(-not ([string]::IsNullOrEmpty($saveY)))
    {
     
        for($i=0;$i -lt $seconds*10;$i++)
        {
            [console]::setcursorposition($saveX,$saveY)
            Write-Host $str[$spinner] -NoNewline
            [console]::setcursorposition(0,$saveY)
            Start-Sleep -Milliseconds 100
            $spinner++
            if($spinner -eq 4)
            {
            $spinner = 0
            }
        }
    }
}

#Test ICMP response from network device
Function Ping-Computer{
    param([System.String]$Computer)    
	$PingResult = Test-Connection -ComputerName $Computer -Count 1 -Quiet
    Write-Debug "Ping Result: $PingResult"
	if($PingResult){
        Write-Verbose "Computer Responds"
        return $true
    }    
    Write-Verbose "No Computer Response"
    return $false    
}

#Test if PowerCLI scripts are imported
Function Load-PowerCLI {  
    try
    {
        $hide = Get-PowerCLIVersion -ErrorAction Stop
        return $false
    }
    catch
    {
        Write-Info "Loading VMware Core environment"
        return $true
    }
}

#Parse the Common Name from a Distinguished Name
Function DN2CN{
    param([Parameter(Mandatory=$true)][System.String]$DN)
    $DNArray = $DN -split ','
    $CN = $DNArray[0].Substring(3)
    return $CN
}

#Identical to Ping-Computer... why?
Function Resolve-Computer{
    param([Parameter(Mandatory=$true)][System.String]$Computer)    
	$PingResult = Test-Connection -ComputerName $Computer -Count 1 -Quiet
    Write-Debug "Ping Result: $PingResult"
	if($PingResult){
        Write-Verbose "Computer Responds"
        return $true
    }    
    Write-Verbose "No Computer Response"
    return $false    
}

#Check if script is running as Administrator.. Alternatively use #Require -Administrator
Function Test-Administrator {  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}

#Returns The time difference from Now and passed value in text format
Function Run-Time {
    param([Parameter(Mandatory=$true)][DateTime]$StartTime,[switch]$FullText=$false)  
    $RunTime = (Get-Date) - $StartTime
    $Hours = [Math]::Floor($RunTime.TotalSeconds / 3600)
    $Minutes = [Math]::Floor($RunTime.TotalSeconds / 60) - ($Hours * 60)
    $Seconds = [Math]::Round($RunTime.TotalSeconds) - ($Minutes * 60)
    if($FullText){
        if($Hours -gt 0){
            return "$($Hours) hours, $($Minutes) minutes, $($Seconds) seconds."
        }
        elseif ($Minutes -gt 0){
            return "$($Minutes) minutes, $($Seconds) seconds."
        }
        else{
            return "$([Math]::Round($RunTime.TotalSeconds,2)) seconds."
        }
    }
    Else{
        if($Hours -gt 0){
            return "$($Hours) : $($Minutes) : $($Seconds)"
        }
        elseif ($Minutes -gt 0){
            return "$($Minutes) : $($Seconds)"
        }
        else{
            return "$([Math]::Round($RunTime.TotalSeconds,2))"
        }
    }
}

#Load Key value from stored CSV file
Function Script-Status {  
    param(  [Parameter(Mandatory=$true)][string]$Script, 
            [string]$File = "c:\Logs\PowerShellValues.csv")
    $result = $false      
    if(Test-Path $File){    
        $CSV = (Import-Csv $File | ?{ $_.Key -eq $Script })
        if($CSV -ne ""){
            $result = $CSV.Value
        }
    }
    return $result
}

#Update the Key value in stored CSV file
Function Script-Update {  
    param(  [Parameter(Mandatory=$true)][string]$Script, 
            [string]$Value, 
            [string]$File = "c:\Logs\PowerShellValues.csv")
    if(Test-Path $File){    
        $CSV = Import-Csv $File
        $Update = $false 
        foreach($i in $CSV){
            if($i.Key -eq $Script){
                $i.Value = $Value
                $Update = $true
            }
        }
        if(!$Update){
            $Row = ""
            $Row = New-Object PsObject -Property @{ Key=$Script; Value = $Value}
            $CSV += $Row
        }
    }
    else{
        if(!(Test-Path (Split-Path $File))){  
            mkdir -Path (Split-Path $File) -Force | Out-Null
        }    
        $CSV = New-Object System.Collections.ArrayList
        $Row = New-Object PsObject -Property @{ Key=$Script; Value = $Value}
        $CSV += $Row
    }
    try{
        $CSV | Export-Csv $File -Force -NoTypeInformation
    }
    catch{
        throw "Error writing Script File $($File)"
    }
}

# Write entry to log file. Inserts timestamp and appends the file defined by $Logfile parameter
Function Write-Log { 
    param(  [Parameter(Mandatory=$true)][AllowEmptyString()][string]$LogEntry, 
            [Parameter(Mandatory=$true)][string]$Logfile ) 
    Write-Verbose "Write-Log\LogPath: $($Logfile)"
    Write-Verbose "Write-Log\LogEntry: $($LogEntry)"
    $LogDate = get-date -Format "yyyyMMdd" 
    $LogEntry = "$($LogDate) <$($MyInvocation.ScriptLineNumber)> $($LogEntry)" 
    if(!(Test-Path (Split-Path $Logfile))){ mkdir -Path (Split-Path $Logfile)  | Out-Null}
    if ($Logfile) { Add-content $Logfile -value $LogEntry.replace("`n","") } 
    $Error.Clear()
} 

#Use to remove NTFS file attribute
Function Clear-FileAttribute {
    param(  [Parameter(Mandatory=$true)][string]$file,
            [Parameter(Mandatory=$true)][string]$attribute )
    $allExcept = ([int]0xFFFFFFFF -bxor ([System.IO.FileAttributes]$attribute).value__)
    $fileObject =(Get-Item $file -force)
    $fileObject.Attributes = [System.IO.FileAttributes]($fileObject.Attributes.value__ -band $allExcept)
    if($?){$true;} else {$false;}
} 

#Use to enable NTFS file attribute
Function Set-FileAttribute {
param(  [Parameter(Mandatory=$true)][string]$file,
        [Parameter(Mandatory=$true)][string]$attribute )
    $fileObject =(Get-Item $file -force);
    $fileObject.Attributes = $fileObject.Attributes -bor ([System.IO.FileAttributes]$attribute).value__;
    if($?){$true;} else {$false;}
}

#Use to read NTFS file attribute
Function Get-FileAttribute {
    param(  [Parameter(Mandatory=$true)][string]$file, 
            [Parameter(Mandatory=$true)][string]$attribute )
    $val = ([System.IO.FileAttributes]$attribute).value__;
    if(((Get-Item -force $file).Attributes -band $val) -eq $val){$true;} else { $false; }
} 

#Get the Current Line Number in the Script
Function Get-CurrentLineNumber{
    $MyInvocation.ScriptLineNumber
}

#Test if File or Folder Exists, Is Writable
Function Validate-Path {
    param(  [Parameter(Mandatory=$true)][string]$Path,
            [switch]$Exit,
            [string]$LogFile )
    $DebugLine = Get-CurrentLineNumber
    If(Test-Path $Path -ErrorAction SilentlyContinue){ 
        try{
            $Validate = Get-ChildItem $Path
        }
        catch{
            Write-Log "<CF:$DebugLine> $Error" $Logfile
            If($Exit){exit}else{return $false}
        }
    }
    else{
        Write-Log "Path does not exist: $Path" $LogFile
        If($Exit){exit}else{return $false}
    }
    return $true
}

#Test if File or Folder Exists, Is Writable
Function Validate-Log {
    param([Parameter(Mandatory=$true)][string]$Path)
        If(!(Test-Path $Path)){ 
            try{
                mkdir -Path (Split-Path $Path) -ErrorAction Stop | Out-Null
            }
            catch{
                Write-Fail $Error
                return $false
            }
        }
        try{
            [io.file]::OpenWrite($Path).close()
        }
        catch{
            Write-Fail $Error
            return $false
        }
    return $true
}

Function Make-Directory {
    param(  [Parameter(Mandatory=$true)][string]$NewPath,
            [string]$Logfile )
    If(!(Test-Path $NewPath)){
        $NewPath = "$($NewPath)."
        If(!(Test-Path (Split-Path $NewPath))){
            try{
                mkdir -Path (Split-Path $NewPath) -ErrorAction Stop | Out-Null
                return $true
            }
            catch{
                If($Logfile){
                    Write-Log ("<CF:$(Get-CurrentLineNumber)> $($Error) : $($NewPath)") $Logfile
                }
                return $false
            }
        }
    }
    return $true
}

# SIG # Begin signature block
# MIIIPQYJKoZIhvcNAQcCoIIILjCCCCoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUe98Jfc0SUYFU36p/vH14/1ZG
# UcqgggWuMIIFqjCCBJKgAwIBAgITbgAAAKzOi+ol+RGLKQAAAAAArDANBgkqhkiG
# 9w0BAQ0FADBBMRMwEQYKCZImiZPyLGQBGRYDbmV0MRUwEwYKCZImiZPyLGQBGRYF
# aHBmb2QxEzARBgNVBAMTClBTTUNFUlRTMDEwHhcNMTgwMjA5MjIwMDM0WhcNMTkw
# MjA5MjIwMDM0WjBvMRMwEQYKCZImiZPyLGQBGRYDbmV0MRUwEwYKCZImiZPyLGQB
# GRYFaHBmb2QxDDAKBgNVBAsTA0ZPRDEOMAwGA1UECxMFVXNlcnMxDDAKBgNVBAsT
# A09wczEVMBMGA1UEAxMMTWlrZSBTdGFudG9uMIIBIjANBgkqhkiG9w0BAQEFAAOC
# AQ8AMIIBCgKCAQEAvk9oqgeTwJGtl8uZNUgf9gyqRi/Lxtyj8zrFlJqrW/yeuJAA
# /XeBQqyPMkBd3Eq6H7Xmx286JOsCH7O7MvZGAUoE7m9gg0nXVIUvADukwK1CMQgF
# ILrowvBYe6gusnn7a+kiYm68usv+OBU3UVcg7brOMZru6OisJFwwhw1HLzNOINwb
# /aFst4MgRIpUZkVr5y/p32N9uNwPbZDeE0GGIiavnnKzlTGBpSNHSUNq+l6yAr2w
# Gl6WS87MQYWXkXMMhdGRNSQJDwkwtw6uWIF0cee3TI2wqXIHTTWS3hzhVpnGnJ3w
# spoWhk2yXGXciP5zKd5uKInRrwqmjoeihjX8/QIDAQABo4ICazCCAmcwJQYJKwYB
# BAGCNxQCBBgeFgBDAG8AZABlAFMAaQBnAG4AaQBuAGcwEwYDVR0lBAwwCgYIKwYB
# BQUHAwMwDgYDVR0PAQH/BAQDAgeAMB0GA1UdDgQWBBTGErOn7vtJpZuLu1MtnX4m
# nK3M6zAfBgNVHSMEGDAWgBSlSAghybFdXgTP1bPcLwoWwleacDCByQYDVR0fBIHB
# MIG+MIG7oIG4oIG1hoGybGRhcDovLy9DTj1QU01DRVJUUzAxLENOPVBTTUNlcnRz
# MDEsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2Vz
# LENOPUNvbmZpZ3VyYXRpb24sREM9aHBmb2QsREM9bmV0P2NlcnRpZmljYXRlUmV2
# b2NhdGlvbkxpc3Q/YmFzZT9vYmplY3RDbGFzcz1jUkxEaXN0cmlidXRpb25Qb2lu
# dDCB3QYIKwYBBQUHAQEEgdAwgc0wgacGCCsGAQUFBzAChoGabGRhcDovLy9DTj1Q
# U01DRVJUUzAxLENOPUFJQSxDTj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1T
# ZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPWhwZm9kLERDPW5ldD9jQUNlcnRp
# ZmljYXRlP2Jhc2U/b2JqZWN0Q2xhc3M9Y2VydGlmaWNhdGlvbkF1dGhvcml0eTAh
# BggrBgEFBQcwAYYVaHR0cDovL3BzbWNlcnQwMS9vY3NwMC0GA1UdEQQmMCSgIgYK
# KwYBBAGCNxQCA6AUDBJtc3RhbnRvbkBocGZvZC5uZXQwDQYJKoZIhvcNAQENBQAD
# ggEBAGj5z+lYcJzFAN7dU/Wcok/uyG0K5FxvNAERyYMjIY/rR6jndFQbnd/qu7Vw
# AymOC8wDLYhoaYDs6XYzwA4aI5XkWslJPrS49nZPvqYcY0lXDPJX8Ryv85vdkIyc
# 55+LD6iDy7Q51sMinrOljSzhkpfQ/87izHXomxF1TyzGk/qURi8w6P5u6Lbf5F0s
# ri+MSAVEJrfAJZC/QIn9rVtGoxtEr7qLQOikGkDVrNZe+5hJtzkb9/hL5035VzTE
# XRW3TXZhvoE9Cno57Z5YYX7oK82VduDroo3Jxt/Bd9VCbhHlCIPu4HuqAGVKBIDn
# PMwnCQ9rZKD0uRWGUQwXjIFs9rMxggH5MIIB9QIBATBYMEExEzARBgoJkiaJk/Is
# ZAEZFgNuZXQxFTATBgoJkiaJk/IsZAEZFgVocGZvZDETMBEGA1UEAxMKUFNNQ0VS
# VFMwMQITbgAAAKzOi+ol+RGLKQAAAAAArDAJBgUrDgMCGgUAoHgwGAYKKwYBBAGC
# NwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUwlO2KCt4
# JpbZVjBUhS4b6lxXW6cwDQYJKoZIhvcNAQEBBQAEggEAoXUkr7jAZiTz2LhiNshK
# 2baMphgzAVlGNq4aw0h2BFptKKQ3NnJAyzMIAxFW41i+lWyggqyIdhKA3Ghh9mzk
# MRZP7vjKmZXQA0d9+8g5UVj71Q/hCeeKjsWOe7xCVC0CiBu3T0aMnlesxwSWYnzS
# uPBoiRP2gpixqllw2yVwcfz7U27NoN3HOJ2LGOG7gh/GruoGtlS1YLMNsljuwHcx
# rX7x1KEU9ng5piwSmdP+/5Y1vKRIdfdujr+qHII0lmMftqIn6mzyHfIkWYwRRlcA
# MnXZAY4iW5U2THpSFHcLqda6t6kt9XHCcb2tbW87mywMPWe9Kq3/+OjsfBGxw4D6
# PA==
# SIG # End signature block
