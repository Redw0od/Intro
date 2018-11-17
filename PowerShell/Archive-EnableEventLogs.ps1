<#   
.SYNOPSIS   
Enable Archiving for Active Event Logs
    
.DESCRIPTION 
This script will check for active Event Logs and Enable auto archiving.
	
.PARAMETER LogPath
Add a path to the list of folders to be archived.
	
.NOTES   
Name:        Archive-EnableEventLogs.ps1
Author:      Michael Stanton
DateUpdated: 2017-02-14
Version:     1.0

.EXAMPLE   
.\Archive-EnableEventLogs.ps1
    
Description 
-----------     
This command only works if you the script is in your current directory

.EXAMPLE   
S:\Archive-EnableEventLogs.ps1 -Logfile "\\files\backup\Logs"
    
Description 
-----------     
This command redirects the log output into \\files\backup\Logs

#>
[cmdletbinding(SupportsShouldProcess)]
param (
    [Alias('LF')]
        [string]  $Logfile = "$env:SYSTEMDRIVE\Logs\EnableEventLogs.log"
)

#PREPARE STANDARD SCRIPT ENVIRONMENT
$StartTime = Get-Date
$Error.Clear()
Set-StrictMode -Version 1.0
#Load useful functions 
if(Test-Path ".\Custom-Functions.ps1"){. ".\Custom-Functions.ps1"}
elseif(Test-Path "S:\Custom-Functions.ps1"){. "S:\Custom-Functions.ps1"}
elseif(Test-Path "C:\Scripts\Custom-Functions.ps1"){. "C:\Scripts\Custom-Functions.ps1"}
elseif(Test-Path "\\$($env:USERDNSDOMAIN)\NETLOGON\Custom-Functions.ps1"){. "\\$($env:USERDNSDOMAIN)\NETLOGON\Custom-Functions.ps1"}

#VALIDATE PARAMETERS
Write-Info "Valid Logfile: $(Validate-Log $LogFile)"

#Create a Scheduled Task with randomized start time
Function Set-Task {
    param([string]$Script,[string]$Title, $Logfile=$Logfile) 
    $Minute = Get-Random -Maximum 59
    $Hour = Get-Random -InputObject "00", "01", "02", "03", "04", "21", "22", "23"
    $Time = "$($Hour):$($Minute.ToString().PadLeft(2,'0'))"
    $action = New-ScheduledTaskAction  "powershell" -Argument $Script -WorkingDirectory "C:\Scripts\"
    $trigger = New-ScheduledTaskTrigger -At $Time -Daily
    $principal = New-ScheduledTaskPrincipal -UserID FOD\FOD_Backup$ -LogonType Password
    try{
        $result = (Register-ScheduledTask $Title -Action $action -Trigger $trigger -Principal $principal | ft -auto)
        Write-Info $result $Logfile
    }
    catch{
        Write-Info $Error $Logfile
    }
}

Function Active-Channels {
    param(  [Parameter(Mandatory=$true)][array]$Channels,
            [switch]$Enabled=$false )
    $List = ($Channels | %{ 
        try{ 
            if($_.Name -ne $null){
                get-itemproperty (($_.Name).Replace('HKEY_LOCAL_MACHINE','hklm:')) -ErrorAction Stop 
            }
        }
        catch{
            Write-Fail "Failed to access: $($_)"  $Logfile
        } 
    })
    If($Enabled){
        $List | ?{$_.Enabled -eq 1 -and $_.AutoBackupLogFiles -ne 1}
    }
    else{
        $List | ?{$_.AutoBackupLogFiles -ne 1}
    }
}

Function Enable-Archiving {
    param(  [Parameter(Mandatory=$true)][array]$Channels,
            [string]$Logfile )
    If($Channels -ne $null){
        $Channels | %{
            try{
                $registryPath =  ($_.PSPath).Replace('Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE','hklm:')
                Write-Info $registryPath -Progress -Return $Logfile
                New-ItemProperty -Path $registryPath -Name "AutoBackupLogFiles" -Value "1" -PropertyType DWORD -Force -ErrorAction Stop | Out-Null
                New-ItemProperty -Path $registryPath -Name "Retention" -Value "4294967295" -PropertyType DWORD -Force -ErrorAction Stop | Out-Null 
                $registryPath = "" 
                Write-Info $registryPath
            }
            catch{
                Write-Fail "Failed to Update Registry"
                Write-Fail $Error
                $Error | %{ Write-Info $_ $Logfile }
            }
        }
        Write-Done -Progress 
    }
}

#VALIDATE PARAMETERS
Write-Info "Valid Logfile: $(Validate-Log $LogFile)" $Logfile

#INITIALIZE VARIABLES
$Channels = ""
$EnabledChannels = ""
$DefaultChannels = ""
$DefaultChannelList = ""

# Check if the script has run on this server before.
$Status = Script-Status "EnableEventLogs"
if($Status -eq "1"){ 
    Write-Info "Status equals 1, exiting" $Logfile
    exit 
}

#BEGINNING MAIN SCRIPT LOGIC
# Create Array of Event Log channels
Write-Info "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog" -Progress  $Logfile
$DefaultChannels = gci "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog"
Write-Done -Progress $Logfile
Write-Info "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels" -Progress $Logfile
$Channels = gci "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels"
Write-Done -Progress $Logfile

Write-Info "Loading Event Channels" $Logfile
$DefaultChannelList = Active-Channels $DefaultChannels 
$EnabledChannels = Active-Channels $Channels -Enabled
Write-Done -Progress $Logfile
Write-Info ("$($EnabledChannels.Count + 1) channels found") $Logfile

Write-Info "Updating Event Channels" $Logfile
if($DefaultChannelsList -ne $null){Enable-Archiving $DefaultChannelList $Logfile}
if($EnabledChannels -ne $null){Enable-Archiving $EnabledChannels $Logfile}
Write-Done -Progress $Logfile


try{
    Write-Info "Checking PowerShell RSAT" $Logfile
    if(!((Get-WindowsFeature RSAT-AD-Powershell).InstallState -eq "Installed")){ Add-WindowsFeature RSAT-AD-PowerShell }
    Import-Module ActiveDirectory
    Write-Info "Installing gMSA FOD_Backup" $Logfile
    Install-ADServiceAccount FOD_Backup$
    Write-Log "gMSA FOD_Backup Installed" $Logfile
}
catch{
    Write-Fail "Failed to install gMSA" $Logfile
    Write-Fail $Error $Logfile
}

Set-Task '-command "& C:\Scripts\Archive-EventLogs.ps1"' "Archive-Event-Logs"
Set-Task '-command "& C:\Scripts\Archive-BackupServiceLogs.ps1"' "Archive-Service-Logs"
Set-Task '-command "& C:\Scripts\Archive-ZeusLogs.ps1"' "Archive-Zeus-Logs"
Set-Task '-command "& C:\Scripts\Archive-OctopusInstalls.ps1"' "Archive-Octopus"
Set-Task '-command "& C:\Scripts\Archive-BackupSystemState.ps1"' "Archive-Backup-SystemState"

#Update Run Once File Value
try
{
    Script-Update "EnableEventLogs" 1
    Write-Info "Powershell CSV Updated" $Logfile
}
catch
{
    $Error | %{ Write-Log $_ $Logfile }
}

Write-Info "Updated $($EnabledChannels.Count) Channels" $Logfile
Write-Info "Complete in $(Run-Time $StartTime -FullText)" $Logfile
