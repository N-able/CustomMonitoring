$FailedLogins4625 = get-eventlog -LogName Security -EntryType FailureAudit -InstanceId 4625 -After ((Get-Date).AddDays(-1)) -ErrorAction SilentlyContinue
$FailedUsers4625 = $FailedLogins4625 | ForEach-Object { $_.ReplacementStrings[5] } | Group-Object
$FailedNetworkSource4625 = $FailedLogins4625 | ForEach-Object { $_.ReplacementStrings[19] } | Group-Object
$FailedAppSource4625 = $FailedLogins4625 | ForEach-Object { $_.ReplacementStrings[18] } | Group-Object

$FailedLogins4771 = get-eventlog -LogName Security -EntryType FailureAudit -InstanceId 4771 -After ((Get-Date).AddDays(-1)) -ErrorAction SilentlyContinue
$FailedUsers4771 = $FailedLogins4771 | ForEach-Object { $_.ReplacementStrings[0] } | Group-Object
$FailedNetworkSource4771 = $FailedLogins4771 | ForEach-Object { $_.ReplacementStrings[6] } | Group-Object
$FailedAppSource4771 = $FailedLogins4771 | ForEach-Object { $_.ReplacementStrings[2] } | Group-Object

#region Output parameters for Automation Manager
$BadAttempt = $FailedLogins4625.Count
$PreAuthAttempt = $FailedLogins4771.Count
$BadUsers = ([array]($FailedUsers4625 | ForEach-Object { "$($_.Name) ($($_.Count)x)" })) -join "<br>"
$BadNetwork = ([array]($FailedNetworkSource4625 | ForEach-Object { "$($_.Name) ($($_.Count)x)" })) -join "<br>"
$BadApps = ([array]($FailedAppSource4625 | ForEach-Object { "$($_.Name) ($($_.Count)x)" })) -join "<br>"
$reAuthUsers = ([array]($FailedUsers4771 | ForEach-Object { "$($_.Name) ($($_.Count)x)" })) -join "<br>"
$PreAuthNetwork = ([array]($FailedNetworkSource4771 | ForEach-Object { "$($_.Name) ($($_.Count)x)" })) -join "<br>"
$PreAuthNames = ([array]($FailedAppSource4771 | ForEach-Object { "$($_.Name) ($($_.Count)x)" })) -join "<br>"
#endregion