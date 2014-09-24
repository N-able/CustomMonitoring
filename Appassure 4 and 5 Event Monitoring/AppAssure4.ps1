param(
     [int32]$numberofhourstocheck 
)

$numberofhourstocheck=1500


if(!$numberofhourstocheck -or $numberofhourstocheck -eq 0)
{
    $numberofhourstocheck = -12
}
else
{
    $numberofhourstocheck= $numberofhourstocheck * -1
}


$Events = get-eventlog appassure -after (get-date).addhours($numberofhourstocheck) | ?{$_.eventid -eq "1" -or $_.eventid -eq "12940" -or $_.eventid -eq "16025" -or $_.eventid -eq "1508" -or $_.eventid -eq "20894" -or $_.eventid -eq "38840" -or $_.eventid -eq "56682" -or $_.eventid -eq "44241" -or $_.eventid -eq "3610" } 
$EventsTotal = get-eventlog appassure #-after (get-date).addhours($numberofhourstocheck) | ?{$_.eventid -eq "1" -or $_.eventid -eq "17746" -or $_.eventid -eq "12940" -or $_.eventid -eq "16025" -or $_.eventid -eq "1508" -or $_.eventid -eq "20894" -or $_.eventid -eq "38840" -or $_.eventid -eq "56682" -or $_.eventid -eq "44241" -or $_.eventid -eq "3610" } 

$SingleEvent = get-eventlog appassure -Newest 1 #| ?{$_.eventid -eq "1" -or $_.eventid -eq "17746" -or $_.eventid -eq "12940" -or $_.eventid -eq "16025" -or $_.eventid -eq "1508" -or $_.eventid -eq "20894" -or $_.eventid -eq "38840" -or $_.eventid -eq "56682" -or $_.eventid -eq "44241" -or $_.eventid -eq "3610" } 



#$Events.count

$ConcatEvtMessage = $Events.Message
$ConcatEvtIDS = $Events.eventID
$ConcatEvtIDSList = $ConcatEvtIDS|select-object -property   @{Name="array"; Expression = {$_}} | Format-Wide -AutoSize
#$ConcatEvtIDS 
#$ConcatEvtMessage 



if($ConcatEvtMessage.Length > 8000)
{
    $ConcatEvtMessage = left($ConcatEvtMessage,8000)
}
if($ConcatEvtIDS.Length > 8000)
{
    $ConcatEvtIDS = left($ConcatEvtIDS,8000)
}





# Declare a few variables that we'll use later on in the script
$Namespace = "NCentral"
$Class = "AppAssure4_Data"
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
$subClass.Properties.Add("NumberofEventsFoundMatch", [System.Management.CimType]::uint64, $false)
$subClass.Properties.Add("NumberofEventsFoundTotal", [System.Management.CimType]::uint64, $false)
$subClass.Properties.Add("MostRecentEventID", [System.Management.CimType]::uint32, $false)
$subClass.Properties.Add("MostRecentEventDesc", [System.Management.CimType]::string, $false)
$subClass.Properties.Add("EventIDList", [System.Management.CimType]::String, $false)
$subClass.Properties.Add("EventDescList", [System.Management.CimType]::String, $false)
$subClass.Properties.Add("Lastscriptexecutiontime", [System.Management.CimType]::String, $false)
$subClass.Properties["Lastscriptexecutiontime"].Qualifiers.Add("Key", $true)
$subClass.Put()


$scriptexecutiontime = Get-Date
WRITE-HOST "This script is being run at the following time: " $scriptexecutiontime
 
$PushDataToWMI = ([wmiclass]"root\cimv2\Ncentral:AppAssure4_Data").CreateInstance()
if(!$Events.count)
{
    $PushDataToWMI.NumberofEventsFoundMatch = 0
}
else
{
    $PushDataToWMI.NumberofEventsFoundMatch = $Events.count
}
if(!$EventsTotal.count)
{
    $PushDataToWMI.NumberofEventsFoundTotal = 0
}
else
{
    $PushDataToWMI.NumberofEventsFoundTotal = $EventsTotal.count
}
if(!$SingleEvent.EventID)
{
    $PushDataToWMI.MostRecentEventID = 0
}
else
{
    $PushDataToWMI.MostRecentEventID =$SingleEvent.EventID
}
if(!$SingleEvent.EventI.MESSAGE)
{
    $PushDataToWMI.MostRecentEventDesc = ""
}
else
{
    $PushDataToWMI.MostRecentEventDesc = $SingleEvent.EventI.MESSAGE
}
if(!$ConcatEvtIDS)
{
    $PushDataToWMI.EventIDList = ""
}
else
{
    $PushDataToWMI.EventIDList = $ConcatEvtIDS
}
if(!$ConcatEvtMessage)
{
    $PushDataToWMI.EventDescList= ""
}
else
{
    $PushDataToWMI.EventDescList= $ConcatEvtMessage
}
if(!$scriptexecutiontime)
{
    $PushDataToWMI.Lastscriptexecutiontime = ""
}
else
{
    $PushDataToWMI.Lastscriptexecutiontime = $scriptexecutiontime
}
    $PushDataToWMI.Put() 

