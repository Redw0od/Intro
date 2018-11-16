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

.PARAMETER Gateway
Specify the gateway to connect to.

.PARAMETER Test
Skip execution until Invoke commands
	

.NOTES   
Name: Replace-VM.ps1
Author: Mike Stanton
Version: 0.1
DateCreated: 2017-8-31
DateUpdated: 2017-8-31

.EXAMPLE   
.\Replace-VM -Computer WebInspect-001 -Pool GOLD -Portgroup VLAN004

#>
[cmdletbinding(SupportsShouldProcess)]
param(
    [Alias('CN')]
        [string]$Computer = (Read-Host "Please enter VM name to modify"),
    [Alias('CR')]
        [pscredential]$Creds = (Get-Credential -UserName "Administrator" -Message "Enter credentials for local administrator"),
    [Alias('AD')]
        [pscredential]$ADCreds = (Get-Credential -Message "Enter credentials for Domain Joining"),
    [Alias('TP')]
        [string]$Template = $(if(($result = Read-Host "Enter a Template name [2012_WI_Template]") -eq ''){"2012_WI_Template"}else{$result}),
    [Alias('VC')]
        [string]$vCenter = $(if(($result = Read-Host "Enter a vCenter name [vcenter02.hpfod.net]") -eq ''){"vcenter02.hpfod.net"}else{$result}),
    [string]$IP,
    [switch]$SaveAD = $false,
    [Alias('PL')]
        [string]$Pool = $(if(($result = Read-Host "Enter a resource pool [2 Normal Priority]") -eq ''){"2 Normal Priority"}else{$result}),
    [Alias('FL')]
        [string]$Folder = $(if(($result = Read-Host "Enter a folder name [Automated]") -eq ''){"Automated"}else{$result}),
    [Alias('DS')]
        [string]$Datastore = $(if(($result = Read-Host "Enter a Datastore name []") -eq ''){""}else{$result}),
    [Alias('PG')]
        [string]$Portgroup = $(if(($result = Read-Host "Enter a Portgroup name []") -eq ''){""}else{$result}),
    [switch]
        $Test = $false,
    [Alias('GW')]
        [string]$gateway = $(if(($result = Read-Host "Enter a gateway [10.0.0.1]") -eq ''){"10.0.0.1"}else{$result}),
    [Alias('SN')]
        [string]$subnet = "24",
    [Alias('D1')]
        [string]$pdns = "10.0.0.5",
    [Alias('D2')]
        [string]$sdns = "10.0.0.6",
    [Alias('LF')]
        [string]$LogFile = "C:\Logs\Replace-VM.log"
)


$StartTime = Get-Date
$Error.Clear()
#Strict Mode v2 breaks vmWare modules
#Set-StrictMode -Version 2.0


#Load useful functions 
if(Test-Path ".\Custom-Functions.ps1"){. ".\Custom-Functions.ps1"}
elseif(Test-Path "S:\Custom-Functions.ps1"){. "S:\Custom-Functions.ps1"}
elseif(Test-Path "C:\Scripts\Custom-Functions.ps1"){. "C:\Scripts\Custom-Functions.ps1"}
elseif(Test-Path "\\$($env:USERDNSDOMAIN)\NETLOGON\Custom-Functions.ps1"){. "\\$($env:USERDNSDOMAIN)\NETLOGON\Custom-Functions.ps1"}

#VALIDATE PARAMETERS
Write-Info "Valid Logfile: $(Validate-Log $LogFile)" $LogFile


#INITIALIZE VARIABLES

Write-Host ""
Write-Info "Computer = $Computer" $LogFile
Write-Info ("Local User = " + $Creds.UserName)  $LogFile
Write-Info ("Local Pass = " + $Creds.Password) $LogFile
Write-Info ("AD User = " + $ADCreds.Username) $LogFile
Write-Info "Template = $Template" $LogFile
Write-Info "vCenter = $vCenter" $LogFile
Write-Info "IP = $IP" $LogFile
Write-Info "Pool = $Pool" $LogFile
Write-Info "Folder = $Folder" $LogFile
Write-Info "Datastore = $Datastore" $LogFile
Write-Info "Portgroup = $Portgroup" $LogFile
Write-Info "gateway = $gateway" $LogFile
Write-Info "subnet prefix = $subnet" $LogFile
Write-Info "primary dns = $pdns" $LogFile
Write-Info "secondary dns = $sdns" $LogFile
if($IP -eq "")
{
    try
    {
        $IP = $(([System.Net.Dns]::GetHostAddresses($Computer)).IPAddressToString)
    }
    catch 
    {
        Write-Info "Cannot find IP for computer name." $LogFile
        $IP = Read-Host "What IP should this VM use?"
    }
}

Function Load-PowerCLI 
{  
    try
    {
        $hide = Get-PowerCLIVersion -ErrorAction Stop
        return $false
    }
    catch
    {
        Write-Info "Loading VMware Core environment" $LogFile
        return $true
    }
}

if(Load-PowerCLI)
{
        Import-Module VMware.VimAutomation.Core
}

if(!$SaveAD){
    try{
        Write-Info "Resetting previous AD object." -Progress $LogFile
        Get-ADComputer -Identity $Computer | %{ dsmod computer $_.DistinguishedName -reset -q} -ErrorAction Stop
        Write-Done -Progress
    }
    catch
    {
        Write-Fail -Progress
    }
}

Write-Info ("Connecting to vCenter: " + $vCenter) -Progress $LogFile
If($global:DefaultVIServers.Count -eq 0){
    If(Ping-Computer $vCenter){
        try{
            Connect-viServer $vCenter | Out-Null
            Write-Done -Progress
        }
        catch{
            Write-Fail -Progress
            exit
        }
    }
    else
    {
        Write-Fail -Progress
    }
}
else
{
    Write-Done -Progress
}

Write-Info ("Loading Template: " + $Template) -Progress $LogFile
try
{
    $Template = Get-Template $Template
    Write-Done -Progress
}
catch
{
    Write-Fail -Progress
}

Write-Info ("Loading Datastore: " + $Datastore) -Progress $LogFile
try
{
    $Datastore = Get-DatastoreCluster $Datastore
    Write-Done -Progress
}
catch
{
    Write-Fail -Progress
}
Write-Info ("Loading ResourcePool: " + $Pool) -Progress $LogFile
try
{
    $Pool = Get-ResourcePool $Pool
    Write-Done -Progress
}
catch
{
    Write-Fail -Progress
}




if(!$Test){
    $ModifyVM = $false
    Write-Info "Checking VM doesn't already exist" -Progress $LogFile
    try
    {
        Get-VM -Name $Computer -ErrorAction stop | Out-Null
        Write-Fail -Progress
        Write-Warning "VM Already Exists"
        $ModifyVM = $(if(($result = Read-Host "Modify Existing VM [Y]? ( Y/N )") -eq ''){"Y"}else{$result})
        if($ModifyVM -ne "Y" -and $ModifyVM -ne "y"){ 
            Write-Warning "Exiting Script"
            exit 
        }


    }
    catch
    {
        Write-Done -Progress
    }

    If(-Not $ModifyVM){
        Write-Info "Creating new VM from Template" -Progress $LogFile
        try
        {
            New-VM -Name $Computer -Template $Template -Datastore $Datastore -ResourcePool $Pool -ErrorAction stop | Out-Null
            Write-Done -Progress
        }
        catch
        {
            Write-Progress 15
            Write-Fail -Progress
            Write-Host $Error
        }

        $ProgressPreference='SilentlyContinue'
        do{
            Write-Info "Connecting new VM to Port Group" -Progress $LogFile
            try
            {
              Get-VM -Name $Computer | Get-NetworkAdapter | Set-NetworkAdapter -Portgroup $Portgroup -Confirm:$false –ErrorAction Stop | Out-Null
                Write-Done -Progress
                $Waiting = $false
            }
            catch
            {
                $Waiting = $true
                Write-Fail -Progress
                Write-Info "Failed to connect to PortGroup." $LogFile
                Write-Info "Retrying" $LogFile
                Start-Sleep -Seconds 30
            }

        }While($Waiting)
        Write-Info "Moving to Folder" -Progress $LogFile
        try
        {
          Get-VM -Name $Computer | Move-VM -Destination $Folder -Confirm:$false –ErrorAction Stop | Out-Null
            Write-Done -Progress
        }
        catch
        {
            Write-Fail -Progress
            Write-Warning "Failed to move to Folder"
            Write-Warning "You will need to update the VM's Folder location."
        }
        Write-Info "Starting up new VM" -Progress
        try
        {
            Start-VM -VM $Computer –ErrorAction Stop | Out-Null
            Write-Done -Progress
        }
        catch
        {
            Write-Fail -Progress
            Write-Warning "Failed to start VM."
            Write-Host $Error
            if($Error -like "*Powered on*"){Write-Warning "VM already started."}
            else{ exit }
        }
    }
}

Write-Info "Launching Completion Script as Job" $LogFile
      


if(Test-Path ".\Replace-VMJob.ps1")
{
$Jobfile = ".\Replace-VMJob.ps1"
}
elseif(Test-Path "S:\Replace-VMJob.ps1")
{
$Jobfile =  "S:\Replace-VMJob.ps1"
}  
Write-Info "Jobfile: $Jobfile" $LogFile      
$Job = Start-Job -FilePath $Jobfile -Name $Computer -ArgumentList $Computer,$Creds,$ADCreds,$vCenter,$IP,$subnet,$gateway,$pdns,$sdns

Write-Info "Complete in $(Run-Time $StartTime -FullText)" $LogFile
#$Sysprep = 'c:\windows\system32\sysprep\sysprep.exe /quiet /oobe /generalize /shutdown /unattend:c:\windows\system32\sysprep\unattend.xml'

