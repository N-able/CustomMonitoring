###########################################################################################
# Filename:		ExchangeMailboxQuota.PS1
# Description:	This script retrieves mailbox statistics for all mailboxes in
#               the designated database and puts the data into instances of acustom WMI
#               class for retrieval by an N-Central custom service
# Created by:	Jon Czerwinski, Cohn Consulting Corporation
# Date:			Nov 16, 2010				
# Version       2.0						
###########################################################################################
   			

# Version History
# 1.0 - Initial release (20101113)
# 2.0 - Added support for Exchange 2010



#########################################
# Hey! YOU NEED TO MODIFY THESE VALUES! #
#########################################
$ExchFQDN = "mail.contoso.com"
$MBDatabase = "Mailbox Database 1"


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
    

#################################################
# Set up the Mailbox status text to code map    #
#################################################
$limits = @{
    "BelowLimit" = 1;
    "IssueWarning" = 2;
    "ProhibitSend" = 4;
    "NoChecking" = 8;
    "MailboxDisabled" = 16
}

   
    
#################################################
# Determine whether we're on Exchange 2007 or   #
# 2010 and load the appropriate Exchange        #
# Powershell cmdlets  		                    #
#################################################
$Exch2010 = gi hklm:\Software\Microsoft\ExchangeServer\v14 -erroraction SilentlyContinue

if ($Exch2010) # Exchange 2010
    {
    $session = new-pssession -configurationname Microsoft.Exchange -connectionuri http://$exchFQDN/powershell -authentication kerberos
    import-pssession $session
    }
else { Add-PSSnapin -name Microsoft.Exchange.Management.PowerShell.Admin } # Exchange 2007


#################################################
# Get mailbox database limits                   #
#################################################
$mbdb = get-mailboxdatabase $MBDatabase
if ($Exch2010)
    {
    $dblimit = [uint64]$mbdb.ProhibitSendReceiveQuota.split('(')[1].split(' bytes')[0]/1MB
    $dbsendlimit = [uint64]$mbdb.ProhibitSendQuota.split('(')[1].split(' bytes')[0]/1MB
    $dbwarning = [uint64]$mbdb.IssueWarningQuota.split('(')[1].split(' bytes')[0]/1MB
    }
else
    {
    $dblimit = $mbdb.ProhibitSendReceiveQuota.Value.ToMB()
    $dbsendlimit = $mbdb.ProhibitSendQuota.Value.ToMB()
    $dbwarning = $mbdb.IssueWarningQuota.Value.ToMB()
    }


#################################################
# Test for and, if necessary, create		    #
# the custom WMI classes            	        #
#################################################
$ParentClass = "NCentral"
$SubClass = "NCentral_Exchange_Mailbox"
$tc = ([wmiclass]"\root\cimv2").getsubclasses() | where {$_.Name -eq $SubClass}	
if ($tc -eq $null)
	{
	$class = new-object wmiclass ("root\cimv2", [String]::Empty, $null)
	$class["__Class"] = $ParentClass
	$class.Qualifiers.Add("Static", $true)
	$class.Put()

	[wmiclass]$subclass = $class.derive($SubClass)
	$subclass.Qualifiers.Add("Static", $false)
	$subclass.Properties.Add("Mailbox", [System.Management.CimType]::String, $false)
	$subclass.Properties["Mailbox"].Qualifiers.Add("Key", $true)
    $subclass.Properties.Add("User", [System.Management.CimType]::String, $false)
	$subclass.Properties["User"].Qualifiers.Add("Normal", $true)    
	$subclass.Properties.Add("ProhibitSendReceiveQuota", [System.Management.CimType]::UInt64, $false)
	$subclass.Properties["ProhibitSendReceiveQuota"].Qualifiers.Add("Normal", $true)
	$subclass.Properties.Add("ProhibitSendQuota", [System.Management.CimType]::UInt64, $false)
	$subclass.Properties["ProhibitSendQuota"].Qualifiers.Add("Normal", $true)
	$subclass.Properties.Add("IssueWarningQuota", [System.Management.CimType]::UInt64, $false)
	$subclass.Properties["IssueWarningQuota"].Qualifiers.Add("Normal", $true)
    $subclass.Properties.Add("MailboxStatus", [System.Management.CimType]::String, $false)
	$subclass.Properties["MailboxStatus"].Qualifiers.Add("Normal", $true)
	$subclass.Properties.Add("MailboxStatusCode", [System.Management.CimType]::UInt8, $false)
	$subclass.Properties["MailboxStatusCode"].Qualifiers.Add("Normal", $true)
	$subclass.Properties.Add("ItemCount", [System.Management.CimType]::UInt64, $false)
	$subclass.Properties["ItemCount"].Qualifiers.Add("Normal", $true)
	$subclass.Properties.Add("TotalItemSize", [System.Management.CimType]::UInt64, $false)
	$subclass.Properties["TotalItemSize"].Qualifiers.Add("Normal", $true)
	$subclass.put()
	}


###############################################################
# Retrieve all the mailboxes on the specified mailstore.      #
# Loop through mailboxes, creating or updating WMI instances  #	
###############################################################
$mailboxes = get-mailbox -database $MBDatabase
$mailboxes | % `
    {
	$mbstats = get-mailboxstatistics $_.Alias
	if ($mbstats)
        {
        $mb = ([wmiclass]$SubClass).CreateInstance()
        $mb.Mailbox = $_.Alias
        $mb.User = $_.DisplayName
        if ($_.UseDatabaseQuotaDefaults)
            {
            $mb.ProhibitSendReceiveQuota = $dblimit
            $mb.ProhibitSendQuota = $dbsendlimit
            $mb.IssueWarningQuota = $dbwarning
            }
        else
            {
            if ($Exch2010)
                {
                if ($_.ProhibitSendReceiveQuota -ne 'unlimited')
                    {
                    $mb.ProhibitSendReceiveQuota = [uint64]$_.ProhibitSendReceiveQuota.split('(')[1].split(' bytes')[0]/1MB
                    }
                else
                    {
                    $mb.ProhibitSendReceiveQuota = 0
                    }
                    
                if ($_.ProhibitSendQuota -ne 'unlimited')
                    {
                    $mb.ProhibitSendQuota = [uint64]$_.ProhibitSendQuota.split('(')[1].split(' bytes')[0]/1MB
                    }
                else
                    {
                    $mb.ProhibitSendQuota = 0
                    }
                    
                if ($_.IssueWarningQuota -ne 'unlimited')
                    {
                    $mb.IssueWarningQuota = [uint64]$_.IssueWarningQuota.split('(')[1].split(' bytes')[0]/1MB
                    }
                else
                    {
                    $mb.IssueWarningQuota = 0
                    }
                }
            else
                {
                if ($_.ProhibitSendReceiveQuota -ne 'unlimited')
                    {
                    $mb.ProhibitSendReceiveQuota = $_.ProhibitSendReceiveQuota.Value.ToMB()
                    }
                else
                    {
                    $mb.ProhibitSendReceiveQuota = 0
                    }
                    
                if ($_.ProhibitSendQuota -ne 'unlimited')
                    {
                    $mb.ProhibitSendQuota = $_.ProhibitSendQuota.Value.ToMB()
                    }
                else
                    {
                    $mb.ProhibitSendQuota = 0
                    }
                    
                if ($_.IssueWarningQuota -ne 'unlimited')
                    {
                    $mb.IssueWarningQuota = $_.IssueWarningQuota.Value.ToMB()
                    }
                else
                    {
                    $mb.IssueWarningQuota = 0
                    }
                }
            }
            
        if ($Exch2010)
            {
            $mb.TotalItemSize = [uint64]$mbstats.TotalItemSize.split('(')[1].split(' bytes')[0]/1MB
            }
        else
            {
            $mb.TotalItemSize = $mbstats.TotalItemSize.Value.ToMB()
            }            
            
        $mb.ItemCount = $mbstats.ItemCount    
        $mb.MailboxStatus = $mbstats.StorageLimitStatus
        $mb.MailboxStatusCode = $limits.Get_Item($mbstats.StorageLimitStatus.ToString())
        $mb.Put()
		}
    }
    

#################################################
# If we were on Exchange 2010, then release     #
# the Remote Management Session                 #
#################################################
if ($Exch2010) { remove-pssession $session }
