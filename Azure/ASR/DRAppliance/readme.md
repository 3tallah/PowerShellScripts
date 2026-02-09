Here is the **updated README**, rewritten to **highlight clearly and explicitly** that this script is designed to uninstall and fully clean environments that used the **Modernized Mobility Service installation method** documented by Microsoft:

🔗 **Install the Mobility service using command prompt (Modernized)**
[https://learn.microsoft.com/en-us/azure/site-recovery/vmware-physical-mobility-service-overview#install-the-mobility-service-using-command-prompt-modernized](https://learn.microsoft.com/en-us/azure/site-recovery/vmware-physical-mobility-service-overview#install-the-mobility-service-using-command-prompt-modernized)

This version is professional, concise, and suitable for GitHub or internal engineering documentation.

---

# **Azure DR Appliance & Modernized Mobility Service – Full Uninstall Script**

This repository contains **AzureDRUninstall.ps1**, a complete removal and cleanup script for environments where the **Azure Site Recovery (ASR) Mobility Service and DR Appliance were installed using the *Modernized installation method*** provided by Microsoft.

> **This script is specifically intended for cleanup after deployments performed using the Microsoft-documented Modernized Mobility Service installation process:**
> 🔗 [https://learn.microsoft.com/en-us/azure/site-recovery/vmware-physical-mobility-service-overview#install-the-mobility-service-using-command-prompt-modernized](https://learn.microsoft.com/en-us/azure/site-recovery/vmware-physical-mobility-service-overview#install-the-mobility-service-using-command-prompt-modernized)
>
> It fully removes every component installed by the modernized command-line installer, including Mobility Service (Unified Agent), Process Server, and all DR Appliance modules.

---

## **Purpose**

This script restores the VM to a **pre-Azure-DR state** by removing:

* Mobility Service (Modernized / Unified Agent)
* InMage RCM stack (Proxy, Replication, Reprotect agents)
* Process Server components
* VMware/Server Discovery Services
* DR Appliance Configuration Manager
* ASR Provider & MARS Agent
* All IIS components installed by the appliance
* All registry entries, cache folders, logs, and configuration files

The result is a **clean VM**, ready for:

* A fresh ASR re-installation
* Switching to a new replication method
* Reusing the VM for another role
* Troubleshooting broken/unhealthy appliances

---

## **What This Script Removes**

### **1. Services**

Stops and disables:

* InMage Mobility Service (Unified Agent)
* RCM Proxy, Replication, Reprotect agents
* Process Server
* VMware & Server Discovery services
* Azure Site Recovery Agent
* MARS Agent

### **2. Installed Products**

Automatically uninstalls:

* All RCM MSI packages
* Mobility Service (UnifiedAgent.exe installation)
* ASR Agent / Provider
* Process Server MSI
* DR Appliance Web App
* AutoUpdater
* Discovery Services
* Azure DR Appliance components

### **3. IIS Features**

Removes all features originally installed by Azure DR Appliance:

* Web-Server
* WAS
* ASP.NET / .NET Extensibility
* Management tools
* CGI/Redirect/Windows Auth
* URL Rewrite module

Use `-KeepIIS` if the VM hosts other apps.

### **4. File System Cleanup**

Deletes:

* `C:\ProgramData\Microsoft Azure`
* Cache folders created by Unified Mobility Agent
* DR Appliance folders
* ApplianceVersion.txt
* Logs and config artifacts

### **5. Registry Cleanup**

Removes:

* `HKLM\SOFTWARE\Microsoft\Azure Appliance`
* `HKLM\Software\Microsoft\AzureAppliance`
* Edge “HideFirstRunExperience” policy (if applied)

### **6. WSMan Cleanup**

Resets TrustedHosts to secure default:

```
TrustedHosts = ""
```

---

## **Prerequisites**

* Windows Server 2016+
* Run **PowerShell as Administrator**
* Execution policy allowing script execution

---

## **How to Run**

### **Full cleanup (recommended):**

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
.\AzureDRUninstall.ps1
```

### **Keep IIS installed:**

```powershell
.\AzureDRUninstall.ps1 -KeepIIS
```

---

## **Log Location**

Logs are stored outside the Microsoft Azure folder to avoid deletion conflicts:

```
C:\Temp\AzureDRCleanupLogs\
```

Provide the log file for support requests.

---

## **After Cleanup**

Reboot the VM:

```powershell
Restart-Computer -Force
```

Your VM now returns to a **clean state**, fully purged of:

* Modernized Mobility Service
* Azure DR Appliance components
* ASR / MARS agents
* Related IIS services and registry footprint

---

If you want a GitHub-style README with badges, markdown formatting enhancements, or a compressed bundle for distribution, I can generate that as well.
