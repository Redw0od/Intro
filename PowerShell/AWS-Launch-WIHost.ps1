<#
.SYNOPSIS   
Create new AWS Instances
    
.DESCRIPTION 
This script will help you launch new AWS instances for WebInspect
	
.PARAMETER AccessKey
AWS Accesskey for authentication

.PARAMETER SecretKey
AWS SecretKey for authentication

.PARAMETER AWSProfile
Credential profile name for storing AWS access.

.PARAMETER LaunchTemplate
Specify a Launch Template to use for deploying new AMI's

.PARAMETER Region
Specify which AWS region to use

.PARAMETER InstanceType
Specify which Virtual Machine type to launch. eg. t2.micro

.PARAMETER Quantity
Specify how many new instances to create. Defaults to 1.

.PARAMETER ADCredentials
Credentials to use for joining the domain

.PARAMETER Credentials
Credentials to use for connecting to the new VM

.PARAMETER DomainName
Name of the domain to join. Defaults to hpfod.net

.PARAMETER OU
Distinguished name for the OU to place the new instance into. Defaults into Dynamic OU

	

.NOTES   
Name: AWS-Launch-WIHost.ps1
Author: Jawdat Abdullah
Version: 0.1
DateCreated: 2018-6-20
DateUpdated: 2018-6-20

.EXAMPLE   
.\AWS-Launch-WIHost.ps1 -P corporate -Accesskey 1234 -SecretKey 6789  -Q 10 -ADCredentials (Get-Credential)

Description 
-----------     
This command will create a AWS credential profile called corporate and then create 10 instances of a chosen launch template 


.EXAMPLE   
.\AWS-Launch-WIHost.ps1 -AWSProfile corporate -LaunchTemplate lt-034968a119495a6eb -InstanceType "t2.micro" -Qty 10

Description 
-----------     
This command will create 10 instances using the specified launch template and t2.micro type with authentication from the stored profile

#>
[cmdletbinding(SupportsShouldProcess)]
param(
    [Alias('AK')]
        [string]$AccessKey,
    [Alias('SK')]
        [string]$SecretKey,
    [Alias('P')]
        [string]$AWSProfile,
    [Alias('LT')]
        [string]$LaunchTemplate,
    [Alias('IT')]
        [string]$InstanceType,
    [Alias('R')]
        [string]$Region = "us-west-1",
    [Alias('Q')]
        [int]$Quantity = 1,
    [Alias('AD')]
        [pscredential]$ADCredentials,
    [Alias('C')]
        [pscredential]$Credentials,
    [Alias('DN')]
        [string]$DomainName = "hpfod.net",
        [string]$OU = "OU=Dynamic,OU=Servers,OU=FOD,DC=hpfod,DC=net",
    [Alias('LF')]
        [string]  $LogFile = "$env:SYSTEMDRIVE\Logs\AWS_Launch_WIHost.log"
)


$StartTime = Get-Date
$Error.Clear()
Set-StrictMode -Version 2.0
#Load useful functions 
if(Test-Path ".\Custom-Functions.ps1"){. ".\Custom-Functions.ps1"}
elseif(Test-Path "S:\Custom-Functions.ps1"){. "S:\Custom-Functions.ps1"}
elseif(Test-Path "C:\Scripts\Custom-Functions.ps1"){. "C:\Scripts\Custom-Functions.ps1"}
elseif(Test-Path "\\$($env:USERDNSDOMAIN)\NETLOGON\Custom-Functions.ps1"){. "\\$($env:USERDNSDOMAIN)\NETLOGON\Custom-Functions.ps1"}

#Check if Powershell has Admin priveledeges (Needed for WSMAN trust)
If(Test-Administrator){
    Write-Verbose "Running as Administrator"
}
Else{
    Write-Warning "Not running as Administrator. Adding new Instances to the domain will fail. Aborting."
    exit
}

#Verify AWS Tools is installed
try{ aws help | Out-Null }
catch{ Write-Fail "AWS tools required. Please install the latest version of AWS Tools. https://aws.amazon.com/powershell/"; exit }
try{ Get-Module -Name AWSPowerShell | Out-Null }
catch{ 
    Write-Fail "AWS Powershell Module required. Attempting to load module"
    try {
    Import-Module "${env:ProgramFiles(x86)}\AWS Tools\PowerShell\AWSPowerShell\AWSPowerShell.psd1"
    }
    catch{Write-Fail "Failed to import AWS Tools Powershell Module, Please install AWS Powershell Tools";Write-Info "https://aws.amazon.com/powershell/"; exit}
}

#VALIDATE PARAMETERS
Write-Info "Valid Logfile: $(Validate-Log $LogFile)" $LogFile
Write-Info "Validating AWS Credentials"
If($AccessKey -ne "" -and $SecretKey -ne ""){
    If($AWSProfile -eq ""){$AWSProfile = "Fortify"}
    try {
        Set-AWSCredential -AccessKey $AccessKey -SecretKey $SecretKey -StoreAs $AWSProfile
        Write-Info "Credential Profile: $AWSProfile" $LogFile
    }
    catch {
        Write-Fail "Credential Profile already exists." $Logfile
    }
}
ElseIf($AWSProfile -ne ""){
    try {
        Set-AWSCredential -ProfileName $AWSProfile 
        Write-Info "Credential Profile: $AWSProfile" $LogFile
    }
    catch {
        Write-Fail "Unable to load stored AWS Credentials" $LogFile
    }      
}
Else{
    Write-Info "You must specify AWS Credentials to continue" $LogFile
    While($AccessKey -eq ""){ $AccessKey = Read-Host "Invalid Access Key, please provide a new Access Key. "  }
    While($SecretKey -eq ""){ $SecretKey = Read-Host "Invalid Secret Key, please provide a new Secret Key. "  }
    If($AWSProfile -eq ""){$AWSProfile = "Fortify"}
    try {
        Set-AWSCredential -AccessKey $AccessKey -SecretKey $SecretKey -StoreAs $AWSProfile
        Write-Info "Credential Profile: $AWSProfile" $LogFile
    }
    catch {
        Write-Fail "Credential Profile already exists." $Logfile
    }
}

# Chose a Launch Template
$Templates = (aws ec2 describe-launch-templates) -join '' | ConvertFrom-JSON 
If($LaunchTemplate -eq "" -or !($Templates.LaunchTemplates.LaunchTemplateId.Contains($LaunchTemplate))){
    $count = 1
    Write-Host ""
    Foreach($Template in $Templates.LaunchTemplates){
        Write-Host "$($count). $($Template.LaunchTemplateName) $($Template.LaunchTemplateId)"
        $count += 1
    }
    $TemplateChoice = Read-Host "Please enter the number of the template you wish to use. " 
    $LaunchTemplate = $Templates.LaunchTemplates[$TemplateChoice - 1].LaunchTemplateID
}
Write-Info "LauchTemplate: $LaunchTemplate"

#Verify Active Directory Credentials
$Permitted = $false
While($Permitted -eq $false){
    $UserName = whoami
    If($ADCredentials -eq $null){
        $ADCredentials = Get-Credential -Message "Please enter Active Directory Credentials" -UserName "$UserName"
    }
    try {
        $ADUser = Split-Path -Leaf ($ADCredentials.UserName)
        $ADGroups = Get-ADPrincipalGroupMembership $ADUser -Server $DomainName | Select Name
        If($ADGroups.Name.Contains("Administrators") -or $ADGroups.Name.Contains("Domain Admins") -or $ADGroups.Name.Contains("Level 1 Support")){
            $Permitted = $true   
        }
    }
    catch{
        Write-Fail "Error testing credentials" $LogFile
    }
    If(!($Permitted)){
        Write-Fail "AD Credentials not authorized to add computer to domain" $LogFile
        Write-Host ""
        Write-Host "Would you like to enter new credentials? (Y,N)[default: Yes]" 
        $Response = Read-Host
        If($Response -ne ""){
            If($Response[0] -ne "Y" -and $Response[0] -ne "y"){
                exit
            }
        }
        $ADCredentials = Get-Credential -Message "Please enter Active Directory Credentials" -UserName "$UserName" 
    }
}
Write-Info "AD User: $ADUser" $LogFile


#Verify Local Administrator Credentials
While($Credentials -eq $null){
    $Credentials = (Get-Credential -UserName "Administrator" -Message "Enter the Local Admin credentials for the new Instance")
}
Write-Info "Local Admin: $($Credentials.UserName)" $LogFile

#Validate Region
$Regions = (aws ec2 describe-regions) -join '' | ConvertFrom-JSON 
While(!($Regions.Regions.RegionName.Contains($Region))){
    Write-Fail "Unknown region $Region"
    Write-Host ""
    Write-Host "Listing available regions:"
    $Regions.Regions.RegionName    
    $Region = Read-Host "Please enter the desired region (Leave blank to exit)"
    If($Region -eq ""){exit}
}
Write-Info "Region: $Region" $LogFile

#Validate Instance Type
If($InstanceType -eq ""){
    $TemplateInstanceType = (aws ec2 describe-launch-template-versions --launch-template-id $LaunchTemplate) -join "" | ConvertFrom-JSON
    $InstanceType = $TemplateInstanceType.LaunchTemplateVersions.LaunchTemplateData[0].InstanceType
}
$History = (aws --region=$Region ec2 describe-spot-price-history --max-items 1000 ) -join '' | ConvertFrom-JSON
$Types = $History.SpotPriceHistory.InstanceType | Select -Unique
While(!($Types.Contains($InstanceType))){
    Write-Fail "Unknown instance type: $InstanceType"
    $InstanceType = Read-Host "`nPlease enter the desired instance type (Leave blank to exit, type help for list)"
    If($InstanceType -eq "help"){
        Write-Host "`nListing instances available in $Region : "
        Sleep -Seconds 2
        $Types | Sort | More
        $InstanceType = Read-Host "`nPlease enter the desired instance type (Leave blank to exit, type help for list)"
    }
    If($InstanceType -eq ""){exit}
}
Write-Info "InstanceType: $InstanceType" $LogFile

Write-Info "Creating $Quantity New Instances"
$Instances = (aws ec2 run-instances --launch-template  LaunchTemplateId=$LaunchTemplate --count $Quantity --instance-type $InstanceType) -join "" | ConvertFrom-JSON

Write-Info "Launching Completion Script as Job"
if(Test-Path ".\AWS-Launch-InstanceJob.ps1")
{
$Jobfile = ".\AWS-Launch-InstanceJob.ps1"
}
elseif(Test-Path "S:\AWS-Launch-InstanceJob.ps1")
{
$Jobfile =  "S:\AWS-Launch-InstanceJob.ps1"
}        
Foreach($Instance in $Instances.Instances){
    $Job = Start-Job -FilePath $Jobfile -Name $Instance.InstanceId -ArgumentList $Instance,$Credentials,$ADCredentials,$DomainName,$OU
}

Write-Info (Run-Time $StartTime -FullText) $LogFile

#$Sysprep = 'c:\windows\system32\sysprep\sysprep.exe /quiet /oobe /generalize /shutdown /unattend:c:\windows\system32\sysprep\unattend.xml'
# SIG # Begin signature block
# MIIIPQYJKoZIhvcNAQcCoIIILjCCCCoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUk7E0gNdhCCZdXEb+4riak4QO
# EGGgggWuMIIFqjCCBJKgAwIBAgITbgAAAKzOi+ol+RGLKQAAAAAArDANBgkqhkiG
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
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUaiNJjIcD
# 5spL6F0LjPrcX9KhrpgwDQYJKoZIhvcNAQEBBQAEggEAsXN3lfvxvhINM643eQUP
# SIuvyjPW3/CKPH4Tjo4JpYP2//xzTnIuLuz+qtnvnBAAbcFswzc8x+SlQaiT9DfJ
# KyluqNcPITHvVVUV024dOq8FD2W9G+16ss44420bxNheebao0eAWtAR/28CDHdUG
# 2jM5E++H8ALEV6oo55R4cVobn8sxztXum3MPWpg/0gzTvnRu2DARzVNUeqwo/hDM
# 3cx9AieRZ1qYQgQ9vKvWrbrcpQjR09BUhAqztwWgDETwvbhkXp2d0f8LqtEWvVcl
# SuHPq9xscjZCs/p+iHtCm9dgjrAkcOy6qqL4B3avssBlBX/9tiD/cIfWyojPFsF/
# zw==
# SIG # End signature block
