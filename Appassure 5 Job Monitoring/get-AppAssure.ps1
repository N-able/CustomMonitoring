#######################################################################################
# Name: get-AppAssure.ps1
# Description: Queries AppAssure Core 5.x for the status of it's backup jobs
# Dependances: Powershell 2.0 must be installed, as well as AppAssure 5.x or above
# Version: 0.1
# Author: R. Grapes @ N-able Technologies
#######################################################################################
 
# Version History
 
# 0.1 - Initial Draft Release (March 8th, 2013)

# Make sure that PowerShell 2.0 is installed
# Requires -Version 2.0
 
 
function Get-DateDiff {
param ( 
[CmdletBinding()] 
[parameter(Mandatory=$true)]
[datetime]$date1, 
[parameter(Mandatory=$true)]
[datetime]$date2
) 
if ($date2 -gt $date1){$diff = $date2 - $date1}
else {$diff = $date1 - $date2}
	$diff.TotalSeconds
} 
function SetExecPolicy {
$CurrentPolicy = Get-ExecutionPolicy
If ($CurrentPolicy -ne 'RemoteSigned')
{
WRITE-HOST "The current execution policy is set to $CurrentPolicy - this is a bad thing!"
WRITE-HOST "I'll try to set the execution policy to 'RemoteSigned' - just a sec."
SET-EXECUTIONPOLICY RemoteSigned
RETURN
}
}
 
 
Function LoadAppAssure 
{
	WRITE-HOST "Now loading the AppAssure PowerShellModule."
    Import-Module AppAssurePowerShellModule
}
 
 
 
Function SetupWMI {
 
# Declare a few variables that we'll use later on in the script
$Namespace = "NCentral"
$Class = "AppAssure_Data"
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
# Check to see if the 'AppAssure_Data' class exists - if it doesn't, then let's create it
If (Get-WmiObject -List -Namespace "root\cimv2\Ncentral" | Where-Object {$_.Name -eq $Class})
{
WRITE-HOST "The " $Class " WMI class exists."
# Because the class already exists, we need to make sure it's 'blank', and does not contain any pre-populated instances
# Hint: Pre-populated instances could have come from someone having already run this script.
$GetExistingInstances = Get-WmiObject -Namespace "root\cimv2\Ncentral" -Class $Class
If ($GetExistingInstances -eq $Null) 
{
WRITE-HOST "There are no instances in this WMI class." 
}
Else
{
WRITE-HOST "There are pre-existing instances of this WMI class - deleting."
Remove-WMIObject -Namespace "root\cimv2\Ncentral" -Class $Class
}
}
WRITE-HOST "Now creating the " $Class " WMI class."
# Because the class doesn't exist, let's create it, and specify all of the appropriate properties.
$subClass = New-Object System.Management.ManagementClass ("root\cimv2\Ncentral", [String]::Empty, $null); 
$subClass["__CLASS"] = $Class; 
$subClass.Qualifiers.Add("Static", $true)
$subClass.Properties.Add("lastresult", [System.Management.CimType]::String, $false)
$subClass.Properties.Add("laststate", [System.Management.CimType]::String, $false)
$subClass.Properties.Add("jobname", [System.Management.CimType]::String, $false)
$subClass.Properties["jobname"].Qualifiers.Add("Key", $true)
$subClass.Properties.Add("jobtype", [System.Management.CimType]::String, $false)
$subClass.Properties.Add("starttime", [System.Management.CimType]::String, $false)
$subClass.Properties.Add("endtime", [System.Management.CimType]::String, $false)
$subClass.Properties.Add("duration", [System.Management.CimType]::String, $false)
$subClass.Properties.Add("lastresulttype", [System.Management.CimType]::UInt8, $false)
$subClass.Properties.Add("scriptexecutiontime", [System.Management.CimType]::String, $false)
$subClass.Properties.Add("timesincebackuplastrun", [System.Management.CimType]::UInt32, $false)
$subClass.Put()
 
}
function Get-AppAssureJobs {
# Now that everything WMI-related has been setup correctly, let's query AppAssure for the status of its backup jobs.
$arrayq = New-Object system.Collections.ArrayList
$arrayq.Insert(0, "transfer");

for($u=0;$u -le $arrayq.count-1; $u++)
{
$jtype = $arrayq[$u]
$jobarray1=""
$ii=0
$rr=0
# Create the array of jobs 
$jobarray1 = New-Object system.Collections.ArrayList
# Get the list of AppAssure completed jobs and insert into $jobarray1 array
Get-completedjobs -all | where {$_.JobClassname -match $jtype} | foreach { 
  
# Get the details about each job that was found

$jobsummary=$_.Summary
$name=$_.Summary
$jobid=$_.Id 

$lastresult=$_.Status
WRITE-HOST "The result value is:" $lastresult
if($lastresult -match 'Warning')
{
$lastresult_type = 1;
}
elseif($lastresult -match 'Succeeded')
{
$lastresult_type = 0;
}
elseif($lastresult -match 'Failed')
{
$lastresult_type = 2;
}
elseif($lastresult -match 'None')
{
$lastresult_type = 1;
}
else
{
$lastresult=""
$lastresult_type = 1
}
WRITE-HOST "The numerical interpretation of the Job Result is: " $lastresult_type
#### Service Type 
$servicetype=$_.JobClassname
If (!$servicetype)
{
$servicetype=""
}
WRITE-HOST "The Job Type is: " $servicetype
### service progress
$laststate=$_.State
WRITE-HOST "The Job State is: " $laststate
If (!$laststate)
{
$laststate=""
}
#### Scheduled Start Time
$starttime=$_.StartTime
WRITE-HOST "The Job Start Time is: " $starttime
If (!$starttime)
{
$starttime=""
}
#### End Time
$endtime=$_.EndTime
WRITE-HOST "The Job End Time is: " $endtime 
If (!$endtime)
{
$endtime=""
}
#### Duration
$duration=(Get-DateDiff -date1 $endtime -date2 $starttime)
WRITE-HOST "The duration of the backup was: " $duration
If (!$duration)
{
$duration=""
}
 
#### Timestamp of the Script Running 
$scriptexecutiontime = Get-Date
WRITE-HOST "This script is being run at the following time: " $scriptexecutiontime
 
$PushDataToWMI = ([wmiclass]"root\cimv2\Ncentral:AppAssure_Data").CreateInstance()
$PushDataToWMI.lastresult = $lastresult
$PushDataToWMI.laststate = $laststate
$PushDataToWMI.jobname = $name
$PushDataToWMI.jobtype = $servicetype
$PushDataToWMI.lastresulttype = $lastresult_type
$PushDataToWMI.starttime = $starttime
$PushDataToWMI.endtime = $endtime
$PushDataToWMI.duration = $duration
$PushDataToWMI.scriptexecutiontime = $scriptexecutiontime
[int]$PushDataToWMI.timesincebackuplastrun = (Get-DateDiff -date1 $endtime -date2 $scriptexecutiontime)/3600
Write-Host "It's been" $PushDataToWMI.timesincebackuplastrun "hours since the backup job last ran."
$PushDataToWMI.Put() 
}
}
}
 
# Set the execution policy for the current session.
SetExecPolicy
 
# Make sure that we can load the AppAssure DLL file
LoadAppAssure
# Setup WMI correctly
SetupWMI
#Grab the status of the AppAssure jobs
Get-AppAssureJobs 
