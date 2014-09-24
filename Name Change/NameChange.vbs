
' NameChange.vbs
' Designed to be run once a day.  Grabs the name of the device it runs on and stores it in WMI.  Next time it runs
' it looks at the name again and compares it to the stored version.  If the names differ, the device has changed name.
' It then writes a value into WMI which the "Name Change" service picks up on in N-central
'
' RECOMMENDED:  If you alert on this service it is recommended that you turn OFF the option in the notification to
'               "Notify on return to normal" and give the notification a 0 minute delay.  The service will transition
'               to a fail state when the name change is detected but will return to a normal state the next time the
'               script runs.

' By Tim Wiser, Orchid IT (July 2012)
' Uses code lifted from Chris Reid's AVstatus.vbs as well as other sources online - credits given where due



option explicit

dim wbemCimtypeString, wbemCimtypeBoolean, wbemCimtypeUint32
dim strComputer, strWMINamespace, strNamespace, strWMIClassWithQuotes, strWMIClassNoQuotes, strStoredComputerName, strComputerName
dim ParentWMINamespace, objWMISvc, objItem, objNamespace, objWMIOrchid, WMINamespace, objWMIService, objClassCreator, objWMI, objData, objInstance, objNewNamespace
dim colItems, colNamespaces, colClasses, objClasses, objClass, objGetClass, objNewInstance

strComputer = "."
strWMINamespace = "ncentral"
strNamespace = "root\cimv2\ncentral"
strWMIClassWithQuotes = chr(34) & "NameChange" & chr(34)
strWMIClassNoQuotes = "NameChange"
wbemCimtypeString = 8
wbemCimtypeUint32 = 19
wbemCimtypeBoolean = 11

Set ParentWMINamespace = GetObject("winmgmts:\\" & strComputer & "\root\cimv2")

Set objWMISvc = GetObject( "winmgmts:\\.\root\cimv2" )
Set colItems = objWMISvc.ExecQuery( "Select * from Win32_ComputerSystem", , 48 )
For Each objItem in colItems
    strComputerName = objItem.Name
Next

wscript.echo "Current device name is " & strComputerName

' Check to see if the namespace exists.  If not, create it
If WMINamespaceExists(ParentWMINamespace, strWMINamespace) then
	wscript.echo "The namespace already exists"
else
	wscript.echo "The namespace does not exist - Creating it now"
	CreateWMINamespace
end if


' Check to see if the class exists.  If not, create it
If WMIClassExists(strComputer, strWMIClassWithQuotes) Then
	wscript.echo "The class exists"
else
	wscript.echo "The class doesn't exist - creating it now"
	CreateWMIClass
	PopulateWMIClass
end if


' OK, so if we get this far we have a namespace and a class to read from.
' Now we need to read the stored name for the device from WMI and compare it with the live name
Set objWMISvc = GetObject( "winmgmts:\\.\root\cimv2\ncentral" )
Set colItems = objWMISvc.ExecQuery( "Select * from NameChange WHERE index = 1", , 48 )
For Each objItem in colItems
    strStoredComputerName = objItem.StoredName
	wscript.echo "The name stored in WMI is " & strStoredComputerName
Next

if strStoredComputerName <> strComputerName then
	wscript.echo "The computer name has changed!"
	Set objWMI = GetObject("winmgmts:root\cimv2\ncentral") 
	Set objData = objWMI.Get("NameChange") 
	Set objInstance = objData.SpawnInstance_ 
		objInstance.Index = 1
		objInstance.NameHasChanged = True
		objInstance.StoredName = strComputerName
		objInstance.Put_()
else
	wscript.echo "The names are the same"
	Set objWMI = GetObject("winmgmts:root\cimv2\ncentral") 
	Set objData = objWMI.Get("NameChange") 
	Set objInstance = objData.SpawnInstance_ 
		objInstance.Index = 1
		objInstance.NameHasChanged = False
		objInstance.StoredName = strComputerName
		objInstance.Put_()
end if







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
    
    objClassCreator.Properties_.add "StoredName", wbemCimtypeString
    objClassCreator.Properties_.add "NameHasChanged", wbemCimtypeBoolean
	objClassCreator.Properties_.add "Index", wbemCimtypeUint32
	
	objClassCreator.Properties_("Index").Qualifiers_.add "key", true
                           
    ' Write the new class
    objClassCreator.Put_

End Sub
    
    
' *****************************  
' Function: WMINamespaceExists
' Thanks to http://www.cruto.com/resources/vbscript/vbscript-examples/misc/wmi/List-All-WMI-Namespaces.asp for this code 
' *****************************
Function WMINamespaceExists(ParentWMINamespace,WMINamespace)
                WMINamespaceExists = vbFalse
                Set colNamespaces = ParentWMINamespace.InstancesOf("__Namespace")
                For Each objNamespace In colNamespaces
                      If instr(objNamespace.Path_.Path,WMINamespace) Then
                            WMINamespaceExists = vbTrue                        
					  End if
                Next
                Set colNamespaces = Nothing
End Function


  


' *****************************  
' Function: WMIClassExists
' Thanks to http://gallery.technet.microsoft.com/ScriptCenter/en-us/a1b23364-34cb-4b2c-9629-0770c1d22ff0 for this code 
' *****************************
Function WMIClassExists(strComputer, strWMIClassWithQuotes)
                WMIClassExists = vbFalse
                Set WMINamespace = GetObject("winmgmts:\\" & strComputer & "\root\cimv2\" & strWMINamespace)
                Set colClasses = WMINamespace.SubclassesOf()
                For Each objClass In colClasses
                      If instr(objClass.Path_.Path,strWMIClassNoQuotes) Then
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
    objNewInstance.StoredName = strComputerName
	objNewInstance.Index = 1
    objNewInstance.NameHasChanged = False
        
    ' Write the instance into the WMI repository
    objNewInstance.Put_()
End Sub




