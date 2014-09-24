How to install custom services on 9.4 or earlier version

1. Login to the admin console of your N-central server

2. Click the "Custom Services" link

3. Click the "Import Service" button

4. Click the Browse button beside "Service File"

5. Select the custom service XML file

6. Click the Import button

on 9.5:

1. Login to your N-central server

2. Select Customer Level.

3. Click the "Administration " Drop Menu.

3. Click the "Service management".

3. Click the "Custom Services".

4. Click Import.

5. Select the custom service XML file

6. Click the Import Custom Service button.

----------------------------------------------------------------------------------------------

To run custom service for SQL 2014.

If you have installed SQL 2014 instance as MSSQLserver no changes are necessary. Just import and add the device.

If your have installed SQL 2014 instance with a different name; you would need to change the WMI Class according to the instance name.

To get instance name of SQL server you can look in registry using regedit under HKEY_LOCAL_MACHINE\Software\Microsoft\Microsoft SQL Server\Instance Names\SQL

To change the WMI click on service detail of each service.

-----------------------------------------------------------------------------------

SQL 2014 Database Information Service

WMIClass : Win32_PerfFormattedData_MSSQLSERVER_SQLServerDatabases

changes for instance named other than MSSQLSERVER; Replace MSSQLServer and SQLServer with MSSQL<instance name>

example : If instance name is "test" this is how the class should look like replaced with MSSQLTEST

WMIClass : Win32_PerfFormattedData_MSSQLTEST_MSSQLTESTDatabases

--------------------------------------------------------------

SQL 2014 Memory Manager

WMIClass : Win32_PerfFormattedData_MSSQLSERVER_SQLServerMemoryManager

changes for instance named other than MSSQLSERVER; Replace MSSQLServer and SQLServer with MSSQL<instance name>

xample : If instance name is "test" this is how the class should look like replaced with MSSQLTEST

WMIClass : Win32_PerfFormattedData_MSSQLTEST_MSSQLTESTMemoryManager

----------------------------------------------------------------

SQL 2014 Server - Buffer Manager

WMIClass : Win32_PerfFormattedData_MSSQLSERVER_SQLServerBufferManager

changes for instance named other than MSSQLSERVER; Replace MSSQLServer and SQLServer with MSSQL<instance name>

Example : If instance name is "test" this is how the class should look like replaced with MSSQLTEST

WMIClass : Win32_PerfFormattedData_MSSQLTEST_MSSQLTESTBufferManager

----------------------------------------------------------------

SQL 2014 Server Locks

WMIClass : Win32_PerfFormattedData_MSSQLSERVER_SQLServerLocks

changes for instance named other than MSSQLSERVER; Replace MSSQLServer and SQLServer with MSSQL<instance name>

Example : If instance name is "test" this is how the class should look like replaced with MSSQLTEST

WMIClass : Win32_PerfFormattedData_MSSQLSERVER_SQLServerBufferManager

----------------------------------------------------------------

SQL 2014 Transaction Information

This service has 3 WMI class that has to change


WMIClass : Win32_PerfFormattedData_MSSQLSERVER_SQLServerLatches
WMIClass : Win32_PerfFormattedData_MSSQLSERVER_SQLServerAccessMethods
WMIClass : Win32_PerfFormattedData_MSSQLSERVER_SQLServerGeneralStatistics

changes for instance named other than MSSQLSERVER; Replace MSSQLServer and SQLServer with MSSQL<instance name>

Example : If instance name is "test" this is how the class should look like replaced with MSSQLTEST

WMIClass : Win32_PerfFormattedData_MSSQLTEST_MSSQLTESTLatches
WMIClass : Win32_PerfFormattedData_MSSQLTEST_MSSQLTESTAccessMethods
WMIClass : Win32_PerfFormattedData_MSSQLTEST_MSSQLTESTGeneralStatistics

-----------------------------------------------------------------





