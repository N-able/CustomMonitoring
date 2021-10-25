$FailedLogins4625 = Get-WinEvent -FilterHashtable @{ ProviderName = "Microsoft-Windows-Security-Auditing" ; Id = 4625 ; StartTime = ((Get-Date).AddDays(-1)) } -ErrorAction SilentlyContinue
$FailedUsers4625 = $FailedLogins4625 | ForEach-Object { $_.Properties[5].Value } | Group-Object
$FailedNetworkSource4625 = $FailedLogins4625 | ForEach-Object { $_.Properties[19].Value } | Group-Object
$FailedAppSource4625 = $FailedLogins4625 | ForEach-Object { $_.Properties[18].Value } | Group-Object

$FailedLogins4771 = Get-WinEvent -FilterHashtable @{ ProviderName = "Microsoft-Windows-Security-Auditing" ; Id = 4771 ; StartTime = ((Get-Date).AddDays(-1)) } -ErrorAction SilentlyContinue
$FailedUsers4771 = $FailedLogins4771 | ForEach-Object { $_.Properties[0].Value } | Group-Object
$FailedNetworkSource4771 = $FailedLogins4771 | ForEach-Object { $_.Properties[6].Value } | Group-Object
$FailedAppSource4771 = $FailedLogins4771 | ForEach-Object { $_.Properties[2].Value } | Group-Object

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