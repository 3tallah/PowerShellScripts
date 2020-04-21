<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2019 v5.6.160
	 Created on:   	4/21/2020 10:58 AM
	 Created by:   	Mahmoud A. ATALLAH
	 Organization: 	https://blog.3tallah.com
	 Filename:     	WVD_CustomizefeedforWindowsVirtualDesktopusers
	===========================================================================
	.DESCRIPTION
		Customize the feed so the RemoteApp and remote desktop resources appear in a recognizable way for your users.
#>


Import-module Microsoft.Rdinfra.RdPowershell

# 2 - Authenticate into your tenant environment:
Add-RdsAccount -DeploymentURL https://rdbroker.wvd.microsoft.com

#region Parameters
#Update the respective $variables first and then execute command
$RdsTenant = "<Tenant Name>"
$hostpool = "< Hostpool Name >"
$myTenantGroupName = "Default Tenant Group"
#endregion Parameters


#region Get App Group Information
$appgroup = get-rdsappgroup -TenantName $RdsTenant -HostPoolName $hostpool
$appgroupname = $appgroup.AppGroupName
#endregion Get App Group Information

#region Get Applications List

$ApplicationsList = Get-RdsRemoteApp $RdsTenant -HostPoolName $hostpool -AppGroupName $appgroupname[1] | select AppGroupName, FriendlyName | ft
$ApplicationsList
#endregion Get Applications List


#region Get User List and App Group Name
$UserList = Get-RdsAppGroupUser -TenantName $RdsTenant -HostPoolName $hostpool -AppGroupName $appgroupname[1] | select UserPrincipalName, AppGroupName | ft
$UserList
#endregion Get User List and App Group Name


#region Get Rds Remote Desktop FriendlyName 
$RdsRemoteDesktop = Get-RdsRemoteDesktop -TenantName $RdsTenant -HostPoolName $hostpool -AppGroupName $appgroupname[0]
$RdsRemoteDesktop.FriendlyName
#endregion Get Rds Remote Desktop FriendlyName 

#region Change Rds Remote Desktop FriendlyName 

Set-RdsRemoteDesktop -TenantName $RdsTenant -HostPoolName $hostpool -AppGroupName $appgroupname[0] -FriendlyName "Corporate Desktop"
$RdsRemoteDesktop.FriendlyName
#endregion Change Rds Remote Desktop FriendlyName 

#region Get Rds Remote Apps FriendlyName 
$RdsRemoteApps = Get-RdsRemoteApp -TenantName $RdsTenant -HostPoolName $hostpool -AppGroupName $appgroupname[1]
$RdsRemoteApps.FriendlyName
#endregion Get Rds Remote Apps FriendlyName 


#region Change Rds Remote Apps FriendlyName 
Set-RdsRemoteApp -TenantName $RdsTenant -HostPoolName $hostpool -AppGroupName $appgroupname[1] -Name <existingappname> -FriendlyName <newfriendlyname>

#endregion Change Rds Remote Apps FriendlyName 


#region Change Rds Remote Apps FriendlyName 
Get-RdsTenant -Name $RdsTenant
Set-RdsTenant -Name $RdsTenant -FriendlyName "Corporate Desktop And Apps"
#endregion Change Rds Remote Apps FriendlyName 