Removable Disk Cycle
====================

Author: James Weakley, Diamond IT. jweakley@diamondgroup.net.au

A script and accompanying custom service which ensures that removable USB drives are being cycled on a machine.

The script maintains a list of all seen removable USB drives which have the Quick Removal policy enabled. This acts as the flag for a disk which should be regularly cycled.

Each time it runs, it updates the last seen and last not seen times for each disk, and stores them in an instance of root\cimv2\NCentral\RemovableMediaInstanceInfo.

Then it determines which currently connected disk has been connected the longest, and calculates how many minutes since it was last removed (i.e. not seen by the script). This information is stored in a single instance of root\cimv2\NCentral\RemovableMediaInstanceInfo which is where the custom service retrieves its values from.

Notes:
- On a system with no drives that match the criteria, the service will sit in a Normal state.
- When a new disk is added which matches the criteria, the initial insertion is also considered a removal. This is to prevent alarms when new disks are inserted.

