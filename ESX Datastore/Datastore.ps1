###########################################################################################
# Filename:	Datastore.PS1
# Description:	This script checks the amount of free space on ESX/ESXi datastores.       	
# Created by:	Chris Reid
# Date:		Oct. 8th, 2010				
# Version       1.0						
###########################################################################################
   			

# Version History
# 1.0 - Initial release (Oct. 17th, 2010)





#########################################
# Hey! YOU NEED TO MODIFY THESE VALUES! #
#########################################

$vcserver="192.168.101.219"
$username = "root"
$password = "password"
$DatastoreNames = @{"N-ableISO"="d28c5e6-348e";"datastore1"="1f71d5f1-348e";"OtherCD"="525802e2-348e"} #Enter the names of the datastores that you want monitored, and their corresponding EDF Activation Codes.



###########################################################################################
# Check to make sure that the ExecutionPolicy for Powershell is set to 'Unrestricted'     #
###########################################################################################
$CurrentPolicy = Get-ExecutionPolicy
If ($CurrentPolicy -ne 'RemoteSigned')
    {
        WRITE-HOST "The current execution policy is set to $CurrentPolicy - this is a bad thing!"
        WRITE-HOST "I'll try to set the execution policy to 'RemoteSigned' - just a sec."
        SET-EXECUTIONPOLICY Unrestricted
        RETURN
    }





##########################################################################################################################################################
# Check to see if the "VMware.VimAutomation.Core" snapin is loaded. If not, load it.                                                                     #
# Thanks to http://ye110wbeard.wordpress.com/2009/12/23/powershell-%E2%80%93-getting-scripts-to-check-for-powershell-snapin-dependencies/ for this code  #
##########################################################################################################################################################
$STATUSLOADED=$FALSE
$SNAPIN=’VMware.VimAutomation.Core'
# Try to silently load the vSphere PowerCLI snapin
ADD-PSSNAPIN $SNAPIN –erroraction SilentlyContinue
IF ((GET-PSSNAPIN $SNAPIN) –eq $NULL)
     {
          # If not loaded – Notify user with required details
          WRITE-HOST ‘This Script requires VMWare vSphere PowerCLI’
          WRITE-HOST ‘Which can be downloaded free from http://communities.vmware.com/community/vmtn/vsphere/automationtools/powercli’
     }
ELSE
    {
          # If it DID, Flag Status as GOOD
          $STATUSLOADED=$TRUE
          WRITE-HOST 'The VMWare vSphere PowerCLI Snapin has been successfully loaded.'
     }

# Only continue with running the script if things are loaded correctly. 
IF ($STATUSLOADED)

{
        ##############################################
        # Initialize the PowerCLI Environment        #
        ##############################################
        "C:\Program Files\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-VIToolkitEnvironment.ps1"






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
        	[math]::Round(($ds.CapacityMB - $ds.FreeSpaceMB)/1024,2)
        }

        function FreeSpace
        {
        	param($ds)
        	[math]::Round($ds.FreeSpaceMB/1024,2)
        }

        function PercFree
        {
        	param($ds)
        	[math]::Round((100 * $ds.FreeSpaceMB / $ds.CapacityMB),0)
        }

        $Datastores = Get-Datastore -Name (foreach {$DatastoreNames.Keys})  
        $myCol = @()
        ForEach ($Datastore in $Datastores)
        {
        	$myObj = "" | Select-Object Datastore, UsedGB, FreeGB, PercFree #Grab the disk data about the datastore.
        	$myObj.Datastore = $Datastore.Name
        	$myObj.UsedGB = UsedSpace $Datastore
        	$myObj.FreeGB = FreeSpace $Datastore
        	$myObj.PercFree = PercFree $Datastore
        	$myCol += $myObj
            
            #############################################
            # Send the data to N-central using EDF      #
            #############################################
            $SCANDETAIL1NAME="EDF13454`_1"
            $SCANDETAIL1VALUE= $Datastore.Name
            $SCANDETAIL2NAME="EDF13454`_2"
            $SCANDETAIL2VALUE= $myObj.FreeGB
            $SCANDETAIL3NAME="EDF13454`_3"
            $SCANDETAIL3VALUE= $myObj.PercFree
            $SCANDETAIL4NAME="EDF13454`_4"
            $SCANDETAIL4VALUE= $myObj.UsedGB
            $SCANDETAIL5NAME="EDF13454`_5"
            $SCANDETAIL5VALUE= $myObj.UsedGB + $myObj.FreeGB
            $javapath = get-content "env:programfiles"
            $exelocation = $javapath +"\java\jre6\bin\java.exe"
            $CPATH = "C:\Users\creid\Desktop\ESX Datastore\axis\WEB-INF\lib\*;C:\Users\creid\Desktop\ESX Datastore\jar\*;C:\Users\creid\Desktop\ESX Datastore\resources"
            & $exelocation -cp $CPATH "com`.nable`.server`.edf`.GenericApp`.EDFGenericApp" $DatastoreNames[$Datastore.Name] "${SCANDETAIL1NAME}:$SCANDETAIL1VALUE" "${SCANDETAIL2NAME}:$SCANDETAIL2VALUE" "${SCANDETAIL3NAME}:$SCANDETAIL3VALUE" "${SCANDETAIL4NAME}:$SCANDETAIL4VALUE" "${SCANDETAIL5NAME}:$SCANDETAIL5VALUE"
        }


        ##############################################
        # Disconnect session from the VMWare Server  #
        ##############################################

        disconnect-viserver -confirm:$false


}




