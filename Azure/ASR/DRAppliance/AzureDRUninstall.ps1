<#
.SYNOPSIS
  Full cleanup script for Azure DR Appliance components installed by AzureDRInstaller.ps1

.DESCRIPTION
  - Stops related services
  - Uninstalls appliance components (RCM agents, Process Server, Discovery services, WebApp, AutoUpdater, MARS, ASR)
  - Removes IIS features used by the Web UI (by default)
  - Cleans ProgramData, cache folders, registry keys, WSMan TrustedHosts, and appliance version file
  - Leaves the VM as close as possible to a clean base OS (without OS reinstall)

.PARAMETER KeepIIS
  If specified, IIS features will NOT be removed.
#>

[CmdletBinding()]
param(
    [switch]$KeepIIS
)

# ---------------------------
# 0. Basic setup & logging
# ---------------------------
$ErrorActionPreference = 'Stop'

$TimeStamp = [DateTime]::Now.ToString("yyyy-MM-dd-HH-mm-ss")
$LogRoot = Join-Path $Env:SystemDrive "Temp\AzureDRCleanupLogs"

New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null

$InstallerLog = Join-Path $LogRoot "AzureDRUninstall_$TimeStamp.log"

function Log-Info([string] $OutputText) {
    Write-Host $OutputText -ForegroundColor White
    $OutputText = [string][DateTime]::Now + " " + $OutputText
    $OutputText | Out-File -FilePath $InstallerLog -Append -Encoding ASCII
}

function Log-Success([string] $OutputText) {
    Write-Host $OutputText -ForegroundColor Green
    $OutputText = [string][DateTime]::Now + " " + $OutputText
    $OutputText | Out-File -FilePath $InstallerLog -Append -Encoding ASCII
}

function Log-Warning([string] $OutputText) {
    Write-Host $OutputText -ForegroundColor Yellow
    $OutputText = [string][DateTime]::Now + " " + $OutputText
    $OutputText | Out-File -FilePath $InstallerLog -Append -Encoding ASCII
}

function Log-Error([string] $OutputText) {
    Write-Host $OutputText -ForegroundColor Red
    $OutputText = [string][DateTime]::Now + " " + $OutputText
    $OutputText | Out-File -FilePath $InstallerLog -Append -Encoding ASCII
}

Log-Success "Log file created '$InstallerLog' for uninstall troubleshooting.`n"

# ---------------------------
# 1. Admin / environment check
# ---------------------------
function Assert-Admin {
    $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($currentIdentity)
    $isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltinRole]::Administrator)

    if (-not $isAdmin) {
        Log-Error "This script must be run as Administrator. Aborting..."
        throw "Not running elevated."
    }

    Log-Success "Running as Administrator."
}

Assert-Admin

# ---------------------------
# 2. Stop related services
# ---------------------------
function Stop-RelatedServices {
    Log-Info "Stopping Azure DR / ASR related services if present..."

    $servicePatterns = @(
        '*InMage*',
        '*Rcm*',
        '*ProcessServer*',
        '*Azure Site Recovery*',
        '*Azure DR Appliance*',
        '*Azure DR*',
        '*Server Discovery*',
        '*VMware Discovery*',
        '*MarsAgent*',
        '*Recovery Services Agent*'
    )

    $stopped = @()

    foreach ($pattern in $servicePatterns) {
        $services = Get-Service -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -like $pattern -or $_.DisplayName -like $pattern
        }

        foreach ($svc in $services) {
            if ($svc.Status -eq 'Running' -or $svc.Status -eq 'StartPending') {
                Log-Info "Stopping service: $($svc.Name) ($($svc.DisplayName))"
                try {
                    Stop-Service -Name $svc.Name -Force -ErrorAction Stop
                    $stopped += $svc.Name
                }
                catch {
                    Log-Warning "Failed to stop service $($svc.Name): $($_.Exception.Message)"
                }
            }
        }
    }

    if ($stopped.Count -gt 0) {
        Log-Success "Stopped services: $($stopped -join ', ')"
    }
    else {
        Log-Info "No matching running services were found or needed stopping."
    }
}

Stop-RelatedServices

# ---------------------------
# 3. Helper: uninstall via registry UninstallString
# ---------------------------
function Get-UninstallEntries {
    param(
        [Parameter(Mandatory)]
        [string]$Pattern
    )

    $paths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $results = @()

    foreach ($p in $paths) {
        $items = Get-ItemProperty -Path $p -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -and ($_.DisplayName -like $Pattern)
        }

        $results += $items
    }

    return $results
}

function Invoke-UninstallEntry {
    param(
        [Parameter(Mandatory)]
        $Entry
    )

    $displayName = $Entry.DisplayName
    $uninstallCmd = $Entry.UninstallString

    if (-not $uninstallCmd) {
        Log-Warning "No UninstallString for '$displayName' – skipping."
        return
    }

    Log-Info "Uninstalling: $displayName"
    Log-Info "Raw UninstallString: $uninstallCmd"

    if ($uninstallCmd -match 'MsiExec\.exe' -or $uninstallCmd -match 'msiexec\.exe') {
        $exe, $args = $uninstallCmd -split '\s+', 2

        if ($args -match '/I') {
            $args = $args -replace '/I', '/X'
        }

        if ($args -notmatch '/qn') {
            $args += ' /qn /norestart'
        }

        Log-Info "Executing MSI uninstall: $exe $args"
        $process = Start-Process -FilePath $exe -ArgumentList $args -Wait -PassThru
    }
    else {
        $exePath = $uninstallCmd
        $args = $null

        if ($uninstallCmd.StartsWith('"')) {
            $closingQuote = $uninstallCmd.IndexOf('"', 1)
            if ($closingQuote -gt 0) {
                $exePath = $uninstallCmd.Substring(1, $closingQuote - 1)
                $args = $uninstallCmd.Substring($closingQuote + 1).Trim()
            }
        }
        else {
            $firstSpace = $uninstallCmd.IndexOf(' ')
            if ($firstSpace -gt 0) {
                $exePath = $uninstallCmd.Substring(0, $firstSpace)
                $args = $uninstallCmd.Substring($firstSpace + 1).Trim()
            }
        }

        if (-not (Test-Path $exePath -PathType Leaf)) {
            Log-Warning "Uninstall executable not found: $exePath – skipping."
            return
        }

        Log-Info "Executing uninstall: $exePath $args"
        if ($null -ne $args -and $args -ne '') {
            $process = Start-Process -FilePath $exePath -ArgumentList $args -Wait -PassThru
        }
        else {
            $process = Start-Process -FilePath $exePath -Wait -PassThru
        }
    }

    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
        Log-Success "Uninstalled '$displayName' (ExitCode: $($process.ExitCode))"
    }
    else {
        Log-Warning "Uninstall for '$displayName' returned ExitCode: $($process.ExitCode). Check manually if needed."
    }
}

function Uninstall-ByPattern {
    param(
        [Parameter(Mandatory)]
        [string]$Pattern
    )

    $entries = Get-UninstallEntries -Pattern $Pattern

    if (-not $entries -or $entries.Count -eq 0) {
        Log-Info "No installed products found matching pattern '$Pattern'."
        return
    }

    foreach ($entry in $entries) {
        Invoke-UninstallEntry -Entry $entry
    }
}

# ---------------------------
# 4. Uninstall appliance components
# ---------------------------
Log-Info "Starting uninstall of Azure DR appliance components..."

$productPatterns = @(
    '*Rcm Proxy*',
    '*RcmProxy*',
    '*Rcm Replication*',
    '*RcmReplication*',
    '*Rcm Reprotect*',
    '*RcmReprotect*',
    '*Push Install Agent*',
    '*PushInstall*',
    '*Process Server*',
    '*Azure Site Recovery Configuration*',
    '*Azure Site Recovery Provider*',
    '*Azure Site Recovery*',
    '*Server Discovery Service*',
    '*VMware Discovery Service*',
    '*DR Appliance Configuration Manager*',
    '*Azure DR Appliance*',
    '*Azure AutoUpdate*',
    '*Microsoft Azure AutoUpdate*',
    '*Recovery Services Agent*',
    '*MARS Agent*'
)

foreach ($pattern in $productPatterns) {
    Uninstall-ByPattern -Pattern $pattern
}

# ---------------------------
# 5. Remove IIS features (unless KeepIIS is set)
# ---------------------------
if (-not $KeepIIS) {
    Log-Info "Removing IIS features that were enabled for the appliance (KeepIIS = `$false)..."

    try {
        Import-Module ServerManager -ErrorAction Stop

        $features = @(
            'WAS',
            'WAS-Process-Model',
            'WAS-Config-APIs',
            'Web-Server',
            'Web-WebServer',
            'Web-Mgmt-Service',
            'Web-Request-Monitor',
            'Web-Common-Http',
            'Web-Static-Content',
            'Web-Default-Doc',
            'Web-Dir-Browsing',
            'Web-Http-Errors',
            'Web-App-Dev',
            'Web-CGI',
            'Web-Health',
            'Web-Http-Logging',
            'Web-Log-Libraries',
            'Web-Security',
            'Web-Filtering',
            'Web-Performance',
            'Web-Stat-Compression',
            'Web-Mgmt-Tools',
            'Web-Mgmt-Console',
            'Web-Scripting-Tools',
            'Web-Asp-Net45',
            'Web-Net-Ext45',
            'Web-Http-Redirect',
            'Web-Windows-Auth',
            'Web-Url-Auth'
        )

        $installed = Get-WindowsFeature | Where-Object { $_.Installed -and ($features -contains $_.Name) }

        if ($installed.Count -gt 0) {
            Log-Info "Removing IIS features: $($installed.Name -join ', ')"
            Remove-WindowsFeature -Name $installed.Name -ErrorAction Stop | Out-Null
            Log-Success "IIS features removed."
        }
        else {
            Log-Info "No targeted IIS features are currently installed or nothing to remove."
        }
    }
    catch {
        Log-Warning "Failed to remove IIS features: $($_.Exception.Message)"
    }
}
else {
    Log-Info "IIS features NOT removed (KeepIIS = `$true)."
}

# ---------------------------
# 6. Remove registry keys
# ---------------------------
Log-Info "Removing Azure appliance registry keys..."

$RegAzureAppliancePath = "HKLM:\SOFTWARE\Microsoft\Azure Appliance"
$RegAzureCredStorePath = "HKLM:\Software\Microsoft\AzureAppliance"

foreach ($regPath in @($RegAzureAppliancePath, $RegAzureCredStorePath)) {
    if (Test-Path $regPath) {
        try {
            Remove-Item $regPath -Recurse -Force -ErrorAction Stop
            Log-Success "Removed registry key: $regPath"
        }
        catch {
            Log-Warning "Failed to remove registry key $($regPath): $($_.Exception.Message)"
        }
    }
    else {
        Log-Info "Registry key not present (already removed): $regPath"
    }
}

# Edge policy cleanup (if HideFirstRunExperience was set)
$RegEdgePolicyPath = "HKLM:\Software\Policies\Microsoft\Edge"
if (Test-Path $RegEdgePolicyPath) {
    try {
        $edgeProps = Get-ItemProperty -Path $RegEdgePolicyPath -ErrorAction SilentlyContinue
        if ($edgeProps -and ($edgeProps.PSObject.Properties.Name -contains 'HideFirstRunExperience')) {
            Remove-ItemProperty -Path $RegEdgePolicyPath -Name "HideFirstRunExperience" -ErrorAction Stop
            Log-Success "Removed Edge policy HideFirstRunExperience."
        }
    }
    catch {
        Log-Warning "Failed to remove Edge policy HideFirstRunExperience: $($_.Exception.Message)"
    }
}

# ---------------------------
# 7. Determine cache directory from appliance.json (if present)
# ---------------------------
$ConfigFileDir = "$env:ProgramData\Microsoft Azure\Config"
$ApplianceJsonFilePath = Join-Path $ConfigFileDir "appliance.json"
$cacheDirsToClean = @()

if (Test-Path $ApplianceJsonFilePath) {
    try {
        $applianceJson = Get-Content $ApplianceJsonFilePath -Raw | ConvertFrom-Json
        if ($applianceJson.CacheDirectory) {
            $cacheDir = $applianceJson.CacheDirectory.TrimEnd('\')
            Log-Info "Found CacheDirectory in appliance.json: $cacheDir"
            $cacheDirsToClean += (Join-Path $cacheDir "Software\Agents")
            $cacheDirsToClean += (Join-Path $cacheDir "Software\PushClients")
        }
    }
    catch {
        Log-Warning "Failed to parse appliance.json for CacheDirectory: $($_.Exception.Message)"
    }
}

# Fallback – common locations
$cacheDirsToClean += @(
    "C:\Software\Agents",
    "C:\Software\PushClients"
)

# ---------------------------
# 8. Remove ProgramData & cache folders (full wipe)
# ---------------------------
Log-Info "Removing Azure appliance ProgramData and cache folders..."

$paths = @(
    "$env:ProgramData\Microsoft Azure\Logs",
    "$env:ProgramData\Microsoft Azure\Config",
    "$env:ProgramData\Microsoft Azure\CredStore",
    "$env:ProgramData\Microsoft Azure\Scripts",
    "$env:ProgramData\Microsoft Azure"
) + $cacheDirsToClean

$paths = $paths | Select-Object -Unique

foreach ($p in $paths) {
    if (Test-Path $p) {
        try {
            Log-Info "Removing directory: $p"
            Remove-Item $p -Recurse -Force -ErrorAction Stop
            Log-Success "Removed: $p"
        }
        catch {
            Log-Warning "Failed to remove $($p): $($_.Exception.Message)"
        }
    }
    else {
        Log-Info "Directory not present (already removed): $p"
    }
}

# Appliance version file on public desktop
$ApplianceVersionFilePath = "$Env:SystemDrive\Users\Public\Desktop\ApplianceVersion.txt"
if (Test-Path $ApplianceVersionFilePath) {
    try {
        Remove-Item $ApplianceVersionFilePath -Force -ErrorAction Stop
        Log-Success "Removed Appliance version file: $ApplianceVersionFilePath"
    }
    catch {
        Log-Warning "Failed to remove Appliance version file: $($_.Exception.Message)"
    }
}

# ---------------------------
# 9. Reset WSMan TrustedHosts
# ---------------------------
Log-Info "Resetting WSMan TrustedHosts to empty (tightening security)..."

try {
    Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value "" -Force -ErrorAction Stop
    Log-Success "WSMan TrustedHosts cleared."
}
catch {
    Log-Warning "Failed to reset TrustedHosts: $($_.Exception.Message)"
}

# ---------------------------
# 10. Final summary
# ---------------------------
Log-Success "Azure DR appliance uninstall/cleanup completed. Review '$InstallerLog' for full details."
Log-Success "VM should now be clean of Azure DR Appliance components (OS not reinstalled)."
