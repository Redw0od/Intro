<#
.SYNOPSIS   
Replace a VM with a new clone
    
.DESCRIPTION 
This script is built to assist with migrating dynamic scanners from existing scanners to new VMs.
	
.PARAMETER Computer
Computer to replace

.PARAMETER Creds
Crendentials to login to VM and change name and IP

.PARAMETER ADCreds
Crendentials to login to Domain and join the VM

.PARAMETER vCenter
vCenter server to create new VM on.

.PARAMETER Template
VM template to be cloned.

.PARAMETER IP
Assign specific IP address

.PARAMETER SaveAD 
Keep the old computer name in Active Directory

.PARAMETER Pool
Specify the resource pool for the new VM

.PARAMETER Folder
Specify the organizational folder for the new VM

.PARAMETER Datastore
Specify the datastore for the new VM

.PARAMETER Portgroup
Specify the portgroup to connect to.

.PARAMETER Test
Skip execution until Invoke commands	

.NOTES   
Name: Replace-VMJob.ps1
Author: Mike Stanton
Version: 1.0
DateCreated: 2017-8-31
DateUpdated: 2017-8-31

.EXAMPLE   
.\Replace-VM -Computer WebInspect-001 -Pool GOLD -Portgroup VLAN004

#>
[cmdletbinding()]
param(
    [string]
        $Computer,
    [pscredential]
        $Creds,
    [pscredential]
        $ADCreds,
    [string]
        $vCenter,
    [string]
        $IP,
    [string]
        $subnet,
    [string]
        $gateway,
    [string]
        $pdns,
    [string]
        $sdns,
    [switch]
        $SaveAD = $false,
    [string]$LogFile
)

$global:StartTime = Get-Date
$Error.Clear()
#Strict Mode v2 breaks vmWare modules
#Set-StrictMode -Version 2.0

#Load useful functions 
if(Test-Path ".\Custom-Functions.ps1"){. ".\Custom-Functions.ps1"}
elseif(Test-Path "S:\Custom-Functions.ps1"){. "S:\Custom-Functions.ps1"}
elseif(Test-Path "C:\Scripts\Custom-Functions.ps1"){. "C:\Scripts\Custom-Functions.ps1"}
elseif(Test-Path "\\$($env:USERDNSDOMAIN)\NETLOGON\Custom-Functions.ps1"){. "\\$($env:USERDNSDOMAIN)\NETLOGON\Custom-Functions.ps1"}

#VALIDATE PARAMETERS
$LogFile = "C:\Logs\Replace-VMJob-$($Computer).log"
Write-Info "Valid Logfile: $(Validate-Log $LogFile)" $LogFile

Write-Info "Computer = $Computer" $LogFile
Write-Info ("Local User = " + $Creds.UserName) $LogFile
Write-Info ("Local Pass = " + $Creds.Password) $LogFile
Write-Info ("AD User = " + $ADCreds.Username) $LogFile
Write-Info "vCenter = $vCenter" $LogFile
Write-Info "IP = $IP" $LogFile
Write-Verbose "gateway = $gateway"
Write-Verbose "subnet prefix = $subnet"
Write-Verbose "primary dns = $pdns"
Write-Verbose "secondary dns = $sdns"


Function Load-PowerCLI {  
    try
    {
        Get-PowerCLIVersion -ErrorAction Stop
        return $false
    }
    catch
    {
        return $true
    }
}

Function Connect-vCenter{
    param(    [string] $Server    )
    Write-Info "Connecting to vCenter: $($Server)" $LogFile
    If($global:DefaultVIServers.Count -eq 0){
        If(Ping-Computer $Server){
            try{
                Connect-viServer $Server | Out-Null
                Write-Info "Connection Established"  $LogFile 
            }
            catch{
                Write-Info "Failed to establish connection: $Error"  $LogFile        
                return $false
            }
        }
        else
        {
            Write-Info "Failed to Ping"  $LogFile 
            return $false
        }
    }
    else{
        Write-Info "Connection Exists"  $LogFile 
        return $true
    }
}

Function Quit-Script {
param([int] $code = 0,$Message="")
    Write-Info "Complete in $(Run-Time $global:StartTime -FullText)" $LogFile
    Write-Info $Message $LogFile
    exit $code
}

Function Load-VM{
param([string]$Computer)
    try
    {
        Write-Info "Attempting to Load VM details" $LogFile
        $global:VM= Get-VM $Computer -ErrorAction Stop
        Write-Info "VM details found." $LogFile
        return $true
    }
    catch
    {
        Write-Info "Failed to Load VM"  $LogFile 
        return $false
    }
}

Function Check-VMTools{
param([string]$Computer)
    try
    {
        Write-Info "Checking VMTools are accessible" $LogFile
        $global:VM = Get-VM $Computer
        if(($global:VM.extensionData.Guest.ToolsStatus) -eq "ToolsOK"){
            Write-Info ($global:VM.extensionData.Guest.ToolsStatus) $LogFile
            return $true
        }
        else{
            Write-Info "VMTools not loaded yet." $LogFile
            return $false
        }
    }
    catch
    {
        Write-Info "Error while checking VMTools status"  $LogFile 
        return $false
    }
}

Function Run-VMScript{
param([string]$Script,[pscredential]$Creds,[string]$Description = "")
    try
    {
        Write-Info "Attempting to Run VMScript: $Description" $LogFile        
        $Output = Invoke-VMScript -vm $global:VM -scripttype Powershell -scripttext $Script -guestcredential $Creds  -ErrorAction Stop
        $global:Output = $Output.ScriptOutput.trim().split("`r`n") | ?{$_ -ne ""}
        Write-Info "Script invoked successfully" $LogFile
        $global:Output | %{Write-Info "< $_ >" $LogFile }
        return $true
    }
    catch
    {
        Write-Info "Error while invoking script. Maybe UAC is enabled?"  $LogFile 
        $global:Output | %{Write-Info "< $_ >" $LogFile }
        return $false
    }
}

if(Load-PowerCLI){
    try{
        Write-Info "Loading VMware Core environment" $LogFile
        Import-Module VMware.VimAutomation.Core
    }
    catch{
        Write-Info "Failed to load PowerCLI environment" $LogFile
    }
}

#Connect to vCenter, try 5 times
################################
$Loops = 5
For($i=0;$i -lt $Loops;$i++){
    If(Connect-vCenter $vCenter){
        break
    }
    Start-Sleep -Seconds 5
}
if($i -ge $Loops){Quit-Script 1 "Failed to Connect to vCenter"}


#Load VM Details, try 10 times
################################
$Loops = 15
For($i=0;$i -lt $Loops;$i++){
    If(Load-VM $Computer){
        break
    }
    Start-Sleep -Seconds 60
}
if($i -ge $Loops){Quit-Script 1}
if($global:VM.PowerState -ne "PoweredOn"){Start-VM $global:VM}


#Check VMTools are ready, try 10 times
################################
$Loops = 10
For($i=0;$i -lt $Loops;$i++){
    If(Check-VMTools $Computer){
        break
    }
    Start-Sleep -Seconds 30
}


#Attempt to invoke VMScript, try 10 times
################################
$Command = "date"
$Loops = 10
For($i=0;$i -lt $Loops;$i++){
    If(Run-VMScript $Command $Creds "date"){
        break
    }
    Start-Sleep -Seconds 30
}
if($i -ge $Loops){Quit-Script 1}

#From this point, if we error, we push on
#$ProgressPreference='SilentlyContinue'

#Check current IP address
################################
$SetIP = $true
$Command = '(get-netipaddress -interfaceindex 20 -AddressFamily IPv4 ).IPAddress'
Run-VMScript $Command $Creds "Checking IP configuration" | Out-Null
$global:Output | %{
    if($_ -eq $IP){ $SetIP = $false}
    else{ Write-Info "$IP ne $_" $LogFile }
}

#Attempt to invoke VMScript and configure IP
################################
If($SetIP){
    $Command = '$net=Get-NetAdapter -Name Ethernet0;$net|New-NetIPAddress -IPAddress '+$IP+' -PrefixLength '+$subnet+' -DefaultGateway '+$gateway+';$net|Set-DNSClientServerAddress -ServerAddresses '+$pdns+','+$sdns
    While(!(Run-VMScript $Command $Creds "Setting IP configuration")){
        Start-Sleep -Seconds 30
    }
}

#Check current Computer Name
################################
$SetName = $true
$Command = "hostname"
Run-VMScript $Command $Creds "Checking VM Name" | Out-Null
$global:Output | %{
    if($_ -eq $Computer){ $SetName = $false}
    else{ Write-Info "VM needs to be renamed." $LogFile }
}

#Attempt to invoke VMScript and rename the VM, try 10 times
################################
If($SetName){
    $Command = 'Rename-Computer -Confirm:$false -Force -Restart -Newname ' + $Computer
    While(!(Run-VMScript $Command $Creds "Rename-Computer")){
        Start-Sleep -Seconds 5
        $Command = "hostname"
        Run-VMScript $Command $Creds "Checking VM Name" | Out-Null
        $global:Output | %{
            if($_ -eq $Computer){ break }
        }
        $Command = 'Rename-Computer -Confirm:$false -Force -Restart -Newname ' + $Computer
    }
}
else {
    Write-Info "Restarting VM" $LogFile
    Restart-VM $global:VM -Confirm:$false | Out-Null
}

#Wait for tools to go offline from reboot,
################################
$Counter = 0
$Restarts = 0
While(Check-VMTools $Computer){ 
    Start-Sleep -Seconds 2 
    $Counter++
    if($Counter -gt 30){ 
        Write-Info "Tool check failed, Restarting VM" $LogFile
        Restart-VM $global:VM -Confirm:$false | Out-Null
        $Counter = 0 
        $Restarts++
    }
    if($Restarts -gt 1) { 
        Write-Info "Stopping VM" $LogFile
        Stop-VM $global:VM -Confirm:$false | Out-Null
        Start-Sleep -Seconds 10
        Write-Info "Starting VM" $LogFile
        Start-VM $global:VM -Confirm:$false | Out-Null
        break 
    }
}

#Check VMTools are back online
################################
$Counter = 0
do{ 
    Start-Sleep -Seconds 30 
    $Counter++
    If($Counter -gt 20){break}
}While(!(Check-VMTools $Computer))


#Verify new computer name
################################
If($SetName){
$Command = "hostname"
    $Loops = 3
    For($i=0;$i -lt $Loops;$i++){
        If(Run-VMScript $Command $Creds){
            break
        }
        Start-Sleep -Seconds 30
    }
    If($global:Output -ne $Computer){
        Write-Info "Compuer name is: $($global:Output)" $LogFile
        Write-Info "Skipping Domain Join" $LogFile

    }
}

#Check Domain name
################################
$AddToDomain = $true
$Command = '$env:USERDNSDOMAIN'
$Loops = 3
For($i=0;$i -lt $Loops;$i++){
    If(Run-VMScript $Command $Creds){
        break
    }
    Start-Sleep -Seconds 30
}
If($global:Output -eq "hpfod.net"){
    Write-Info "Compuer domain is: $($global:Output)" $LogFile
    Write-Info "Skipping Domain Join" $LogFile
    $AddToDomain = $false
}

#Add VM to domain
################################
If($AddToDomain){
    $pwd = $ADCreds.GetNetworkCredential().Password
    $usr = $ADCreds.UserName
    $OU = "OU=Dynamic,OU=Servers,OU=FOD,DC=hpfod,DC=net"

    $Command = @"
`$domain = "hpfod.net"
`$password = "$pwd" | ConvertTo-SecureString -asPlainText -force;
`$username = "$usr";
`$ounit = "$OU"
`$credential = New-Object System.Management.Automation.PSCredential(`$username, `$password);
`$output = Add-Computer -DomainName `$domain -Credential `$credential -OUPath `$ounit -Force -Restart -Confirm:`$false -passthru *>&1
`$output.HasSucceeded
"@
    $Loops = 3
    For($i=0;$i -lt $Loops;$i++){
        If(Run-VMScript $Command $Creds "Adding VM to Domain"){
            break
        }
        Start-Sleep -Seconds 30
    }

#Wait for tools to go offline from reboot,
################################
    $Counter = 0
    $Restarts = 0
    While(Check-VMTools $Computer){ 
        Start-Sleep -Seconds 2 
        $Counter++
        if($Counter -gt 30){ Restart-VM $global:VM -Confirm:$false | Out-Null; $Counter = 0 ; $Restarts++}
        if($Restarts -gt 1) { Stop-VM $global:VM -Confirm:$false | Out-Null; Start-Sleep -Seconds 10; Start-VM $global:VM -Confirm:$false | Out-Null; break }
    }
}
#Check VMTools are back online
################################
$Counter = 0
do{ 
    Start-Sleep -Seconds 30 
    $Counter++
    If($Counter -gt 20){break}
}While(!(Check-VMTools $Computer))

#Attempt to invoke VMScript, try 10 times
################################
$Command = "date"
$Loops = 10
For($i=0;$i -lt $Loops;$i++){
    If(Run-VMScript $Command $Creds "date"){
        break
    }
    Start-Sleep -Seconds 30
}


#Enable UAC
################################
$Command = "New-ItemProperty -Path 'hklm:\Software\Microsoft\Windows\CurrentVersion\policies\system' -Name 'EnableLUA' -Value '1' -PropertyType DWORD -Force | Out-Null"
$Loops = 10
For($i=0;$i -lt $Loops;$i++){
    If(Run-VMScript $Command $Creds "Enable UAC"){
        break
    }
    Start-Sleep -Seconds 30
}

Quit-Script
$ProgressPreference='Continue'
