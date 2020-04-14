
<#
Author:		Mahmoud A. ATALLAH
Date:		27/02/2020
Script:  	InstallOMSAgentwithServiceMap_V.4.ps1
Version: 	4.0
Description: Install ServiceMap and MMA Agents as well as Modify OMS Agent workspace And workspace Key optionally Configure Proxy
Twitter: 	@Mahmoud_Atallah
#>

#region Parameters

$WorkSpaceID = "<WorkSpaceID>"
$WorkSpaceKey = "<WorkSpaceKey>"
$ProxyDomainName = "<http://ProxyServer:PORT>"
$MMAAgentFile = "MMASetup-AMD64.exe"
$DependencyAgent = "InstallDependencyAgent-Windows.exe"
$OMSFolder = 'C:\OMSSourceFolder'
$MMAFile = $OMSFolder + "\" + $MMAAgentFile
$DependencyAgentFile = $OMSFolder + "\" + $DependencyAgent
$Shared = "< \\sahred\OMSLogs >" # Use Create Shared Folder With Read Access to Everyone
$SharedMMA = $Shared + "\" + $MMAAgentFile
$SharedDependencyAgent = $Shared + "\" + $DependencyAgent

#endregion Parameters


#-----------------------------------------------------
#-----------------------------------------------------
#region Check if $OMSFolder folder exists, if not, create it

if (Test-Path $OMSFolder)
{
	Write-Host "The folder $OMSFolder already exists."
}
else
{
	Write-Host "The folder $OMSFolder does not exist, creating..." -NoNewline
	New-Item $OMSFolder -type Directory | Out-Null
	Write-Host "done!" -ForegroundColor Green
}

#endregion Check if $OMSFolder folder exists, if not, create it
# Change the location to the specified folder
Set-Location $OMSFolder
#-----------------------------------------------------
#region Check if Microsoft Monitoring Agent file exists, if not, Copy it
if (Test-Path $MMAAgentFile)
{
	Write-Host "The file $MMAAgentFile already exists."
}

else
{
	Write-Host "The file $MMAAgentFile does not exist, Copying..." -NoNewline
	Copy-Item $SharedMMA -Destination $OMSFolder -verbose
	Write-Host "done!" -ForegroundColor Green
}
#endregion Check if Microsoft Monitoring Agent file exists, if not, Copy it
#-----------------------------------------------------
#region Install the Microsoft Monitoring Agent
Write-Host "Installing Microsoft Monitoring Agent.." -nonewline
Set-Location $OMSFolder
$ArgumentList = '/C:"setup.exe /qn ADD_OPINSIGHTS_WORKSPACE=1 ' + "OPINSIGHTS_WORKSPACE_ID=$WorkspaceID " + "OPINSIGHTS_WORKSPACE_KEY=$WorkSpaceKey " + 'AcceptEndUserLicenseAgreement=1"'
Start-Process $MMAAgentFile -ArgumentList $ArgumentList -ErrorAction Stop -Wait | Out-Null
Write-Host "done!" -ForegroundColor Green

#endregion Install the Microsoft Monitoring Agent
#region Check if Service Map Agent exists, if not, Copy it


if (Test-Path $DependencyAgent)
{
	Write-Host "The file $DependencyAgent already exists."
}

else
{
	Write-Host "The file $DependencyAgent does not exist, Copying..." -NoNewline
	Copy-Item $SharedDependencyAgent -Destination $OMSFolder -verbose
	Write-Host "done!" -ForegroundColor Green
	
}
#endregion Check if Service Map Agent exists, if not, download it
#-----------------------------------------------------
#region Install the Service Map Agent

Write-Host "Installing Service Map Agent.." -nonewline
Set-Location $OMSFolder
$ArgumentList = '/C:"InstallDependencyAgent-Windows.exe /S /AcceptEndUserLicenseAgreement:1"'
Start-Process $DependencyAgent -ArgumentList $ArgumentList -ErrorAction Stop -Wait | Out-Null
Write-Host "done!" -ForegroundColor Green
#endregion Install the Service Map Agent
#-----------------------------------------------------
#region - Configure the MMA agent proxy via PowerShell

# First we get the health service configuration object. We need to determine if we have the right update rollup with the API we need. If not, no need to run the rest of the script.

$healthServiceSettings = New-Object -ComObject 'AgentConfigManager.MgmtSvcCfg'

$proxyMethod = $healthServiceSettings | Get-Member -Name 'SetProxyInfo'

if (!$proxyMethod)
{
	
	Write-Output 'Health Service proxy API not present, will not update settings.'
	
	return
	
}

Write-Output "Clearing proxy settings."

$healthServiceSettings.SetProxyInfo('', '', '')

Write-Output "Setting Proxy to ${ProxyDomainName}"

$healthServiceSettings.SetProxyInfo($ProxyDomainName, '', '')

#endregion Configure the MMA agent proxy via PowerShell
#-----------------------------------------------------
#region Upgrade the agent and add a workspace using a script

$mma = New-Object -ComObject 'AgentConfigManager.MgmtSvcCfg'
$mma.AddCloudWorkspace($workspaceId, $workspaceKey)
$mma.ReloadConfiguration()

#endregion Upgrade the agent and add a workspace using a script
#-----------------------------------------------------
# Change the location to C: to remove the created folder
Set-Location -Path "C:\"
#-----------------------------------------------------
#region Remove the folder with the agent files
if (-not (Test-Path $OMSFolder))
{
	Write-Host "The folder $OMSFolder does not exist."
}
else
{
	Write-Host "Removing the folder $OMSFolder ..." -NoNewline
	Remove-Item $OMSFolder -Force -Recurse | Out-Null
	Write-Host "done!" -ForegroundColor Green
}

#endregion Remove the folder with the agent files