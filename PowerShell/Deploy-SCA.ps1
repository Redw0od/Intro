<#   
.SYNOPSIS   
Build SCA packages and push to Octopus
    
.DESCRIPTION 
To update Octopus with the latest SCA package, this script will take the source files and create Nuget packages, then upload to Octopus
	
.PARAMETER ComputerName
The Octopus server to upload files too.

.PARAMETER SourcePath
The location of the new SCA files

.PARAMETER SubFolder
The Subfolder that contains SCA Files

.PARAMETER APIKey
The Octopus API Key

.PARAMETER FPRmem
Amount of memory to dedicate to FPRUtility

.PARAMETER SkipUpload
Disable loading this package into Octopus

.PARAMETER Version
The SCA Version that will be tagged in Octopus

.PARAMETER Nuget
Location of nuget.exe 
	
.PARAMETER LogPath
Add a path to the list of folders to be archived.


.NOTES   
Name:        Deploy-SCA.ps1
Author:      Michael Stanton
DateUpdated: 2018-05-31
Version:     1.0

.EXAMPLE   
.\Deploy-SCA.ps1
    
Description 
-----------     
This command only works if the script is in your current directory

.EXAMPLE
S:\Deploy-SCA.ps1 -SourcePath C:\SCA\ -ComputerName plmoctopus02.hpfod.net

Description
-----------
Use the files located in C:\SCA to create Nuget packages and upload to plmoctopus02.hpfod.net
#>
[cmdletbinding(SupportsShouldProcess)]
param (
    [Alias('CN')]
        [string]  $ComputerName = "octopus01.hpfod.net",
        #[string]  $ComputerName = "plfodOctopus02.hpfod.net",
    [Alias('SP')]
        [string]  $SourcePath = "\\psmfiles.hpfod.net\Software\FOD\SCA\",
        #[string]  $SourcePath = "\\plmfiles\Software\FOD\SCA\SCA Deploy",
    [Alias('SF')]
        [string]  $SubFolder = "",
    [Alias('API')]
        [string]  $APIKey = "API-ZERPUFWGR07BNAO0P7PCTCJQSE",
        #[string]  $APIKey = "API-FI0UIGK9KENXMLNHUVWFAEQA6M",
    [Alias('V')]
        [string]  $Version = "18.20.1071",
    [Alias('FPR')]
        [string]  $FPRmem = "64g",
    [Alias('U')]
        [switch]  $SkipUpload = $false,
    [Alias('N')]
        [string]  $Nuget = "\\psmfiles.hpfod.net\Software\Octopus\nuget.exe",
        #[string]  $Nuget = "\\plmfiles.hpfod.net\Software\Octopus\nuget.exe",
    [Alias('LP')]
        [string]  $LogFile = "$env:SYSTEMDRIVE\Logs\DeploySCA.log"
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

#Prompt for empty parameters, provide default values
$nuspec = "Fortify.Zeus.SCA.nuspec"
$nuspectmp = "Fortify.Zeus.SCA.tmp.nuspec"
$author = "mstanton"
$rulespath = "$SourcePath\..\..\rules\"

$ComputerName = $(if(($result = Read-Host "Enter Octopus Server Name [$($ComputerName)]") -eq ''){$ComputerName}else{$result})
While(-Not (Ping-Computer $ComputerName )){
    Write-Fail "$($ComputerName) is not responding to ping. Please enter a new Octopus server."
    $ComputerName = $(if(($result = Read-Host "Enter Octopus Server Name [$($ComputerName)]") -eq ''){$ComputerName}else{$result})
}

$SourcePath = $(if(($result = Read-Host "Enter SCA Package Location [$($SourcePath)]") -eq ''){$SourcePath}else{$result})
While(-Not (Test-Path "$($SourcePath)" )){
    Write-Fail "$($SourcePath) not found." $LogFile
    $SourcePath = $(if(($result = Read-Host "Enter SCA Package Location [$($SourcePath)]") -eq ''){$SourcePath}else{$result})
}

$SubFolder = $(if(($result = Read-Host "Enter the SCA subfolder name: [$($SubFolder)]") -eq ''){$SubFolder}else{$result})
While(-Not (Test-Path "$($SourcePath)\$($SubFolder)" )){
    Write-Fail "$($SubFolder) not found." $LogFile
    $SubFolder = $(if(($result = Read-Host "Enter the SCA subfolder name: [$($SubFolder)]") -eq ''){$SubFolder}else{$result})
}

$Version = $(if(($result = Read-Host "Enter SCA Version [$($Version)]") -eq ''){$Version}else{$result})

While(-Not (Test-Path "$($Nuget)" )){
    Write-Fail "$($Nuget) not found." $LogFile
    $Nuget = $(if(($result = Read-Host "Enter Location for nuget.exe [$($Nuget)]") -eq ''){$Nuget}else{$result})
}

#VALIDATE PARAMETERS
Write-Info "Valid Logfile: $(Validate-Log $LogFile)" $LogFile
Write-Info "Valid SourcePath: $(Validate-Path $SourcePath -Exit $LogFile)" $LogFile


#Function to create a temporary folder for compiling packages
function New-TemporaryDirectory {
     $path = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())

    #if/while path already exists, generate a new path
    while(Test-Path $path) {
        $path = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
    }
    #create directory with generated path
    try{
        New-Item -ItemType Directory -Path $path -ErrorAction Stop | Out-Null
    }
    catch{
        Write-Fail "Unable to create temporary directory." $LogFile
    }
    Return $path
}


$SCADeploy = New-TemporaryDirectory
$SCAXML = "$SCADeploy\$nuspec"

# Create nuget spec file
[xml]$XMLfile = New-Object System.Xml.XmlDocument
$Declared = $XMLfile.CreateXmlDeclaration("1.0","UTF-8",$null)
$XMLfile.AppendChild($Declared) | Out-Null
$Package = $XMLfile.CreateNode("element","package", $null)
$Metadata = $XMLfile.CreateNode("element","metadata", $null)
$id = $XMLfile.CreateNode("element","id", $null)
$id.InnerText = "Fortify.Zeus.SCA"
$ver = $XMLfile.CreateNode("element","version", $null)
$ver.InnerText = $Version
$authors = $XMLfile.CreateNode("element","authors", $null)
$authors.InnerText = $author
$owners = $XMLfile.CreateNode("element","owners", $null)
$owners.InnerText = $author
$req = $XMLfile.CreateNode("element","requireLicenseAcceptance", $null)
$req.InnerText = "false"
$desc = $XMLfile.CreateNode("element","description", $null)
$desc.InnerText = "FoDSCA"
$Metadata.AppendChild($id) | Out-Null
$Metadata.AppendChild($ver) | Out-Null
$Metadata.AppendChild($authors) | Out-Null
$Metadata.AppendChild($owners) | Out-Null
$Metadata.AppendChild($req) | Out-Null
$Metadata.AppendChild($desc) | Out-Null
$Package.AppendChild($Metadata) | Out-Null
$XMLfile.AppendChild($Package) | Out-Null
$XMLFile.save("$SCAXML")

Write-Info "Copying SCA files to Temp directory" $LogFile
Copy-Item $SourcePath\$SubFolder\* $SCADeploy -Recurse

$rules = gci "$SourcePath\$SubFolder\Core\config\rules\"
if(($rules| Measure-Object).Count -lt 2){
    Write-Info "Rules missing"
    $newrules = gci $rulespath
    if(($newrules| Measure-Object).Count -lt 2){Write-Fail "Rules directory is missing rules, update rulespath variable"}
    else {
        Write-Info "Copying Rules"
        Copy-Item "$rulespath\*" "$SCADeploy\Core\config\rules\"}
}
else { Write-Info "Rules included in package" }

Write-Info "Updating FPRUtility.bat to $FPRmem" $LogFile
if(Test-Path "$SCADeploy\bin\FPRUtility.bat"){
    (Get-Content "$SCADeploy\bin\FPRUtility.bat").replace('1000m', $FPRmem) | Set-Content "$SCADeploy\bin\FPRUtility.bat"
} else {
Write-Info "FPRUtility.bat not found" $LogFile
}


Write-Host "Creating nupkg"
&$Nuget pack $SCAXML -OutputDirectory (Split-Path -Path $SourcePath) -BasePath $SCADeploy -Verbosity quiet -NoPackageAnalysis

Write-Info "Removing Temp Folder" $LogFile
Remove-Item $SCADeploy -Recurse -Force

if(!($SkipUpload)){
Write-Host "Pushing to Octopus"              
    $Arguments = @()
    $Arguments += "push"   
    $Arguments += "$(Split-Path -Path $SourcePath)\Fortify.Zeus.SCA.$($Version).nupkg"
    $Arguments += "-Timeout"   
    $Arguments += "600"   
    $Arguments += "-ApiKey"   
    $Arguments += $APIKey   
    $Arguments += "-Source"   
    $Arguments += "http://$($ComputerName)/nuget/packages"   
&$Nuget $Arguments 
}
#&$Nuget push -Source "http://$($ComputerName)/nuget/packages" "$(Split-Path -Path $SourcePath)\Fortify.Zeus.SCA.$($Version).nupkg" "$APIKey" 

Write-Info "Complete in $(Run-Time $StartTime -FullText)" $LogFile