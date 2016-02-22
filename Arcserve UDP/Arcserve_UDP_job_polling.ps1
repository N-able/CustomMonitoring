Param(
    [string]$domain = [string]::Empty,
    [string]$user,
    [string]$pass,
    [string]$lookbackHours = 100
)

Function NewJobHistoryObj($JobTypes, $JobStatuses)
{
    $jobHistoryCollection = @()

    $JobTypes | % {
        $jobHistoryData = New-Object PSObject
        Add-Member -InputObject $jobHistoryData -MemberType NoteProperty -Name JobType -Value $_
        Add-Member -InputObject $jobHistoryData -MemberType NoteProperty -Name JobStatuses -Value @{}
        $JobStatuses | % { $jobHistoryData.JobStatuses.Add($_, 0) }

        $jobHistoryCollection += $jobHistoryData
    }

    return $jobHistoryCollection
}

$error.Clear()

##############################################################################################
# WMI Setup Start
##############################################################################################

Write-Host "Creating NCentral WMI namespace"

#Creates Namespace if doesn't exist, if exists will just overwrite
$Namespace=[wmiclass]'__namespace'
$newNamespace=$Namespace.CreateInstance()
$newNamespace.Name='NCentral'
$newNamespace.Put()

$wmiClassName = "ArcserveUDP";
$wmiNameSpacePath = "root\cimv2\NCentral";

Write-Host "Testing for presence of $wmiClassName class"
#Check whether WMI class already exists, if not then create a new instance and configure
try
{
    $class = New-Object System.Management.ManagementClass ($wmiNameSpacePath, $wmiClassName, $null)
    $class
    Write-Host "$wmiClassName class already exists"
}
catch [System.Management.Automation.ExtendedTypeSystemException]
{
    Write-Host "$wmiClassName class does not exist, creating"
    $class = New-Object System.Management.ManagementClass ($wmiNameSpacePath, [String]::Empty, $null)
    $class["__CLASS"] = $wmiClassName
    $class.Qualifiers.Add("Static", $true)
    $class.Put()
}

Write-Host "Adding any missing properties to $wmiClassName class"

if ($class["RPSId"] -eq $null)
{
    $class.Properties.Add("RPSId", [System.Management.CimType]::uint32, $false)
    $class.Properties["RPSId"].Qualifiers.Add("Key", $true)
}

if ($class["RPSNodeName"] -eq $null){$class.Properties.Add("RPSNodeName", [System.Management.CimType]::string, $false);}
if ($class["BackupActiveCount"] -eq $null){$class.Properties.Add("BackupActiveCount", [System.Management.CimType]::uint32, $false);}
if ($class["BackupFinishedCount"] -eq $null){$class.Properties.Add("BackupFinishedCount", [System.Management.CimType]::uint32, $false);}
if ($class["BackupFailedCount"] -eq $null){$class.Properties.Add("BackupFailedCount", [System.Management.CimType]::uint32, $false);}
if ($class["BackupOtherCount"] -eq $null){$class.Properties.Add("BackupOtherCount", [System.Management.CimType]::uint32, $false);}
if ($class["VMBackupActiveCount"] -eq $null){$class.Properties.Add("VMBackupActiveCount", [System.Management.CimType]::uint32, $false);}
if ($class["VMBackupFinishedCount"] -eq $null){$class.Properties.Add("VMBackupFinishedCount", [System.Management.CimType]::uint32, $false);}
if ($class["VMBackupFailedCount"] -eq $null){$class.Properties.Add("VMBackupFailedCount", [System.Management.CimType]::uint32, $false);}
if ($class["VMBackupOtherCount"] -eq $null){$class.Properties.Add("VMBackupOtherCount", [System.Management.CimType]::uint32, $false);}
if ($class["ReplicateActiveCount"] -eq $null){$class.Properties.Add("ReplicateActiveCount", [System.Management.CimType]::uint32, $false);}
if ($class["ReplicateFinishedCount"] -eq $null){$class.Properties.Add("ReplicateFinishedCount", [System.Management.CimType]::uint32, $false);}
if ($class["ReplicateFailedCount"] -eq $null){$class.Properties.Add("ReplicateFailedCount", [System.Management.CimType]::uint32, $false);}
if ($class["ReplicateOtherCount"] -eq $null){$class.Properties.Add("ReplicateOtherCount", [System.Management.CimType]::uint32, $false);}
if ($class["StatusText"] -eq $null){$class.Properties.Add("StatusText", [System.Management.CimType]::string, $false);}
if ($class["DatastoreValid"] -eq $null){$class.Properties.Add("DatastoreValid", [System.Management.CimType]::Boolean, $false);}
if ($class["DatastoreValidationOutput"] -eq $null){$class.Properties.Add("DatastoreValidationOutput", [System.Management.CimType]::string, $false);}
if ($class["Timestamp"] -eq $null){$class.Properties.Add("Timestamp", [System.Management.CimType]::uint64, $false);}
if ($class["ValidationTimestamp"] -eq $null){$class.Properties.Add("ValidationTimestamp", [System.Management.CimType]::uint64, $false);}

try
{
    $class.Put()
    Write-Host "Class changes saved"
}
catch [System.Management.Automation.MethodInvocationException]
{
    Write-Host "Class has changed but instances exist, deleting all instances of $wmiClassName"
    Remove-WmiObject -class $wmiClassName -Namespace $wmiNameSpacePath
    $class.Put()
}

##############################################################################################
# WMI Setup End
##############################################################################################

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$True}

$URI = "https://localhost:8015/services/UDPService?wsdl"
$agent = New-WebServiceProxy -Uri $URI  -Namespace WebServiceProxy -Class UDPAgent
$cookieContainer = New-Object system.Net.CookieContainer
$agent.CookieContainer = $cookieContainer

$session = $agent.login($user,$pass, $domain)

# Should consider using a DateTime CimType and migrating service into automation policy with a Powershell script instead of epoch
$timeNow = Get-Date
$earliest = $timeNow.AddHours(-$lookbackHours)

$timenowUtc = $timeNow.ToUniversalTime()
$timestamp = (((((($timenowUtc.Year - 1970.0) * 31556926) + (($timenowUtc.Month - 1.0) * 2678400)) + (($timenowUtc.Day - 1.0) * 86400)) + ($timenowUtc.Hour * 3600)) + ($timenowUtc.Minute * 60)) + ($timenowUtc.Second)

Add-Type -TypeDefinition @"
    [System.Flags]
    public enum JobType
    {
        BACKUP = 0,
        VM_BACKUP = 3,
        CATALOG_FS = 11,
        RPS_REPLICATE = 22
    }

    public enum JobStatus
    {
        Active,
        Finished,
        Canceled,
        Failed,
        Incomplete,
        Idle,
        Waiting,
        Crash,
        LicenseFailed,
        Missed
    }
"@

#Assume all RPSes for now.  We could loop through and create new WMI objects with each RPS ID as primary key
#$rpsId = $jobHistory.data[0].targetRPSId
$rpsId = 0 
$rpsInfo = $agent.getRpsInfo($rpsId)
$rpsNodeName = $rpsInfo.node_name

$jobTypes = [enum]::GetValues([JobType])
$jobStatuses = [enum]::GetValues([JobStatus])
$jobHistoryCollection = NewJobHistoryObj -JobTypes $jobTypes -JobStatuses $jobStatuses

$nodeIds = $agent.getNodeList($null, $null).data | Select -ExpandProperty Id

foreach($nodeId in $nodeIds)
{
    Write-Host "Checking job history for node $nodeId"
    
    $jobHistory = $agent.getJobHistoryList($nodeId, $null, $null)

    $jobHistoryData = $jobHistory.data |
                        select  targetRPSId,
                                jobUTCStartDate, 
                                jobUTCEndDate,
                                jobStatus,
                                jobType,
                                nodeName | ? { $_.jobUTCStartDate -ge $earliest }

    foreach ($job in $jobHistoryData)
    {
        $jobHistory = $jobHistoryCollection | ? { [int] $_.JobType -eq $job.jobType } | Select -First 1

        if ($jobHistory -ne $null)
        {
            $jobHistory.JobStatuses[[JobStatus]([string]$job.jobStatus)]++
        }
    }
}

$wmiFilter = "RPSId=$rpsId"
$wmiFilter = $wmiFilter.Replace("\","\\")
$currentValue = Get-WmiObject -Namespace $wmiNameSpacePath -Class $wmiClassName -Filter $wmiFilter

$backupTaskHistory = $jobHistoryCollection | ? { $_.JobType -eq [JobType]::BACKUP }
$vmBackupTaskHistory = $jobHistoryCollection | ? { $_.JobType -eq [JobType]::VM_BACKUP }
$replicateTaskHistory = $jobHistoryCollection | ? { $_.JobType -eq [JobType]::RPS_REPLICATE }

# Get active, finished, failed counts for backup, VM backup and replication jobs
$backupActiveCount = $backupTaskHistory.JobStatuses[[JobStatus]::Active]
$backupFinishedCount = $backupTaskHistory.JobStatuses[[JobStatus]::Finished]
$backupFailedCount = $backupTaskHistory.JobStatuses[[JobStatus]::Failed]

$vmBackupActiveCount = $vmBackupTaskHistory.JobStatuses[[JobStatus]::Active]
$vmBackupFinishedCount = $vmBackupTaskHistory.JobStatuses[[JobStatus]::Finished]
$vmBackupFailedCount = $vmBackupTaskHistory.JobStatuses[[JobStatus]::Failed]

$replicateActiveCount = $replicateTaskHistory.JobStatuses[[JobStatus]::Active]
$replicateFinishedCount = $replicateTaskHistory.JobStatuses[[JobStatus]::Finished]
$replicateFailedCount = $replicateTaskHistory.JobStatuses[[JobStatus]::Failed]

# Get all other status accounts for these job types
$backupOtherCount = 0
$vmBackupOtherCount = 0
$replicateOtherCount = 0

[enum]::GetValues([JobStatus]) | ? {
    $_ -ne [JobStatus]::Active -and
    $_ -ne [JobStatus]::Finished -and
    $_ -ne [JobStatus]::Failed
} | % {
    $jobStatus = $_
    $backupOtherCount += $backupTaskHistory.JobStatuses[$jobStatus]
    $vmBackupOtherCount += $vmBackupTaskHistory.JobStatuses[$jobStatus]
    $replicateOtherCount += $replicateTaskHistory.JobStatuses[$jobStatus]
}

$lineStr = "_________________________________________________"
$statusText = "$lineStr`n"

[enum]::GetValues([JobType]) | % {
    $jobType = $_
    $jobTypeHistory = $jobHistoryCollection | ? {                                                                                               
        $_.JobType -eq $jobType
    }
    
    $jobTypeHistory.JobStatuses.GetEnumerator() | % {
        $statusText += "$($jobTypeHistory.JobType): $($_.Value) $($_.Name)`n".PadRight(50)
        Write-Host $_
    }
    $statusText += "$lineStr`n"
}

$args = 
@{
RPSNodeName = $rpsNodeName;
BackupActiveCount = $backupActiveCount;
BackupFinishedCount = $backupFinishedCount;
BackupFailedCount = $backupFailedCount;
BackupOtherCount = $backupOtherCount;
VMBackupActiveCount = $vmBackupActiveCount;
VMBackupFinishedCount = $vmBackupFinishedCount;                                                                       
VMBackupFailedCount = $vmBackupFailedCount;
VMBackupOtherCount = $vmBackupOtherCount;
ReplicateActiveCount = $replicateActiveCount;
ReplicateFinishedCount = $replicateFinishedCount;
ReplicateFailedCount = $replicateFailedCount;
ReplicateOtherCount = $replicateOtherCount;
StatusText = $statusText;
Timestamp = $timestamp
}

if ($Error.Count -gt 0)
{
    exit
}

if ($currentValue -eq $null)
{
    Write-Host "Creating new instance of $wmiClassName class for RPS Id = $rpsId"
    $args += @{RPSId = $rpsId; ValidationTimestamp = 0; DatastoreValidationOutput = 'N/A'; DatastoreValid = $false}
    Set-WmiInstance -Namespace $wmiNameSpacePath -Class $wmiClassName -Arguments $args
}
else
{
    Write-Host "Updating existing instance of $wmiClassName class for RPS Id = $rpsId"
    $currentValue | Set-WmiInstance -Arguments $args
}