Param(
    [string]$domain = [string]::Empty,
    [string]$user,
    [string]$pass,
    [string]$lookbackHours = 100
)

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
if ($class["JobActiveCount"] -eq $null){$class.Properties.Add("JobActiveCount", [System.Management.CimType]::uint32, $false);}
if ($class["JobFinishedCount"] -eq $null){$class.Properties.Add("JobFinishedCount", [System.Management.CimType]::uint32, $false);}
if ($class["JobCancelledCount"] -eq $null){$class.Properties.Add("JobCancelledCount", [System.Management.CimType]::uint32, $false);}
if ($class["JobFailedCount"] -eq $null){$class.Properties.Add("JobFailedCount", [System.Management.CimType]::uint32, $false);}
if ($class["JobIncompleteCount"] -eq $null){$class.Properties.Add("JobIncompleteCount", [System.Management.CimType]::uint32, $false);}
if ($class["JobIdleCount"] -eq $null){$class.Properties.Add("JobIdleCount", [System.Management.CimType]::uint32, $false);}
if ($class["JobWaitingCount"] -eq $null){$class.Properties.Add("JobWaitingCount", [System.Management.CimType]::uint32, $false);}
if ($class["JobCrashedCount"] -eq $null){$class.Properties.Add("JobCrashedCount", [System.Management.CimType]::uint32, $false);}
if ($class["JobLicenseFailedCount"] -eq $null){$class.Properties.Add("JobLicenseFailedCount", [System.Management.CimType]::uint32, $false);}
if ($class["JobSkippedCount"] -eq $null){$class.Properties.Add("JobSkippedCount", [System.Management.CimType]::uint32, $false);}
if ($class["JobStoppedCount"] -eq $null){$class.Properties.Add("JobStoppedCount", [System.Management.CimType]::uint32, $false);}
if ($class["JobMissedCount"] -eq $null){$class.Properties.Add("JobMissedCount", [System.Management.CimType]::uint32, $false);}
if ($class["Timestamp"] -eq $null){$class.Properties.Add("Timestamp", [System.Management.CimType]::uint64, $false);}

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
$timenow = (Get-Date).ToUniversalTime()
$earliest = $timeNow.AddHours(-$lookbackHours)
$timestamp = (((((($timeNow.Year - 1970.0) * 31556926) + (($timeNow.Month - 1.0) * 2678400)) + (($timeNow.Day - 1.0) * 86400)) + ($timeNow.Hour * 3600)) + ($timeNow.Minute * 60)) + ($timeNow.Second)

$jobHistory = $agent.getJobHistoryList(-1, $null, $null)

#Assume all RPSes for now.  We could loop through and create new WMI objects with each RPS ID as primary key
#$rpsId = $jobHistory.data[0].targetRPSId
$rpsId = 0 
$rpsInfo = $agent.getRpsInfo($rpsId)
$rpsNodeName = $rpsInfo.node_name

$jobHistoryData = $jobHistory.data |
                    select  targetRPSId,
                            jobLocalStartDate, 
                            jobLocalEndDate,
                            jobStatus,
                            jobType,
                            nodeName | ? { $_.jobLocalStartDate -ge $earliest }

$jobAllCount = 0
$jobActiveCount = 0
$jobFinishedCount = 0
$jobCancelledCount = 0
$jobFailedCount = 0
$jobIncompleteCount = 0
$jobIdleCount = 0
$jobWaitingCount = 0
$jobCrashedCount = 0
$jobLicenseFailedCount = 0
$jobSkippedCount = 0
$jobStoppedCount = 0
$jobMissedCount = 0

foreach ($job in $jobHistoryData)
{
    if ($job.jobStatus -eq 'Active')
    {
        $jobActiveCount++
    }
    elseif ($job.jobStatus -eq 'Finished')
    {
        $jobFinishedCount++
    }
    elseif ($job.jobStatus -eq 'Canceled')
    {
        $jobCancelledCount++
    }
    elseif ($job.jobStatus -eq 'Failed')
    {
        $jobFailedCount++
    }
    elseif ($job.jobStatus -eq 'Incomplete')
    {
        $jobIncompleteCount++
    }
    elseif ($job.jobStatus -eq 'Idle')
    {
        $jobIdleCount++
    }
    elseif ($job.jobStatus -eq 'Waiting')
    {
        $jobWaitingCount++
    }
    elseif ($job.jobStatus -eq 'Crash')
    {
        $jobCrashedCount++
    }
    elseif ($job.jobStatus -eq 'LicenseFailed')
    {
        $jobLicenseFailedCount++
    }
    elseif ($job.jobStatus -eq 'Missed')
    {
        $jobMissedCount++
    }
}

$wmiFilter = "RPSId=$rpsId"
$wmiFilter = $wmiFilter.Replace("\","\\")
$currentValue = Get-WmiObject -Namespace $wmiNameSpacePath -Class $wmiClassName -Filter $wmiFilter

$args = 
@{
RPSNodeName = $rpsNodeName;
JobActiveCount = $jobActiveCount;
JobFinishedCount = $jobFinishedCount;
JobCancelledCount = $jobCancelledCount;
JobFailedCount = $jobFailedCount;
JobIncompleteCount = $jobIncompleteCount;
JobIdleCount = $jobIdleCount;
JobWaitingCount = $jobWaitingCount;
JobCrashedCount = $jobCrashedCount;
JobLicenseFailedCount = $jobLicenseFailedCount;
JobSkippedCount = $jobSkippedCount;
JobStoppedCount = $jobStoppedCount;
JobMissedCount = $JobMissedCount;
Timestamp = $timestamp
}

if ($currentValue -eq $null)
{
    Write-Host "Creating new instance of $wmiClassName class for RPS Id = $rpsId"
    $args += @{RPSId = $rpsId}
    Set-WmiInstance -Namespace $wmiNameSpacePath -Class $wmiClassName -Arguments $args
}
else
{
    Write-Host "Updating existing instance of $wmiClassName class for RPS Id = $rpsId"
    $currentValue | Set-WmiInstance -Arguments $args
}