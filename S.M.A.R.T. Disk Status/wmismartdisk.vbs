Dim objWMI : Set objWMI = GetObject("winmgmts:\\.\root\wmi")
Dim inames : Set inames = objWMI.ExecQuery("Select * from MSStorageDriver_FailurePredictStatus")
For Each iname in inames
 WScript.StdOut.WriteLine iname.InstanceName
Next
