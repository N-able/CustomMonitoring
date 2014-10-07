#
# DoubleTake job polling script
# Author: James Weakley (jweakley@diamondgroup.net.au)
# This script:
# 1) Creates the root\cimv2\NCentral namespace if missing
# 2) Creates/updates the DoubleTake WMI class as needed
# 3) Uses the DoubleTake powershell cmdlets provided by the DoubleTake console 
#    installation to iterates all jobs, creates a WMI object using the Job Name as the identifier
#
Write-Host "Creating NCentral WMI namespace"

$serverName = $args[0];
if ($serverName -eq $null -or $serverName -eq "") {$serverName = 'localhost'}
$username = $args[1];
$password = $args[2];

#Creates Namespace if doesn't exist, if exists will just overwrite
$Namespace=[wmiclass]'__namespace'
$newNamespace=$Namespace.CreateInstance()
$newNamespace.Name='NCentral'
$newNamespace.Put()

$wmiClassName = "DoubleTake";
$wmiNameSpacePath = "root\cimv2\NCentral";


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

if ($class["JobName"] -eq $null)
{
    $class.Properties.Add("JobName", [System.Management.CimType]::String, $false)
    $class.Properties["JobName"].Qualifiers.Add("Key", $true);
}
if ($class["HealthValue"] -eq $null){$class.Properties.Add("HealthValue", [System.Management.CimType]::uint32, $false);}
if ($class["HealthString"] -eq $null){$class.Properties.Add("HealthString", [System.Management.CimType]::String, $false);}
if ($class["Timestamp"] -eq $null){$class.Properties.Add("Timestamp", [System.Management.CimType]::uint64, $false);}
if ($class["ListOfAllServerJobs"] -eq $null){$class.Properties.Add("ListOfAllServerJobs", [System.Management.CimType]::String, $false);}
if ($class["SourceHostUri"] -eq $null){$class.Properties.Add("SourceHostUri", [System.Management.CimType]::String, $false);}
if ($class["TargetHostUri"] -eq $null){$class.Properties.Add("TargetHostUri", [System.Management.CimType]::String, $false);}
if ($class["JobType"] -eq $null){$class.Properties.Add("JobType", [System.Management.CimType]::String, $false);}
if ($class["JobId"] -eq $null){$class.Properties.Add("JobId", [System.Management.CimType]::String, $false);}
if ($class["HighLevelState"] -eq $null){$class.Properties.Add("HighLevelState", [System.Management.CimType]::String, $false);}
if ($class["PercentageComplete"] -eq $null){$class.Properties.Add("PercentageComplete", [System.Management.CimType]::uint32, $false);}

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

#calculation for timestamp
$timenow = Get-WmiObject win32_utctime
$timestamp = (((((($timenow.Year - 1970.0) * 31556926 ) + (($timenow.Month - 1.0) * 2678400)) + (($timenow.Day - 1.0) * 86400)) + ($timenow.Hour * 3600)) + ($timenow.Minute * 60)) + ($timenow.Second)

$timenow = get-date

# load DoubleTake Powershell dll
if (test-path -Path "C:\Program Files\Vision Solutions\Double-Take\Console")
{
    import-module "C:\Program Files\Vision Solutions\Double-Take\Console\DoubleTake.PowerShell.dll"
}
elseif (test-path -Path "C:\Program Files\Double-Take Software\Double-Take\Console")
{
    import-module "C:\Program Files\Double-Take Software\Double-Take\Console\DoubleTake.PowerShell.dll"
}
else
{
    Write-Error "Double-Take Console directory not found"
}
# retrieve all local jobs
$server = New-DtServer -name "localhost"
$jobs = get-dtjob -ServiceHost $server

# if username and password are defined, use them to connect to a remote server
if ($username -ne $null -and $username -ne "" -and $password -ne $null -and $password -ne "")
{
    $server = New-DtServer -name $serverName -UserName $username -Password $password
    $remoteJobs = get-dtjob -ServiceHost $server
    $jobs = $jobs + $remoteJobs
}


#get a list of the names of all backup jobs, separated by comma
$allJobNames="";

$jobs | % {$allJobNames=$allJobNames+$_.Options.Name+","}

if ($allJobNames.length -gt 0)
{
    $allJobNames=$allJobNames.substring(0,$allJobNames.length-1)
}

#iterate through backup jobs
$jobs | where-object {$_.Id -ne $null} | % {
    $JobName = $_.Options.Name
    $JobName
    $wmiFilter = "JobName='$JobName'"
    $wmiFilter = $wmiFilter.replace("\","\\")
    
    # Checks to see if instance exists for job, if doesn't exist instance is created otherwise updated
    $currentValue = Get-WmiObject -Namespace $wmiNameSpacePath -Class $wmiClassName -Filter $wmiFilter
    
    $healthString = $_.Status.Health
    $healthValue = $_.Status.Health.value__
    $sourceHostUri = $_.SourceHostUri
    $targetHostUri = $_.TargetHostUri
    $jobType = $_.JobType
    $jobId = $_.Id
    $percentageComplete = $_.Status.PermillageComplete/10
    $highLevelState = $_.Status.HighLevelState
    if ($currentValue -eq $null)
    {
        Write-Host "Creating new instance of DoubleTake class for this job ($($_.JobName))"
        Set-WmiInstance -Namespace $wmiNameSpacePath -Class $wmiClassName -Arguments @{JobName=$JobName;Timestamp=$timestamp;ListOfAllServerJobs=$allJobNames;HealthString=$healthString;HealthValue=$healthValue;SourceHostUri=$sourceHostUri;TargetHostUri=$targetHostUri;JobType=$jobType;JobId=$jobId;PercentageComplete=$percentageComplete;HighLevelState=$highLevelState}
    }
    else
    {
        Write-Host "Updating existing instance of DoubleTake class for this job ($($_.DisplayName))"
        $currentValue | Set-WmiInstance -Arguments @{Timestamp=$timestamp;ListOfAllServerJobs=$allJobNames;HealthString=$healthString;HealthValue=$healthValue;SourceHostUri=$sourceHostUri;TargetHostUri=$targetHostUri;JobType=$jobType;JobId=$jobId;PercentageComplete=$percentageComplete;HighLevelState=$highLevelState}
    }

}
