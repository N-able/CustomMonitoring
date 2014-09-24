###########################################################################################
# Filename:	Datastore.sp1       	
# Created by:	Chris Reid
# Date:		Oct. 8th, 2010				
# Version       1.0						
###########################################################################################
# Description:	This script checks the amount of free space on datastores.   			
###########################################################################################





#########################################
# Hey! YOU NEED TO MODIFY THESE VALUES! #
#########################################

$vcserver="192.168.101.210"
$username = "root"
$password = "Password***"






######################################################################################
# Add VI-toolkit Powershell Snapin, and initialize the VMWare VIToolkit Environment  #
######################################################################################

$Count=0
ForEach ($Snapin in Get-PSSnapin)
{If ($Snapin.Name -ne "VMware.VimAutomation.Core")
    {$Count = $Count+1
    Write-Host $Count}
 Else 
    {$Count=0}  
}


If($Count -gt 0)
    {Add-PSsnapin VMware.VimAutomation.Core
    "C:\Program Files\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-VIToolkitEnvironment.ps1"}






#################################
# Connect to the VMWare Server  #
#################################

connect-VIServer $vcserver -Protocol https -User $username -Password $password






#####################################################
# Grab the Total/Free/Used space on each Datastore  #
#####################################################

function UsedSpace
{
	param($ds)
	[math]::Round(($ds.CapacityMB - $ds.FreeSpaceMB)/1024,0)
}

function FreeSpace
{
	param($ds)
	[math]::Round($ds.FreeSpaceMB/1024,0)
}

function PercFree
{
	param($ds)
	[math]::Round((100 * $ds.FreeSpaceMB / $ds.CapacityMB),0)
}

$Datastores = Get-Datastore
$myCol = @()
ForEach ($Datastore in $Datastores)
{
	$myObj = "" | Select-Object Datastore, UsedGB, FreeGB, PercFree
	$myObj.Datastore = $Datastore.Name
	$myObj.UsedGB = UsedSpace $Datastore
	$myObj.FreeGB = FreeSpace $Datastore
	$myObj.PercFree = PercFree $Datastore
	$myCol += $myObj
    #write-host $myObj.Datastore  #These fields are commented out because they aren't needed for the production version of the script. Useful for debugging though.
    #write-host $myObj.UsedGB
    #write-host $myObj.FreeGB
    #write-host $myObj.PercFree
}


##############################################
# Disconnect session from the VMWare Server  #
##############################################

disconnect-viserver -confirm:$false




#############################################
# Send the data to N-central using EDF      #
#############################################
$ACTIVATIONCODE = "2a8df227-348e"
$SCANDETAIL1NAME="EDF13454_1"
$SCANDETAIL1VALUE= $myObj.FreeGB
$SCANDETAIL2NAME="EDF13454_2"
$SCANDETAIL2VALUE= $myObj.PercFree
$SCANDETAIL3NAME="EDF13454_3"
$SCANDETAIL3VALUE= $myObj.UsedGB
$SCANDETAIL4NAME="EDF13454_4"
$SCANDETAIL4VALUE= $myObj.UsedGB + $myObj.FreeGB
$CPATH = "C:\users\creid\Documents\EDFSDK\jar\EDFGenApp.jar"
$EDFCommand = " com.nable.server.edf.GenericApp.EDFGenericApp " +$ACTIVATIONCODE +" " +$SCANDETAIL1NAME +":" +$SCANDETAIL1VALUE +" " +$SCANDETAIL2NAME +":" +$SCANDETAIL2VALUE +" " +$SCANDETAIL3NAME +":" +$SCANDETAIL3VALUE +" " +$SCANDETAIL4NAME +":" +$SCANDETAIL4VALUE
java.exe -cp . $EDFCommand









