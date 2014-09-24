Dim strComputer
strComputer = "."
Set objWMIService = GetObject("winmgmts:" & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\NableEnhancements")
Set colDrives = objWMIService.ExecQuery("SELECT * FROM Disk_Health")
Dim strResults
strResults = "WMI Contains Following Defrag Statistics: " & vbCrLf & "-------------------------------------------------------------------------" & vbCrLf 
For Each objDrive in colDrives
 strResults = strResults & _
 "DriveID: " & vbTab & vbTab & vbTab & objDrive.DriveID & vbCrLf & _
 "CheckDiskResults: " & vbTab & vbTab & objDrive.CheckDiskResults & vbCrLf & _
 "FragPercentageBefore: " & vbTab & objDrive.FragPercentageBefore & vbCrLf & _
 "FragPercentageAfter: " & vbTab & objDrive.FragPercentageAfter & vbCrLf & _
 "LastRunSuccessful: " & vbTab & vbTab & objDrive.LastRunSuccessful & vbCrLf & _
 "DefragStartTime: " & vbTab & vbTab & objDrive.DefragStartTime & vbCrLf & _
 "DefragStopTime: " & vbTab & vbTab & objDrive.DefragEndTime & vbCrLf & _
 "CommandUsed: " & vbTab & vbTab & objDrive.CommandUsed & vbCrLf & _
 "FreeSpaceBefore: " & vbTab & vbTab & objDrive.FreeSpaceBefore & vbCrLf & _
 "FreeSpaceAfter: " & vbTab & vbTab & objDrive.FreeSpaceAfter & vbCrLf & _
 "CleanupCommandUsed: " & vbTab & objDrive.CleanupCommandUsed & vbCrLf & _
 "DefragScriptVersion: " & vbTab & vbTab & objDrive.DefragScriptVersion & vbCrLf & _
 "ScriptReturnCode: " & vbTab & vbTab & objDrive.ScriptReturnCode & vbCrLf & _
 "DiskSpaceCleanedUp: " & vbTab & objDrive.DiskSpaceCleanedUp & vbCrLf & _
 "FragPercentEliminated: " & vbTab & objDrive.FragPercentEliminated & vbCrLf & _
 "-------------------------------------------------------------------------" & vbCrLf  
Next
Wscript.Echo strResults