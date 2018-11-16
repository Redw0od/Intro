<#
.SYNOPSIS   
Create Baseline Report for Security
    
.DESCRIPTION 
Inventory various parts of a system to create a baseline report.
	
.PARAMETER Computer
Get report from remote computer

.PARAMETER Creds
Credentials to use for running the report

.PARAMETER IIS
Include IIS information in report

.PARAMETER Octopus
Include Octopus information in report

.PARAMETER SQL
Include SQL information in report

.PARAMETER CSV
Create CSV Files for report

.PARAMETER CSVPath
Directory to create CSV files in.


.PARAMETER Verbose
Output more than usual.
	

.NOTES   
Name: Get-Baseline.ps1
Author: Mike Stanton
Version: 0.1
DateCreated: 2017-1-26
DateUpdated: 2017-1-26

.TODO
Exclude Service Accounts
Compare alias
Show OU
Retry Queue
Status Output
LastLogon

.LINK
http://www.hpe.com

.EXAMPLE   
.\Get-Baseline.ps1 -IIS -SQL -Computer PSMAD01 -Creds $(Get-Credentials) -Verbose -CSV -CSVPath .

#>
[cmdletbinding()]
param(
    [string]
        $Computer = $env:COMPUTERNAME,
    [switch]
        $IIS = $false,
    [switch]
        $SQL = $false,
    [switch]
        $Octopus = $false,
    [switch]
        $CSV = $false,
    [string]
        $CSVPath = ".",
    [pscredential]$Creds
)

Write-Host "Computer = $Computer"
Write-Verbose "CSVPath = $CSVPath"
Write-Verbose "IIS = $IIS"
Write-Verbose "SQL = $SQL"
Write-Verbose "CSV = $CSV"

$Exclude = @(   "PSMAD01",
                "PSMAD02",
                "PSMAD03",
                "PSMAD04",
                "PSMAD05",
                "PSMAD06",
                "PSMAD07",
                "PSMAD08",
                "PLMAD01",
                "PLMAD02",
                "PSZWSN157")
$Exclude | %{If($_ -eq $Computer){Exit}}

Function BuildIISObject{
    param([System.String]$RemoteComputer = $false) 
    $IISo = ""
    if($RemoteComputer -ne $false){
        Write-Verbose "Executing IIS command on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'ipmo WebAdministration;gci IIS://sites' )
        $IISo = $(icm -ComputerName $RemoteComputer -ScriptBlock $Command)
        Write-Verbose "Roles = $Roles"        
    }
    else{
        Write-Verbose "Executing role command on local computer"
        $IISo = $(ipmo WebAdministration;gci IIS://sites)
    }
     
    $IISo | %{Add-member -InputObject $_ -Force -MemberType NoteProperty -Name Binding -Value $_.Bindings.Collection.bindingInformation}
    $IISo | %{Add-member -InputObject $_ -Force -MemberType NoteProperty -Name Protocol -Value $_.Bindings.Collection.protocol}
    $IISo | %{Add-member -InputObject $_ -Force -MemberType NoteProperty -Name LogDir -Value $_.logFile.directory}
    $Sites = $IISo | Select Name,State,PhysicalPath,Protocol,Binding,LogDir
    return $Sites
}
Function BuildIIAObject{
    param([System.String]$RemoteComputer = $false) 
    if($RemoteComputer -ne $false){
        Write-Verbose "Executing IIS command on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'ipmo WebAdministration;gci IIS://apppools' )
        $IISa = $(icm -ComputerName $RemoteComputer -ScriptBlock $Command)
        Write-Verbose "Roles = $Roles"        
    }
    else{
        Write-Verbose "Executing role command on local computer"
        $IISa = $(ipmo WebAdministration;gci IIS://apppools)
    }
    $IISa | %{Add-member -InputObject $_ -Force -MemberType NoteProperty -Name UserName -Value $_.ProcessModel.UserName}
    $AppPools = $IISa | Select Name,State,@{n="Application";e={$_.PSChildName}},UserName
    return $AppPools
}
function GetSqlInstance { 
    param ( 
	[Parameter(ValueFromPipeline)] 
        [string[]]$Computername = 'localhost' 
    ) 
    process { 
        foreach ($Computer in $Computername) { 
            try { 
                $SqlServices = Get-Service -ComputerName $Computer -DisplayName 'SQL Server (*' 
                if (!$SqlServices) { 
                    Write-Verbose 'No instances found' 
                } else { 
                    $InstanceNames = $SqlServices | Select-Object @{ n = 'Instance'; e = { $_.DisplayName.Trim('SQL Server ').Trim(')').Trim('(') } } | Select-Object -ExpandProperty Instance 
                    foreach ($InstanceName in $InstanceNames) { 
                        [pscustomobject]@{ 'Computername' = $Computer; 'Instance' = $InstanceName } 
                    } 
                } 
            } catch { 
                Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" 
                $false 
            } 
        } 
    } 
}
function GetSqlLogin { 
    param ( 
        [Parameter(ValueFromPipelineByPropertyName)] 
        [string[]]$Computername = 'localhost', 
        [Parameter(ValueFromPipelineByPropertyName)] 
        [string]$Instance, 
        [string]$Name 
    ) 
    begin { 
        [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null 
    } 
    process { 
        try { 
            foreach ($Computer in $Computername) { 
                $Instances = GetSqlInstance -Computername $Computer 
                foreach ($Instance in $Instances.Instance) { 
                    if ($Instance -eq 'MSSQLSERVER') { 
                        $Server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $Computer 
                    } else { 
                        $Server = new-object ('Microsoft.SqlServer.Management.Smo.Server') "$Computer`\$Instance" 
                    } 
                    if (!$Name) { 
                        $Server.Logins 
                    } else { 
                        $Server.Logins | where { $_.Name -eq $Name } 
                    } 
                } 
            } 
        } catch { 
            Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" 
            $false 
        } 
    } 
} 
Function BuildSQLObject{
    param ( 
        [ValidateScript({ Test-Connection -ComputerName $_ -Quiet -Count 1 })] 
	[Parameter(ValueFromPipeline)] 
        [System.String]$Computername = "localhost" 
    ) 	
	$Logins = GetSqlLogin $Computername 
	$SQLServerObj = New-Object System.Collections.ArrayList
	$Logins |?{$_.Name -match "FOD\\"}|  %{
		$sqlusr = $_
		$Members = $_.ListMembers()
		if(!$Members -gt 0){$Members = @("none")}
		foreach($Role in $Members  ){
			$sqlobj = New-Object PSObject
			$sqlobj | Add-Member -MemberType NoteProperty -Name "SQL" -Value $($sqlusr.Parent.Name + ":" + $sqlusr.Parent.ServiceName)
			$sqlobj | Add-Member -MemberType NoteProperty -Name "Name" -Value $sqlusr.Name
			$sqlobj | Add-Member -MemberType NoteProperty -Name "LoginType" -Value $sqlusr.LoginType
			$sqlobj | Add-Member -MemberType NoteProperty -Name "Created" -Value $sqlusr.CreateDate
			$sqlobj | Add-Member -MemberType NoteProperty -Name "ID" -Value $sqlusr.ID
			$sqlobj | Add-Member -MemberType NoteProperty -Name "Role" -Value $Role
			$SQLServerObj.Add($sqlobj) | Out-Null
			$sqlobj = ""
		}		
	}
	return $SQLServerObj 
}
Function BuildDBObject{
	param ( 
		[ValidateScript({ Test-Connection -ComputerName $_ -Quiet -Count 1 })] 
		[Parameter(ValueFromPipeline)] 
		[System.String]$Computername = "localhost" 
	) 	
		[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null 
 
		try { 
			$Instances = GetSqlInstance -Computername $Computer 
			$DBRoles = New-Object System.Collections.Arraylist
			foreach ($Instance in $Instances.Instance) { 
				if ($Instance -eq 'MSSQLSERVER') { 
					 $Server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $Computer 
				} else { 
					$Server = new-object ('Microsoft.SqlServer.Management.Smo.Server') "$Computer`\$Instance" 
				} 
				$Users = $Server.databases.users | ?{$_.Name -match "FOD\\"}
				$Users | %{
					$DB = $_.Parent.Name
					$User = $_.Login
				#	$roles = $_.enumroles()
				#	if(!$roles -gt 0){$roles="none"}
				#	$roles | %{
						$UserRole = New-Object PSObject
						$UserRole | Add-Member -MemberType NoteProperty -Name "DB" -Value $DB
						$UserRole | Add-Member -MemberType NoteProperty -Name "Login" -Value $User
				#		$UserRole | Add-Member -MemberType NoteProperty -Name "Role" -Value $_
						$DBRoles.Add($UserRole) | Out-Null
						$UserRole = $null
				#	} 
				}
			}
		} catch { 
			 Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" 
			$false 
		} 
	return $DBRoles
}
Function BuildOctopusObject{
    param([System.String]$RemoteComputer = $false) 
    if($RemoteComputer -ne $false){
        Write-Verbose "Executing Octopus command on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'Get-Content C:\Octopus\Applications\.Tentacle\DeploymentJournal.xml ' )
        Try{
        [XML]$XML = $(icm -ComputerName $RemoteComputer -ScriptBlock $Command) 
        }
        Catch{
            Write-Warning "Octopus Journal Missing."
        }
        Write-Verbose "Octopus = $XML"        
    }
    else{
        Write-Verbose "Executing Octopus command on local computer"
        [XML]$XML = Get-Content C:\Octopus\Applications\.Tentacle\DeploymentJournal.xml
    }
    $Apps = $($xml.Deployments.Deployment.PackageId | Sort -Unique | %{$a=$_;$xml.Deployments.Deployment | ?{$_.PackageId -eq $a} | Sort InstalledOn | select -last 1})
    $OctopusObj = New-Object System.Collections.ArrayList
    $Apps | %{
        Write-Verbose $_.PackageId
        $app = New-Object PSObject
        $app | Add-Member -Force -MemberType NoteProperty -Name "Id" -Value $_.Id
        $app | Add-Member -Force -MemberType NoteProperty -Name "ProjectId" -Value $_.ProjectId
        $app | Add-Member -Force -MemberType NoteProperty -Name "PackageId" -Value $_.PackageId
        $app | Add-Member -Force -MemberType NoteProperty -Name "PackageVersion" -Value $_.PackageVersion
        $app | Add-Member -Force -MemberType NoteProperty -Name "InstalledOn" -Value $_.InstalledOn
        $app | Add-Member -Force -MemberType NoteProperty -Name "ExtractedTo" -Value $_.ExtractedTo
        $OctopusObj.Add($app) | Out-Null
    }
    return $OctopusObj
    }
Function BuildVersionObject{
    param([System.String]$RemoteComputer = $false) 
    if($RemoteComputer -ne $false){
        Write-Verbose "Executing version commands on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'get-wmiobject -class win32_operatingsystem | %{$OS = "$($_.Caption) $($_.OSArchitecture)"}; $OS' )
        $Caption = icm -ComputerName $RemoteComputer -ScriptBlock $Command
        Write-Verbose "Caption = $Caption"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'dism /online /get-currentedition | ?{$_ -match "Current Edition :"} | %{$_.split('': '')[-1]}' )
        $Edition = icm -ComputerName $RemoteComputer -ScriptBlock $Command
        Write-Verbose "Edition = $Edition"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'dism /online /get-currentedition | ?{$_ -match "Image Version:"} | %{$_.split('': '')[-1]}' )
        $Version =  icm -ComputerName $RemoteComputer -ScriptBlock $Command
        Write-Verbose "Version = $Version"
    }
    else{
        Write-Verbose "Executing version commands on local computer"
        $Caption = $(get-wmiobject -class win32_operatingsystem | %{$OS = "$($_.Caption) $($_.OSArchitecture)"}; $OS)
        Write-Verbose "Caption = $Caption"
        $Edition = $(dism /online /get-currentedition | ?{$_ -match "Current Edition :"} | %{$_.split(': ')[-1]})
        Write-Verbose "Edition = $Edition"
        $Version = $(dism /online /get-currentedition | ?{$_ -match "Image Version:"} | %{$_.split(': ')[-1]})
        Write-Verbose "Version = $Version"
    }
    $Object = New-Object PSObject
    Add-Member -InputObject $Object -MemberType NoteProperty -Name Caption -Value $Caption
    Add-Member -InputObject $Object -MemberType NoteProperty -Name Edition -Value $Edition
    Add-Member -InputObject $Object -MemberType NoteProperty -Name Version -Value $Version
    return $Object    
    }
Function BuildRoleObject{
    param([System.String]$RemoteComputer = $false) 
    if($RemoteComputer -ne $false){
        Write-Verbose "Executing role command on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'get-windowsfeature | ?{$_.InstallState -eq "Installed"} ' )
        $Roles = $(icm -ComputerName $RemoteComputer -ScriptBlock $Command) | Select Name
        Write-Verbose "Roles = $Roles"        
    }
    else{
        Write-Verbose "Executing role command on local computer"
        $Roles = $(get-windowsfeature | ?{$_.InstallState -eq "Installed"} | Select Name)
    }

    return $Roles    
    }
Function BuildSoftwareObject{
    param([System.String]$RemoteComputer = $false) 
    if($RemoteComputer -ne $false){
        Write-Verbose "Executing software command on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'get-itemproperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | ?{$_.DisplayName -gt 0 } ' )
        $Software = $(icm -ComputerName $RemoteComputer -ScriptBlock $Command) | Select DisplayName, DisplayVersion, InstallDate
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'get-itemproperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*  | ?{$_.DisplayName -gt 0 } ' )
        $Software += $(icm -ComputerName $RemoteComputer -ScriptBlock $Command) | Select DisplayName, DisplayVersion, InstallDate
        Write-Verbose "Software = $Software"        
    }
    else{
        Write-Verbose "Executing software command on local computer"
        $Software = $(get-itemproperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | ?{$_.DisplayName -gt 0 } | Select DisplayName, DisplayVersion, InstallDate)
        $Software += $(get-itemproperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*  | ?{$_.DisplayName -gt 0 } | Select DisplayName, DisplayVersion, InstallDate)
    }

    return $Software
}
Function BuildGPOObject{
    param([System.String]$RemoteComputer = $false) 
    if($RemoteComputer -ne $false){
        Write-Verbose "Executing GPO command on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'gpresult /v' )
        $GPresult = $(icm -ComputerName $RemoteComputer -ScriptBlock $Command) 
        Write-Verbose "GPOs = $GPO"        
    }
    else{
        Write-Verbose "Executing GPO command on local computer"
        $GPresult = $(gpresult /v )
    }
    $count=0
    $GPOList = New-Object System.Collections.ArrayList
    $GPresult | %{
        if($_ -match "Applied Group Policy Objects"){$go = $true}
        if($_ -match "The following GPOs"){$go = $false;$count=0}
        if ($go){
            $count+=1
            if($count -gt 2){
                $pname = $_.trim()
                if($pname -ne ""){
                    $ogpo = New-Object -TypeName PSObject -Property @{Policy=$pname}
                    $GPOList.Add($ogpo) | Out-Null
                }
            }
        } 
    }
    return $GPOList 
}
Function BuildGroupObject{
    param([System.String]$RemoteComputer = $false) 
    $Groups = New-Object System.Collections.ArrayList
    if($RemoteComputer -ne $false){
        Write-Verbose "Executing Groups command on remote computer"
        $WMIGroups = $(gwmi win32_groupuser -ComputerName $RemoteComputer) 
        $WMIGroups| %{
            $LocalGroup = New-Object -TypeName PSObject
            $_.PartComponent -match '.+Domain\=(.+)\,Name\=(.+)$' > $nul 
            $User = $matches[1].Trim('"') + "\" + $matches[2].Trim('"')
            $_.GroupComponent -match '.+Domain\=(.+)\,Name\=(.+)$' > $nul 
            $Group = $matches[1].Trim('"') + "\" + $matches[2].Trim('"')
            $LocalGroup | Add-Member -Force -MemberType NoteProperty -Name Group -Value $Group
            $LocalGroup | Add-Member -Force -MemberType NoteProperty -Name User -Value $User
            $Groups.Add($LocalGroup) | Out-Null
            $LocalGroup=""
            }
        Write-Verbose "Groups = $Groups"        
    }
    else{
        Write-Verbose "Executing Groups command on local computer"
        net localgroup | ?{$_ -match "\*"} | %{$_.Trim('*')}| %{
            $Group=$env:COMPUTERNAME + "\" + $_ 
            NET LOCALGROUP $_ | Select -Skip 6 | ?{$_ -notmatch "The command" -and $_ -gt 0}| %{
                $LocalGroup = New-Object -TypeName PSObject
                $LocalGroup | Add-Member -Force -MemberType NoteProperty -Name Group -Value $Group
                $LocalGroup | Add-Member -Force -MemberType NoteProperty -Name User -Value $_
                $Groups.Add($LocalGroup) | Out-Null
                $LocalGroup=""
            }
        }
    }
    return $Groups 
}
Function BuildServiceObject{
    param([System.String]$RemoteComputer = $false) 
    if($RemoteComputer -ne $false){
        Write-Verbose "Executing Service command on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'get-wmiobject win32_Service' )
        $Service = $(icm -ComputerName $RemoteComputer -ScriptBlock $Command)  | Select Name,StartName,StartMode,State
        Write-Verbose "GPOs = $GPO"        
    }
    else{
        Write-Verbose "Executing Service command on local computer"
        $Service = $(get-wmiobject win32_Service | Select Name,StartName,StartMode,State)
    }
    return $Service }
Function BuildNTFSObject{
    param([System.String]$File,
    [System.String]$RemoteComputer = $false) 
    if($RemoteComputer -ne $false){
        $File = $File -replace '%SystemDrive%','$env:SystemDrive'
        Write-Verbose "Executing ACL command on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( "Get-Acl ""$File"" |Select Access" )
        $ACLs = $(icm -ComputerName $RemoteComputer -ScriptBlock $Command) 
    }
    else{
        $File = $File -replace '%SystemDrive%',$env:SystemDrive
        Write-Verbose "Executing ACL command on local computer"
        $ACLs = $(Get-Acl $File | Select Access)
    }
    $ACLo = New-Object System.Collections.ArrayList
    $ACLs.Access | %{
        $tempACL = New-Object -TypeName PSObject
        $tempACL | Add-Member -Force -MemberType NoteProperty -Name "File" -Value $File
        $tempACL | Add-Member -Force -MemberType NoteProperty -Name "IdentityReference" -Value $_.IdentityReference
        $tempACL | Add-Member -Force -MemberType NoteProperty -Name "FileSystemRights" -Value $_.FileSystemRights
        $tempACL | Add-Member -Force -MemberType NoteProperty -Name "AccessControlType" -Value $_.AccessControlType
        $tempACL | Add-Member -Force -MemberType NoteProperty -Name "IsInherited" -Value $_.IsInherited
        $ACLo.Add($tempACL) | Out-Null
        $tempACL = ""
    }
    $ACLo = $ACLo | ?{$_ -ne $null}
    return $ACLo }
Function BuildShareObject{
    param([System.String]$RemoteComputer = $false) 
    if($RemoteComputer -ne $false){
        Write-Verbose "Executing Share command on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'Get-smbshare | ?{$_.Special -eq $false -and $_.Name -ne "print$"} | %{$p=$_.Path;$s=Get-smbshareaccess $_.Name; $s | Add-Member -Force -MemberType NoteProperty -Name "Path" -Value $p; $s }' )
        $Shares = $(icm -ComputerName $RemoteComputer -ScriptBlock $Command)
        Write-Verbose "Shares = $Shares"        
    }
    else{
        Write-Verbose "Executing Share command on local computer"
        $Shares = $(Get-smbshare | ?{$_.Special -eq $false -and $_.Name -ne "print$"} | %{$p=$_.Path;$s=Get-smbshareaccess $_.Name; $s | Add-Member -Force -MemberType NoteProperty -Name "Path" -Value $p; $s })
    }
    return $Shares    
}
Function ResolveComputer{
    param([System.String]$Computer)    
	$PingResult = Test-Connection -ComputerName $Computer -Count 1 -Quiet
    Write-Debug "Ping Result: $PingResult"
	if($PingResult){
        Write-Verbose "Computer Responds"
        try{
	        $WinRMResult = Test-WSMan -ComputerName $Computer 
        }
        catch{
            Write-Warning "Cannot complete WinRM connection"
            Exit
            return $false
        }
        return $true
    }    
    Write-Debug "No Computer Response"
    return $false    
}
Function Test-Administrator {  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}
If(Test-Administrator){
    Write-Verbose "Running as Administrator"
}
Else{
    Write-Warning "Not running as Administrator. Some errors will result."
}
$ACLlist = New-Object System.Collections.ArrayList
$Grps = New-Object System.Collections.ArrayList

If($Computer -ne $env:COMPUTERNAME){
    Write-Verbose "Running report on remote computer"
    If(ResolveComputer $Computer){
       # $ServerVersion = BuildVersionObject $Computer
        $InstalledRoles = BuildRoleObject $Computer
       # $InstalledSoftware = BuildSoftwareObject $Computer
       # $AppliedGPOs = BuildGPOObject $Computer
        $LocalGroups = BuildGroupObject $Computer
        $Services = BuildServiceObject $Computer
        $SMB = BuildShareObject $Computer        
        $SMB | %{
            $ACLArray = BuildNTFSObject $_.Path $Computer
            $ACLArray | %{
                $ACLlist.Add($_)| Out-Null
            }
        }
        If($IIS){
            if($InstalledRoles.Name -match "Web-Server"){
                $IISSites = BuildIISObject $Computer
                $IISAppPools = BuildIIAObject $Computer
                $IISSites | %{
                    $ACLArray = BuildNTFSObject $_.PhysicalPath $Computer
                    $ACLArray | %{
                        $ACLlist.Add($_)| Out-Null
                    }
                }
            }
            Else{
                Write-Warning "IIS not installed"
            }
        }
        If($SQL){
            if($InstalledRoles.Name -match "MSMQ"){
                $SQLInstanceLogins= BuildSQLObject $Computer
                $SQLDBLogins= BuildDBObject $Computer
                $SQLLogins| %{
                 #   $ACLArray = BuildNTFSObject $_.PhysicalPath $Computer
                 #   $ACLArray | %{
                 #       $ACLlist.Add($_)| Out-Null
                 #   }
                }
            }
            Else{
                Write-Warning "SQL not installed"
            }
        }
        If($Octopus){
            $OctApp = BuildOctopusObject $Computer
            $OctApp | %{
                $ACLArray = BuildNTFSObject $_.ExtractedTo $Computer
                $ACLArray | %{
                    $ACLlist.Add($_)| Out-Null
                }
            }
        }
    }
    Else{
        Write-Warning "Computer response not received.(Failed Ping)"
        Exit
    }
}
Else{
    Write-Verbose "Running report on local computer"
  #  $ServerVersion = BuildVersionObject
    $InstalledRoles = BuildRoleObject 
  #  $InstalledSoftware = BuildSoftwareObject 
  #  $AppliedGPOs = BuildGPOObject 
    $LocalGroups = BuildGroupObject 
    $Services = BuildServiceObject
    $SMB = BuildShareObject       
    $SMB | %{
        $ACLArray = BuildNTFSObject $_.Path
        $ACLArray | %{
            $ACLlist.Add($_)| Out-Null
        }
    }
    If($IIS){
        if($InstalledRoles.Name -match "Web-Server"){
            $IISSites = BuildIISObject
            $IISAppPools = BuildIIAObject
            $IISSites | %{
                $ACLArray = BuildNTFSObject $_.PhysicalPath 
                $ACLArray | %{
                    $ACLlist.Add($_)| Out-Null
                }
            }
        }
        Else{
            Write-Warning "IIS not installed"
        }

    }
        If($SQL){
            if($InstalledRoles.Name -match "MSMQ"){
                $SQLInstanceLogins= BuildSQLObject $Computer
                $SQLDBLogins= BuildDBObject $Computer
                $SQLLogins| %{
                 #   $ACLArray = BuildNTFSObject $_.PhysicalPath $Computer
                 #   $ACLArray | %{
                 #       $ACLlist.Add($_)| Out-Null
                 #   }
                }
            }
            Else{
                Write-Warning "SQL not installed"
            }
        }
    If($Octopus){
        $OctApp = BuildOctopusObject 
        $OctApp | %{
            $ACLArray = BuildNTFSObject $_.ExtractedTo 
            $ACLArray | %{
                $ACLlist.Add($_)| Out-Null
            }
        }
    }
}

$LocalGroups | ?{$_.User -match 'FOD'} | %{
    $GrpObj = New-Object PSObject
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Category" -Value "LocalGroups"
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Group" -Value $_.User
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Location" -Value $_.Group
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Computer" -Value $Computer
    $Grps.Add($GrpObj) | Out-Null
}
$Services | ?{$_.StartName -match 'FOD'} | %{
    $GrpObj = New-Object PSObject
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Category" -Value "Services"
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Group" -Value $_.StartName
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Location" -Value $_.Name
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Computer" -Value $Computer
    $Grps.Add($GrpObj) | Out-Null
}
$SMB | ?{$_.AccountName -match 'FOD'} | %{
    $GrpObj = New-Object PSObject
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Category" -Value "Share"
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Group" -Value $_.AccountName
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Location" -Value $_.Name
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Computer" -Value $Computer
    $Grps.Add($GrpObj) | Out-Null
}
$IISAppPools | ?{$_.UserName -match 'FOD'} | %{
    $GrpObj = New-Object PSObject
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Category" -Value "AppPool"
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Group" -Value $_.UserName
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Location" -Value $_.Application
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Computer" -Value $Computer
    $Grps.Add($GrpObj) | Out-Null
}
$ACLlist | ?{$_.IdentityReference -match 'FOD'} | %{
    $GrpObj = New-Object PSObject
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Category" -Value "NTFS"
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Group" -Value $_.IdentityReference
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Location" -Value $_.File
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Computer" -Value $Computer
    $Grps.Add($GrpObj) | Out-Null
}
$SQLInstanceLogins | ?{$_.Name.length -gt 1 } | %{
    $GrpObj = New-Object PSObject
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Category" -Value "SQLLogin"
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Group" -Value $_.Name
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Location" -Value $_.SQL
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Computer" -Value $Computer
    $Grps.Add($GrpObj) | Out-Null
}
$SQLDBLogins | ?{$_.Login.length -gt 1 } | %{
    $GrpObj = New-Object PSObject
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Category" -Value "DBLogin"
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Group" -Value $_.Login
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Location" -Value $_.DB
    $GrpObj | Add-Member -Force -MemberType NoteProperty -Name "Computer" -Value $Computer
    $Grps.Add($GrpObj) | Out-Null
}


If($CSV){
    If(-not (Test-Path $CSVPath)){
        $CSVPath = "."
    }
        $Grps | Export-CSV -Path $($CSVPath + '\' + $Computer + '-ADObjects.csv') -NoTypeInformation
}
Else {
    $Grps
#$SQLDBLogins | ft -auto
}
# SIG # Begin signature block
# MIIIPQYJKoZIhvcNAQcCoIIILjCCCCoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU7oHbGICmcO5I0pNxO3ZOldPb
# vHWgggWuMIIFqjCCBJKgAwIBAgITbgAAAKzOi+ol+RGLKQAAAAAArDANBgkqhkiG
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
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUBqgw2oIO
# VSANWLNXn5Dd73KHeJUwDQYJKoZIhvcNAQEBBQAEggEAYmwzX9j43loHb33MINBr
# 7oCk7fTM3Ddf4D/0uFI3cDj+rnoBVPTCAcPK+g5LOOEfASDq9wNh3hzVVLY7GXwa
# Fe9mzqBN2Zcq1CoBxbkgCLCZG2Ey3qW+3zJmKBvIneagGJ5cpAzjeCa+ZQMCTcuz
# ACIhKkg24m17in5f8TShJn1t04GERzXq1lgZf40NNYDiC1HWaz++FMWHu4Zhp7+4
# gA87JAs43f+GzrLdnbhkn5u7BE2cs9gcvkQjO2+Nkse+FOcQgUwcS4l8bgONB2/c
# 2d+TBBYLxo7vXnRskH588APvTMpKNs4Zq1IvNPPUrRcCDACd0KVDRekPaXwek6bm
# jg==
# SIG # End signature block
