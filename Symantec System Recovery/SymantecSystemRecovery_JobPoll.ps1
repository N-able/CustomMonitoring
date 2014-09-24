#
# Symantec System Recovery job polling script
# Author: James Weakley (jweakley@diamondgroup.net.au)
# This script:
# 1) Creates the root\cimv2\NCentral namespace if missing
# 2) Creates/updates the SymantecSystemRecovery WMI class as needed
# 3) Uses the SSR COM object to iterates all jobs, creates a WMI object using the Job Name as the identifier
#
Write-Host "Creating NCentral WMI namespace"

#Creates Namespace if doesn't exist, if exists will just overwrite
$Namespace=[wmiclass]'__namespace'
$newNamespace=$Namespace.CreateInstance()
$newNamespace.Name='NCentral'
$newNamespace.Put()

$wmiClassName = "SymantecSystemRecovery";
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
if ($class["MinsSinceLastBackup"] -eq $null){$class.Properties.Add("MinsSinceLastBackup", [System.Management.CimType]::uint32, $false);}
if ($class["Timestamp"] -eq $null){$class.Properties.Add("Timestamp", [System.Management.CimType]::uint64, $false);}
if ($class["ListOfAllServerJobs"] -eq $null){$class.Properties.Add("ListOfAllServerJobs", [System.Management.CimType]::String, $false);}
if ($class["JobDestination"] -eq $null){$class.Properties.Add("JobDestination", [System.Management.CimType]::String, $false);}

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
$timestamp = (((((($timenow.Year - 1970.0) * 31556926 ) + (($timenow.Month - 1.0) * 2628000)) + (($timenow.Day - 1.0) * 86400)) + ($timenow.Hour * 3600)) + ($timenow.Minute * 60)) + ($timenow.Second)

$timenow = get-date

# Instantiate Symantec System Recovery management object, connect to localhost
$ssr = New-Object -ComObject Symantec.ProtectorAuto
$ssr.Connect('localhost')

#get a list of the names of all backup jobs, separated by comma
$allJobNames="";
$ssr.ImageJobs | % {$allJobNames=$allJobNames+$_.DisplayName+","}
if ($allJobNames.length -gt 0)
{
    $allJobNames=$allJobNames.substring(0,$allJobNames.length-1)
}

#iterate through backup jobs
$ssr.ImageJobs | % {
    $_.DisplayName
    
    $lastBackupDate = $_.LastBackup
    $destination = $_.Location($_.Volumes[0]).Path
    if ($_.IncrementalTask -ne $null)
    {
        $lastBackupDate = $lastBackupDate.AddMinutes($_.IncrementalTask.BaseBias*-1)
    }
    
    $lastBackupMinsAgo = (($lastBackupDate - $timenow).Totalminutes) * -1

    $wmiFilter = "JobName='$($_.DisplayName)'"
    $wmiFilter = $wmiFilter.replace("\","\\")
    
    # Checks to see if instance exists for job, if doesn't exist instance is created otherwise updated
    $currentValue = Get-WmiObject -Namespace $wmiNameSpacePath -Class $wmiClassName -Filter $wmiFilter
    if ($currentValue -eq $null)
    {
        Write-Host "Creating new instance of SymantecSystemRecovery class for this job ($($_.DisplayName))"
        Set-WmiInstance -Namespace $wmiNameSpacePath -Class $wmiClassName -Arguments @{MinsSinceLastBackup = $lastBackupMinsAgo;JobName=$_.DisplayName;Timestamp=$timestamp;ListOfAllServerJobs=$allJobNames;JobDestination=$destination}
    }
    else
    {
        Write-Host "Updating existing instance of SymantecSystemRecovery class for this job ($($_.DisplayName))"
        $currentValue | Set-WmiInstance -Arguments @{MinsSinceLastBackup = $lastBackupMinsAgo;Timestamp=$timestamp;ListOfAllServerJobs=$allJobNames;JobDestination=$destination}
    }

}



    