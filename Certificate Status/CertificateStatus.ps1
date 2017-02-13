###########################################################################################
# Filename:		CertificateStatus.PS1
# Description:	This script retrieves all certificates on the local machine and uploads
#               certificate data via WMI
# Created by:	Jon Czerwinski, Cohn Consulting Corporation
# Date:			Sep 1, 2011				
# Version       1.0						
###########################################################################################
   			

# Version History
# 1.0 - Initial release (20110901)


#########################################
# Hey! YOU NEED TO MODIFY THESE VALUES! #
#########################################
$ParentClass = "NCentral"
$SubClass = $ParentClass + "_Certificate_Status"


###########################################################################################
# Check to make sure that the ExecutionPolicy for Powershell isn't set to 'Restricted'    #
###########################################################################################
$CurrentPolicy = Get-ExecutionPolicy
If ($CurrentPolicy -eq 'Restricted')
    {
        WRITE-HOST "The current execution policy is set to $CurrentPolicy - this is a bad thing!"
        WRITE-HOST "I'll try to set the execution policy to 'RemoteSigned' - just a sec."
        SET-EXECUTIONPOLICY RemoteSigned
        RETURN
    }
    

#################################################
# Test for and, if necessary, create		    #
# the custom WMI classes            	        #
#################################################
$tc = ([wmiclass]"\root\cimv2").getsubclasses() | where {$_.Name -eq $SubClass}	
if ($tc -eq $null)
	{
	$class = new-object wmiclass ("root\cimv2", [String]::Empty, $null)
	$class["__Class"] = $ParentClass
	$class.Qualifiers.Add("Static", $true)
	$rc = $class.Put()

	[wmiclass]$sc = $class.derive($SubClass)
	$sc.Qualifiers.Add("Static", $false)
	$sc.Properties.Add("Thumbprint", [System.Management.CimType]::String, $false)
	$sc.Properties["Thumbprint"].Qualifiers.Add("Key", $true)
    $sc.Properties.Add("Subject", [System.Management.CimType]::String, $false)
	$sc.Properties["Subject"].Qualifiers.Add("Normal", $true)    
    $sc.Properties.Add("FriendlyName", [System.Management.CimType]::String, $false)
	$sc.Properties["FriendlyName"].Qualifiers.Add("Normal", $true)    
    $sc.Properties.Add("NotAfter", [System.Management.CimType]::String, $false)
	$sc.Properties["NotAfter"].Qualifiers.Add("Normal", $true)    
    $sc.Properties.Add("NotBefore", [System.Management.CimType]::String, $false)
	$sc.Properties["NotBefore"].Qualifiers.Add("Normal", $true)    
    $sc.Properties.Add("Expires", [System.Management.CimType]::Real32, $false)
    $sc.Properties["Expires"].Qualifiers.Add("Normal", $true)
    $sc.Properties.Add("Valid", [System.Management.CimType]::Boolean, $false)
    $sc.Properties["Valid"].Qualifiers.Add("Normal", $true)
	$sc.Properties.Add("LastUpdate", [System.Management.CimType]::UInt64, $false)
	$sc.Properties["LastUpdate"].Qualifiers.Add("Normal", $true)
	
    $rc = $sc.put()
	}


###############################################################
# Loop through and remove existing instances                  #
###############################################################
$certarray = gwmi $SubClass
if ($certarray)
    {
    $certarray | % `
        {
        $_ | Remove-WMIObject
        }
    }


###############################################################
# Loop through certificates, creating WMI instances           #
###############################################################
$certlist = dir -recurse cert:\LocalMachine
$certlist | % `
    {
    if ($_.Thumbprint)
        {
        $Now = [DateTime]::Now
        $cert = ([wmiclass]$SubClass).CreateInstance()
        $cert.Thumbprint = $_.Thumbprint
        $cert.Subject = $_.Subject
        $cert.FriendlyName = $_.FriendlyName
        $cert.NotAfter = $_.NotAfter
        $cert.NotBefore = $_.NotBefore
        $cert.Valid = (($_.NotBefore -le $Now) -and ($Now -le $_.NotAfter))
        
        $WeekstoExpire = [Math]::Round(([TimeSpan]($_.NotAfter.Ticks - $Now.Ticks)).Days / 7, 2)
        if ($WeekstoExpire -ge 0)
            {
            $cert.Expires = $WeekstoExpire
            }
         else
            {
            $cert.Expires = 0
            }
 
        $cert.LastUpdate = $Now.Ticks
        
        $rc = $cert.Put()
		}
    
    }
