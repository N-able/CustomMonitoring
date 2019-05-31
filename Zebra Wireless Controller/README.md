Created by Robby Swartenbroekx (robbys@b-inside.be)
Requires minimum nCentral 11.0

The is a Service Template and a Custom Service to monitor a Zebra Wireless controller (tested with RFS4000) to monitor itself and it's access points. It uses SNMP discovered assets to automatically add all access points.

Just import the service template (Zebra Wireless Controller.zip), custom services that are needed will also be imported with it.

Afterwards you can create a rule to automatically add this to RFS's or do this manually. You need to set SNMP info correct (so it needs to be a professional license) and do an asset update. You need to redo the asset update after the custom service and service template are imported, this way it searches in the right OID's.
