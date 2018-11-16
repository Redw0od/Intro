<#
.SYNOPSIS   
Make basic modifications to new ESXi Servers
    
.DESCRIPTION 
Perform multiple operations on ESXi servers for the new vCenter. 
Including distributed switch migration, vmkernel creation, 
datastore renaming, profile applications and more.
	
.PARAMETER VMHost
Name of the ESXi Server to modify.

.PARAMETER ESXCreds
Credentials to use for connecting to the ESXi Server, usually root

.PARAMETER Cluster
The name of the cluster to attach host into

.PARAMETER vCreds
Credentials to use for connecting to vCenter, usually Administrator@vsphere.local

.PARAMETER vCenter
The name of the vCenter Server.

.PARAMETER IPOctet
The last octet of the ESXi servers IP address. Used for consistency on additional vmKernels

.PARAMETER IPNet
The first 2 octets of the ESX IP address inluding "." i.e. "10.114"

.PARAMETER NTP
The time servers to apply to ESXi servers NTP service in array format.

.PARAMETER Logs
The directory to configure as the persistant log location.

.PARAMETER Session
vCenter session to use instead of creating a new one.

.PARAMETER Restart
Reboot the ESXi Server after changes are complete.

.PARAMETER Verbose
Output more than usual.
	

.NOTES   
Name: Configure-VMHost.ps1
Author: Mike Stanton
Version: 0.5
DateCreated: 2017-4-26
DateUpdated: 2017-4-26


.EXAMPLE   
.\Configure-VMHost.ps1 -vmhost server1.hpfod.net -ESXCreds $(Get-Credentials) -Verbose 

#>
[cmdletbinding()]
param(
    [string]
        $VMHost = (Read-Host "Please enter a ESXi Server name to modify"),
    [PSCredential]
        $ESXCreds = (Get-Credential -Credential "root"),
    [string]
        $Cluster = $(if(($result = Read-Host "Enter a cluster name [bl460c g9]") -eq ''){"bl460c g9"}else{$result}),
    [PSCredential]
        $vCreds = (Get-Credential -Credential "Administrator@vsphere.local"),
    [string]
        $vCenter = $(if(($result = Read-Host "Enter a vCenter name [vcenter1.hpfod.net]") -eq ''){"vcenter1.hpfod.net"}else{$result}),
    [string]
        $IPOctet = $(([System.Net.Dns]::GetHostAddresses($VMHost)).IPAddressToString.Split('.')[3]),
    [string]
        $IPNet = $((([System.Net.Dns]::GetHostAddresses($VMHost)).IPAddressToString.Split('.')[0,1]) -join '.'),
    [array]
        $NTP = @("pool.ntp.org"),
	[string]
		$Logs = "/vmfs/volumes/syslogs",
	[object]
		$Session = "",
    [switch]
        $Restart = $false
)
$ErrorActionPreference = 'Stop'

Write-Host "ESXi Server = $VMHost"
Write-Verbose "vCenter = $vCenter"
Write-Verbose "Cluster = $Cluster"
Write-Verbose "IPOctet = $IPOctet"
Write-Verbose "IPNet = $IPNet"
try{Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null}
catch {Write-Warning ("Failed to configure certificate exceptions")}
if($Session -eq ""){
	try{Disconnect-VIServer -Server * -Force -Confirm:$false}
	catch {Write-Verbose ("No current virtual server connections.")}
}

#When updating the defaults, Also update Datastore name in SetDSName Function
$global:VMHost = $VMHost
$ManagementSubnetNumber = "10"
$vMotionSubnetNumber = "100"
$vMigrationSubnetNumber = "101"
$vFTSubnetNumber = "102"
$VSANSubnetNumber = "103"
$VRepSubnetNumber = "104"
$ManagementPortgroup = "VLAN-010 Management"
$vMotionPortgroup = "VLAN-100 vMotion"
$vMigrationPortgroup = "VLAN-101 vMigration"
$vFTPortgroup = "VLAN-102 vFT"
$vSANPortgroup = "VLAN-103 vSAN"
$vRepPortgroup = "VLAN-104 vReplication"

#Build IP addresses for new kernels
$vMotionIP = $IPNet + "." + $vMotionSubnetNumber + "." + $IPOctet
$vMigrationIP = $IPNet + "." + $vMigrationSubnetNumber + "." + $IPOctet
$vFtIP = $IPNet + "." + $vFTSubnetNumber + "." + $IPOctet
$vSanIP = $IPNet + "." + $VSANSubnetNumber + "." + $IPOctet
$vRepIP = $IPNet + "." + $VRepSubnetNumber + "." + $IPOctet


Function ResolveHost{
	param( 	$vHost	)
	Write-Host ("Testing lookup details for: " + $vHost)	
	$unconnected = $true
	while($unconnected){
		try
		{
			$([System.Net.Dns]::GetHostAddresses($vHost).IPAddressToString) | Out-Null
			$unconnected = $false 
		}
		catch
		{
			Write-Warning ("ResolveHost: Failed to resolve " + $vHost + " server name"); 
			if(($result = Read-Host "Try again? [Y/N](Y)") -eq 'n'){exit}else{$vHost = Read-Host "Enter vCenter server Name: "}
		}
	}
	return $vHost
}
Function vCenterConnect{
	param( 	$vHost,
			$Creds)	
	$unconnected = $true
	while($unconnected){
		try
		{			
			Connect-VIServer $vHost -Credential $Creds | Out-Null
			$unconnected = $false
		}
		catch
		{
			Write-Warning ("vCenterConnect: Failed to connect to vCenter: "+ $vHost); 
			if(($result = Read-Host "Try again? [Y/N](Y)") -eq 'n'){exit}else{$Creds = Get-Credential}
		}
	}
}
Function VerifyOctet{
	param( 	$IPOctet,
			$vHost)
	Write-Host ("Validating host octect for " + $vHost)	
	$unverified = $true
	while($unverified){
		try
		{			
			$ResolvedOctet = $(([System.Net.Dns]::GetHostAddresses($vHost)).IPAddressToString.Split('.')[3])
		}
		catch
		{
			Write-Warning ("VerifyOctet: Failed to lookup host IP address. Unique ID: " + $IPOctet); 
			if(($result = Read-Host "Continue? [Y/N](Y)") -eq 'n'){exit}else{$IPOctet = Read-Host "What's the unique number for this server?"}
		}
		try
		{
			if($IPOctet -eq $ResolvedOctet)
			{
				$unverified = $false
			}
			else
			{
				Write-Host ("Resolved IP octet " + $ResovlvedOctet + " does not match " + $IPOctet); 
				if(($result = Read-Host "Continue? [Y/N](Y)") -eq 'n')
				{				
					Write-Host "Exitting script"
					exit
				}
				else
				{
					$unverified = $false
				}				
			}
		}
		catch
		{
			Write-Warning ("VerifyOctet: Failed to verify octet " + $IPOctet); 
		}
	}
	return $IPOctet
}
Function VerifyCluster{
	param($Cluster)
	Write-Host ("Testing lookup details for: " + $Cluster)	
	$noCluster = $true
	while($noCluster){
		try
		{
			$vHost = Get-Cluster $Cluster | Get-VMHost | ?{$_.name -eq $global:VMHost} 
			$noCluster = $false
		}
		catch{
			Write-Warning ("Cluster name: " + $Cluster + " not found." ); 
			Get-Cluster
			if(($result = Read-Host "Try again? [Y/N](Y)") -eq 'n'){exit}else{$Cluster = Read-Host ("Enter cluster name: ")}
		}
	}
	Return $vHost
}
Function AddToCluster{
	param(	$vHost,
			$Cluster,
			$Creds)
	if($vHost.count -eq 0){
		Write-Verbose ($global:VMHost + " is not part of cluster " + $Cluster)
		Write-Verbose ("Adding: " + $global:VMHost + " to cluster " + $Cluster)
		$noAuth = $true
		while($noAuth){
			try
			{
				Get-Cluster $Cluster | Add-VMHost -Credential $Creds -Name $global:VMHost
				$noAuth = $false
			}
			catch 
			{
				Write-Warning ("AddToCluster: Failed to add " + $global:VMHost + " to " + $Cluster); 
				if(($result = Read-Host "Try again? [Y/N](Y)") -eq 'n'){exit}else{$Creds = Get-Credential}
			}
		}
	}
	else
	{
		Write-Host ($global:VMHost + " is already in cluster: " +  $Cluster)
	}
	Return $Creds
}
Function dvSwitch{
	try
	{
		Write-Verbose "Getting Distributed Switch"
		$VDSw = Get-VDSwitch
	}
	catch 
	{
		Write-Warning ("dvSwitch: Failed to get distributed switch"); 
		return $false
	}
	if($VDSw.count -gt 1)
	{
		Write-Host "Found more than one Distrubuted Switch"
		for ($i=0; $i -lt $VDSw.count; $i++)
			{
				Write-Host ($i.tostring() + ". " + $VDSw[$i].Name)
			}
			$VDSw = $(if(($result = Read-Host "Please enter the number of the desired switch. [0]") -eq ''){$VDSw[0]}else{$VDSw[$result]})
	}
	Return $VDSw
}
Function dvSwitchAdd{
	param($VDSw)
	if($VDSw -ne $false){
		try
		{	
			$OnSwitch = $global:VMHostObj | get-vdswitch
			if($OnSwitch.count -eq 0){
				write-host ("Adding: " + $global:VMHost + " to switch: " + $VDSw.Name)
				Add-VDSwitchVMHost -VDSwitch $VDSw -VMHost $global:VMHost
			}
			else
			{
				write-host ($global:VMHost + " is already in switch: " +  $VDSw.Name)
			}
		}
		catch 
		{
			Write-Warning ("dvSwitchAdd: Failed to add host to distributed switch");
			Write-Warning $Error[0];
		}
	}
}
Function dvSwitchNics{
	param($VDSw)
	try
	{	
		$Nics = $global:VMHostObj | Get-VMHostNetworkAdapter -Physical -DistributedSwitch $VDSw
	}
	catch 
	{
		Write-Warning ("dvSwitchNics: Failed to add host to distributed switch");
		$Nics = 0
	}
	Return $Nics
}
Function vSwitch{
	try{
		$switch = $global:VMHostObj | Get-VirtualSwitch -Standard 
	}
	catch
	{
		$switch = $false
		write-warning ("No standard switch found!")
	}
    if($switch.count -eq 0)
    {
        Return $false
		write-warning ("No standard switch found!")
    }
    else
    {
	    Return $switch
    }
}
Function vSwitchNics{
	param($vswitch)
	if($vswitch -ne $false)
	{
		try{
			$Nics = $vswitch | Get-VMHostNetworkAdapter -Physical
		}
		catch
		{
			write-warning ("vSwitchNics: No NICs found on standard switch")
		}
	}
	else
	{
		$Nics = 0
	}
	Return $Nics
}
Function dvSwitchAdapterAdd{
	param(	$VDSw,
			$Nic )
	try
	{
		$Nic | %{Add-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $_ -DistributedSwitch $VDSw -Confirm:$false}
		return $true
	}
	catch
	{
			write-warning ("dvSwitchAdapterAdd: Failed to add Nic " + $Nic.Name + " to distributed switch")
	
	}
	Return $Nics
}
Function dvAddFirstNic{
	param(	$VDSw,
			$Nics,
            $VDNics )	
    if($VDNics.count -eq 0){	
	    if($Nics.count -gt 0)
	    {
		    try
		    {
			    write-host ("Adding first physical nic to Distributed switch : " + $VDSw.Name)
			    $Nics = dvSwitchAdapterAdd $VDSw $($Nics | Select -First 1) 
		    }
		    catch
		    {
				    write-warning ("dvSwitchAdapterAdd: Failed to add Nic " + $Nic.Name + " to distributed switch")	
			        $Nics = $false	
		    }
	    }
	    else
	    {
		    write-host ("dvAddFirstNic: No physical NICs attached to standard switch")
			$Nics = $false
	    }
    }
    else
    {
        write-host ("dvAddFirstNic: Physical network adapters already connected to " + $VDSw.Name)
        $Nics = $true
    }
	Return $Nics
}
Function dvAddVmk{
	param(	$VDSw,
			$PG,
			$vmk)	
	try
	{
		$dvmk = $global:VMHostObj | Get-VMHostNetworkAdapter -vmKernel -DistributedSwitch $VDSw -Name $vmk
	}
	catch
	{
		write-host ("dvAddVmk:  Failed to enumerate vmKernel adapters on " + $VDSw.Name + " " + $vmk)
	}
	if($dvmk.count -eq 0)
	{
		write-host ("Migrating vmKernel " + $vmk + " to: " + $VDSw.Name)
		$dvportgroup = Get-VDPortGroup -Name $PG -VDSwitch $VDSw
		$vmk = $global:VMHostObj | Get-VMHostNetworkAdapter -vmKernel -Name $vmk
		Set-VMHostNetworkAdapter -PortGroup $dvportgroup -VirtualNic $vmk -confirm:$false | Out-Null
	}
	else{
		write-host ("dvAddVmk: vmKernel adapter already connected to Distributed switch : " + $VDSw.Name)
	}	
}
Function vmkByNetwork{
	param(	$networks,
			$Octet)	
	try
	{
		$vmk = ($networks | ?{$_.Net -eq $Octet}).Name
        write-host ("vmkByNetwork: " + $vmk + " points to " + $Octet)
	}
	catch
	{
		write-host ("vmkByNetwork:  Error accessing networks array " )
	}
	return $vmk
}
Function dvAddAllNics{
	param(	$VDSw,
			$Nics )		
	$Uplinks = $VDSw.NumUplinkPorts - 1
	if($Nics)
	{
		try
		{
			foreach($Nic in $Nics)
			{
				if($Uplinks -gt 0)
				{
					write-host ("Adding nic " + $Nic.Name + " to Distributed switch : " + $VDSw.Name)
					dvSwitchAdapterAdd $VDSw $Nic 					
					$Uplinks -= 1
				}
			}
		}
		catch
		{
			write-warning ("dvAddAllNics: Failed to add Nic " + $Nic.Name + " to distributed switch")		
		}
	}
	else
	{
		write-host ("dvAddFirstNic: No physical NICs attached to standard switch")
	}
}
Function UpdateInterfaceTable{
	param($esxcli)
	try
	{
		$interfaces = $esxcli.network.ip.interface.ipv4.address.list() 
	}
	catch
	{
		Write-Warning "UpdateInterfaceTable: Failed to enumerate ipv4 interfaces"
	}
	return $interfaces
}
Function UpdateNetworkTable{
	param($interfaces)
	try
	{
		$table = $interfaces | Select  Name, @{Name="Net"; Expression={$_.IPv4Address.Split('.')[2]}}
	}
	catch
	{
		Write-Warning "UpdateNetworkTable: Failed to build network table"
	}
	return $table
}
Function EnumerateNetstacks{
	param($esxcli)
	try
	{
		$netstacks = $esxcli.network.ip.netstack.list() 
	}
	catch
	{
		Write-Warning "EnumerateNetstacks: Failed to enumerate netstacks"
	}
	return $netstacks
}
Function vNetstack{
	param(	$esxcli,
			$netstacks,
			$name)
	if($netstacks.Key -notcontains $name){
		try
		{
			$esxcli.network.ip.netstack.add($null,$name)
			return $true
		}
		catch
		{
			Write-Warning ("vMotionNetstack: Failed to create netstack: " + $name)
		}
	}
	return $false
}
Function vKernel{
	param(	$esxcli,
			$networks,
			$NewvMotion,
			$Net,
			$Name)
	$vname = $networks | ?{ $_.Net -eq $Net } | %{$_.Name}
	if($vname.count -gt 0)
	{
		try 
		{
			$interface = $esxcli.network.ip.interface.list() | ?{$_.Name -eq $vname}
		}
		catch
		{
			Write-Warning ("vKernel: Failed to lookup ip interface list: " + $vname)
		}
		if($interface.NetstackInstance -ne $Name){
			try
			{
				$global:VMHostObj | Remove-vmHostNetworkAdapter -Nic $vname -Confirm:$false
				return $true
			}
			catch
			{
				Write-Warning ("vKernel: Failed to remove vmKernel adapter: " + $vname)
				$esxcli.network.ip.interface.remove($null, $null, $vname, $null, $null)
			}
		}
	}
	return $NewvMotion
}
Function CreateVirtualSwitch{
	try
	{
		$vstandard = $global:VMHostObj | Get-VirtualSwitch -standard
		if($vstandard.count -eq 0) 
		{		
			$vstandard = New-VirtualSwitch -VMHost $global:VMHost -Name "vSwitch0" -Mtu 9000 -Confirm:$false 
		}
	}
	catch
	{
		Write-Warning "CreateVirtualSwitch: Trouble with virtual switch"
	}
	return $vstandard
}
Function CreatePortGroup{
	param(	$vstandard,
			$Net,
			$Name )
	try
	{
		$vspg = Get-VirtualPortGroup -VirtualSwitch $vstandard | ?{$_.VLanId -eq $Net}
		if($vspg.count -eq 0)
		{	
			$vspg = New-VirtualPortGroup -Name $Name -VirtualSwitch $vstandard -VLanID $Net -Confirm:$false 
			return $Name
		}
		else 
		{
			return $vspg.Name
		}
	}
	catch
	{
		Write-Warning ("CreatePortGroup: Trouble with port group " + $Name)
	}
	return $Name
}
Function vmkRepair{
	param(	$esxcli,
            $networks,
			$vmk,
			$Name,
			$pgname,
			$New)
    try
    {
        $exists = $esxcli.network.ip.interface.list() | ?{$_.NetstackInstance -eq $Name}
    }
    catch
    {
        Write-Warning ("vmkRepair: Unable to query ESXCLI")
    }
    if($exists.count -eq 0)
    {
        $New = $true
    }
	if($New)
	{
		$vname = if($networks.Name -contains $vmk){"vmk" + $networks.count}else{$vmk}
		try
		{
			$($esxcli.network.ip.interface.add($null,$null,$vname,$null,9000,$Name,$pgname) ) | Out-Null
		}
		catch
		{
			Write-Warning ("vmkRepair: " +$vname + " interface already exists.")
		}
	}
    else 
    {
        $vname = $vmk
    }
	return $vname
}
Function MigrateVmk{
	param(	$VDSw,
			$pgname,
			$vname,
			$IP)
	try
	{
        $pg = $VDSw |  Get-VirtualPortgroup -Name $pgname
        $vmk = $pg | Get-VMHostNetworkAdapter -VMHost $global:VMHost
        if($vmk.count -eq 0)
        {
	        write-host ("MigrateVmk: Migrating " + $vname + " vmKernel to: " + $VDSw.Name + ":" + $pgname)
		    $dvportgroup = Get-VDPortGroup -Name $pgname -VDSwitch $VDSw
		    sleep 5
	        write-host ("MigrateVmk: Get-VMHostNetworkAdapter -VMHost" +  $global:VMHost + " -vmKernel -Name " + $vname)
            $adapters = Get-VMHostNetworkAdapter -VMHost $global:VMHost -vmKernel 
            write-host $adapters
		    $vmk = Get-VMHostNetworkAdapter -VMHost $global:VMHost -vmKernel -Name $vname
		    Set-VMHostNetworkAdapter -VirtualNic $vmk -PortGroup $dvportgroup -confirm:$false | Out-Null
		    Set-VMHostNetworkAdapter -VirtualNic $vmk -IP $IP -SubnetMask 255.255.255.0 -confirm:$false | Out-Null
        }
	}
	catch
	{
		Write-Warning ("MigrateVmk: Error migrating " + $vname + " to distributed switch.")
		Write-Warning $Error[0]
	}
}
Function RemoveVirtualSwitch{
	param($vswitch)
	write-host ("Removing Standard Virtual Switch")
	try
	{
		$vswitch | Remove-VirtualSwitch -Confirm:$false 
	}
	catch
	{
		Write-Warning ("RemoveVirtualSwitch: " + $vswitch + " removal failed.")
	}
}
Function vmkValidate{
	param( 	$VDSw,
			$IP,
			$pgname,
			$Option
			)
    $pg = $VDSw |  Get-VirtualPortgroup -Name $pgname
    $vmk = $pg | Get-VMHostNetworkAdapter -VMHost $global:VMHost
    $OptionArray = @{$Option = $true}
    if($vmk.count -eq 0)
    {
	    try
	    { 
	        write-host ("Setting up vmk for " + $pgname)
            if($Option -ne ""){
                $vmk = New-VMHostNetworkAdapter -VMHost $global:VMHost -PortGroup $pg -VirtualSwitch $VDSw -Mtu 9000 -confirm:$false @OptionArray
            }
            else
            {
			$vmk = New-VMHostNetworkAdapter -VMHost $global:VMHost -PortGroup $pg -VirtualSwitch $VDSw -Mtu 9000 -confirm:$false
            }
	    }
	    catch
	    {
		    Write-Warning ("vmkValidate: " + $pgname + " addition failed.")
            Write-Host ("Option: "+ $Option)
	    }
        
    }
    else
    {
        try
        {
            if($Option -ne ""){
                Get-VMHostNetworkAdapter -VMHost $global:VMHost -Name $vmk | Set-VMHostNetworkAdapter -confirm:$false @OptionArray
            }
            else{
            Get-VMHostNetworkAdapter -VMHost $global:VMHost -Name $vmk | Set-VMHostNetworkAdapter -confirm:$false
            }
        }
        catch
        {
		    Write-Warning ("vmkValidate: " + $pgname + " update failed.")
            Write-Host ("Option: "+ $Option)
        }
    }
	try
	{
		$net = $vmk | ?{$_.IP -eq $IP}
		if($net.count -eq 0)
		{ 
	        write-host ("Updating IP address for " + $pgname)
            $vmk |  Set-VMHostNetworkAdapter -IP $IP -SubnetMask 255.255.255.0 -confirm:$false 
		}
	}
	catch
	{
		Write-Warning ("vmkValidate: " + $pgname + " addition failed.")
            $vmk |  Set-VMHostNetworkAdapter -IP $IP -SubnetMask 255.255.255.0 -confirm:$false 
	}
}
Function SetDSName{
	try
	{
		$localds = Get-VMHost $VMHost | Get-Datastore | ?{$_.Name -notmatch "3PAR" -and $_.Name -notmatch "sql" }
        if($localds.Name -notmatch $global:VMHost){ 		
            $dsname = ($VMHost.split('.')| Select -First 1 ) + ".local"								
            if($localds.count -eq 1){ $localds | Set-Datastore -Name $dsname | Move-Datastore -Destination "Local Disks"}
            if($localds.count -gt 1){																
	            For($i=0; $i -lt $localds.count; $i++){												
		            $localds[$i] | Set-Datastore -Name ($dsname + $i)| Move-Datastore -Destination "Local Disks"
	            }
            }
        }
	}
	catch
	{
		Write-Warning ("RemoveVirtualSwitch: " + $vswitch + " removal failed.")
	}
}


$vCenter = ResolveHost $vCenter															#Test vCenter is network accessible
if($Session -eq ""){
	vCenterConnect $vCenter $vCreds															#Connect to vCenter Server
}
$global:VMHost = ResolveHost $global:VMHost												#Test new host is network accessble
$global:VMHostObj = Get-VMHost $global:VMHost											#Create object for host
$IPOctet = VerifyOctet $IPOctet $global:VMHost											#Test IP option is correct
$ESXCreds = AddToCluster $(VerifyCluster $Cluster) $Cluster $ESXCreds					#Verify Credentials for host
$VDSw = dvSwitch																		#Load Distributed Switch
dvSwitchAdd $VDSw																		#Add host to distributed switch
$vdmnics = dvSwitchNics $VDSw															#Create array of physical nics on distributed switch
$vswitch = vSwitch																		#Get standard switch
$vsnics = vSwitchNics $vswitch															#Create array of physical nics on standard switch
$outnull = dvAddFirstNic $VDSw $vsnics	$vdmnics													#connect at least 1 physcial nic to distributed switch						
$vsnics = vSwitchNics $vswitch															#update array

#Work some magic to create vmkernel Adapter on vMotion NetStack
$esxcli = Get-Esxcli -VMHost $VMHost													
$netstacks = EnumerateNetstacks $esxcli													#Array of current TCP NetStacks "defaultTCPstack", "vmotion", "vSphereProvisioning"
$interfaces = UpdateInterfaceTable $esxcli												#Object with each interface. Includes AddressType, DHCPDNS,Gateway,IPv4Address,IPv4Broadcast,IPv4Netmask,Name (vmk0)
$networks = UpdateNetworkTable $interfaces												#2 Dimension array of network and vmk @{("100","vmk1"),("101","vmk2")}
$ManagementVmk = vmkByNetwork $networks $ManagementSubnetNumber 						#Lookup vmk name associated with Managment subnet
dvAddVmk $VDSw $ManagementPortgroup $ManagementVmk										#Add vmk for managment to distributed switch

$NewvMotion = vNetstack $esxcli $netstacks "vmotion"									#Create vmotion TCP network stack if missing, returns bool
$NewProvisioning = vNetstack $esxcli $netstacks	"vSphereProvisioning" 					#Create Provisioning TCP network stack if missing
$NewvMotion = vKernel $esxcli $networks $NewvMotion $vMotionSubnetNumber "vmotion"						#Check for vmk on vmotion network, verify its network stack
$NewProvisioning = vKernel $esxcli $networks $NewvMotion $vMigrationSubnetNumber "vSphereProvisioning"	#Check for vmk on provisioning network, verify its network stack

$vstandard = CreateVirtualSwitch 														#Check if standard virtual switch exists, if not, create it.
$pgname = CreatePortGroup $vstandard $vMotionSubnetNumber "vMotion"						#Check if vlan 100 portgroup exists, if not, create it.
#refreshing these arrays incase 
#vmk's were removed from the stack
$interfaces = UpdateInterfaceTable $esxcli												#Refresh reference tables in case they've changed
$networks = UpdateNetworkTable $interfaces
$vname = vmkRepair $esxcli $networks "vmk1" "vmotion" $pgname $NewvMotion				#Create new vmotion vmk if needed.
write-host ("Portgroup: " + $vMotionPortgroup + " vname: " + $vname + " IP: " + $vMotionIP)
MigrateVmk $VDSw $vMotionPortgroup $vname $vMotionIP									# -VMotionEnabled $true necessary?

$pgname = CreatePortGroup $vstandard $vMigrationSubnetNumber "Provisioning"				#Check if vlan 101 portgroup exists, if not, create it.
#refreshing these arrays incase 
#vmk's were removed from the stack
$interfaces = UpdateInterfaceTable $esxcli				
$networks = UpdateNetworkTable $interfaces
$vname = vmkRepair $esxcli $networks "vmk2" "vSphereProvisioning" $pgname $NewProvisioning		#Create new vmotion vmk if needed.
MigrateVmk $VDSw $vMigrationPortgroup $vname $vMigrationIP								# -VMotionEnabled $true necessary?

$outnull = dvAddAllNics $VDSw $vsnics																

RemoveVirtualSwitch $vstandard															

$outnull = vmkValidate $VDSw $vFtIP $vFTPortgroup "-FaultToleranceLoggingEnabled"					
$outnull = vmkValidate $VDSw $vSanIP $vSANPortgroup "-VsanTrafficEnabled"							
$outnull = vmkValidate $VDSw $vRepIP $vRepPortgroup ""							

$outnull = SetDSName

try
{
    #Apply-VMHostProfile -Entity $VMHost -Profile $Cluster -Confirm:$false
}
catch
{
    Write-Warning "Error Applying Host Profile"
}

#write-host ("Disconnecting from vCenter Server")
#Disconnect-VIServer -Server $vCenter -Force -Confirm:$false
#write-host ("Connecting directly to host: " + $VMHost)
#Connect-VIServer $VMHost -Credential $ESXCreds | Out-Null

write-host ("Adding NTP Servers")
foreach ($server in $NTP){
	if(($global:VMHostObj | Get-VMHostNtpServer) -notcontains $server ){ $global:VMHostObj| Add-VmHostNtpServer -NtpServer $server}
}

write-host ("Setting NTP firewall exception")
$global:VMHostObj | Get-VMHostFirewallException | ?{$_.Name -eq "NTP client"} | Set-VMHostFirewallException -Enabled:$true | out-null
write-host ("Setting SSH firewall exception")
$global:VMHostObj | Get-VMHostFirewallException | ?{$_.Name -eq "SSH Server"} | Set-VMHostFirewallException -Enabled:$true | out-null
write-host ("Starting NTP Service")
$global:VMHostObj | Get-VmHostService | ?{$_.key -eq "ntpd"} | Start-VMHostService | out-null
write-host ("Setting NTP servers to start automatically")
$global:VMHostObj | Get-VmHostService | ?{$_.key -eq "ntpd"} | Set-VMHostService -policy "automatic" | out-null
write-host ("Starting SSH Service")
$global:VMHostObj | Get-VmHostService | ?{$_.Key -eq "TSM-SSH" } | Start-VMHostService | out-null
write-host ("Setting SSH server to start automatically")
$global:VMHostObj | Get-VmHostService | ?{$_.Key -eq "TSM-SSH" } | Set-VMHostService -policy "automatic" | out-null

write-host ("Setting Scratch Location")
$global:VMHostObj | Get-AdvancedSetting -Name "ScratchConfig.ConfiguredScratchLocation" | Set-AdvancedSetting -Value $Logs -Confirm:$false | out-null
write-host ("Suppressing Shell Warning")
$global:VMHostObj | Get-AdvancedSetting -Name "UserVars.SuppressShellWarning" | Set-AdvancedSetting -Value "1" -Confirm:$false | out-null
write-host ("Packet Bandwidth setting")
$global:VMHostObj | Get-AdvancedSetting -Name "Net.NetPktSlabFreePercentThreshold" | Set-AdvancedSetting -Value "10" -Confirm:$false | out-null
write-host ("vSAN WorkerThreads")
$global:VMHostObj | Get-AdvancedSetting -Name "VSAN-iSCSI.ctlWorkerThreads" | Set-AdvancedSetting -Value "1" -Confirm:$false | out-null
#write-host ("Power Performance Bias")
#$global:VMHostObj | Get-AdvancedSetting -Name "Power.PerfBias" | Set-AdvancedSetting -Value "6"





if($Restart){
    write-host ("Restarting Server")
	restart-vmhost $VMHost -Confirm:$false -Force
}
write-host ("Disconnecting from ESX Server")
if($Session -eq ""){
	Disconnect-VIServer -Server $VMHost -Force -Confirm:$false
}
