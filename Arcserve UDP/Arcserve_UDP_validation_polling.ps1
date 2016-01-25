Param(
    [string]$domain = [string]::Empty,
    [string]$user,
    [string]$pass
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

#Assume all RPSes for now.  We could loop through and create new WMI objects with each RPS ID as primary key
$rpsId = 0 
$rpsInfo = $agent.getRpsInfo($rpsId)
$rpsNodeName = $rpsInfo.node_name

$wmiFilter = "RPSId=$rpsId"
$wmiFilter = $wmiFilter.Replace("\","\\")
$currentValue = Get-WmiObject -Namespace $wmiNameSpacePath -Class $wmiClassName -Filter $wmiFilter

$dataStoreValid = $false
$allVerifyResults = "N/A"

$lastValidatedTimestamp = 0
if ($currentValue -ne $null -and $currentValue.ValidationTimestamp -ne $null)
{
        $lastValidatedTimestamp = $currentValue.ValidationTimestamp
}

$timeNowUtc = (Get-Date).ToUniversalTime()
$timeNowTimestamp = (((((($timenowUtc.Year - 1970.0) * 31556926) + (($timenowUtc.Month - 1.0) * 2678400)) + (($timenowUtc.Day - 1.0) * 86400)) + ($timenowUtc.Hour * 3600)) + ($timenowUtc.Minute * 60)) + ($timenowUtc.Second)

$timeSinceValidation = $timeNowTimestamp - $lastValidatedTimestamp
if ($timeSinceValidation -gt (4 * 24 * 60 * 60))
{
    Write-Host "Validation has not occurred in > 4 days.. It is time.."
    $nodeRunningJob = $agent.getNodeList($null, $null).data | ? { $_.jobRunning -eq $true }   
    if ($nodeRunningJob -eq $null)
    {
        Write-Host "UDP is idle.. Attempting to stop data store for verification.."
        $datastores = @()
        $agent.getDataStoreList($rpsId, $true) | % { $datastores += $_.dataStoreSetting.displayName }
        $binDir = "C:\Program Files\CA\arcserve Unified Data Protection\Engine\BIN"

        $allVerifyResults = [string]::Empty

        $datastores | % {
            Write-Host "Stopping $_ ..."
            &"$binDir\ca_dsmgr.exe" /StopDS $_

            Write-Host "Scanning $_ ..."
            $verifyResult = &"$binDir\ca_gddmgr.exe" -Scan VerifyAll $_  2>&1
            $allVerifyResults += $verifyResult + "`n`n"

            Write-Host "Starting $_ ..."
            &"$binDir\ca_dsmgr.exe" /StartDS $_

            $errorMatch = [regex]::match($verifyResult, "(Error)")
            $datastoreValid = $errorMatch -eq $null -or [string]::IsNullOrEmpty($errorMatch.Groups[1].Value)

            Write-Host "Datastore valid?: $datastoreValid"

            if (-Not($datastoreValid))
            {
                break
            }
        }

        $lastValidatedTimestamp = $timeNowTimestamp

        $args = 
        @{
        DatastoreValid = $datastoreValid
        DatastoreValidationOutput = $allVerifyResults
        ValidationTimestamp = $lastValidatedTimestamp
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
    }
    else
    {
        Write-Host "UDP is NOT idle.. Skipping data store verification.."
    }
 }