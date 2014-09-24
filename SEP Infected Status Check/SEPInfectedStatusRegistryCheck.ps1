# *************************************************************************************************************************************************
# Script: SEPInfectedStatusRegistryCheck.ps1
# Version: 1.00
# Author: Marc-Andre Tanguay
# Description: This script when run on a local computer will clear the root\cimv2\nable\SEPInfectedStatus class, or create it 
#              if it doesnt exist, then will check the SEP Infected Registry key and return its status to WMI
# Date: March 1st, 2013
# *************************************************************************************************************************************************




# Version History

# 1.00 - Initial Version. returns 8 data points (countryname,countrycode,regionname,regioncode,city,externalip,latitude,longitude)



$ns=[wmiclass]'__namespace'
$sc=$ns.CreateInstance()
$sc.Name='nable'
$sc.Put()
$file="c:\temp\file1.txt"

if ((get-wmiobject -namespace "root/cimv2/nable" -list -EV namespaceError) | ? {$_.name -match "SEPInfectedStatus"})
{
   
    $dbcount = New-Object system.Collections.ArrayList
    $testfolder=Get-WMIObject -namespace root/cimv2/nable -query "Select * From SEPInfectedStatus"
    $rr=0;
    Get-WMIObject -namespace root/cimv2/nable -query "Select * From SEPInfectedStatus" | foreach {$dbcount.Insert($rr, $_);$rr++ }

    $dbcnt=$dbcount.count
    if($dbcount.count -ge '1')
    {
        $testfolder | Remove-WMIObject
    }  

}
else
{
    

    if( ![string]::IsNullOrEmpty( $namespaceError[0] ) )
    {
    	add-content $file "ERROR accessing namespace: $namespaceError[0]"
    	RETURN
    }

    try 
    {

    $newClass = New-Object System.Management.ManagementClass `
        ("root\cimv2\nable", [String]::Empty, $null); 
        $newClass["__CLASS"] = "SEPInfectedStatus"; 

    $newClass.Qualifiers.Add("Static", $true)
	$newClass.Properties.Add("DoesKeyExist", [System.Management.CimType]::Boolean, $false)
    $newClass.Properties["DoesKeyExist"].Qualifiers.Add("Key", $true)
	
    $newClass.Qualifiers.Add("Static", $true)
	$newClass.Properties.Add("IsInfectedFound", [System.Management.CimType]::Boolean, $false)
    $newClass.Properties["IsInfectedFound"].Qualifiers.Add("Key", $true)

    $newClass.Qualifiers.Add("Static", $true)
	$newClass.Properties.Add("LastTimeTheScriptWasRun", [System.Management.CimType]::String, $false)
    $newClass.Properties["LastTimeTheScriptWasRun"].Qualifiers.Add("Key", $true)
	
    $newClass.Put()
    }
    catch
    {
       add-content $file "ERROR creating WMI class: $_"
    }
    ######################################
}

$Error.Clear()




$VAL = Get-ItemProperty -Path "HKLM:\Software\Symantec\Symantec Endpoint Protection\currentversion\public-opstate" 
$VAL



 if ( $Error.Count -gt 0 )
 {
    $KeyExist=$false
    $InfectedStatus=$false
 }
 else
 {
    $KeyExist=$true
    if($VAL.Infected -eq "1")
    {
        $InfectedStatus=$true
    }
    else
    {
        $InfectedStatus=$false
    }
 }

$KeyExist
$InfectedStatus
try 
{
    $mb = ([wmiclass]"root/cimv2/nable:SEPInfectedStatus").CreateInstance()
    $mb.DoesKeyExist=$KeyExist
    $mb.IsInfectedFound=$InfectedStatus
    $mb.LastTimeTheScriptWasRun= get-date


    $mb.Put() 
}
catch
{
    add-content $file "ERROR creating a new instance: $_"
}
  
   

