# Windows 10 Feature Update monitoring suite
This suite of 3 monitors provides visibility on:
* **FU Status Check**: Windows 10 feature update error codes it is encountering, the failure and rollback counts
* **FU Release**: A simple Windows 10 feature update release id validation check
* **FU BCD CheckV2**: A Boot Configuration Data health check to find devices where Windows 10 has left remnants, or has left it in a bad state that is causing boot errors.

## FU Status Check
The FU Status check provides a metrics on a number of important registry key values that the Windows 10 feature update _often_ writes for information purpose. These include:
* Failure count
* Install attempts
* Setup host Result
* Box Result
* Rollback count

These values generally relate to where in the update phases it reached, in the below exmaple where the disk space is no sufficient, windows has failed many times in attempting to update, there is no rollback value as it never reached a downlevel phase and rolled back during the migration.

The author notes that Microsoft _often_ updates these keys but doesn't always, I have also provided FU Clear Status.amp to run against devices, run it with a certain release id below which is delete the HKLM:\SYSTEM\Setup\MoSetup key where Microsoft keeps the status data.

![image](https://user-images.githubusercontent.com/17693460/119506497-4f2ad400-bdb1-11eb-9438-7ab95cfffb39.png)

## FU Release
The FU release checks HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion ReleaseId registry key value, and checks it against your defined release id tresholds

![image](https://user-images.githubusercontent.com/17693460/119507169-f0198f00-bdb1-11eb-842d-b7368faac886.png)

The author notes that at time of writing Microsoft is starting to deprecate the release id, and the status monitor will be updated to reflect that.

## FU BCD CheckV2
An upgraded version of the "Feature Upgrade BCD Issue" by Andrew Hurl of Presilient, this status monitor parses the Boot Configuration Data (BCD) for boot configuration data left over by the feature upgrade process. If the status monitor is yellow, it means that there is remnant configuration entries but they do not effect the bootup. 

![image](https://user-images.githubusercontent.com/17693460/119508589-31f70500-bdb3-11eb-8ddf-14601e164b48.png)

If the monitor is red it means that the boot configuration is misconfigured/malformed and is effecting the boot up of the device. In most cases if there is a bad boot config users can hit escape a few times and get past these boot issues, sometimes not.

![image](https://user-images.githubusercontent.com/17693460/119508688-4935f280-bdb3-11eb-8ec6-093f38b5de8e.png)

### Deployment Notes
When deploying the custom service via Service Template, **turn off** the threshold for the "Boot Path" value as this is for diagnostics purposes only, you will expect to see \Windows\system32\winload.exe for BIOS boot devices and \Windows\system32\winload.efi for EFI boot devices.

### Remdiation Nots
If you do encounter a broken boot configuration, a way in which you may resolve the issue is to:
1. Backup the BCD! `bcdedit /export C:\temp\bcd.bak`
2. Get the list of all the boot configuration entries with `bcdedit /enum /v`
3. Go through the output and get the identifiers for the bad entries, their entry names are typically entries with **$WINDOWS.~BT** in their path values.
4. For each bad boot entry delete it. ie. `bcdedit /delete {7254a080-1510-4e85-ac0f-e7fb3d444736}`
5. Set the boot manager default entry to point to the correct Windows Boot Loader, this is one where the path is \Windows\system32\winload.efi `bcdedit /set {bootmgr} default {current}`
