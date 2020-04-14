This script for Creating a bunch of ADGroups "New-ADGroup, Set-ADGroup" using CSV file with the use of "Notes, ManagedBy" fields for more information on the group.

The attachment has two files (PS1 Script and CSV Sample)

\#CSV file Should include two rows (Name,Description) and optional (ManagedBy,NOTES)



PowerShell

```
Import-module ActiveDirectory   
 
#Define CSV file location variables 
#CSV file Should include two rows (Name,Description) and optional (ManagedBy,NOTES) 
 
#Replace "\ADGroups.csv" with the CSV path folder.  
 
$ADGroups = Import-CSV "\ADGroups.csv" 
 
#Replace "DC=QTG,DC=local" with the groups OU Distinguished Name 
 
$ADGroupsPath = "DC=QTG,DC=local" 
foreach ($ADGroup in $ADGroups)
```

 



 
