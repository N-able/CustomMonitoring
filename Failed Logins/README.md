# Failed Logins for N-able nCentral

This is a monitoring Service Template for Failed Logins functionality in N-able nCentral (as prebuild seen in N-able RMM)

## Installation

you only need the 3 zip files _(yes, for each class we still need to create one sperate Service Template)_ if you want to install it fast in your N-able nCentral. Import these and you are good to go.
Probably, you want to make a filter to target devices you would like to activate this on and create a rule to combine the filter and one or more of these Service Templates.

## Extra files

the Automation Manager Policy (.amp) is the raw script I used. It is just a wrapper for the Powershell script (.ps1) itself. if you want to make changes to it for your environment, you need this file (or you extract it from your nCentral after installing the Service Templates).

## Release Notes

1.0|2021/10/25|Initial Release (25/10/2021)
1.1|2021/10/25|Changed from Get-EventLog to Get-WinEvent and worked with FilterHashTable to speedup requests even more. I've tested on some servers with multiple Gb's of event logs and went in the most extreme case van 12 minutes to 37 seconds. or on more normal servers from 63,9 seconds to 2,6 seconds

## License

This work is licensed under Creative Commons Attribition 4.0 International (CC BY 4.0) - https://creativecommons.org/licenses/by/4.0/
This means, you can do with it whatever you want, as long as you give credits for it to me, Robby Swartenbroekx, https://github.com/Robby-Swartenbroekx