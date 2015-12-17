#######################################################################################
# Name: Veeam.ps1
# Description: Queries Veeam 5.x or 6.x for the status of it's backup jobs
# Dependances: Powershell 2.0 must be installed, as well as Veeam 5.x or above
# Version: 2.6
# Author: Chris Reid & Marc-Andre Tanguay @ N-able Technologies
#######################################################################################
 
# Version History
 
# 2.6 - added fix for variable limitation causing issues in count
# 2.5 - Changed the script to load the Veeam PowerShell commandlets by using the Add-PSSnapin command, instead of the Import-Module command. This removes any dependancy on the script knowing the location of the Veeam DLL file (March 1st, 2013)
# 2.4 - Fixed an issue where the script wasn't being specific enough when querying for backup job GUIDs; this resulted in incorrect data being pushed into WMI (Feb 19th, 2013)
#     - Changed the 'timesincebackuplastrun' value to be a UINT32 as it's previous classification (UINT16) wasn't large enough (Feb 19th, 2013)
# 2.3 - Fixed an issue where the script was trying to query for the properties of Sure Backups even when none were found (Jan 11th, 2013)
# 2.2 - Fixed an issue where the script was unable to detect properties about 'Sure Backup' jobs (Jan 8th, 2013)
# 2.1 - Removed the code that invoked .NET 4.0, as upgrading to PowerShell 3.0 solves the issue. (Dec. 31st, 2012)
# - Made the script correctly report Failed as a value of 2 instead of 3
# - Started reporting the date when the script was last ran
# - Added a scandetail that compares the current time vs. the time that the backup job last ran 
# 2.0 - Added support for Veeam 6.5 which requires .NET 4 assemblies
# 1.9 - Added better error handling if the Veeam PowerShell module isn't found (Oct. 11th, 2012)
# 1.8 - Added code to better handle null values (Oct. 11th, 2012) 
# 1.7 - Added code that ensures that Powershell 2.0 is installed. Some of the functions that this script calls don't work on Powershell 1.0 (April 20th, 2012)
# 1.6 - Added support for Veeam 6.0 and added support for the situation where the Job Result is 'None' (Dec. 20th, 2011)
# 1.5 - Changed where the script was looking for the Veeam DLL file, and cleaned up how the script creates/manages the WMI class (Oct. 31st, 2011)
# 1.4 - Changed how the WMI class is created so that only the 'jobname' property is considered to be a primary key (Oct. 12th, 2011)
# 1.3 - Fixed an issue with the logic used to delete an existing instance of the WMI class (August 22nd, 2011)
# 1.2 - Changed the operator to look for the job name from -match to -contains. This fixes an issue where the script errored out if the job name contains the () characters. (June 20th, 2011)
# 1.1 - Fixed an issue where the wrong WMI class was referenced when pushing the data to WMI (June 20th, 2011)
# 1.0 - Initial Release (March 28th, 2011)
# Make sure that PowerShell 2.0 is installed
#Requires -Version 2.0
 
 
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
 
 
Function LoadVeeamDLL 
{
	WRITE-HOST "Now loading the Veeam PowerShell Snap-in."
	Add-PSSnapin -Name VeeamPSSnapIn
}
 
 
 
Function SetupWMI {
 
# Declare a few variables that we'll use later on in the script
$Namespace = "NCentral"
$Class = "Veeam_Data"
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
# Check to see if the 'Veeam_Data' class exists - if it doesn't, then let's create it
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
function Get-VeeamJobs {
# Now that everything WMI-related has been setup correctly, let's query Veeam for the status of its backup jobs.
$arrayq = New-Object system.Collections.ArrayList
$arrayq.Insert(0, "Backup");
$arrayq.Insert(1, "Replica");
for($u=0;$u -le $arrayq.count-1; $u++)
{
$jtype = $arrayq[$u]
$jobarray1=""
$ii=0
$rr=0
# Create the array of jobs 
$jobarray1 = New-Object system.Collections.ArrayList
# Get the list of Backup jobs and insert into $jobarray1 array
Get-VBRJob | where {$_.JobTargetType -match $jtype} | foreach {$jobarray1.Insert( $ii, $_.name); $ii++ 
}
# Get the details about each job that was found
for ($i=0; $i -le $jobarray1.count – 1; $i++)
{
$name=$jobarray1[$i]
$job1=get-vbrjob | where {$_.name -eq $name}
#$jobid=$job1.FindLastSession().Id 
$job = Get-VBRBackupSession | where {$_.Name -eq $name -and $_.Result -ne 'None'} | Sort-Object EndTime -Descending | Select-Object -First 1
WRITE-HOST "The sessionID for this job is: " $job.Id 
 
 
# Figure out if the job completed successfully the last time it ran 
$lastresult=$job.Result
WRITE-HOST "The result value is:" $lastresult
if($lastresult -match 'Warning')
{
$lastresult_type = 1;
}
elseif($lastresult -match 'Success')
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
$servicetype=$job.JobType
If (!$servicetype)
{
$servicetype=""
}
WRITE-HOST "The Job Type is: " $servicetype
### service progress
$laststate=$job.State
WRITE-HOST "The Job State is: " $laststate
If (!$laststate)
{
$laststate=""
}
#### Scheduled Start Time
$starttime=$job.Progress.StartTime
WRITE-HOST "The Job Start Time is: " $starttime
If (!$starttime)
{
$starttime=""
}
#### End Time
$endtime=$job.Progress.StopTime
WRITE-HOST "The Job End Time is: " $endtime 
If (!$endtime)
{
$endtime=""
}
#### Duration
$duration=$job.Progress.Duration
WRITE-HOST "The duration of the backup was: " $duration
If (!$duration)
{
$duration=""
}
 
 
 
#### Timestamp of the Script Running 
$scriptexecutiontime = Get-Date
WRITE-HOST "This script is being run at the following time: " $scriptexecutiontime
 
$PushDataToWMI = ([wmiclass]"root\cimv2\Ncentral:Veeam_Data").CreateInstance()
$PushDataToWMI.lastresult = $lastresult
$PushDataToWMI.laststate = $laststate
$PushDataToWMI.jobname = $name
$PushDataToWMI.jobtype = $servicetype
$PushDataToWMI.lastresulttype = $lastresult_type
$PushDataToWMI.starttime = $starttime
$PushDataToWMI.endtime = $endtime
$PushDataToWMI.duration = $duration
$PushDataToWMI.scriptexecutiontime = $scriptexecutiontime
[int]$datevalue= (Get-DateDiff -date1 $endtime -date2 $scriptexecutiontime)/3600
if($datevalue -gt 31000) 
{
[int]$PushDataToWMI.timesincebackuplastrun = 31000
}
else
{
[int]$PushDataToWMI.timesincebackuplastrun = (Get-DateDiff -date1 $endtime -date2 $scriptexecutiontime)/3600
}
Write-Host "It's been" $PushDataToWMI.timesincebackuplastrun "hours since the backup job last ran."
$PushDataToWMI.Put() 
}
}
############## Sure Backups require the use of different PowerShell commandlets, so let's get those rolling!
$tt=0;
$vsbjob = New-Object system.Collections.ArrayList
Get-VSBJob | foreach {$vsbjob.Insert( $tt, $_.name); $tt++}
$u=0;
WRITE-HOST "The number of found Sure Backups is:" $vsbjob.count
If ($vsb.count -gt 0){

    for ($k=0; $k -le $vsbjob.count – 1; $k++){
    $jname=$vsbjob[$k]
    WRITE-HOST "The Sure Backup Job is:" $jname
    $vsbid = New-Object system.Collections.ArrayList
    $aa=Get-VSBSession | where {$_.name -match $jname}| Sort-Object CreationTime | select Id -last 1 | foreach {$_}
    WRITE-HOST "The JobID is:" $aa.ID
    #$a1=$aa -replace "Id", ""
    #$a1=$a1 -replace "@{=", ""
    #$jobid=$a1 -replace "}", ""
    }
    $job=Get-VSBSession | where {$_.Id -match $aa.ID}
    $lastresult=$job.Result
    if($lastresult -match 'Warning'){
    $lastresult_type = 1;
    }elseif($lastresult -match 'Success'){
    $lastresult_type = 0;
    }elseif($lastresult -match 'Failed'){
    $lastresult_type = 2;
    }else
    {
    $lastresult_type=1;
    }
    if(!$lastresult)
    {
    $lastresult="" 
    }
    #### Service Type 
    $servicetype=$job.JobTargetType
    If (!$servicetype)
    {
    $servicetype=""
    }
    ### service progress
    $laststate=$job.State
    If (!$laststate)
    {
    $laststate=""
    }
    #### Schedule time Start Time
    $starttime=$job.CreationTime
    If (!$starttime)
    {
    $starttime=""
    }
    #### Schedule time End Time
    $endtime=$job.EndTime
    If (!$endtime)
    {
    $endtime=""
    }
    $mb = ([wmiclass]"root/cimv2/Ncentral:Veeam_Data").CreateInstance()
    $mb.lastresult = $lastresult
    $mb.laststate = $laststate
    $mb.jobname = $jname
    $mb.jobtype = $servicetype
    $mb.lastresulttype = $lastresult_type
    $mb.starttime = $starttime
    $mb.endtime = $endtime

    WRITE-HOST "Last State:" $laststate
    WRITE-HOST "Job Name:" $jname
    WRITE-HOST "Service Type:" $servicetype
    WRITE-HOST "Last Result Type:" $lastresult_type
    WRITE-HOST "Start Time:" $starttime
    WRITE-HOST "End Time:" $endtime
 
    [int]$duration=Get-DateDiff -date1 $starttime -date2 $endtime
    $mb.duration = $duration

    $scriptexecutiontime = Get-Date
    WRITE-HOST "This script is being run at the following time: " $scriptexecutiontime
    $mb.scriptexecutiontime = $scriptexecutiontime

    $mb.timesincebackuplastrun = (Get-DateDiff -date1 $endtime -date2 $scriptexecutiontime)/3600
    
    $mb.Put() 
    }
}
 
# Set the execution policy for the current session.
SetExecPolicy
 
# Make sure that we can load the Veeam DLL file
LoadVeeamDLL
# Setup WMI correctly
SetupWMI
#Grab the status of the Veeam backup jobs
Get-VeeamJobs 
