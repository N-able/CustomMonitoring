' ******************************************************************************
' Script: ShadowProtect.vbs
' Version: 2.1
' Author: Patrick Albert (palbert@n-able.com)
' Description: This script checks the status of all backup jobs in ShadowProtect, 
'              and places the results in WMI.
' Date: November 11th, 2013
' ******************************************************************************


' Version History:

' 2.1 - Added monitorable job names to the script output

' 2.0 - Added output variable required for reporting

' 1.6 - added 2 output variables

' 1.5 - Used the Rtrim command to remove any trailing spaces from the name of the Backup Job, as that can cause the service to go Misconfigured. Thanks to David Allaire for discovering this issue! (June 25th, 2012) '

' 1.4 - Fixed an issue where if the script couldn't find the throughput/running stats of the backup job, it would put data into WMI that would cause the service to report a Failed state. (June 13th, 2012)

' 1.3 - Fixed an issue where throughput and time statistics weren't being populated if the backup job was in a 'Running' state. Thanks to Stuart James for finding this issue! (March 5th, 2012)

' 1.2 - Fixed an issue where the data wouldn't get populated in WMI if the backup job was in a 'Queued' state. Thanks to Jonathan Filson for finding this issue! (March 5th, 2012)

' 1.1 - Initial Release (Nov 23rd, 2011)


' Let's declare all of the variables this script will use.
Option Explicit
Dim output, Scheduler, ShadowProtect, BackupJob, Job, JobName, Volume, volumes 
Dim JobStatus, VolumeStatus, totalTime, remainingTime, bytesPerSecond, startTime
Dim HKEY_LOCAL_MACHINE, strComputer, wbemCimtypeString, wbemCimtypeUint32
Dim wbemCimtypeBoolean, objReg, strWMIClassWithQuotes, strWMIClassNoQuotes, strWMIClassWithQuotesTime, strWMIClassNoQuotesTime
Dim strWMINamespace, ParentWMINamespace, WshShell, WMINamespaceExists
Dim colNamespaces, objNamespace, objItem, objNewNamespace, WMINamespace 
Dim colClasses, objClass, objWMIService, objClassCreator, objGetClass
Dim objNewInstance, JobStatusDescription, strJobStatusValues, FinalJobStatus
Dim StrLastJobTime, strInstallFolder32, strInstallFolder64, StrLastBackupFile 
Dim IntMinuteSinceLastActivity
Dim fso, Path, file
Dim recentDate, recentFile


' Let's set values for some of the variables.
Set output = WScript.Stdout
HKEY_LOCAL_MACHINE = &H80000002
strComputer = "."
wbemCimtypeString = 8
wbemCimtypeUint32 = 19
wbemCimtypeBoolean = 11
Const wbemFlagReturnImmediately = &h10
Const wbemFlagForwardOnly = &h20 
Set objReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & strComputer & "\root\default:StdRegProv")
strWMIClassWithQuotes = chr(34) & "StorageCraft" & chr(34)
strWMIClassWithQuotesTime = chr(34) & "StorageCraftTime" & chr(34)
strWMIClassNoQuotes = "StorageCraftStandAlone"
strWMIClassNoQuotesTime = "StorageCraftTime"
strWMINamespace = "Ncentral"
Set ParentWMINamespace = GetObject("winmgmts:\\" & strComputer & "\root\cimv2")
Set WshShell = WScript.CreateObject("WScript.Shell")
StrLastJobTime = "No Log File Found"
strInstallFolder32 = "C:\Program Files (x86)\StorageCraft\ShadowProtect\Logs"
strInstallFolder64 = "C:\Program Files\StorageCraft\ShadowProtect\Logs"
Set fso = CreateObject("Scripting.FileSystemObject")


ON ERROR RESUME NEXT



' This unassuming bit of is where all of the WMI magic happens - this calls all
' of the subroutines that create the necessary WMI class and properties.
  If DoesTheWMINamespaceExist(ParentWMINamespace) Then
      output.writeline "The Namespace already exists."
      If WMIClassExists(strComputer,strWMIClassNoQuotes) Then
          output.writeline "The WMI Class exists"
          WMINamespace.Delete strWMIClassNoQuotes
          CreateWMIClass
      Else
          output.writeline "The Namespace exists, but the Standard WMI class does not. Curious." 
          CreateWMIClass   
      End If
      If WMIClassExists(strComputer,strWMIClassNoQuotesTime) Then
          output.writeline "The WMI Class exists (Time)"
          WMINamespace.Delete strWMIClassNoQuotesTime
          CreateWMIClassTime
      Else
          output.writeline "The Namespace exists, but the Time WMI class does not. Curious." 
          CreateWMIClassTime
      End If
  Else
      'Create the WMI Namespace (if it doesn't already exist) and the WMI Class.           
      output.writeline "The WMI Namespace and Class does not exist"
      CreateWMINamespace
      CreateWMIClass
      CreateWMIClassTime
  End If
  

' this is getting the last log file size in the default folder

   If (fso.FolderExists(strInstallFolder32)) Then
      Path = strInstallFolder32
      output.writeline strInstallFolder32 & " exists."
   ElseIf (fso.FolderExists(strInstallFolder64)) Then
      Path = strInstallFolder64
      output.writeline strInstallFolder64 & " exists."
   Else
      Path = "INVALID"
      output.writeline "The Log File Folder is not found."
   End If

   Set recentFile = Nothing
For Each file in fso.GetFolder(Path).Files
  if(instr(1,file,"{") > 0 ) then
	  If (recentFile is Nothing) Then
	    Set recentFile = file
	  ElseIf (file.DateLastModified > recentFile.DateLastModified) Then
	    Set recentFile = file
	  End If
  ElseIf(instr(1,file,"BackupHistory.dat") > 0 ) then
	  If (recentFile is Nothing) Then
	    Set recentFile = file
	  ElseIf (file.DateLastModified > recentFile.DateLastModified) Then
	    Set recentFile = file
	  End If
   end if
Next

If recentFile is Nothing Then
  output.writeline "no recent files"
Else
  output.writeline "Recent file is " & recentFile.Name & " " & recentFile.DateLastModified
  StrLastJobTime = recentFile.DateLastModified
  StrLastBackupFile = recentFile
  IntMinuteSinceLastActivity = datediff("n",recentFile.DateLastModified,(date & " " & time))
	output.writeline IntMinuteSinceLastActivity 
End If



  
' This 'For' loop finds each Backup job that is running and dumps its data into WMI.  
Set ShadowProtect = CreateObject ("ShadowStor.ShadowProtect")
For Each Job in ShadowProtect.Jobs
  If Job.IsBackup Then
    JobName = Job.Description
    output.writeline "The found job is: " & JobName
    Err.Clear    
    Set BackupJob = ShadowProtect.Jobs.GetBackupJob(JobName)
    If Err<>0 Then
      output.writeline "GetBackupJob failed for " & JobName & vbCrLf
      output.writeline Err
    Else
      BackupJob.GetVolumes volumes
	
      If Err<>0 Then
        output.writeline "GetVolumes failed" & vbCrLf
      Else
        BackupJob.GetJobStatus JobStatus
                                
      'In order to make thresholding in WMI possible, we need to map the Job Status codes to a Normal/Warning/Failed value.
      If JobStatus = 0  then
        FinalJobStatus = 0  
      ElseIf JobStatus = 1  Then 
        FinalJobStatus = 1 
      ElseIf JobStatus = 2  Then 
        FinalJobStatus = 1 
      ElseIf JobStatus = 3  Then 
        FinalJobStatus = 0 
      ElseIf JobStatus = 4  Then 
        FinalJobStatus = 0 
      ElseIf JobStatus = 5  Then 
        FinalJobStatus = 1 
      ElseIf JobStatus = 6  Then 
        FinalJobStatus = 1 
      ElseIf JobStatus = 7  Then 
        FinalJobStatus = 2 
      ElseIf JobStatus = 8  Then 
        FinalJobStatus = 2 
      ElseIf JobStatus = 9  Then 
        FinalJobStatus = 0 
      ElseIf JobStatus = 10  Then 
        FinalJobStatus = 0 
      ElseIf JobStatus = 11  Then 
        FinalJobStatus = 1 
      ElseIf JobStatus = 12  Then 
        FinalJobStatus = 1 
      ElseIf JobStatus = 13  Then 
        FinalJobStatus = 1 

      End If
      
    
         
      GetJobStatus
      If JobStatusDescription <> "Queued" Then  ' If the Job Status is anything but 'Queued' then we can get accurate data.
        For Each Volume In volumes
	  output.writeline "Volume: " & Volume
          Err.Clear
          BackupJob.GetStatus Volume, VolumeStatus
          If Err<>0 Then
            output.writeline "Unable to get volume status" & vbCrLf
          Else
            output.writeline "The status of " & Volume & " is: " & VolumeStatus & vbCrLf
          End If
          
          BackupJob.GetRunningStatus Volume, totalTime, remainingTime, bytesPerSecond
          If Err<>0 Then
            output.writeline "Unable to get running status; this could be because the job has already completed, so it may not be a big deal. The Error Code from ShadowProtect was: " & Err & vbCrLf
            totalTime = 0
            remainingTime = 0
            bytesPerSecond = 1000001
			startTime = "Job is not active"		
	    output.writeline "Because we couldn't get the running status, we'll populate WMI with the following fake/placeholder data:" & vbCrLf
            output.writeline "  Elapsed Time: " & totalTime & " Seconds"
            output.writeline "  Remaining Time: " & remainingTime & " Seconds"
            output.writeline "  Transfer Rate: " & bytesPerSecond & " Bytes Per Second"
          Else
            startTime = DateAdd("s",totalTime*-1,Now())
			startTime = RIGHT("00" & Day(StartTime),2) & "-" & MonthName(Month(StartTime),True) & "-" & DatePart("yyyy",StartTime) & " " & Right("0" & DatePart("h",StartTime),2) & ":" & Right("0" & DatePart("n",StartTime),2) & ":" & Right("0" & DatePart("s",StartTime),2) 
            output.writeline "Running Statistics:"
            output.writeline "  Start Time: " & startTime
            output.writeline "  Elapsed Time: " & totalTime & " Seconds"
            output.writeline "  Remaining Time: " & remainingTime & " Seconds"
            output.writeline "  Transfer Rate: " & bytesPerSecond & " Bytes Per Second"
          End If
            output.writeline  vbCrLf
        Next
      Else ' If the Job Status is 'Queued' then no valid data exists. To fix the issue, we'll populate WMI with some placeholder data.
        VolumeStatus = 0
        TotalTime  = 0
        remainingTime = 0
        bytesPerSecond = 1000001
		startTime = "Job is not active"		
        output.writeline "This job is queued, so we'll populate WMI with the following fake/placeholder data:" & vbCrLf
        output.writeline "Volume Status: " & VolumeStatus & vbCrLf
        output.writeline "Total Time: " & TotalTime & vbCrLf
        output.writeline "Remaining Time: " & remainingTime & vbCrLf
        output.writeline "Throughput: " & bytesPerSecond & vbCrLf
      End If  
      End If    
    End If 
  End If
  PopulateWMIClass
Next
PopulateWMIClassTime
ShowJobNames


'***************************************************
' Sub: GetJobStatus
'***************************************************
Sub GetJobStatus
  strJobStatusValues = Array("Placeholder. This value should never be shown in N-central","Init","Intialized","Queued","Running","Aborting","Aborted","Failed","Failedqueued","Completed","Completedqueued","Deleted","Expired","Disabled")
  JobStatusDescription = (strJobStatusValues(JobStatus))
  output.writeline "Job Status Description: " & JobStatusDescription
  output.writeline "Final Job Status: " & FinalJobStatus & " (0 = Normal, 1 = Warning, 2 = Failed)"



End Sub


' *****************************  
' Sub: CreateWMINamespace
' *****************************
Sub CreateWMINamespace
    Set objItem = ParentWMINamespace.Get("__Namespace")
    Set objNewNamespace = objItem.SpawnInstance_    
    objNewNamespace.Name = strWMINamespace
    objNewNamespace.Put_
End Sub





' *****************************  
' Sub: CreateWMIClass
' *****************************
Sub CreateWMIClass
    Set objWMIService = GetObject("Winmgmts:root\cimv2\" & strWMINamespace)
    Set objClassCreator = objWMIService.Get() 'Load the Namespace           
    'Define the Properties of the WMI Class
    objClassCreator.Path_.Class = "" & strWMIClassNoQuotes
    
    objClassCreator.Properties_.add "Name", wbemCimtypeString
    objClassCreator.Properties_.add "JobStatus", wbemCimtypeUint32
    objClassCreator.Properties_.add "JobStatusDescription", wbemCimtypeString
    objClassCreator.Properties_.add "VolumeStatus", wbemCimtypeUint32
    objClassCreator.Properties_.add "RunningTimeElapsed", wbemCimtypeUint32
    objClassCreator.Properties_.add "RunningTimeRemaining", wbemCimtypeUint32
    objClassCreator.Properties_.add "RunningBytesPerSecond", wbemCimtypeUint32
    objClassCreator.Properties_.add "StartTime", wbemCimtypeString
    objClassCreator.Properties_.add "LastScriptExecutionDate", wbemCimtypeString
    objClassCreator.Properties_.add "LastBackupActivityDate", wbemCimtypeString
          
                
    ' Make the 'Name' property a 'key' (or index) property
    objClassCreator.Properties_("Name").Qualifiers_.add "key", true
                
    ' Write the new class to the '`' namespace in the repository
    objClassCreator.Put_

End Sub
    


' *****************************  
' Sub: CreateWMIClassTime
' *****************************
Sub CreateWMIClassTime
    Set objWMIService = GetObject("Winmgmts:root\cimv2\" & strWMINamespace)
    Set objClassCreator = objWMIService.Get() 'Load the Namespace           
    'Define the Properties of the WMI Class
    objClassCreator.Path_.Class = "" & strWMIClassNoQuotesTime
    
    objClassCreator.Properties_.add "LastBackupActivityDate", wbemCimtypeString
    objClassCreator.Properties_.add "MinutesSinceLastBackupActivity", wbemCimtypeUint32
    objClassCreator.Properties_.add "LastScriptExecutionDate", wbemCimtypeString
    objClassCreator.Properties_.add "LastBackupFileName", wbemCimtypeString
                 
    ' Make the 'Name' property a 'key' (or index) property
    objClassCreator.Properties_("LastBackupActivityDate").Qualifiers_.add "key", true
                
    ' Write the new class to the '`' namespace in the repository
    objClassCreator.Put_

End Sub
    
    
' *****************************  
' Function: DoesTheWMINamespaceExist
' Thanks to http://www.cruto.com/resources/vbscript/vbscript-examples/misc/wmi/List-All-WMI-Namespaces.asp for this code 
' *****************************
Function DoesTheWMINamespaceExist(ParentWMINamespace)
                DoesTheWMINamespaceExist = vbFalse
                Set colNamespaces = ParentWMINamespace.InstancesOf("__Namespace")
                  For Each objNamespace In colNamespaces
                        If instr(objNamespace.Path_.Path,strWMINamespace) Then
                              DoesTheWMINamespaceExist = vbTrue
                        End If
                  Next
                Set colNamespaces = Nothing
End Function


  


' *****************************  
' Function: WMIClassExists
' Thanks to http://gallery.technet.microsoft.com/ScriptCenter/en-us/a1b23364-34cb-4b2c-9629-0770c1d22ff0 for this code 
' *****************************
Function WMIClassExists(strComputer, strValue)
                WMIClassExists = vbFalse
                Set WMINamespace = GetObject("winmgmts:\\" & strComputer & "\root\cimv2\" & strWMINamespace)
                Set colClasses = WMINamespace.SubclassesOf()
                For Each objClass In colClasses
                      If instr(objClass.Path_.Path,strValue) Then
                            WMIClassExists = vbTrue
                      End if
                Next
                Set colClasses = Nothing
End Function  
 

    
' *****************************  
' Sub: PopulateWMIClass
' *****************************
Sub PopulateWMIClass    
    'Create an instance of the WMI class using SpawnInstance_
    Set WMINamespace = GetObject("winmgmts:\\" & strComputer & "\root\cimv2\" & strWMINamespace)
    Set objGetClass = WMINamespace.Get(strWMIClassNoQuotes)
    Set objNewInstance = objGetClass.SpawnInstance_
    objNewInstance.Name = Rtrim(JobName)
    objNewInstance.JobStatus = FinalJobStatus
    objNewInstance.JobStatusDescription = JobStatusDescription
    objNewInstance.VolumeStatus = VolumeStatus
    objNewInstance.RunningTimeElapsed = TotalTime
    objNewInstance.RunningTimeRemaining = remainingTime
    objNewInstance.RunningBytesPerSecond = bytesPerSecond
    objNewInstance.StartTime = startTime
    objNewInstance.LastScriptExecutionDate = Date & " - " & Time
    objNewInstance.LastBackupActivityDate = StrLastJobTime
    
    ' Write the instance into the WMI repository
    objNewInstance.Put_()
End Sub


' *****************************  
' Sub: PopulateWMIClassTime
' *****************************
Sub PopulateWMIClassTime    
    'Create an instance of the WMI class using SpawnInstance_
    Set WMINamespace = GetObject("winmgmts:\\" & strComputer & "\root\cimv2\" & strWMINamespace)
    Set objGetClass = WMINamespace.Get(strWMIClassNoQuotesTime)
    Set objNewInstance = objGetClass.SpawnInstance_
    objNewInstance.LastScriptExecutionDate = Date & " - " & Time
    objNewInstance.LastBackupActivityDate = StrLastJobTime
    objNewInstance.MinutesSinceLastBackupActivity = IntMinuteSinceLastActivity 
    objNewInstance.LastBackupFileName = StrLastBackupFile
	output.writeline IntMinuteSinceLastActivity 
    output.writeline "Populating the Time WMI Class with the data."
    
    ' Write the instance into the WMI repository
    objNewInstance.Put_()
End Sub

Sub ShowJobNames
	' This 'For' loop finds each Backup job that is running and dumps its data into WMI.  
	Set ShadowProtect = CreateObject ("ShadowStor.ShadowProtect")
	output.writeline
	output.writeline
	output.writeline
	output.writeline "Jobs that can be configured for monitoring in N-central are:"
	For Each Job in ShadowProtect.Jobs
		If Job.IsBackup Then
			JobName = Job.Description
			output.writeline "   " & JobName
		End if
	Next
End Sub