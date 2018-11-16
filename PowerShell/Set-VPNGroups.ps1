<#
.SYNOPSIS   
Script to add an AD User to the Checkpoint VPN groups corresponding to the VPN Group Memberships
    
.DESCRIPTION 
This script will lookup the VPN groups of the specified AD User and then add them to the individual groups required to give Checkpoint access permissions.
	
.PARAMETER User
Active Directory User to that we are going to add to their specific security groups

.PARAMETER Clean
Remove user from Checkpoint Access groups not included in master VPN Access groups.

.PARAMETER Remove
Remove user from all Checkpoint Access groups.

.PARAMETER WhatIf
Test command use without actually changing anything.

.PARAMETER Verbose
Output more than usual.
	

.NOTES   
Name: Set-VPNGroups.ps1
Author: Mike Stanton
Version: 0.1
DateCreated: 2016-8-25
DateUpdated: 2016-8-25

.EXAMPLE   
.\Set-VPNGroups.ps1 -User mstanton -Verbose

Description:
Will set the VPN security groups required for user mstanton

#>
[cmdletbinding()]
param(
    [string]
        $User,
    [switch]
        $Clean,
    [switch]
        $Remove,
    [switch]
        $WhatIf
)
#Import-Module ActiveDirectory

$VPNGroups = @{}
$VPNGroups["VPN_Static"] =  "CUSTOM_STATIC_SCANNERS",
                            "CUSTOM_AUDIT_PORTAL01",
                            "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_PORTALS",
                            "CUSTOM_ADMIN_PORTAL"
$VPNGroups["VPN_TAM"] =   # "FoD_Admin_Portal01", 
                            "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_TENANT_PORTALS",
                            "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_AUDIT_PORTAL01",
                            "CUSTOM_RDP_71",
                            "CUSTOM_PORTALS",
                            "CUSTOM_ADMIN_PORTAL"
$VPNGroups["VPN_Dev"] =     "CUSTOM_LOGGER",
                            "CUSTOM_DEV_CROSSBOW",
                            "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_RDP_71",
                            "CUSTOM_OCTOPUS",
                            "CUSTOM_AUDIT_PORTAL01",
                            "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_STAGING_ADMIN_PORTAL",
                            "CUSTOM_STAGING_TENANT_PORTAL",
                          # "FoD_RDP_PRONQ",
                            "CUSTOM_PORTALS",
                            "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_ADMIN_PORTAL"
$VPNGroups["VPN_Storage"] = "CUSTOM_RDP_71",
                            "CUSTOM_SHARED_STORAGE_TEAM"
$VPNGroups["VPN_SSR"] =     "CUSTOM_RDP_71"
$VPNGroups["VPN_TEST"] =    "CUSTOM_RDP_71",
                            "CUSTOM_OCTOPUS",
                            "CUSTOM_ADMIN_PORTAL"
$VPNGroups["VPN_TAM_DAST"] ="CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_TENANT_PORTALS",
                            "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_AUDIT_PORTAL01",
                            "CUSTOM_PORTALS",
                            "CUSTOM_ADMIN_PORTAL"
$VPNGroups["VPN_Dynamic_DAST"] = "CUSTOM_DYNAMIC_SCANNERS",
                          #  "MABLDAP_DAST",
                            "CUSTOM_DYNAMIC_FILESHARE",
                            "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_PORTALS",
                            "CUSTOM_ADMIN_PORTAL"
$VPNGroups["VPN_Dynamic"] = "CUSTOM_DYNAMIC_SCANNERS",
                            "CUSTOM_DYNAMIC_FILESHARE",
                            "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_PORTALS",
                            "CUSTOM_ADMIN_PORTAL"
$VPNGroups["VPN_MOBILITY_DAST"] = "FoD_Mobile_Rep_Servers",
                            "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_DYNAMIC_FILESHARE",
                            "CUSTOM_PORTALS",
                            "CUSTOM_ADMIN_PORTAL"
$VPNGroups["VPN_EMEA_DYNAMIC"] = "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_DYNAMIC_SCANNERS"
$VPNGroups["VPN_EMEA_STATIC"] = "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_STATIC_SCANNERS"
$VPNGroups["VPN_EMEA_TAM"] = "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_DYNAMIC_SCANNERS",
                            "CUSTOM_STATIC_SCANNERS"

$DRGroups = @{}
$DRGroups["VPN_Static"] =  "CUSTOM_STATIC_SCANNERS",
                            "CUSTOM_ADMIN_PORTAL"
$DRGroups["VPN_TAM"] =     "CUSTOM_TENANT_PORTALS",
                            "CUSTOM_ADMIN_PORTAL",
                            "CUSTOM_RDP_71"
$DRGroups["VPN_Dev"] =     "CUSTOM_RDP_71",
                            "CUSTOM_OCTOPUS",
                            "CUSTOM_ADMIN_PORTAL"
$DRGroups["VPN_Storage"] = "CUSTOM_RDP_71",
                            "CUSTOM_TEAM"
$DRGroups["VPN_SSR"] =     "CUSTOM_RDP_71"
$DRGroups["VPN_TEST"] =    "CUSTOM_RDP_71",
                            "CUSTOM_OCTOPUS",
                            "CUSTOM_ADMIN_PORTAL"
$DRGroups["VPN_TAM_DAST"] ="CUSTOM_ADMIN_PORTAL"
$DRGroups["VPN_Dynamic_DAST"] = "CUSTOM_DYNAMIC_SCANNERS",
                            "CUSTOM_ADMIN_PORTAL"
$DRGroups["VPN_Dynamic"] = "CUSTOM_DYNAMIC_SCANNERS",
                            "CUSTOM_ADMIN_PORTAL"
$DRGroups["VPN_MOBILITY_DAST"] = "CUSTOM_ADMIN_PORTAL"

Function Find-User
{
param(
    [string]
        $UserSAM
)
    Write-Verbose "Searching for Specified User"
    Try{
        $UserObject = Get-ADUser -Identity $UserSAM
    }
    Catch{        
        $ErrorMessage - $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Host "User not found"
        Write-Verbose "Failed to access " $FailedItem
        Write-Verbose "The error is: " $ErrorMessage
        Break
    }
    return $UserObject    
}

$ADUser = Find-User $User 
$ADUserName = $ADUser.name
$ADGroups = Get-ADPrincipalGroupMembership -Identity $ADUser
$VPNAccessGroups = @{}
$DRAccessGroups = @{}
$DR = $false;

If($Remove){
    $ADGroups | Foreach-Object {
        $GroupName = $_.name
        $VPNGroups.Keys | ForEach-Object{
            Foreach($CheckPointGroup In $VPNGroups.Item($_)){
                If ($CheckPointGroup -eq $GroupName){
                    Write-Verbose "removing from group $CheckPointGroup"
                    If($WhatIf){
                        Remove-ADGroupMember -Identity $CheckPointGroup -Member $ADUser -Confirm:$false -Whatif
                    }
                    Else {
                        Remove-ADGroupMember -Identity $CheckPointGroup -Member $ADUser -Confirm:$false
                    }
                }
            }
        }
    }
}
else{
    $ADGroups | Foreach-Object {
        $GroupName = $_.name
        Write-Verbose "`'$ADUserName`' is a member of `'$GroupName`'"
        #Creating VPNAccessGroups Array which lists the VPN group memberships for this user
        $VPNGroups.Keys | ForEach-Object{
            If ($GroupName -eq $_){
                Foreach($CheckPointGroup In $VPNGroups.Item($_)){
                    $VPNAccessGroups[$CheckPointGroup] = 1
                }
            }
        }
        #Flag to build DR Array
        If($GroupName -eq "VPN_DR"){
            $DR = $true;
        }
        $DRGroups.Keys | ForEach-Object{
            If ($GroupName -eq $_){
                Foreach($CheckPointGroup In $DRGroups.Item($_)){
                    $DRAccessGroups[$CheckPointGroup] = 1
                }
            }
        }
    }
    #Cycle through VPN groups
    $VPNAccessGroups.Keys | ForEach-Object{
        $CheckpointGroup = $_
        $Membership = 0
        #Check if the User is already a member of the VPN group
        $ADGroups | Foreach-Object {
            $ADGroupName = $_.name
            If( $CheckpointGroup -eq $ADGroupName ){
                $Membership = 1
            }
        }
        #Add user to missing groups
        If(!$Membership){
            write-host "Adding $CheckpointGroup"
            If($WhatIf){
                Add-ADGroupMember -Identity $CheckpointGroup -Member $ADUser -Whatif
            }
            Else {
                Add-ADGroupMember -Identity $CheckpointGroup -Member $ADUser
            }
        }
    }
    If($DR){
        $DRAccessGroups.Keys | ForEach-Object{
            $CheckpointGroup = $_
            $Membership = 0
            #Check if the User is already a member of the VPN group
            $ADGroups | Foreach-Object {
                $ADGroupName = $_.name
                If( $CheckpointGroup -eq $ADGroupName ){
                    $Membership = 1
                }
            }
            #Add user to missing groups
            If(!$Membership){
                write-host "Adding $CheckpointGroup"
                If($WhatIf){
                    Add-ADGroupMember -Identity $CheckpointGroup -Member $ADUser -Whatif
                }
                Else {
                    Add-ADGroupMember -Identity $CheckpointGroup -Member $ADUser
                }
            }
        }
    }

    If($Clean){
        #Storing all CP groups into CheckpointGroups
        $CheckpointGroups = @{}
        $VPNGroups.Keys | ForEach-Object{
            Foreach($CheckPointGroup In $VPNGroups.Item($_)){
                $CheckpointGroups[$CheckPointGroup] = 1
            }
        }
        #Setting boolean of CP groups from authorized group list
        $VPNAccessGroups.Keys | ForEach-Object{
            $CheckpointGroups[$_] = 0
        }        
        $CheckpointGroups.Keys | ForEach-Object{
            If($CheckpointGroups.Item($_)){
                $CheckPointName = $_
                $ADGroups | Foreach-Object {
                    $GroupName = $_.name
                    If($GroupName -eq $CheckPointName){
                        write-host "Removing group " $GroupName
                        If($WhatIf){
                            Remove-ADGroupMember -Identity $GroupName -Member $ADUser -Confirm:$false -Whatif
                        }
                        Else {
                            Remove-ADGroupMember -Identity $GroupName -Member $ADUser -Confirm:$false
                        }
                    }
                }
            }
        }
    }
}