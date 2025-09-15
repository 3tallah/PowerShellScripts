# PowerShellScripts
PowerShell functions and scripts for automation daily routine tasks (AD, Exchange, SCCM, O365, ...)

## Update-AVDAgent

A PowerShell script to update Azure Virtual Desktop (AVD) Session Host Agent with a new registration token.

### Description

This script automates the process of updating AVD agents by:
- Stopping AVD services
- Uninstalling old AVD Agent & Bootloader
- Downloading and installing the latest AVD Agent & Bootloader
- Registering the host with a new registration token
- Restarting services to establish host heartbeat

### Prerequisites

- Windows PowerShell 5.1 or later
- Administrator privileges
- Internet access to download installers
- Valid AVD registration token from Azure Portal

### Usage

```powershell
.\Update-AVDAgent.ps1 -RegistrationToken "<your-registration-token>"
```

#### Parameters

- `RegistrationToken` (Mandatory): The AVD registration key/token from Azure Portal

### Example

```powershell
.\Update-AVDAgent.ps1 -RegistrationToken "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9..."
```

### Important Notes

- **Run as Administrator**: The script must be executed with administrator privileges
- **Token Validity**: Registration tokens are only valid for a few hours
- **Internet Access**: The script downloads the latest installers from Microsoft's official sources
- **Service Impact**: AVD services will be temporarily unavailable during the update process

### What the Script Does

1. **Validation**: Checks for administrator privileges
2. **Download**: Downloads latest AVD Agent and Bootloader from Microsoft
3. **Stop Services**: Stops RDAgentBootLoader and RDAgent services
4. **Uninstall**: Removes old versions of AVD components
5. **Install**: Installs new AVD Agent with the provided registration token
6. **Install Bootloader**: Installs the AVD Bootloader
7. **Restart Services**: Starts AVD services to establish heartbeat

## Author

**Mahmoud A. Atallah**  
Azure Solutions Lead | Microsoft MVP  
Cloud Mechanics FZC

- Email: mahmoud@cloudmechanics.ae
- Website: https://cloudmechanics.ae
- LinkedIn: https://www.linkedin.com/in/mahmoudatallah/
- GitHub: https://github.com/3tallah

## License

MIT License

## Support

For issues or questions, please contact the author or create an issue in the repository.
