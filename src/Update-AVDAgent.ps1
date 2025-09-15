<#
# ===============================================================================
# Title        : Update-AVDAgent.ps1
# Description  : Script to update Azure Virtual Desktop (AVD) Session Host Agent
#                with a new registration token. Downloads the latest installers,
#                uninstalls old versions, installs new agent + bootloader, and
#                restarts services to re-establish host heartbeat.
#
# Author       : Mahmoud A. Atallah
# Role         : Azure Solutions Lead | Microsoft MVP
# Company      : Cloud Mechanics FZC
# Contact      : mahmoud@cloudmechanics.ae | https://cloudmechanics.ae
# LinkedIn     : https://www.linkedin.com/in/mahmoudatallah/
# GitHub       : https://github.com/3tallah
# License      : MIT License
#
# Usage Example:
#   .\Update-AVDAgent.ps1 -RegistrationToken "<registration-token>"
#
# Requirements:
#   - Run as Administrator
#   - Registration token generated in Azure Portal (valid only for a few hours)
#   - Internet access to download installers (or provide local files)
# ===============================================================================
#>

<#
.SYNOPSIS
Updates Azure Virtual Desktop (AVD) agent and registers session host with new registration key.

.DESCRIPTION
- Stops AVD services
- Uninstalls old AVD Agent & Bootloader
- Downloads and installs the latest AVD Agent & Bootloader
- Registers host with the provided registration token
- Restarts services to start heartbeat

.PARAMETER RegistrationToken
New AVD registration key/token from Azure portal
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$RegistrationToken
)

# Ensure script runs as Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "You must run this script as Administrator."
    exit 1
}

$DownloadPath = "C:\Temp\AVDAgent"
if (-not (Test-Path $DownloadPath)) {
    New-Item -Path $DownloadPath -ItemType Directory -Force | Out-Null
}

# Microsoft official download links
$AgentUrl      = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv"
$BootLoaderUrl = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH"

$AgentFile      = Join-Path $DownloadPath "RDInfraAgent.msi"
$BootLoaderFile = Join-Path $DownloadPath "RDInfraBootLoader.msi"

Write-Host "=== Downloading latest AVD Agent and Bootloader from Microsoft ==="
Invoke-WebRequest -Uri $AgentUrl -OutFile $AgentFile -UseBasicParsing
Invoke-WebRequest -Uri $BootLoaderUrl -OutFile $BootLoaderFile -UseBasicParsing

Write-Host "=== Stopping AVD services ==="
Stop-Service RDAgentBootLoader -Force -ErrorAction SilentlyContinue
Stop-Service RDAgent -Force -ErrorAction SilentlyContinue

Write-Host "=== Uninstalling old AVD Agent and Bootloader ==="
$applications = @("Remote Desktop Services Infrastructure Agent", "Remote Desktop Services Infrastructure Geneva Agent", "Remote Desktop Agent Boot Loader")
foreach ($app in $applications) {
    $pkg = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "$app*" }
    if ($pkg) {
        Write-Host "Uninstalling $($pkg.Name)"
        $pkg.Uninstall() | Out-Null
    }
}

Write-Host "=== Installing latest AVD Agent with Registration Token ==="
Start-Process "msiexec.exe" -ArgumentList "/i `"$AgentFile`" REGISTRATIONTOKEN=$RegistrationToken /quiet /norestart" -Wait -NoNewWindow

Write-Host "=== Installing Bootloader ==="
Start-Process "msiexec.exe" -ArgumentList "/i `"$BootLoaderFile`" /quiet /norestart" -Wait -NoNewWindow

Write-Host "=== Restarting AVD services ==="
Start-Service RDAgentBootLoader
Start-Service RDAgent

Write-Host "=== Done. Host should now be registered and sending heartbeat. ==="
