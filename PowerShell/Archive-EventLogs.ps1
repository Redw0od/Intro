<#   
.SYNOPSIS   
Archive windows eventlogs
    
.DESCRIPTION 
Search for "Archive" files in windows event logs folder. Compress with 7zip then move to backup server
	
.PARAMETER SourcePath
This is the Location of the logs to be archived

.PARAMETER DestinationPath
The location of the new archives
	
.PARAMETER LogPath
Add a path to the list of folders to be archived.

.PARAMETER ComputerName
The folder name to use at the DestinationPath location

.NOTES   
Name:        Archive-EventLogs.ps1
Author:      Michael Stanton
DateUpdated: 2017-02-14
Version:     1.0

.EXAMPLE   
.\Archive-EventLogs.ps1
    
Description 
-----------     
This command only works if you the script is in your current directory

.EXAMPLE
S:\Archive-EventLogs.ps1 -SourcePath C:\Windows\System32\winevt\Logs -DestinationPath \\StoreOnce.stanton.wtf\backups\

Description
-----------
All files that begin with "Archive" in C:\Windows\System32\winevt\Logs will be compressed and moved to -DestinationPath \\StoreOnce.stanton.wtf\backups\
#>
[cmdletbinding(SupportsShouldProcess)]
param (
    [Alias('SP')]
        [string]  $SourcePath = "$env:SYSTEMROOT\System32\winevt\Logs",
    [Alias('DP')]
        [string]  $DestinationPath = "\\files\Backups",
    [Alias('LF')]
        [string]  $LogFile = "$env:SYSTEMDRIVE\Logs\ArchiveEvents.log",
    [Alias('CN')]
        [string]  $ComputerName = $env:COMPUTERNAME
)

#PREPARE STANDARD SCRIPT ENVIRONMENT
$StartTime = Get-Date
$Error.Clear()
Set-StrictMode -Version 2.0
#Load useful functions 
if(Test-Path ".\Custom-Functions.ps1"){. ".\Custom-Functions.ps1"}
elseif(Test-Path "S:\Custom-Functions.ps1"){. "S:\Custom-Functions.ps1"}
elseif(Test-Path "C:\Scripts\Custom-Functions.ps1"){. "C:\Scripts\Custom-Functions.ps1"}
elseif(Test-Path "\\$($env:USERDNSDOMAIN)\NETLOGON\Custom-Functions.ps1"){. "\\$($env:USERDNSDOMAIN)\NETLOGON\Custom-Functions.ps1"}

#VALIDATE PARAMETERS
Write-Info "Valid Logfile: $(Validate-Log $LogFile)" $LogFile
Write-Info "Valid SourcePath: $(Validate-Path $SourcePath -Exit $LogFile)" $LogFile
Write-Info "Valid DestinationPath: $(Validate-Path $DestinationPath -Exit $LogFile)" $LogFile
Make-Directory "$($DestinationPath)\$($ComputerName)\EventLogs" $LogFile | Out-Null

#Checking Compression Utilitiy
$Compress = $true
$7z = "C:\Scripts\7z.exe"    
If(!(Validate-Path $7z)){    
    $7z = "\\stanton.wtf\NETLOGON\7z.exe"
    $Compress = Validate-Path $7z 
}

#BEGINNING MAIN SCRIPT LOGIC
# Verify Source Path is Valid, then build Object of logs to backup
Get-ChildItem $SourcePath -Filter "Archive*" -File | %{ 
    $ArchiveFile = $_.VersionInfo.FileName
    $ArchiveName = (Split-Path -Leaf $ArchiveFile).Replace('%4','-')
    $DestinationName = "$($DestinationPath)\$($ComputerName)\EventLogs\$($ArchiveName)"
    If($Compress){
        $CompressionMethod = "ppmd"
        $PPMdRAM = "256"
        $PPMdSwitch = "-m0=PPMd:mem"+$PPMdRAM+"m"
        try{
            Write-Log $ArchiveName $LogFile               
            $Arguments = @()
            $Arguments += "a"
            $Arguments += "-t7z"
            $Arguments += "-sdel"
            $Arguments += "-bd"
            $Arguments += $PPMdSwitch
            $Arguments += "$($DestinationName).7z"
            $Arguments += $ArchiveFile
            $7zip = &$7z $Arguments
            $7zip | %{ if($_ -ne ""){Write-Log ($_) $LogFile } }               
            }
        catch{
            $Error | %{ Write-Log $_ $LogFile }
        }
    }
    else{ 
        try{
            Write-Log $ArchiveName $LogFile 
            Move-Item $ArchiveFile $DestinationName -ErrorAction Stop 
        }
        catch{
            $Error | %{ Write-Log $_ $LogFile }
        }
    }
} 


Write-Info "Complete in $(Run-Time $StartTime -FullText)"
Write-Log "Complete in $(Run-Time $StartTime -FullText)" $LogFile
