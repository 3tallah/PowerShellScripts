###########################################################
# AUTHOR  : Mahmoud A. Atallah
# WEBSITE : https://social.technet.microsoft.com/profile/mahmoud%20a.%20atallah/
# Aboutme : https://about.me/Mahmoud_Atallah
# CREATED : 15-07-2017 
# UPDATED : 22-08-2017 
# COMMENT : This script generates a brief of all current users have access to send on behalf then
#           based on the template CSV file will import and grant Full Mailbox Access and send
#           on behalf access to the new users. 
###########################################################


#Define CSV file location variables
#CSV file Should include two rows (One for User IDs "Name" and one for Mailboxes "Mail")

$csv = Import-Csv C:\Users\mat801\Downloads\users.csv 

$csv | ForEach-Object -Process{
$users = $_.name
$name = @{Add="$users"}

Get-Mailbox $_.mail | Select-Object -ExpandProperty GrantSendOnBehalfTo

Add-MailboxPermission $_.mail -User $_.name -AccessRights FullAccess

Set-Mailbox $_.mail -GrantSendOnBehalfTo $name

Get-Mailbox $_.mail | Select-Object -ExpandProperty GrantSendOnBehalfTo

}
