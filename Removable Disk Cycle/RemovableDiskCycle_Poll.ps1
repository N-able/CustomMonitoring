#
# Generic Removable Media Cycle polling script.
# To be used in conjunction with the custom service.
# Author: James Weakley (jweakley@diamondgroup.net.au)
#

function main()
{
	$eqline   = " ================================================= "
	$dashline = " _________________________________________________ "
	$ErrorActionPreference = "Stop"
	$namespaceName = "NCentral"
	$wmiClassNameCycle = "RemovableMediaCycle";
	$wmiClassNameEachInstance = "RemovableMediaInstanceInfo";
	$wmiNameSpacePath = "root\cimv2\$namespaceName";
	
	CreateOrUpdateNamespace
	CreateOrUpdateWMIClasses
	
	#calculation for timestamp
	$timenow = Get-WmiObject win32_utctime
	$timenowDmtf = (Get-WMIObject Win32_OperatingSystem).LocalDateTime
	$timestamp = (((((($timenow.Year - 1970.0) * 31556926 ) + (($timenow.Month - 1.0) * 2678400)) + (($timenow.Day - 1.0) * 86400)) + ($timenow.Hour * 3600)) + ($timenow.Minute * 60)) + ($timenow.Second)
	$timenow = get-date
	$timenowString = $timenow.ToString()
	$gracePeriodFinish = $timenow.AddDays($newMediaGracePeriodDays*-1)
	$gracePeriodFinishDmtf = [System.Management.ManagementDateTimeConverter]::ToDmtfDateTime($gracePeriodFinish)
	
	$logicaldisks = Get-WmiObject -Namespace "root\cimv2" -Class "Win32_LogicalDisk"
	
	$logicaldisks | % {
		$logicalDisk = $_
		$logicalDiskDeviceID=$logicalDisk.DeviceID
		Write-Host "Found LogicalDisk $logicalDiskDeviceID with VolumeSerialNumber $volumeSerialNumber"
		try{
			$partition = Get-WmiObject -namespace "root\cimv2" -Query "ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='$logicalDiskDeviceID'} WHERE AssocClass=Win32_LogicalDiskToPartition"
		}
		catch{
			Write-Host "Unable to query for partitions for this device, skipping"
			return;
		}
		$partitionDeviceID=$partition.DeviceID
		Write-Host "Found Partition $partitionDeviceID"
		try{
			$diskDrive = Get-WmiObject -namespace "root\cimv2" -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$partitionDeviceID'} WHERE AssocClass=Win32_DiskDriveToDiskPartition"
		}
		catch{
			Write-Host "Unable to query for disks for this partition, skipping"
			return;
		}
		$diskDriveDeviceID= $diskDrive.DeviceID
		$pnpDeviceID=$diskDrive.PNPDeviceID
		Write-Host "Found Physical disk $diskDriveDeviceID with PNPDeviceID $pnpDeviceID"
		if ($diskDrive.InterfaceType -ne "USB"){
			Write-Host "InterfaceType is '$($diskDrive.InterfaceType)' not 'USB', skipping"
			return;
		}
		write-host "Checking UserRemovalPolicy of device $pnpDeviceID"
		$quickRemovalPolicy = $false;
		$classPNPKeyExists = test-path "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpDeviceID\Device Parameters\ClassPNP"
		if ($classPNPKeyExists -eq $false){
			Write-Host "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpDeviceID\Device Parameters\ClassPNP path not found, assuming default setting of Quick Removal"
			$quickRemovalPolicy = $true;
		}
		else
		{
		
			$userRemovalPolicy = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpDeviceID\Device Parameters\ClassPNP").UserRemovalPolicy
			if ($userRemovalPolicy -eq 3){
				$quickRemovalPolicy = $true;
				write-host "UserRemovalPolicy = 3, this means Quick Removal policy set"
			}
			else
			{
				write-host "UserRemovalPolicy != 3, Quick Removal policy is not set"
				$quickRemovalPolicy = $false;
			}
		}
		
		if ($quickRemovalPolicy)
		{
            $diskSerialNumber=$diskDrive.SerialNumber
            if ($diskSerialNumber -eq $null -or $diskSerialNumber.Length -lt 2)
            {
                $diskSerialNumber="NoDiskSerialNumber"
            }
			$volumeSerialNumberAndDiskSerialNumber = "$($logicalDisk.VolumeSerialNumber)_$diskSerialNumber"
            [regex]$r="[^\w\.]"
            $volumeSerialNumberAndDiskSerialNumber = $r.Replace($volumeSerialNumberAndDiskSerialNumber,"")

			write-host "UserRemovalPolicy = 3, retrieving drive information for serial number $volumeSerialNumberAndDiskSerialNumber"
			$wmiFilter = "VolumeSerialNumber='$volumeSerialNumberAndDiskSerialNumber'"
			$wmiFilter = $wmiFilter.replace("\","\\")
			$existingEntry = Get-WmiObject -Namespace $wmiNameSpacePath -Class $wmiClassNameEachInstance -Filter $wmiFilter
			
			$wmiObject = @{}
			$wmiObject.DriveLetter=$logicalDiskDeviceID
			$wmiObject.VolumeLabel=$logicalDisk.VolumeName
			$wmiObject.PhysicalDiskCaption=$diskDrive.Caption
			$wmiObject.PhysicalDiskModel=$diskDrive.Model
			$wmiObject.VolumeSize=$logicalDisk.Size
			$wmiObject.PNPDeviceID=$pnpDeviceID
			$wmiObject.LastTimeSeen=$timenowDmtf
			$wmiObject.LastTimeSeenString=$timenowString
			
			if ($existingEntry -eq $null)
			{
				$wmiObject.VolumeSerialNumber=$volumeSerialNumberAndDiskSerialNumber
				$wmiObject.LastTimeNotSeen=$timenowDmtf
				$wmiObject.LastTimeNotSeenString=$timenowString
				$wmiObject.FirstTimeSeen=$timenowDmtf
				$wmiObject.FirstTimeSeenString=$timenowString
				Write-Host "No existing $wmiClassNameEachInstance instance found in $wmiNameSpacePath for this serial number"
				Set-WmiInstance -Namespace $wmiNameSpacePath -Class $wmiClassNameEachInstance -Arguments $wmiObject
			}
			else
			{
				Write-Host "Existing $wmiClassNameEachInstance instance found in $wmiNameSpacePath for this serial number"
				$existingEntry | Set-WmiInstance -Arguments $wmiObject
			}
		}
		else
		{
			write-host "UserRemovalPolicy is $userRemovalPolicy, skipping"
		}
		Write-Host "$dashline"
	}
	
	# Now get a list of all known disks and filter out the ones we just saw. Update the 'LastTimeNotSeen' to the current time
	Write-Host "Getting a list of all known volumes not seen just now"
	Get-WmiObject -Namespace $wmiNameSpacePath -Class $wmiClassNameEachInstance | Where-Object {$_.LastTimeSeen -ne $timenowDmtf} | % {
		$lastTimeNotSeen = [System.Management.ManagementDateTimeConverter]::ToDateTime($_.LastTimeNotSeen)
		Write-Host "Updating missing volume $($_.DriveLetter) ($($_.VolumeLabel))"
		$_.LastTimeNotSeen=$timenowDmtf
		$_.LastTimeNotSeenString=$timenowString
		$_ | Set-WmiInstance
	}
	$allDiskDetails = "";
	# Now update the MinsSinceLastNotSeen of all known volumes. For volumes not currently present, this will snap back to 0. For others it will increase
	Get-WmiObject -Namespace $wmiNameSpacePath -Class $wmiClassNameEachInstance | % {
		
		$lastTimeNotSeen = [System.Management.ManagementDateTimeConverter]::ToDateTime($_.LastTimeNotSeen)
		$timeSinceLastNotSeen = $timenow - $lastTimeNotSeen 
		$minsSinceLastNotSeen = [UInt32] $timeSinceLastNotSeen.TotalMinutes
		$_.MinsSinceLastNotSeen=$minsSinceLastNotSeen
		$_ | Set-WmiInstance
		$allDiskDetails += "$eqline Volume Serial Number: $($_.VolumeSerialNumber) $dashline Drive and Label: $($_.DriveLetter) ($($_.VolumeLabel)) $dashline Physical Disk Model: $($_.PhysicalDiskModel) $dashline First Seen: $($_.FirstTimeSeenString) $dashline Last Seen: $($_.LastTimeSeenString) $dashline Last Not Seen: $($_.LastTimeNotSeenString) "
	}
	$allDiskDetails += $eqline;
	
	$existingEntry = Get-WmiObject -Namespace $wmiNameSpacePath -Class $wmiClassNameCycle
	$wmiObject = @{}
	$wmiObject.Timestamp=$timestamp
	$lastScriptRunTime = $timenow.ToString()
	$wmiObject.LastScriptRunTime=$lastScriptRunTime
			
	# Now get all known disks, and find the one with the largest MinsSinceLastNotSeen
	$longestConnectedDisk = Get-WmiObject -Namespace $wmiNameSpacePath -Class $wmiClassNameEachInstance | sort-object -Descending -Property MinsSinceLastNotSeen | Select-Object -First 1
	if ($longestConnectedDisk -eq $null)
	{
		Write-Host "No instances of $wmiClassNameEachInstance found, populating a $wmiClassNameCycle instance with 'No disks found' info"
		$wmiObject.TimeOfOldestDiskRemoval="N/A"
		$wmiObject.MinsSinceOldestDiskRemoval=0
		$wmiObject.OffendingDiskDetails="N/A"
		$wmiObject.AllDiskDetails="No USB disks with Quick Removal policy set were found on this system"
	}
	else
	{
		$longestConnectedDisk | % {
			$timeOfOldestDiskRemoval = [System.Management.ManagementDateTimeConverter]::ToDateTime($_.LastTimeNotSeen).ToString();
			$minsSinceOldestDiskRemoval = $_.MinsSinceLastNotSeen;
			$offendingDiskDetails = "$eqline Volume Serial Number: $($_.VolumeSerialNumber) $dashline Drive and Label: $($_.DriveLetter) ($($_.VolumeLabel)) $dashline Physical Disk Model: $($_.PhysicalDiskModel) $dashline First Seen: $($_.FirstTimeSeenString) $dashline Last Seen: $($_.LastTimeSeenString) $dashline Last Not Seen: $($_.LastTimeNotSeenString) $eqline"
			$wmiObject.TimeOfOldestDiskRemoval=$timeOfOldestDiskRemoval
			$wmiObject.MinsSinceOldestDiskRemoval=$minsSinceOldestDiskRemoval
			$wmiObject.OffendingDiskDetails=$offendingDiskDetails
			$wmiObject.AllDiskDetails=$allDiskDetails
			
			
		}
	}
	
	if ($existingEntry -eq $null)
	{
		$wmiObject.ID=1
		Write-Host "No existing $wmiClassNameCycle instance found in $wmiClassNameCycle"
		Set-WmiInstance -Namespace $wmiNameSpacePath -Class $wmiClassNameCycle -Arguments $wmiObject
	}
	else
	{
		Write-Host "Existing $wmiClassNameCycle instance found in $wmiClassNameCycle"
		$existingEntry | Set-WmiInstance -Arguments $wmiObject
	}
	
	Write-Host "Script run complete"
}

function CreateOrUpdateNamespace
{
	Write-Host "Creating $namespaceName WMI namespace"
	#Creates Namespace if doesn't exist, if exists will just overwrite
	$Namespace=[wmiclass]'__namespace'
	$newNamespace=$Namespace.CreateInstance()
	$newNamespace.Name=$namespaceName
	$newNamespace.Put()

}
function CreateOrUpdateWMIClasses
{
	Write-Host "Testing for presence of $wmiClassNameCycle class"
	
	#Check whether WMI class already exists, if not then create a new instance and configure
	try
	{
	    $class = New-Object System.Management.ManagementClass ($wmiNameSpacePath, $wmiClassNameCycle, $null);
	    $class
	    Write-Host "$wmiClassNameCycle class already exists"
	}
	catch [System.Management.Automation.ExtendedTypeSystemException]
	{
	    Write-Host "$wmiClassName class does not exist, creating"
	    $class = New-Object System.Management.ManagementClass ($wmiNameSpacePath, [String]::Empty, $null);
	    $class["__CLASS"] = $wmiClassNameCycle; 
	    $class.Qualifiers.Add("Static", $true);
	    $class.Put();
	}

	Write-Host "Adding any missing properties to $wmiClassNameCycle class"
	if ($class["ID"] -eq $null)
	{
	    $class.Properties.Add("ID", [System.Management.CimType]::UInt32, $false)
	    $class.Properties["ID"].Qualifiers.Add("Key", $true);
	}
	if ($class["TimeOfOldestDiskRemoval"] -eq $null){$class.Properties.Add("TimeOfOldestDiskRemoval", [System.Management.CimType]::String, $false);}
	if ($class["MinsSinceOldestDiskRemoval"] -eq $null){$class.Properties.Add("MinsSinceOldestDiskRemoval", [System.Management.CimType]::uint64, $false);}
	if ($class["OffendingDiskDetails"] -eq $null){$class.Properties.Add("OffendingDiskDetails", [System.Management.CimType]::String, $false);}
	if ($class["AllDiskDetails"] -eq $null){$class.Properties.Add("AllDiskDetails", [System.Management.CimType]::String, $false);}
	if ($class["LastScriptRunTime"] -eq $null){$class.Properties.Add("LastScriptRunTime", [System.Management.CimType]::String, $false);}
	if ($class["Timestamp"] -eq $null){$class.Properties.Add("Timestamp", [System.Management.CimType]::uint64, $false);}

	try
	{
	    $class.Put();
	    Write-Host "Class changes saved"
	}
	catch [System.Management.Automation.MethodInvocationException]
	{
	    Write-Host "Class has changed but instances exist, deleting all instances of $wmiClassName"
	    Remove-WmiObject -class $wmiClassNameCycle -Namespace $wmiNameSpacePath;
	    $class.Put();
	}
	
	Write-Host "Testing for presence of $wmiClassNameEachInstance class"
	#Check whether WMI class already exists, if not then create a new instance and configure
	try
	{
	    $class = New-Object System.Management.ManagementClass ($wmiNameSpacePath, $wmiClassNameEachInstance, $null);
	    $class
	    Write-Host "$wmiClassNameEachInstance class already exists"
	}
	catch [System.Management.Automation.ExtendedTypeSystemException]
	{
	    Write-Host "$wmiClassNameEachInstance class does not exist, creating"
	    $class = New-Object System.Management.ManagementClass ($wmiNameSpacePath, [String]::Empty, $null);
	    $class["__CLASS"] = $wmiClassNameEachInstance; 
	    $class.Qualifiers.Add("Static", $true);
	    $class.Put();
	}

	Write-Host "Adding any missing properties to $wmiClassNameEachInstance class"

	if ($class["VolumeSerialNumber"] -eq $null)
	{
	    $class.Properties.Add("VolumeSerialNumber", [System.Management.CimType]::String, $false)
	    $class.Properties["VolumeSerialNumber"].Qualifiers.Add("Key", $true);
	}
	if ($class["DriveLetter"] -eq $null){$class.Properties.Add("DriveLetter", [System.Management.CimType]::String, $false);}
	if ($class["VolumeLabel"] -eq $null){$class.Properties.Add("VolumeLabel", [System.Management.CimType]::String, $false);}
	if ($class["PhysicalDiskCaption"] -eq $null){$class.Properties.Add("PhysicalDiskCaption", [System.Management.CimType]::String, $false);}
	if ($class["PhysicalDiskModel"] -eq $null){$class.Properties.Add("PhysicalDiskModel", [System.Management.CimType]::String, $false);}
	if ($class["PNPDeviceID"] -eq $null){$class.Properties.Add("PNPDeviceID", [System.Management.CimType]::String, $false);}
	if ($class["FirstTimeSeen"] -eq $null){$class.Properties.Add("FirstTimeSeen", [System.Management.CimType]::DateTime, $null);}
	if ($class["FirstTimeSeenString"] -eq $null){$class.Properties.Add("FirstTimeSeenString", [System.Management.CimType]::String, $null);}
	if ($class["LastTimeSeen"] -eq $null){$class.Properties.Add("LastTimeSeen", [System.Management.CimType]::DateTime, $null);}
	if ($class["LastTimeSeenString"] -eq $null){$class.Properties.Add("LastTimeSeenString", [System.Management.CimType]::String, $null);}
	if ($class["LastTimeNotSeen"] -eq $null){$class.Properties.Add("LastTimeNotSeen", [System.Management.CimType]::DateTime, $null);}
	if ($class["LastTimeNotSeenString"] -eq $null){$class.Properties.Add("LastTimeNotSeenString", [System.Management.CimType]::String, $null);}
	if ($class["MinsSinceLastNotSeen"] -eq $null){$class.Properties.Add("MinsSinceLastNotSeen", [System.Management.CimType]::uint64, $false);}
	if ($class["VolumeSize"] -eq $null){$class.Properties.Add("VolumeSize", [System.Management.CimType]::uint64, $false);}
	
	try
	{
	    $class.Put();
	    Write-Host "Class changes saved"
	}
	catch [System.Management.Automation.MethodInvocationException]
	{
	    Write-Host "Class has changed but instances exist, deleting all instances of $wmiClassName"
	    Remove-WmiObject -class $wmiClassNameEachInstance -Namespace $wmiNameSpacePath;
	    $class.Put();
	}
}
main