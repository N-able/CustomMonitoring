#region Input Variables
$UserName = "apiuser@vsphere.local"
$Password = "VerySecure1337P@ssword"
$vCenterURL = "vCenter.contoso.com"
$ClusterInputName = ""
#endregion

$PasswordSec = ConvertTo-SecureString -String $Password -AsPlainText -Force
$credential = New-Object -TypeName PSCredential -ArgumentList $UserName, $PasswordSec

#Generate Auth
$auth = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Credential.UserName + ':' + $Credential.GetNetworkCredential().Password))
$head = @{
    'Authorization' = "Basic $auth"
}

#Ignore SelfSign Cert 
if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
    $certCallback = @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            if(ServicePointManager.ServerCertificateValidationCallback ==null)
            {
                ServicePointManager.ServerCertificateValidationCallback += 
                    delegate
                    (
                        Object obj, 
                        X509Certificate certificate, 
                        X509Chain chain, 
                        SslPolicyErrors errors
                    )
                    {
                        return true;
                    };
            }
        }
    }
"@
    Add-Type $certCallback
}
[ServerCertificateValidationCallback]::Ignore()

#Connect to VCSA 
$RestApi = Invoke-WebRequest -Uri https://$vCenterURL/rest/com/vmware/cis/session -Method Post -Headers $head -UseBasicParsing
$token = (ConvertFrom-Json $RestApi.Content).value
$session = @{'vmware-api-session-id' = $token }

#Get All Clusters
$RClusters = Invoke-WebRequest -Uri https://$vCenterURL/rest/vcenter/cluster -Method GET -Headers $session -UseBasicParsing
$Clusters = (ConvertFrom-Json $RClusters.Content).value

$Cluster = if ($Clusters.count -eq 1) { $Clusters[0] }
else { $Clusters | ForEach-Object { if ($_.name -eq $ClusterInputName) { $_ } } }

#Output Variables
$global:OutputVariables = @{
    ClusterName = if ($Cluster) { $Cluster.name } else { "[NO CLUSTER FOUND]" }
    HA_Enabled  = if ($Cluster) { $Cluster.ha_enabled } else { "[NO CLUSTER FOUND]" }
    DRS_Enabled = if ($Cluster) { $Cluster.drs_enabled } else { "[NO CLUSTER FOUND]" }
}