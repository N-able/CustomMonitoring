#
# StorageCraft ImageManager polling script
# Author: James Weakley (jweakley@diamondgroup.net.au)
# This script:
# 1) Creates the root\cimv2\NCentral namespace if missing
# 2) Creates/updates the ImageManager WMI class as needed
# 3) Locates and opens the ImageManager.mdb database file and iterates all watched folders, creates a WMI object using the path as the identifier
#
$global:scriptname = $myinvocation.Mycommand.path
function main()
{
	if ($env:Processor_Architecture -ne "x86")   
	{
        write-host '64 bit environment detected, launching x86 PowerShell'
		&"$env:windir\syswow64\windowspowershell\v1.0\powershell.exe" -noninteractive -noprofile -executionpolicy bypass -file "$global:scriptname"
		exit
	}
    
	write-host "Architecture: $($env:Processor_Architecture). Always running in 32bit PowerShell at this point."
	
	
	$eqline   = "================================================="
	$dashline = "_________________________________________________"
	$ErrorActionPreference = "Stop"
	$ServiceName = "StorageCraft ImageManager"
	$namespaceName = "NCentral"
	$wmiClassName = "ImageManager";
	$wmiNameSpacePath = "root\cimv2\$namespaceName";
	
	CreateOrUpdateWMIClass
	
	#calculation for timestamp
	$timenow = Get-WmiObject win32_utctime
	$timestamp = (((((($timenow.Year - 1970.0) * 31556926 ) + (($timenow.Month - 1.0) * 2678400)) + (($timenow.Day - 1.0) * 86400)) + ($timenow.Hour * 3600)) + ($timenow.Minute * 60)) + ($timenow.Second)
	$timenow = get-date
	

	$serviceObj = gwmi win32_service|?{$_.name -eq "$ServiceName"}
	if ($serviceObj -eq $null)
	{
	    throw "'$ServiceName' Windows service not found"
	}
	$serviceExePath = $serviceObj.PathName
	$mdblocation = $serviceExePath.Replace(".exe",".mdb")
	$adOpenStatic = 3
	$adLockOptimistic = 3
	
	$replicationTypeMappings = @{"loc" = "Local Folder"; "ftp" = "FTP"; "lan" = "Network Share"; "hsr" = "Headstart Restore"; "sst" = "ShadowStream"; "cloud" = "StorageCraft Cloud"}
	
	# define connection object to access DB, to be used for all queries
	$objConnection = New-Object -comobject ADODB.Connection
	# define record sets used to iterate table data
	$objRecordsetWatchPaths = New-Object -comobject ADODB.Recordset
	$objRecordsetFilesAndSets = New-Object -comobject ADODB.Recordset
	$objRecordsetAllTables = New-Object -comobject ADODB.Recordset
	$objRecordsetSentFiles = New-Object -comobject ADODB.Recordset
	
    # attempting open of database using Jet OLEDB. This should be installed along with ImageManager, but will only work in a 32 bit powershell environment
    $objConnection.Open("Provider=Microsoft.Jet.OLEDB.4.0;Data Source=$mdblocation;Jet OLEDB:Database")

	# The ImageManager database is hideous, and favours dynamically named tables rather than proper entity relationships
	# The tables used to store replication information don't seem to even be knowable, rather trial and error is required to determine 
	# whether the table name starts with ftp, lan, or loc for the different replication types

	# Create a Hash Table to store the list of TargetPaths from the database
	# This will end up looking like @{"1" = "\\remoteserver\shadowprotect"; "2" = "\\localserver\shadowprotect"}
	$targetPathsMap = @{}
	GetAllTargetPaths
	
	# Create a HashTable to store a mapping of TargetPath Indexes to their type
	# This will end up looking like @{"1" = "loc"; "2" = "loc"; 3 = "ftp"}
	$targetPathsMapTypesMap = @{}	

	# Create a HashTable to store a more accessible version of the status of each replication target
	# We are basically searching for all Queue and Sent tables and constructing our own representation 
	# in memory that we can query more easily later
	# This will end up looking like:
	# @{"1" = @{"ReplicationType" = "loc" ; "QueuedFileCount" = 1 ; "QueuedFileSizeBytes" = 2310 ; "SentFileCount" = 51 ; "SentFileSizeBytes" = 987231 };
	#	"2" = @{"ReplicationType" = "ftp" ; "QueuedFileCount" = 4 ; "QueuedFileSizeBytes" = 5123 ; "SentFileCount" = 30 ; "SentFileSizeBytes" = 897123 }}
	$replicationTargetStats = @{}
	
	# Create a HashTable to store a mapping of Backup Set guids to replication targets
	# This will end up looking like:
	# @{"{694A6C72-21D0-4A98-B7B8-79F553E460CC}" = "1" ; "{694A6C72-21D0-4A98-B7B8-79F553E460CC}" = "1"}
	$backupSetReplicationTargetMap = @{} 
	BuildReplicationTargetObjects	

	# Create an array to store all of the Watch Paths (Managed Folders) before storing in WMI
	# This will end up looking like an array of exactly what's stored in WMI
	$global:watchPaths = @()
	GetAllWatchPaths
	write-host "Finished compiling list of Watch Paths"
	
	#get a list of the names of all Watch Paths, separated by comma. This is stored in all of the class instances, and can be used by the "StorageCraft ImageManager Managed Folders List" N-Central service
	$allWatchedPathNames="";
	$global:watchPaths | % {
		$allWatchedPathNames=$allWatchedPathNames+$eqline+" "+$_.ManagedFolder+" "
	}
	
	Write-Host "Writing all Watch Paths to WMI"
	$global:watchPaths | % {
		write-host "Checking for existing WMI objects Managed Folder '$($_.ManagedFolder)'"

	    $wmiFilter = "ManagedFolder='$($_.ManagedFolder)'"
	    $wmiFilter = $wmiFilter.replace("\","\\")
	    $currentValue = Get-WmiObject -Namespace $wmiNameSpacePath -Class $wmiClassName -Filter $wmiFilter

	    write-host "Writing to WMI"
	    if ($currentValue -eq $null)
	    {
	        Write-Host "Creating new instance of $wmiClassName class for this job ($($_.ManagedFolder))"
	        Set-WmiInstance -Namespace $wmiNameSpacePath -Class $wmiClassName -Arguments @{ManagedFolder = $_.ManagedFolder;MachineName=$_.MachineName;NumberOfSets=$_.NumberOfSets;NumberOfFilesFailingVerification=$_.NumberOfFilesFailingVerification;NumberOfFilesQueuedForReplication=$_.NumberOfFilesQueuedForReplication;AgeOfOldestQueuedFileMins=$_.AgeOfOldestQueuedFileMins;SetDetails=$_.SetDetails;ReplicationTargetDetails=$_.ReplicationTargetDetails;LastScriptRunTime=$_.LastScriptRunTime;Timestamp=$_.Timestamp;ListOfAllManagedFolders=$allWatchedPathNames}
	    }
	    else
	    {
	        Write-Host "Updating existing instance of $wmiClassName class for this job ($($_.ManagedFolder))"
	        $currentValue | Set-WmiInstance -Arguments @{ManagedFolder = $_.ManagedFolder;MachineName=$_.MachineName;NumberOfSets=$_.NumberOfSets;NumberOfFilesFailingVerification=$_.NumberOfFilesFailingVerification;NumberOfFilesQueuedForReplication=$_.NumberOfFilesQueuedForReplication;AgeOfOldestQueuedFileMins=$_.AgeOfOldestQueuedFileMins;SetDetails=$_.SetDetails;ReplicationTargetDetails=$_.ReplicationTargetDetails;LastScriptRunTime=$_.LastScriptRunTime;Timestamp=$_.Timestamp;ListOfAllManagedFolders=$allWatchedPathNames}
	    }
	}
	Write-Host "Script run complete"
}

function CreateOrUpdateWMIClass
{
	Write-Host "Creating $namespaceName WMI namespace"
	#Creates Namespace if doesn't exist, if exists will just overwrite
	$Namespace=[wmiclass]'__namespace'
	$newNamespace=$Namespace.CreateInstance()
	$newNamespace.Name=$namespaceName
	$newNamespace.Put()


	Write-Host "Testing for presence of $wmiClassName class"

	#Check whether WMI class already exists, if not then create a new instance and configure
	try
	{
	    $class = New-Object System.Management.ManagementClass ($wmiNameSpacePath, $wmiClassName, $null);
	    $class
	    Write-Host "$wmiClassName class already exists"
	}
	catch [System.Management.Automation.ExtendedTypeSystemException]
	{
	    Write-Host "$wmiClassName class does not exist, creating"
	    $class = New-Object System.Management.ManagementClass ($wmiNameSpacePath, [String]::Empty, $null);
	    $class["__CLASS"] = $wmiClassName; 
	    $class.Qualifiers.Add("Static", $true);
	    $class.Put();
	}

	Write-Host "Adding any missing properties to $wmiClassName class"

	if ($class["ManagedFolder"] -eq $null)
	{
	    $class.Properties.Add("ManagedFolder", [System.Management.CimType]::String, $false)
	    $class.Properties["ManagedFolder"].Qualifiers.Add("Key", $true);
	}
	if ($class["MachineName"] -eq $null){$class.Properties.Add("MachineName", [System.Management.CimType]::String, $false);}
	if ($class["NumberOfSets"] -eq $null){$class.Properties.Add("NumberOfSets", [System.Management.CimType]::uint32, $false);}
	if ($class["SetDetails"] -eq $null){$class.Properties.Add("SetDetails", [System.Management.CimType]::String, $false);}
	if ($class["NumberOfFilesFailingVerification"] -eq $null){$class.Properties.Add("NumberOfFilesFailingVerification", [System.Management.CimType]::uint32, $false);}
	if ($class["ReplicationTargetDetails"] -eq $null){$class.Properties.Add("ReplicationTargetDetails", [System.Management.CimType]::String, $false);}
	if ($class["NumberOfFilesQueuedForReplication"] -eq $null){$class.Properties.Add("NumberOfFilesQueuedForReplication", [System.Management.CimType]::uint32, $false);}
	if ($class["AgeOfOldestQueuedFileMins"] -eq $null){$class.Properties.Add("AgeOfOldestQueuedFileMins", [System.Management.CimType]::uint64, $false);}
	if ($class["LastScriptRunTime"] -eq $null){$class.Properties.Add("LastScriptRunTime", [System.Management.CimType]::String, $false);}
	if ($class["Timestamp"] -eq $null){$class.Properties.Add("Timestamp", [System.Management.CimType]::uint64, $false);}
	if ($class["ListOfAllManagedFolders"] -eq $null){$class.Properties.Add("ListOfAllManagedFolders", [System.Management.CimType]::String, $false);}
	try
	{
	    $class.Put();
	    Write-Host "Class changes saved"
	}
	catch [System.Management.Automation.MethodInvocationException]
	{
	    Write-Host "Class has changed but instances exist, deleting all instances of $wmiClassName"
	    Remove-WmiObject -class $wmiClassName -Namespace $wmiNameSpacePath;
	    $class.Put();
	}
}
function GetAllTargetPaths
{
	$objRecordsetTargetPaths = New-Object -comobject ADODB.Recordset
	$objRecordsetTargetPaths.Open("SELECT * FROM TargetPaths", $objConnection,$adOpenStatic,$adLockOptimistic)
	if ($objRecordsetTargetPaths.RecordCount -gt 0)
	{
		$objRecordsetTargetPaths.MoveFirst()
		while ($objRecordsetTargetPaths.EOF -eq $False)
		{
		    $index = $objRecordsetTargetPaths.Fields.Item("Index").Value
		    $path = $objRecordsetTargetPaths.Fields.Item("Path").Value
		    write-host "Adding Replication target $index : $path"
		    $targetPathsMap.Set_Item($index,$path)
		    $objRecordsetTargetPaths.MoveNext()
		}
	}
	$objRecordsetTargetPaths.Close()
}

function BuildReplicationTargetObjects
{
	$objRecordsetQueueTables = New-Object -comobject ADODB.Recordset
	# get a list of all queue and sent tables in the database
	$objRecordsetAllTables.Open("SELECT * FROM MSysObjects WHERE Type=1 AND Flags=0 AND (Name LIKE '%Queue' OR Name LIKE '%Sent')", $objConnection,$adOpenStatic,$adLockOptimistic)
	if ($objRecordsetAllTables.RecordCount -gt 0)
	{
		$objRecordsetAllTables.MoveFirst()
		while ($objRecordsetAllTables.EOF -eq $False)
		{
		    $tableName = $objRecordsetAllTables.Fields.Item("Name").Value;
			# check whether the table starts with 'ftp', 'loc', or 'lan', etc
			$replicationTypeMappings.get_Keys() | % {
				if ($tableName.StartsWith($_)){
			        $targetPathId = [int] $tableName.Replace($_,"").Replace("Queue","").Replace("Sent","")
			        $replicationType = $replicationTypeMappings.get_Item($_);
			        $targetPathsMapTypesMap.Set_Item($targetPathId,$replicationType)

			        $replicationTargetStat = $replicationTargetStats.Get_Item($targetPathId)
			        if ($replicationTargetStat -eq  $null)
			        {
			            $replicationTargetStat = @{}
			            $replicationTargetStat.ReplicationType = $replicationType
			            $replicationTargetStat.QueuedFileCount = 0;
			            $replicationTargetStat.QueuedFileSizeBytes = 0;
			            $replicationTargetStat.SentFileCount = 0;
			            $replicationTargetStat.SentFileSizeBytes = 0;

			        }

			        if ($tableName.EndsWith("Queue"))
			        {
			            write-host "Queue table found: '$tableName', replication type is '$replicationType'"

			            # for queue tables, we want the full lists
			            # query the table and add its rows the the appropriate in-memory array
			            $objRecordsetQueueTables.Open("SELECT SetGuid, COUNT(*) AS FileCount, SUM(FileSize) AS QueuedFileSizeBytes, MIN(CreateTime) AS OldestQueuedFileDate FROM $tableName GROUP BY SetGuid", $objConnection,$adOpenStatic,$adLockOptimistic)
			            while ($objRecordsetQueueTables.EOF -eq $False)
			            {
			                $setGuid = $objRecordsetQueueTables.Fields.Item("SetGuid").Value;
			                $targetsForSet = @()
			                $targetsForSet += $targetPathId;
			                $targetsForSet += $backupSetReplicationTargetMap.Get_Item($setGuid);
			                $backupSetReplicationTargetMap.Set_Item($setGuid,$targetsForSet);

			                $oldestQueuedFileDate = ($objRecordsetQueueTables.Fields.Item("OldestQueuedFileDate").Value).AddMinutes([System.TimeZoneInfo]::Local.BaseUtcOffset.TotalMinutes);

			                if ($replicationTargetStat.OldestQueuedFileDate -eq $null -or $replicationTargetStat.OldestQueuedFileDate -gt $oldestQueuedFileDate)
			                {
			                    $replicationTargetStat.OldestQueuedFileDate = $oldestQueuedFileDate;
			                }
			                $replicationTargetStat.QueuedFileCount += [int] $objRecordsetQueueTables.Fields.Item("FileCount").Value;
			                $replicationTargetStat.QueuedFileSizeBytes += [long] $objRecordsetQueueTables.Fields.Item("QueuedFileSizeBytes").Value;
			                
			                $objRecordsetQueueTables.MoveNext();

			            }
			            $objRecordsetQueueTables.Close()
			        }
			        elseif ($tableName.EndsWith("Sent"))
			        {
			            write-host "Sent files table found: '$tableName', replication type is '$replicationType'"
			            # for sent files, we just want summary data rather than the full lists
			            $objRecordsetQueueTables.Open("SELECT SetGuid, COUNT(*) AS FileCount, SUM(BytesSent) AS TotalBytesSent FROM $tableName WHERE BytesSent > 0 GROUP BY SetGuid", $objConnection,$adOpenStatic,$adLockOptimistic)
			            while ($objRecordsetQueueTables.EOF -eq $False)
			            {
			                $setGuid = $objRecordsetQueueTables.Fields.Item("SetGuid").Value;
			                $targetsForSet = @()
			                $targetsForSet += $targetPathId;
			                $targetsForSet += $backupSetReplicationTargetMap.Get_Item($setGuid);
			                $backupSetReplicationTargetMap.Set_Item($setGuid,$targetsForSet);

			                $replicationTargetStat.SentFileCount += [int] $objRecordsetQueueTables.Fields.Item("FileCount").Value;
			                $replicationTargetStat.SentFileSizeBytes += [long] $objRecordsetQueueTables.Fields.Item("TotalBytesSent").Value;
			                
			                $objRecordsetQueueTables.MoveNext();

			            }
			            $objRecordsetQueueTables.Close()
			        }
			        $replicationTargetStats.Set_Item($targetPathId,$replicationTargetStat)
				}
			}
		    
		        
		    $objRecordsetAllTables.MoveNext()
		}
	}
	$objRecordsetAllTables.Close()
}
function GetAllWatchPaths
{
	$objRecordsetWatchPaths.Open("SELECT * FROM WatchPaths", $objConnection,$adOpenStatic,$adLockOptimistic)
	if ($objRecordsetWatchPaths.RecordCount -gt 0)
	{
		while ($objRecordsetWatchPaths.EOF -eq $False)
		{
			$watchedPath = $objRecordsetWatchPaths.Fields.Item("Path").Value; 
		    $index = $objRecordsetWatchPaths.Fields.Item("Index").Value; 
		    $machineName = "unknown"
		    $setCount = 0;
		    write-host "Found Watched Folder - Path: $watchedPath, Index: $index"
		    write-host "-------------------------------------------------"

		    #retrieve list of backup sets for watched folder
		    $setTableName = "w$($index)Sets";

		    # watched folders which have since stopped being watched, will still exist in this table but will not have a set table
		    $objRecordsetAllTables.Open("SELECT COUNT(*) AS SetTableCount FROM MSysObjects WHERE Type=1 AND Flags=0 AND Name = '$setTableName'", $objConnection,$adOpenStatic,$adLockOptimistic)
		    $objRecordsetAllTables.MoveFirst()
		    $tableCount = [int]$objRecordsetAllTables.Fields.Item("SetTableCount").Value
		    $objRecordsetAllTables.Close()
		    if ($tableCount -eq 0)
		    {
		        $objRecordsetWatchPaths.MoveNext()
		        continue;
		    }
		    
		    $objRecordsetFilesAndSets.Open("SELECT * FROM $setTableName ", $objConnection,$adOpenStatic,$adLockOptimistic)
		    
		    $setsText = ""
		    $setsReplicationTargetsText = "";

		    $totalFilesSentToTarget = 0;
		    $totalBytesSentToTarget = 0;
		    $queuedFilesRelatingToWatchedFolder = 0;
		    $replicationType="Unknown"

		    $replicationTargetPathIds = @()

		    #iterate through the sets
		    while ($objRecordsetFilesAndSets.EOF -eq $False)
		    {
		        $setId = $objRecordsetFilesAndSets.Fields.Item("Id").Value
		        $machineName = $objRecordsetFilesAndSets.Fields.Item("Machine").Value
		        $baseName = $objRecordsetFilesAndSets.Fields.Item("BaseName").Value
		        $setGuid = $objRecordsetFilesAndSets.Fields.Item("SetGuid").Value
		        $imageCount = $objRecordsetFilesAndSets.Fields.Item("Images").Value
		        $latestCreateTime = ($objRecordsetFilesAndSets.Fields.Item("LatestCreateTime").Value).AddMinutes([System.TimeZoneInfo]::Local.BaseUtcOffset.TotalMinutes)
		        $syncTime = ($objRecordsetFilesAndSets.Fields.Item("SyncTime").Value).AddMinutes([System.TimeZoneInfo]::Local.BaseUtcOffset.TotalMinutes)

		        $setsText += "$eqline Base Name: $baseName $eqline Image Count: $imageCount $dashline Last Create Time: $latestCreateTime $dashline Last Sync Time: $syncTime $dashline "

		        $setCount++;

		        write-host "Set $setId : Machine Name: $machineName, BaseName: $baseName, Set Guid: $setGuid, Image Count: $imageCount, Latest Create Time: $latestCreateTime, Sync Time: $syncTime"

		        # get a list of all replication targets relating to this set, add it to the running list
		        $replicationTargetPathIds += $backupSetReplicationTargetMap.Get_Item($setGuid)

		        $objRecordsetFilesAndSets.MoveNext()
		    }
		    $objRecordsetFilesAndSets.Close()

		    
		    $filesTableName = "w$($index)Files";

		    #retrieve count of verify failures for watched folder
		    $objRecordsetFilesAndSets.Open("SELECT COUNT(*) AS VerifyFailedCount FROM $filesTableName WHERE VerifyStatus = -1 ", $objConnection,$adOpenStatic,$adLockOptimistic)
		    $objRecordsetFilesAndSets.MoveFirst()
		    $failedVerifications = [int] $objRecordsetFilesAndSets.Fields.Item("VerifyFailedCount").Value
		    $objRecordsetFilesAndSets.Close()

		    #retrieve file count and total size of files in watched folder
		    $objRecordsetFilesAndSets.Open("SELECT COUNT(*) AS FileCount, SUM(FileSize) AS TotalFileSizeBytes FROM $filesTableName ", $objConnection,$adOpenStatic,$adLockOptimistic)
		    $objRecordsetFilesAndSets.MoveFirst()
		    
		    $totalFiles = [int] $objRecordsetFilesAndSets.Fields.Item("FileCount").Value
		    if ($objRecordsetFilesAndSets.Fields.Item("TotalFileSizeBytes").Value.GetType().Name -eq "DBNull")
		    {
		        $totalFileSizeBytes = 0;
		    }
		    else
		    {
		        $totalFileSizeBytes = [long] $objRecordsetFilesAndSets.Fields.Item("TotalFileSizeBytes").Value
		    }
		    
		    $totalFileSizeBytesString = ("{0:N0}" -f $totalFileSizeBytes).ToString()
		    $objRecordsetFilesAndSets.Close()

		    $runningOldestQueuedFile = $null;
			
		    $replicationTargetPathIds | Sort-Object | Get-Unique | % {
		        # retrieve status from previously compiled hash table
		        $stats = $replicationTargetStats.Get_Item($_)
		        # retrieve path
		        $path = $targetPathsMap.Get_Item($_)
		        # Retrieve the replication type
		        $replicationType = $stats.ReplicationType
		        # track the oldest queued file out of all of the replication targets for the managed file. No need to adjust timezone offset as these were already adjusted above
		        $oldestQueuedFileDate = $($stats.OldestQueuedFileDate)
		        if ($oldestQueuedFileDate -eq $null)
		        {
		            $oldestQueuedFileDate = "N/A"
		        }
		        if ($runningOldestQueuedFile -eq $null -or $runningOldestQueuedFile -gt $stats.OldestQueuedFileDate)
		        {
		            $runningOldestQueuedFile = $stats.OldestQueuedFileDate;
		        }
		        $sentFileBytesString = ("{0:N0}" -f $($stats.SentFileSizeBytes)).ToString()
		        $queuedFileBytesString = ("{0:N0}" -f $($stats.QueuedFileSizeBytes)).ToString()
		        $queuedFilesRelatingToWatchedFolder += $stats.QueuedFileCount
		        # add to the targets string
		        
		        $setsReplicationTargetsText += "$eqline Path: $path $eqline Type: $replicationType $dashline Queued Files Count: $($stats.QueuedFileCount) $dashline Total Queued File Size: $queuedFileBytesString $dashline Oldest Queued File Date: $oldestQueuedFileDate $dashline Sent Files Count: $($stats.SentFileCount) $dashline Total Bytes Sent: $sentFileBytesString $dashline "
		    }
			if ($setsReplicationTargetsText.Length -eq 0)
			{
				$setsReplicationTargetsText = "No replication targets configured"
			}
			
		    if ($runningOldestQueuedFile -eq $null)
		    {
		        $oldestQueuedFileMinsAgo = 0;
		    }
		    else
		    {
		        $oldestQueuedFileMinsAgo = [int] ($runningOldestQueuedFile - $timenow).TotalMinutes*-1
		    }
			write-host "Replication Targets: $setsReplicationTargetsText"
		    write-host "Files Failing Verification: $failedVerifications"
		    write-host "Queued files relating to watched folder: $queuedFilesRelatingToWatchedFolder"
		    write-host "Oldest queued file on all replication targets: $runningOldestQueuedFile ($oldestQueuedFileMinsAgo mins ago)"
		    write-host "Total file count: $totalFiles, total bytes: $totalFileSizeBytesString"
		    
    		$watchedPathObject = New-Object -TypeName PSObject -Property @{ ManagedFolder=$watchedPath; MachineName=$machineName; NumberOfSets=$setCount; NumberOfFilesFailingVerification=$failedVerifications; NumberOfFilesQueuedForReplication=$queuedFilesRelatingToWatchedFolder; AgeOfOldestQueuedFileMins=$oldestQueuedFileMinsAgo; SetDetails=$setsText; ReplicationTargetDetails=$setsReplicationTargetsText; LastScriptRunTime=$timenow; Timestamp=$timestamp}
			$global:watchPaths += $watchedPathObject
			$objRecordsetWatchPaths.MoveNext()
		}
		$watchPaths.Length
	}
	else
	{
		Write-Host "No Watched folders found in database"
	}
	$objRecordsetWatchPaths.Close()
	$objConnection.Close()
}
main
