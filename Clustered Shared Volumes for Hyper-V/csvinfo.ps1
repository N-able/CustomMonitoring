# Tnx for ChrisReid for sharing the WMI in another script
# Script created by Wim Lamot from Accel Computer Service to use by N-Central users
# Idea was posted in Thread : https://nrc.n-able.com/community/Pages/forums.aspx?action=ViewPosts&fid=5&tid=1823
#
#
# Declare a few variables that we'll use later on in the script
$Namespace = "NCentral"
$Class = "CSVInfo"

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

# Check to see if the 'CSVDetails' class exists - if it doesn't, then let's create it
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
    $subClass.Properties.Add("FriendlyVolumeName", [System.Management.CimType]::String, $false)
    $subClass.Properties.Add("PartitionSize", [System.Management.CimType]::UInt64, $false)
	$subClass.Properties.Add("PartitionFreeSpace", [System.Management.CimType]::UInt64, $false)
    $subClass.Properties.Add("PartitionUsedSpace", [System.Management.CimType]::UInt64, $false)
    $subClass.Properties.Add("PartitionPercentFree", [System.Management.CimType]::UInt64, $false)
    $subClass.Properties.Add("DateLastCheck", [System.Management.CimType]::String, $false)
    $subClass.Put()

# We now did set the NameSpace-Class and if there was data in it cleared it out
# Now we can proceed with the actual data collection
# Parts used from http://blogs.msdn.com/b/clustering/archive/2010/06/19/10027366.aspx
Import-Module FailoverClusters
$objs = @()
$csvs = Get-ClusterSharedVolume
foreach ( $csv in $csvs )
{
   $csvinfos = $csv | select -Property Name -ExpandProperty SharedVolumeInfo
   foreach ( $csvinfo in $csvinfos )
   {
      $obj = New-Object PSObject -Property @{
         Name        = $csv.Name
         Path        = $csvinfo.FriendlyVolumeName
         Size        = $csvinfo.Partition.Size
         FreeSpace   = $csvinfo.Partition.FreeSpace
         UsedSpace   = $csvinfo.Partition.UsedSpace
         PercentFree = $csvinfo.Partition.PercentFree
      }
      $objs += $obj
	  
	  $PushDataToWMI = ([wmiclass]"root\cimv2\Ncentral:CSVInfo").CreateInstance()
	  $PushDataToWMI.Name =  $csv.Name
	  $PushDataToWMI.FriendlyVolumeName = $csvinfo.FriendlyVolumeName
	  $PushDataToWMI.PartitionSize = $csvinfo.Partition.Size/1024/1024/1024
	  $PushDataToWMI.PartitionFreeSpace = $csvinfo.Partition.FreeSpace/1024/1024/1024
	  $PushDataToWMI.PartitionUsedSpace = $csvinfo.Partition.UsedSpace/1024/1024/1024
	  $PushDataToWMI.PartitionPercentFree = $csvinfo.Partition.PercentFree
	  $PushDataToWMI.DateLastCheck = Get-Date -format "yyyy-MMM-dd HH:mm"
	  $PushDataToWMI.Put()
     }
}