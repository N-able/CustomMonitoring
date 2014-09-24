#############################################################################################################################################
# Name: Windows Server Backup.ps1
# Description: Monitors the status of the most recent Backup job in Windows Server Backup
# Dependances: Needs Windows 2008 R2, Powershell 2.0 must be installed, and the Command Line Tools for Windows Server Backup (it's a Feature in Windows)
# Version: 1.6
# Author: Chris Reid @ N-able Technologies
#############################################################################################################################################


# Version History

# 1.7.1 - Supressed the get-wbjob errors if CMDLet not present

# 1.7 - Added additional logging for ErrorDescription - see thread : https://nrc.n-able.com/community/pages/forums.aspx?action=ViewPosts&fid=5&tid=5817

# 1.6 - Added additional logging, and ensured that any values that come back 'null' are populated with fake data. This change will resduce the number of Misconfigured instances of this service. (May 22nd, 2012)

# 1.5 - Changed the data type of the NumberOfVersions, HoursSinceLastBackup, and HoursSinceLastSuccessfulBackup values from Uint16 to Uint32. Thanks to Bill Gile for finding this issue! (Jan. 4th, 2012) 

# 1.4 - Add a 'REQUIRES' statement so that the script will only run when PowerShell 2.0 is installed. Thanks (again!) to Tim Wiser for the suggestion! (Nov 2nd, 2011)

# 1.3 - Changed the data type of the LastBackupResultHR and LastBackupResultDetailedHR values from Uint8 to Uint32. Thanks to Tim Wiser for finding this issue! (Nov 1st, 2011)

# 1.2 - Fixed an issue where the root\cimv2\Ncentral WMI namespace was not getting created. Thanks to Nick Jarratt for finding this issue! (Oct. 24th, 2011)

# 1.1 - Started gathering (in hours) the amount of time between the script's execution time and the last successful/last recorded backup (Oct. 3rd, 2011)

# 1.0 - Initial Release (August 18th, 2011)



# Make sure that PowerShell 2.0 is installed
#requires -version 2


# Declare a few variables that we'll use later on in the script
$Namespace = "NCentral"
$Class = "WindowsServerBackup_Data"


# Load the Powershell commandlets for Windows Backup - we need this later on to query Windows Backup.
Add-PSSnapin Windows.ServerBackup -ErrorAction SilentlyContinue

# Gets the execution policies for the current session.
$CurrentPolicy = Get-ExecutionPolicy
If ($CurrentPolicy -ne 'RemoteSigned')
    {
        WRITE-HOST "The current execution policy is set to $CurrentPolicy - this is a bad thing!"
        WRITE-HOST "I'll try to set the execution policy to 'RemoteSigned' - just a sec."
        SET-EXECUTIONPOLICY RemoteSigned
        RETURN
    }
    
    
# Check to see if the root\cimv2\Ncentral WMI namespace exists - if it doesn't, then let's create it
# Thanks to http://gallery.technet.microsoft.com/scriptcenter/d230c216-9d21-4130-a190-4049ca2df21c for the code
If (Get-WmiObject -Namespace "root\cimv2" -Class "__NAMESPACE" | Where-Object {$_.Name -eq $Namespace})
{
    WRITE-HOST "The root\cimv2\Ncentral WMI namespace exists."
}
Else
{
    WRITE-HOST "The root\cimv2\Ncentral WMI namespace does not exist."
    $wmi= [wmiclass]"root\cimv2:__Namespace" 
    $newNamespace = $wmi.createInstance() 
    $newNamespace.name = $Namespace 
    $newNamespace.put() 
}






# Check to see if the 'WindowsServerBackup_Data' class exists - if it doesn't, then let's create it
If (Get-WmiObject -List -Namespace "root\cimv2\Ncentral" | Where-Object {$_.Name -eq $Class})
{
    WRITE-HOST "The " $Class " WMI class exists."
    # Because the class already exists, we need to make sure it's 'blank', and does not contain any pre-populated instances
    # Hint: Pre-populated instances could have come from someone having already run this script.
    $GetExistingInstances = Get-WmiObject -Namespace "root\cimv2\Ncentral" -Class $Class
	WRITE-HOST $GetExistingInstances
    If ($GetExistingInstances -eq $Null) 
    {
        WRITE-HOST "There are no instances in this WMI class."         
    }
    Else
    {
        WRITE-HOST "There are pre-existing instances of this WMI class - deleting."
        ForEach ($Instance in $GetExistingInstances) {Remove-WMIObject -Namespace "root\cimv2\Ncentral" -Class $Class}
    }
}

    WRITE-HOST "The " $Class " WMI class does needs to be created."
    # Because the class doesn't exist (or has just been deleted), let's create it, and specify all of the appropriate properties.
    $subClass = New-Object System.Management.ManagementClass ("root\cimv2\Ncentral", [String]::Empty, $null); 
    $subClass["__CLASS"] = $Class; 
    $subClass.Qualifiers.Add("Static", $true)
    $subClass.Properties.Add("Name", [System.Management.CimType]::String, $false)
    $subClass.Properties["Name"].Qualifiers.Add("Key", $true)
    $subClass.Properties.Add("NextBackupTime", [System.Management.CimType]::String, $false)
    $subClass.Properties.Add("NumberOfVersions", [System.Management.CimType]::UInt32, $false)
    $subClass.Properties.Add("LastSuccessfulBackupTime", [System.Management.CimType]::String, $false)
    $subClass.Properties.Add("LastSuccessfulBackupTargetPath", [System.Management.CimType]::String, $false)
    $subClass.Properties.Add("LastSuccessfulBackupTargetLabel", [System.Management.CimType]::String, $false)
    $subClass.Properties.Add("LastBackupTime", [System.Management.CimType]::String, $false)
    $subClass.Properties.Add("LastBackupTarget", [System.Management.CimType]::String, $false)
    $subClass.Properties.Add("DetailedMessage", [System.Management.CimType]::String, $false)
    $subClass.Properties.Add("LastBackupResultHR", [System.Management.CimType]::UInt32, $false)
    $subClass.Properties.Add("LastBackupResultDetailedHR", [System.Management.CimType]::UInt32, $false)
    $subClass.Properties.Add("CurrentOperationStatus", [System.Management.CimType]::String, $false)
    $subClass.Properties.Add("HoursSinceLastBackup", [System.Management.CimType]::UInt32, $false)
    $subClass.Properties.Add("HoursSinceLastSuccessfulBackup", [System.Management.CimType]::UInt32, $false)
	$subClass.Properties.Add("LastErrorDescription", [System.Management.CimType]::String, $false)
	$subClass.Properties.Add("LastErrorDescriptionStatus", [System.Management.CimType]::UInt32, $false)
    $subClass.Put()





# Now that everything WMI-related has been setup correctly, let's query Windows Server Backup for the status of it's backup jobs.
$BackupData = Get-WBSummary


# Let's check to see if some of the values are NULL (a common occurance when backups have never completed successfully). If they are NULL, let's 
# substitute them with placeholder data.

$LastSuccessfulBackupTargetPath = $BackupData.LastSuccessfulBackupTargetPath
$LastSuccessfulBackupTargetLabel = $BackupData.LastSuccessfulBackupTargetLabel
$LastBackupTime = $BackupData.LastBackupTime
$LastSuccessfulBackupTime = $BackupData.LastSuccessfulBackupTime
$LastErrorDescription = ""
$ErrorActionPreference = "SilentlyContinue"
$LastErrorDescription = (get-wbjob -previous 1).ErrorDescription
$ErrorActionPreference = "Continue"

If ($LastSuccessfulBackupTargetPath -eq $Null) {$LastSuccessfulBackupTargetPath = "NULL"}
If ($LastSuccessfulBackupTargetLabel -eq $Null) {$LastSuccessfulBackupTargetLabel = "NULL"}
If ($LastBackupTime -eq $Null) {$LastBackupTime = "01/01/0001 00:00:00"}
If ($LastSuccessfulBackupTime -eq $Null) {$LastSuccessfulBackupTime = "01/01/0001 00:00:00"}
if ($LastErrorDescription.Length -eq 0) {$LastErrorDescriptionStatus="0"
$LastErrorDescription = "No Errors"} 
Else 
{$LastErrorDescriptionStatus="1"}


WRITE-HOST "Here is the raw data about Windows Backup from WMI:"
WRITE-HOST "Next Backup Time: " $BackupData.NextBackupTime
WRITE-HOST "Number of Versions: " $BackupData.NumberOfVersions
WRITE-HOST "Last Successful Backup Time: " $BackupData.LastSuccessfulBackupTime
WRITE-HOST "Target Path of the Last Successful Backup: " $LastSuccessfulBackupTargetPath
WRITE-HOST "Target Label of the Last Successful Backup: " $LastSuccessfulBackupTargetLabel
WRITE-HOST "Time of the Last Backup: " $LastBackupTime
WRITE-HOST "Target of the Last Backup: " $BackupData.LastBackupTarget
WRITE-HOST "Detailed Message: " $BackupData.DetailedMessage
WRITE-HOST "Result Code of Last Backup: " $BackupData.LastBackupResultHR
WRITE-HOST "Detailed Result Code of Last Backup: " $BackupData.LastBackupResultDetailedHR
WRITE-HOST "Status of the Current Operation: " $BackupData.CurrentOperationStatus
WRITE-HOST "Error Description: " $LastErrorDescription
WRITE-HOST "Error Description Status: " $LastErrorDescriptionStatus 


#Now let's calculate how many hours it's been since backups were last ran
$LastBackupDifference = [DateTime]::Now - [system.datetime]$LastBackupTime
$LastBackupDifference = "{0:N0}" -f $LastBackupDifference.TotalHours
$LastSuccessfulBackupDifference = [DateTime]::Now - [system.datetime]$LastSuccessfulBackupTime
$LastSuccessfulBackupDifference = "{0:N0}" -f $LastSuccessfulBackupDifference.TotalHours
WRITE-HOST "It's been " $LastSuccessfulBackupDifference " hours since a backup last ran successfully."
WRITE-HOST ""
WRITE-HOST ""


# Now let's push the backup data into WMI
$PushDataToWMI = ([wmiclass]"root\cimv2\Ncentral:WindowsServerBackup_Data").CreateInstance()
$PushDataToWMI.NextBackupTime =  $BackupData.NextBackupTime
$PushDataToWMI.Name =  "Windows Server Backup"
$PushDataToWMI.NumberOfVersions = $BackupData.NumberOfVersions
$PushDataToWMI.LastSuccessfulBackupTime = $BackupData.LastSuccessfulBackupTime
$PushDataToWMI.LastSuccessfulBackupTargetPath = $LastSuccessfulBackupTargetPath
$PushDataToWMI.LastSuccessfulBackupTargetLabel = $LastSuccessfulBackupTargetLabel
$PushDataToWMI.LastBackupTime = $LastBackupTime
$PushDataToWMI.LastBackupTarget = $BackupData.LastBackupTarget
$PushDataToWMI.DetailedMessage = $BackupData.DetailedMessage
$PushDataToWMI.LastBackupResultHR = $BackupData.LastBackupResultHR
$PushDataToWMI.LastBackupResultDetailedHR = $BackupData.LastBackupResultDetailedHR
$PushDataToWMI.CurrentOperationStatus = $BackupData.CurrentOperationStatus
$PushDataToWMI.HoursSinceLastBackup = $LastBackupDifference
$PushDataToWMI.HoursSinceLastSuccessfulBackup = $LastSuccessfulBackupDifference
$PushDataToWMI.LastErrorDescription = $LastErrorDescription
$PushDataToWMI.LastErrorDescriptionStatus = $LastErrorDescriptionStatus
$PushDataToWMI.Put() 