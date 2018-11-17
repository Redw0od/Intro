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
.\AWS-Launch-IsntanceJob -I ((aws ec2 run-instances --launch-template  LaunchTemplateId=$LaunchTemplate).Instances -join "" | ConvertFrom-JSON) -C (Get-Credential) -AD (Get-Credential) -D "stanton.wtf" 

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
        [string]$Domain = "stanton.wtf",
    [Alias('O')]
        [string]$OU,
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
