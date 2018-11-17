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
Name of the domain to join. Defaults to stanton.wtf

.PARAMETER OU
Distinguished name for the OU to place the new instance into. Defaults into Dynamic OU

	

.NOTES   
Name: AWS-Launch-WIHost.ps1
Author: Mike Stanton
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
        [string]$DomainName = "stanton.wtf",
        [string]$OU ,
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
