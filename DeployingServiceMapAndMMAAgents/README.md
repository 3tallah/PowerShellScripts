# Deploying Dependency, MMA Agents, Update Microsoft Monitoring Agent Configuration

This script was created to help our customer needs to Install ServiceMap and MMA Agents.

## Getting Started

[![img](https://1.bp.blogspot.com/-JgXxUgufYvo/XlfXbMRpyVI/AAAAAAABDYY/16EzGCYXn883G-ya_TbAOeoH3lOU6R8YgCLcBGAsYHQ/s400/Install%2BServiceMap%2Band%2BMMA%2BAgents%252C%2BUpdate%2BOMS%2BAgent%2BworkspaceID%2BAnd%2BworkspaceKey%252C%2Boptionally%2BConfigure%2BProxy.png)](https://1.bp.blogspot.com/-JgXxUgufYvo/XlfXbMRpyVI/AAAAAAABDYY/16EzGCYXn883G-ya_TbAOeoH3lOU6R8YgCLcBGAsYHQ/s1600/Install%2BServiceMap%2Band%2BMMA%2BAgents%2C%2BUpdate%2BOMS%2BAgent%2BworkspaceID%2BAnd%2BworkspaceKey%2C%2Boptionally%2BConfigure%2BProxy.png)

 **[Deploying Dependency, MMA Agents and Update Microsoft Monitoring Agent Configuration](https://blog.3tallah.com/2020/02/Deploying-Dependency-MMA-Agents-and-Update-Microsoft-Monitoring-Agent-Configuration.html)**

This script was created to help our customer needs to Install ServiceMap and MMA Agents then Update this Agent with Azure OMS workspaceID And workspaceKey, optionally Configure Proxy

I had customer requirement to push MMA and Dependency Agent automatically on 530 VMs with specific configuration as the already have SCOM in place, for that purpose I created two scripts one for just modifying current MMA agent and configure to push their logs to SCOM as well as OMS gateway and the second one is just to replace the current MMA agent with the new MMA one and its configuration. then added both to SCCM for normal deployment.

 

Here I'm sharing with you a kind of combined script which includes both functionalities with clear NOTES, hence you have the right to just use the script as-is or remove region which not part of your target.

For more information on the script, please check my Post; [here](https://blog.3tallah.com/2020/02/Deploying-Dependency-MMA-Agents-and-Update-Microsoft-Monitoring-Agent-Configuration.html).

Tags
Microsoft Azure, Powershell, Powershell Script, Windows PowerShell, OMS, MMA, Microsoft Monitoring Agent, Dependency Agent, Microsoft Monitoring
