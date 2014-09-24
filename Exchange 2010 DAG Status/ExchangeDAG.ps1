#######################################################################################
# Exchange2010DAGStatus.ps1
# Description: Queries the Exchange 2010 DAG Status
# Dependancies: Exchange 2010
# Version: 1.0
# Author: Cheops technology - Manu Vanden Broeck
# More details: manu.vandenbroeck@cheops.be
#######################################################################################

# Version History
# 1.0 - Initial Release (01-07-2012)
Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010
$ParentClass = "NCentral"
$SubClass = "NCentral_DAGCopyStatus"
$tc = ([wmiclass]"\root\cimv2").getsubclasses() | where {$_.Name -eq $SubClass}	
if ($tc -eq $null)
	{
	$class = new-object wmiclass ("root\cimv2", [String]::Empty, $null)
	$class["__Class"] = $ParentClass
	$class.Qualifiers.Add("Static", $true)
	$class.Put()

	[wmiclass]$subclass = $class.derive($SubClass)
	$subclass.Qualifiers.Add("Static", $false)
	$subclass.Properties.Add("Name", [System.Management.CimType]::String, $false)
	$subclass.Properties["Name"].Qualifiers.Add("Key", $true)
    $subclass.Properties.Add("Status", [System.Management.CimType]::String, $false)
	$subclass.Properties["Status"].Qualifiers.Add("Normal", $true)    
	$subclass.Properties.Add("CopyQ", [System.Management.CimType]::String, $false)
	$subclass.Properties["CopyQ"].Qualifiers.Add("Normal", $true)
	$subclass.Properties.Add("ReplayQ", [System.Management.CimType]::String, $false)
	$subclass.Properties["ReplayQ"].Qualifiers.Add("Normal", $true)
	$subclass.Properties.Add("LastInspectedLogTime", [System.Management.CimType]::String, $false)
	$subclass.Properties["LastInspectedLogTime"].Qualifiers.Add("Normal", $true)
    $subclass.Properties.Add("ContentIndexState", [System.Management.CimType]::String, $false)
	$subclass.Properties["ContentIndexState"].Qualifiers.Add("Normal", $true)

	$subclass.put()
	}
	
$statuses = Get-MailboxDatabaseCopyStatus
$statuses | % `
 {
        $mb = ([wmiclass]$SubClass).CreateInstance()
        $mb.Name = $_.Name
        $mb.Status = $_.Status
		$mb.CopyQ = $_.CopyQueueLength
		$mb.ReplayQ = $_.ReplayQueueLength
		$mb.LastInspectedLogTime = $_.LastInspectedLogTime
		$mb.ContentIndexState = $_.ContentIndexState
		$mb.Put()
}