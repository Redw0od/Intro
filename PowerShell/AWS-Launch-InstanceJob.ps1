<#
.SYNOPSIS   
Replace a VM with a new clone
    
.DESCRIPTION 
This script is built to assist with migrating dynamic scanners from existing scanners to new VMs.
	
.PARAMETER Instance
JSON Formatted Instance information provided from AWS CLI

.PARAMETER Credentials
Crendentials to login to VM and run commands

.PARAMETER ADCredentials
Crendentials to join VM to the domain

.PARAMETER Domain
FQDN of the domain to join

.PARAMETER OU
The Organizational Unit to place the new VM computer account into. Uses Distinguished Name only.


.NOTES   
Name: AWS-Launch-IsntanceJob.ps1
Author: Mike Stanton
Version: 1.0
DateCreated: 2018-6-21
DateUpdated: 2018-6-21

.EXAMPLE   
.\AWS-Launch-IsntanceJob -I ((aws ec2 run-instances --launch-template  LaunchTemplateId=$LaunchTemplate).Instances -join "" | ConvertFrom-JSON) -C (Get-Credential) -AD (Get-Credential) -D "hpfod.net" 

#>
[cmdletbinding(SupportsShouldProcess)]
param(
    [Alias('I')]
        [object]$Instance,
    [Alias('C')]
        [pscredential]$Credentials,
    [Alias('AD')]
        [pscredential]$ADCredentials,
    [Alias('D')]
        [string]$Domain = "hpfod.net",
    [Alias('O')]
        [string]$OU = "OU=Dynamic,OU=Servers,OU=FOD,DC=hpfod,DC=net",
    [Alias('LF')]
        [string]  $LogFile = "$env:SYSTEMDRIVE\Logs\AWS_Launch_InstanceJob.log"
)

$StartTime = Get-Date
$Error.Clear()
Set-StrictMode -Version 2.0
$ProgressPreference='SilentlyContinue'
#Load useful functions 
if(Test-Path ".\Custom-Functions.ps1"){. ".\Custom-Functions.ps1"}
elseif(Test-Path "S:\Custom-Functions.ps1"){. "S:\Custom-Functions.ps1"}
elseif(Test-Path "C:\Scripts\Custom-Functions.ps1"){. "C:\Scripts\Custom-Functions.ps1"}
elseif(Test-Path "\\$($env:USERDNSDOMAIN)\NETLOGON\Custom-Functions.ps1"){. "\\$($env:USERDNSDOMAIN)\NETLOGON\Custom-Functions.ps1"}

#Initialize Variables
$InstanceID = $Instance.InstanceId
$InstanceState = $Instance.State.Name
$InstanceIP = $Instance.PrivateIpAddress
$Counter = 0

Write-Info "$InstanceID : InstanceState = $InstanceState : InstanceIP = $InstanceIP : Domain = $Domain : OU = $OU" $LogFile
Write-Info "$InstanceID : Local User = $($Credentials.UserName) : AD User = $($ADCredentials.UserName) :" $LogFile



do {
    Write-Info "$InstanceID : Checking Instance State in 10 Seconds. " $LogFile
    Start-Sleep -Seconds 10
    try
    {
        $InstanceState = (aws ec2 describe-instance-status --instance-id $InstanceID --query 'InstanceStatuses[0].SystemStatus.Details[0].Status' ) -join '' | ConvertFrom-JSON
        Write-Info "$InstanceID : Instance State = $InstanceState" $LogFile
    }
    catch
    {
        Write-Fail "$InstanceID : Error polling AWS. Exiting" $LogFile
        exit
    }
}while($InstanceState -ne '"passed"')


do {
    Write-Info "$InstanceID : Checking Instance Network Response in 10 seconds" $LogFile
    Start-Sleep -Seconds 10
    $Counter += 1
    If($Counter -gt 60){
        Write-Fail "$InstanceID : No Ping after 10 minutes. Moving on." $LogFile
        $Counter = 0
        break
    }
}while(!(Ping-Computer $InstanceIP))


[ScriptBlock]$InvokeTest = "date"
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $InstanceIP -Force

do {
    Write-Info "$InstanceID : Attempting to Invoke Script" $LogFile
    Start-Sleep -Seconds 5
    try
    {
        $Date = Invoke-Command -ComputerName $InstanceIP -ScriptBlock $InvokeTest -Credential $Credentials -ErrorAction Stop
        Write-Info "$InstanceID : Host Date = $Date" $LogFile
        $Responsive = $true
    }
    catch
    {
        $Responsive = $false
        $Counter +=  1
    }
    If($Counter -gt 10){
        Write-Fail "$InstanceID : Failed to run scripts over 10 times.  Exiting." $LogFile        
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value "" -Force 
        exit
    }
}while(!$Responsive)

[ScriptBlock]$InvokeCommand = "hostname"
try
{
    $HostName = Invoke-Command -ComputerName $InstanceIP -ScriptBlock $InvokeCommand -Credential $Credentials -ErrorAction Stop
    Write-Info "$InstanceID : HostName = $HostName" $LogFile
}
catch
{
    Write-Fail "$InstanceID : Failed to decifer hostname" $LogFile
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "" -Force 
    exit
}
try{
    Add-Computer -ComputerName $HostName -LocalCredential $Credentials -DomainName $Domain -Credential $ADCredentials -OUPath $OU -Force -Restart -ErrorAction Stop
    Write-Info "$InstanceID : Join domain command successful" $LogFile
}
catch{    
    Write-Fail "$InstanceID : Failed to join domain" $LogFile
}


Set-Item WSMan:\localhost\Client\TrustedHosts -Value "" -Force                                                             

Write-Info (Run-Time $StartTime -FullText) $LogFile
$ProgressPreference='Continue'

# SIG # Begin signature block
# MIIIPQYJKoZIhvcNAQcCoIIILjCCCCoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUFYNn7Xs9Ml2qW73Wu7IzdhPl
# Ib2gggWuMIIFqjCCBJKgAwIBAgITbgAAAKzOi+ol+RGLKQAAAAAArDANBgkqhkiG
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
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUkZWj1TMC
# G5jcLVKyVMAq4ifUZFQwDQYJKoZIhvcNAQEBBQAEggEAFG1yN8mWlWJnV7O8t6Px
# +aInVGwXdGZR0zs3egN1HUFAGUyD1bJCI6r7ql3LDRympRxPEEJ0OgECND5YQFPC
# IOuJVd7r7WaLrRext9RHAczXxnoDUO+cgBpXOJvY2YUOIROhO3oXsyvrJeuGaIo5
# SiiTJLnPsBzm05L4rNA5+7hLWBCkA6SVrs437kPcLm2vDH1Thz00KeKc/8wfQNSa
# /T1ccHrh7kt9jUN9aDDH0SzPyLiAuqD++g3e8f+RjDwMDLaOKLMSKdzhgT0xV8rM
# h1Gd3NQQw4cmAKepK98HRJYXCXTrh9Jzl9Nq0+WGTZz6Maq0kSRfjzFwzAokTcHb
# /g==
# SIG # End signature block
