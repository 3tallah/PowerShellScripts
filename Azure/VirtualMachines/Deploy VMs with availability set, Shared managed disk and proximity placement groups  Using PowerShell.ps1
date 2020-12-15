<#	
	.NOTES
	===========================================================================
	 Created on:   	09/14/2020 3:48 PM
	 Created by:   	Mahmoud A. ATALLAH
	 Blog: 	        https://3tallah.com/blog
	===========================================================================
	.DESCRIPTION
		This PowerShell Script is used to:
		- Create an availability set	
		- Deploy VMs to proximity placement groups 
		- Create and deploy highly available virtual machines 
		- Attaching a Shared managed disk to multiple VMs
#>

#region VARs
$cred            = Get-Credential
$resourceGroup   = "RG-PRD-STC-01"
$location        = "Westeurope"
$VMName          = "STC-CM0"
$VNet            = "Vnet-HUB-01" 
$SNet            = "SNet-STC01"
$NSG             = "SPServer-nsg"
$SharedDiskName  = "STCAppSharedDisk"
$DiskSizeGB 	 = "256"
$PubIp           = "STCPublicIpAddress"
$AvailabilitySet = "STCAvailabilitySet"
$ProximityGroup  = "STCProximityGroup"
#endregion VARs

#region Deploy a premium SSD as a shared disk
$dataDiskConfig = New-AzDiskConfig -Location $location -DiskSizeGB 256 -AccountType Premium_LRS -CreateOption Empty -MaxSharesCount 2
New-AzDisk -ResourceGroupName $resourceGroup -DiskName $SharedDiskName -Disk $dataDiskConfig
#endregion Deploy a premium SSD as a shared disk

#region Create an availability set
New-AzAvailabilitySet `
					  -Location $location `
					  -Name $AvailabilitySet `
					  -ResourceGroupName $resourceGroup `
					  -Sku aligned `
					  -PlatformFaultDomainCount 2 `
					  -PlatformUpdateDomainCount 2
#endregion Create an availability set

#region Create a proximity placement group
$AzProximityGroup = New-AzProximityPlacementGroup `
												  -Location $location `
												  -Name $ProximityGroup `
												  -ResourceGroupName $resourceGroup `
												  -ProximityPlacementGroupType Standard
#endregion Create a proximity placement group

#region Create VMs inside an availability set and Using Azure shared disks with your VMs
for ($i = 1; $i -le 2; $i++)
{
	$vm = New-AzVm `
			 -ResourceGroupName $resourceGroup `
			 -Name "$VMName$i" `
			 -Location $location `
			 -VirtualNetworkName $VNet `
			 -SubnetName $SNet `
			 -SecurityGroupName $NSG `
			 -PublicIpAddressName "$PubIp$i" `
			 -AvailabilitySetName $AvailabilitySet `
			 -Credential $cred
			#Using Azure shared disks with your VMs
			$dataDisk = Get-AzDisk -ResourceGroupName $resourceGroup -DiskName $SharedDiskName
			$vm = Add-AzVMDataDisk -VM $vm -Name $SharedDiskName -CreateOption Attach -ManagedDiskId $dataDisk.Id -Lun 0
			update-AzVm -VM $vm -ResourceGroupName $resourceGroup
	
}
#endregion Create VMs inside an availability set

#region Move an existing availability set into a proximity placement group
$avSet = Get-AzAvailabilitySet -ResourceGroupName $resourceGroup -Name $AvailabilitySet
$vmIds = $avSet.VirtualMachinesReferences
foreach ($vmId in $vmIDs)
{
	$string = $vmID.Id.Split("/")
	$vmName = $string[8]
	Stop-AzVM -ResourceGroupName $resourceGroup -Name $vmName -Force
}

Update-AzAvailabilitySet -AvailabilitySet $avSet -ProximityPlacementGroupId $AzProximityGroup.Id
foreach ($vmId in $vmIDs)
{
	$string = $vmID.Id.Split("/")
	$vmName = $string[8]
	Start-AzVM -ResourceGroupName $resourceGroup -Name $vmName
}
#endregion Move an existing availability set into a proximity placement group
