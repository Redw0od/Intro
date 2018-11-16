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
S:\Archive-EventLogs.ps1 -SourcePath C:\Windows\System32\winevt\Logs -DestinationPath \\psmStoreOnce.hpfod.net\backups\

Description
-----------
All files that begin with "Archive" in C:\Windows\System32\winevt\Logs will be compressed and moved to -DestinationPath \\psmStoreOnce.hpfod.net\backups\
#>
[cmdletbinding(SupportsShouldProcess)]
param (
    [Alias('SP')]
        [string]  $SourcePath = "$env:SYSTEMROOT\System32\winevt\Logs",
    [Alias('DP')]
        [string]  $DestinationPath = "\\Psmfiles\Backups",
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
    $7z = "\\hpfod.net\NETLOGON\7z.exe"
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

# SIG # Begin signature block
# MIIIPQYJKoZIhvcNAQcCoIIILjCCCCoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUKeleFYKsv9sd7JLFniNs5am1
# jSSgggWuMIIFqjCCBJKgAwIBAgITbgAAAKzOi+ol+RGLKQAAAAAArDANBgkqhkiG
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
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUdOwsFMxB
# I8hTrZlNbA9UsfJwL4QwDQYJKoZIhvcNAQEBBQAEggEANzUvaU5LPPoqgyZAzgsa
# u+q4MCQO5x6mtpp7QhHTrsqrE1KcKi8TRimfwAYP4eIb3qGd4U3ECTVUY/xZ+BIZ
# yoql0uDuQ3xJ7WnZir4ZbjkCTLu8gNeJYsLNI7yK4AlAMezLUvTdsIjDxmiwEORU
# a6j9MCe9yl/ovK/WzqDSQsNQbZSYJXbmZkrRpPs7rvSdytATzlxKE7o/XypQj/qA
# A2XFLKRjYxp6+Y5FFcsy6KmgcqlXQzhIt1A6lFv8i50qzQM2bDYir0wl/XswTwFW
# +WODds4oodVvvezhmp94+ubJxp7Y4WjBSFyjCtJbX6N/Sqx/Jl8MdJP/jnCol1B7
# Zg==
# SIG # End signature block
