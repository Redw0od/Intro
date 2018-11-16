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

Function BuildIISObject{
    param([System.String]$RemoteComputer = $false) 
    $IISo = ""
    if($RemoteComputer -ne $false){
        Write-Verbose "Executing IIS command on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'ipmo WebAdministration;gci IIS://sites' )
        $IISo = $(icm -ComputerName $RemoteComputer -ScriptBlock $Command)
    }
    else{
        Write-Verbose "Executing IIS command on local computer"
        $IISo = $(ipmo WebAdministration;gci IIS://sites)
    }
    Write-Verbose ("Sites = " + $IISo.count)        
     
    $IISo | %{Add-member -InputObject $_ -Force -MemberType NoteProperty -Name Binding -Value $_.Bindings.Collection.bindingInformation}
    $IISo | %{Add-member -InputObject $_ -Force -MemberType NoteProperty -Name Protocol -Value $_.Bindings.Collection.protocol}
    $IISo | %{Add-member -InputObject $_ -Force -MemberType NoteProperty -Name LogDir -Value $_.logFile.directory}
    $Sites = $IISo | Select Name,State,PhysicalPath,Protocol,Binding,LogDir
    Write-Verbose ("Sites = " + $Sites.count)  
    return $Sites
}
Function TestIIS{
    param([System.String]$RemoteComputer = $false) 
    $IISo = ""
    if($RemoteComputer -ne $false){
        Write-Verbose "Checking IIS on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'get-service' )
        $IISo = $(icm -ComputerName $RemoteComputer -ScriptBlock $Command)
    }
    else{
        Write-Verbose "Executing role command on local computer"
        $IISo = $(get-service)
    }        
    if($IISo | ?{$_.Name -match 'w3svc'}){ $status = $true }
    else { $status = $false }
    Write-Verbose "IIS Test = $status"   
    return $status     
}
Function TestOctopus{
    param([System.String]$RemoteComputer = $false) 
    $Octo = ""
    if($RemoteComputer -ne $false){
        Write-Verbose "Checking Octopus on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'Test-Path C:\octopus\Applications\.Tentacle\DeploymentJournal.xml' )
        $Octo = $(icm -ComputerName $RemoteComputer -ScriptBlock $Command)
    }
    else{
        Write-Verbose "Executing Octopus command on local computer"
        $Octo = $(Test-Path C:\octopus\Applications\.Tentacle\DeploymentJournal.xml)
    }        
    Write-Verbose "Octopus Status = $Octo"    
    return $Octo
}
Function TestWinRM{
    param([System.String]$RemoteComputer = $false) 
    $WinRM = ""
    if($RemoteComputer -ne $false){
        Write-Verbose "Checking WinRM on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'date' )
        try{
        $WinRM = $(icm -ComputerName $RemoteComputer -ScriptBlock $Command -ErrorAction Stop)
        $status = $true
        }
        catch
        {
            Write-Warning "WinRM not accessible."
            $status = $false
        }
    }
    else{
        $status = $true
    }        
    Write-Verbose "WinRM Status = $status"
    return $status    
}
Function BuildIIAObject{
    param([System.String]$RemoteComputer = $false) 
    if($RemoteComputer -ne $false){
        Write-Verbose "Executing AppPools command on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'ipmo WebAdministration;gci IIS://apppools' )
        $IISa = $(icm -ComputerName $RemoteComputer -ScriptBlock $Command)
    }
    else{
        Write-Verbose "Executing AppPools command on local computer"
        $IISa = $(ipmo WebAdministration;gci IIS://apppools)
    }
        Write-Verbose "AppPools = $($IISa.count)"       
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
					$roles = $_.enumroles()
					if(!$roles -gt 0){$roles="none"}
					$roles | %{
						$UserRole = New-Object PSObject
						$UserRole | Add-Member -MemberType NoteProperty -Name "DB" -Value $DB
						$UserRole | Add-Member -MemberType NoteProperty -Name "Login" -Value $User
						$UserRole | Add-Member -MemberType NoteProperty -Name "Role" -Value $_
						$DBRoles.Add($UserRole) | Out-Null
						$UserRole = $null
					} 
				}
			}
		} catch { 
			 Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" 
			$false 
		} 
	return $DBRoles
}
Function BuildSQLDBObject{
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
            $SQLDetails = New-Object System.Collections.Arraylist
            foreach ($Computer in $Computername) { 
                $Instances = GetSqlInstance -Computername $Computer 
                foreach ($Instance in $Instances.Instance) { 
                    if ($Instance -eq 'MSSQLSERVER') { 
                        $Server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $Computer 
                    } else { 
                        $Server = new-object ('Microsoft.SqlServer.Management.Smo.Server') "$Computer`\$Instance" 
                    } 
                    $SQLDetails.Add($Server) | Out-Null

                } 
            } 
            Return $SQLDetails
        } catch { 
            Write-Error "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" 
            $false 
        } 
    } 
}
Function BuildOctopusObject{
    param([System.String]$RemoteComputer = $false) 
    if($RemoteComputer -ne $false){
        Write-Verbose "Executing Octopus command on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'Get-Content C:\Octopus\Applications\.Tentacle\DeploymentJournal.xml ' )
        [XML]$XML = $(icm -ComputerName $RemoteComputer -ScriptBlock $Command) 
    }
    else{
        Write-Verbose "Executing Octopus command on local computer"
        [XML]$XML = Get-Content C:\Octopus\Applications\.Tentacle\DeploymentJournal.xml
    }
        Write-Verbose "Octopus = $(($XML.Deployments.Deployment).count)"        
    $Apps = $($xml.Deployments.Deployment.PackageId | Sort -Unique | %{$a=$_;$xml.Deployments.Deployment | ?{$_.PackageId -eq $a} | Sort InstalledOn | select -last 1})
    $OctopusObj = New-Object System.Collections.ArrayList
    $Apps | %{
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
    $VersionObj = New-Object System.Collections.ArrayList
    $VersionObj.Add($Object)
    return $VersionObj    
    }
Function BuildRoleObject{
    param([System.String]$RemoteComputer = $false) 
    if($RemoteComputer -ne $false){
        Write-Verbose "Executing role command on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'get-windowsfeature | ?{$_.InstallState -eq "Installed"} ' )
        $Roles = $(icm -ComputerName $RemoteComputer -ScriptBlock $Command) | Select Name
    }
    else{
        Write-Verbose "Executing role command on local computer"
        $Roles = $(get-windowsfeature | ?{$_.InstallState -eq "Installed"} | Select Name)
    }
        Write-Verbose "Roles = $($Roles.count)"        

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
              
    }
    else{
        Write-Verbose "Executing software command on local computer"
        $Software = $(get-itemproperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | ?{$_.DisplayName -gt 0 } | Select DisplayName, DisplayVersion, InstallDate)
        $Software += $(get-itemproperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*  | ?{$_.DisplayName -gt 0 } | Select DisplayName, DisplayVersion, InstallDate)
    }
    Write-Verbose "Software = $($Software.count)"  
    return $Software
}
Function BuildGPOObject{
    param([System.String]$RemoteComputer = $false) 
    if($RemoteComputer -ne $false){
        Write-Verbose "Executing GPO command on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'gpresult /r' )
        $GPresult = $(icm -ComputerName $RemoteComputer -ScriptBlock $Command) 
    }
    else{
        Write-Verbose "Executing GPO command on local computer"
        $GPresult = $(gpresult /r )
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
        Write-Verbose "GPOs = $($GPOList.count)"        
    return $GPOList 
}
Function BuildGroupObject{
    param([System.String]$RemoteComputer = $false) 
    $Groups = New-Object System.Collections.ArrayList
    if($RemoteComputer -ne $false){
        Write-Verbose "Executing Groups command on remote computer"
        try{
        $WMIGroups = $(gwmi win32_groupuser -ComputerName $RemoteComputer -ErrorAction Stop) 
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
        }
        catch{
            Write-Warning "Local Group lookup failed to reach RPC Server"
        }
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
        Write-Verbose "Groups = $($Groups.count)"   
    return $Groups 
}
Function BuildServiceObject{
    param([System.String]$RemoteComputer = $false) 
    if($RemoteComputer -ne $false){
        Write-Verbose "Executing Service command on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'get-wmiobject win32_Service' )
        $Service = $(icm -ComputerName $RemoteComputer -ScriptBlock $Command)  | Select Name,StartName,StartMode,State
          
    }
    else{
        Write-Verbose "Executing Service command on local computer"
        $Service = $(get-wmiobject win32_Service | Select Name,StartName,StartMode,State)
    } 
    Write-Verbose "Service = $($Service.count)"    
    return $Service 
}
Function BuildNTFSObject{
    param([System.String]$File,
    [System.String]$RemoteComputer = $false) 
    if($RemoteComputer -ne $false){
        $File = $File -replace '%SystemDrive%','$env:SystemDrive'
        Write-Verbose "Executing ACL command on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( "Get-Acl ""$File""|Select Access" )
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
    Write-Verbose "NTFS = $($ACLo.count)"   
    return $ACLo }
Function BuildShareObject{
    param([System.String]$RemoteComputer = $false) 
    if($RemoteComputer -ne $false){
        Write-Verbose "Executing Share command on remote computer"
        [ScriptBlock]$Command = [ScriptBlock]::Create( 'Get-smbshare | ?{$_.Special -eq $false -and $_.Name -ne "print$"} | %{$p=$_.Path;$s=Get-smbshareaccess $_.Name; $s | Add-Member -Force -MemberType NoteProperty -Name "Path" -Value $p; $s }' )
        $Shares = $(icm -ComputerName $RemoteComputer -ScriptBlock $Command)
    }
    else{
        Write-Verbose "Executing Share command on local computer"
        $Shares = $(Get-smbshare | ?{$_.Special -eq $false -and $_.Name -ne "print$"} | %{$p=$_.Path;$s=Get-smbshareaccess $_.Name; $s | Add-Member -Force -MemberType NoteProperty -Name "Path" -Value $p; $s })
    }
        Write-Verbose "Shares = $($Shares.count)"        
    return $Shares    
}
Function ResolveComputer{
    param([System.String]$Computer)    
	$PingResult = Test-Connection -ComputerName $Computer -Count 1 -Quiet
    Write-Debug "Ping Result: $PingResult"
	if($PingResult){
        Write-Verbose "Computer Responds"
        return $true
    }    
    Write-Verbose "No Computer Response"
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

If($Computer -ne $env:COMPUTERNAME){
    Write-Verbose "Running report on remote computer"
    If(ResolveComputer $Computer){
        $LocalGroups = BuildGroupObject $Computer
        If(TestWinRM $Computer){
            $ServerVersion = BuildVersionObject $Computer
            $InstalledRoles = BuildRoleObject $Computer
            $InstalledSoftware = BuildSoftwareObject $Computer
            $AppliedGPOs = BuildGPOObject $Computer
            $Services = BuildServiceObject $Computer
            $SMB = BuildShareObject $Computer        
            $SMB | %{
                $ACLArray = BuildNTFSObject $_.Path $Computer
                $ACLArray | %{
                    $ACLlist.Add($_)| Out-Null
                }
            }
            If($IIS){
                If(TestIIS $Computer){
                    $IISSites = BuildIISObject $Computer
                    $IISAppPools = BuildIIAObject $Computer
                    $IISSites | %{
                        $ACLArray = BuildNTFSObject $_.PhysicalPath $Computer
                        $ACLArray | %{
                            $ACLlist.Add($_)| Out-Null
                        }
                    }
                }
                else { Write-Warning "IIS not found"}
            }
            If($SQL){
                if($InstalledRoles.Name -match "MSMQ"){
                    $SQLInstanceLogins= BuildSQLObject $Computer
                    $SQLDBLogins= BuildDBObject $Computer
                    $SQLDBDetails = BuildSQLDBObject $Computer
                    $SQLDBDetails| %{
                        $ACLArray = BuildNTFSObject $_.BackupDirectory $Computer
                        $ACLArray | %{
                            $ACLlist.Add($_)| Out-Null
                        }
                        $ACLArray = BuildNTFSObject $_.DefaultFile $Computer
                        $ACLArray | %{
                            $ACLlist.Add($_)| Out-Null
                        }
                        $ACLArray = BuildNTFSObject $_.DefaultLog $Computer
                        $ACLArray | %{
                            $ACLlist.Add($_)| Out-Null
                        }
                        $ACLArray = BuildNTFSObject $_.ErrorLogPath $Computer
                        $ACLArray | %{
                            $ACLlist.Add($_)| Out-Null
                        }
                        $ACLArray = BuildNTFSObject $_.InstallDataDirectory $Computer
                        $ACLArray | %{
                            $ACLlist.Add($_)| Out-Null
                        }
                        $ACLArray = BuildNTFSObject $_.MasterDBPath $Computer
                        $ACLArray | %{
                            $ACLlist.Add($_)| Out-Null
                        }
                        $ACLArray = BuildNTFSObject $_.RootDirectory $Computer
                        $ACLArray | %{
                            $ACLlist.Add($_)| Out-Null
                        }
                    }
                }
                Else{
                    Write-Warning "SQL not installed"
                }
            }
            If($Octopus){
                If(TestOctopus $Computer){
                    $OctApp = BuildOctopusObject $Computer
                    $OctApp | %{
                        $ACLArray = BuildNTFSObject $_.ExtractedTo $Computer
                        $ACLArray | %{
                            $ACLlist.Add($_)| Out-Null
                        }
                    }
                }
                else { Write-Warning "Octopus not found"}
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
    $ServerVersion = BuildVersionObject
    $InstalledRoles = BuildRoleObject 
    $InstalledSoftware = BuildSoftwareObject 
    $AppliedGPOs = BuildGPOObject 
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
        If(TestIIS){
            $IISSites = BuildIISObject
            $IISAppPools = BuildIIAObject
            $IISSites | %{
                $ACLArray = BuildNTFSObject $_.PhysicalPath 
                $ACLArray | %{
                    $ACLlist.Add($_)| Out-Null
                }
            }
        }
        else { Write-Warning "IIS not found"}
    }
        If($SQL){
            if($InstalledRoles.Name -match "MSMQ"){
                $SQLInstanceLogins= BuildSQLObject $Computer
                $SQLDBLogins= BuildDBObject $Computer
                $SQLDBDetails = BuildSQLDBObject $Computer
                $SQLDBDetails| %{
                    $ACLArray = BuildNTFSObject $_.BackupDirectory $Computer
                    $ACLArray | %{
                        $ACLlist.Add($_)| Out-Null
                    }
                    $ACLArray = BuildNTFSObject $_.DefaultFile $Computer
                    $ACLArray | %{
                        $ACLlist.Add($_)| Out-Null
                    }
                    $ACLArray = BuildNTFSObject $_.DefaultLog $Computer
                    $ACLArray | %{
                        $ACLlist.Add($_)| Out-Null
                    }
                    $ACLArray = BuildNTFSObject $_.ErrorLogPath $Computer
                    $ACLArray | %{
                        $ACLlist.Add($_)| Out-Null
                    }
                    $ACLArray = BuildNTFSObject $_.InstallDataDirectory $Computer
                    $ACLArray | %{
                        $ACLlist.Add($_)| Out-Null
                    }
                    $ACLArray = BuildNTFSObject $_.MasterDBPath $Computer
                    $ACLArray | %{
                        $ACLlist.Add($_)| Out-Null
                    }
                    $ACLArray = BuildNTFSObject $_.RootDirectory $Computer
                    $ACLArray | %{
                        $ACLlist.Add($_)| Out-Null
                    }
                }
            }
            Else{
                Write-Warning "SQL not installed"
            }
        }
    If($Octopus){
        If(TestOctopus){
            $OctApp = BuildOctopusObject 
            $OctApp | %{
                $ACLArray = BuildNTFSObject $_.ExtractedTo 
                $ACLArray | %{
                    $ACLlist.Add($_)| Out-Null
                }
            }
        }
        else { Write-Warning "Octopus not found"}
    }
}

If($CSV){
    If(-not (Test-Path $CSVPath)){
        $CSVPath = "."
    }
        if($LocalGroups.Count -gt 0){
            $LocalGroups | Export-CSV -Path $($CSVPath + '\' + $Computer + '-Groups.csv') -NoTypeInformation
        }
        if($ServerVersion.Count -gt 0){
            $ServerVersion | Export-CSV -Path $($CSVPath + '\' + $Computer + '-Version.csv') -NoTypeInformation
        }
        if($InstalledRoles.Count -gt 0){
            $InstalledRoles | Export-CSV -Path $($CSVPath + '\' + $Computer + '-Roles.csv') -NoTypeInformation
        }
        if($InstalledSoftware.Count -gt 0){
            $InstalledSoftware | Sort DisplayName | Get-Unique -AsString | Export-CSV -Path $($CSVPath + '\' + $Computer + '-Software.csv') -NoTypeInformation
        }
        if($AppliedGPOs.Count -gt 0){
            $AppliedGPOs | Export-CSV -Path $($CSVPath + '\' + $Computer + '-GPOs.csv') -NoTypeInformation
        }
        if($Services.Count -gt 0){
            $Services | Export-CSV -Path $($CSVPath + '\' + $Computer + '-Services.csv') -NoTypeInformation
        }
        if($SMB.Count -gt 0){
            $SMB | Export-CSV -Path $($CSVPath + '\' + $Computer + '-Shares.csv') -NoTypeInformation
        }
        If($IIS){
            if($IISSites.Count -gt 0){
                $IISSites | Export-CSV -Path $($CSVPath + '\' + $Computer + '-WebSites.csv') -NoTypeInformation
            }
            if($IISAppPools.Count -gt 0){
                $IISAppPools | Export-CSV -Path $($CSVPath + '\' + $Computer + '-AppPools.csv') -NoTypeInformation
            }
        }
        If($SQL){
            if($SQLInstanceLogins.Count -gt 0){
                $SQLInstanceLogins | Export-CSV -Path $($CSVPath + '\' + $Computer + '-SQLLogins.csv') -NoTypeInformation
            }
            if($SQLDBLogins.Count -gt 0){
                $SQLDBLogins | Export-CSV -Path $($CSVPath + '\' + $Computer + '-SQLDBusers.csv') -NoTypeInformation -Force
            }
            if($SQLDBDetails.Count -gt 0){
                $SQLDBDetails | Export-CSV -Path $($CSVPath + '\' + $Computer + '-SQLServer.csv') -NoTypeInformation -Force
            }
        }
        If($Octopus){
            if($OctApp.Count -gt 0){
                $OctApp | Export-CSV -Path $($CSVPath + '\' + $Computer + '-Octopus.csv') -NoTypeInformation
            }
        }
        If($Octopus -or $IIS -or $SQL){
            if($ACLlist.Count -gt 0){
                $ACLlist | Export-CSV -Path $($CSVPath + '\' + $Computer + '-NTFS.csv') -NoTypeInformation
            }
        }
}
Else {
    $ServerVersion | ft -AutoSize
    $InstalledRoles | ft -AutoSize
    $InstalledSoftware | Sort DisplayName | Get-Unique -AsString | ft -AutoSize
    $AppliedGPOs | ft -AutoSize
    $LocalGroups | ft -AutoSize
    $Services | ft -AutoSize
    If($SMB.length -gt 0){
        $SMB | ft -AutoSize
    }
    If($IIS){
        $IISSites | ft -AutoSize
        $IISAppPools | ft -AutoSize
    }
    If($SQL){
        $SQLInstanceLogins | ft -AutoSize
        $SQLDBLogins | ft -AutoSize
        $SQLDBDetails | ft -AutoSize
    }
    If($Octopus){
        $OctApp | ft -Autosize
    }
    If($IIS -or $Octopus -or $SQL){
        $ACLlist | ft -AutoSize
    }
}
# SIG # Begin signature block
# MIIIPQYJKoZIhvcNAQcCoIIILjCCCCoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU8be9kfwQsfpdBKzP07T8HFsQ
# s2mgggWuMIIFqjCCBJKgAwIBAgITbgAAAKzOi+ol+RGLKQAAAAAArDANBgkqhkiG
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
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUaCQ+ZoPb
# kfCgrUGw8FExfMtqdaAwDQYJKoZIhvcNAQEBBQAEggEAgPnd4j/v7CbaAG1KE8dQ
# FAhLeFeX78f+M8eidagM1cg8n+Irh7Vi2sUkek/v/bbk5ytL7WpSzNLe4KRTDBPp
# J6FYXVZZTuhUM9WDVvIzp49wiaV6frfxRxjQ3vPt2z3qxPpGiAPUc/cL1MqEF/GP
# Yk9GZQtJqPb67t4qvwsVLXUfAnc81ISswzf/KmIUGkh2IRS1u0zGp/BIBupb6wxB
# dzgpogrPl+joHO/xmVhPhaB3AIR5xv5U7FDRDOcIG0+QTCgEtnkRgLYEv3RcMGlm
# ZonI8+fFD8dbjBo+qf4Kcf0vAZz4kbcAX1lKkGHDqSo/ov1b+vGZNFeZtKBfltSP
# rw==
# SIG # End signature block
