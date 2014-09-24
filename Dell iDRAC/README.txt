Dell iDRAC Service Description

The Dell iDRAC service return an INTEGER or ENUM for some settings. In order to understand the value returned and change the mappings, the MIB description for each setting has to be available .

This document explain each custom settings taken from iDRAC MIB and their mapping on the current provided service:

--------------------------------------------------------------------------------------------------------------------------------------------------------------
1.
Name of Service: Power Supply ( Dell iDRAC)

Custom Settings:

status:
ObjectStatusEnum (INTEGER) {other(1), unknown(2), ok(3), nonCritical(4), critical(5), nonRecoverable(6) }

Current Mapping in custom Service:
Normal : 3
Warning : 4
Failed : All Other values

---------------------------------------------------------------------------------------------------------------------------------------------------------------
2.
Name of Service: System battery status ( Dell iDRAC)

Custom Settings:

status:
ObjectStatusEnum (INTEGER) {other(1), unknown(2), ok(3), nonCritical(4), critical(5), nonRecoverable(6) }

Current Mapping in custom Service:
Normal : 3
Warning : 4
Failed : All Other values
-----------------------------------------------------------------------------------------------------------------------------------------------------------------
3.
Name of Service: Temperature status ( Dell iDRAC)

Custom Settings:

Status:
ObjectStatusEnum (INTEGER) {other(1), unknown(2), ok(3), nonCritical(4), critical(5), nonRecoverable(6) }

Current Mapping in custom Service:
Normal : 3
Warning : 4
Failed : All Other values
-----------------------------------------------------------------------------------------------------------------------------------------------------------------
4.
Name of Service: Chassis Intrusion ( Dell iDRAC)

Custom Settings:

Reading:
DellIntrusionReading  (INTEGER) {chassisNotBreached(1), chassisBreached(2), chassisBreachedPrior(3), chassisBreachSensorFailure(4) }

Current Mapping in custom Service:
Normal : 1
Failed : All Other values

Status:
DellStatus (INTEGER) {other(1), unknown(2), ok(3), nonCritical(4), critical(5), nonRecoverable(6) }

Current Mapping in custom Service:
Normal : 3
Warning : 4
Failed : All Other values

The following are Displayed as String.
Type:
DellIntrusionType (INTEGER) {chassisBreachDetectionWhenPowerON(1), chassisBreachDetectionWhenPowerOFF(2) }

Settings:
DellStateSettings (INTEGER) {unknown(1), enabled(2), notReady(4), enabledAndNotReady(6) }

-----------------------------------------------------------------------------------------------------------------------------------------------------------------
5.
Name of Service : Network Card (Dell iDRAC)

Status:
NetworkDeviceConnectionStatusEnum (INTEGER) {connected(1), disconnected(2), driverBad(3), driverDisabled(4), hardwareInitalizing(10), hardwareResetting(11), hardwareClosing(12), hardwareNotReady(13) }

Current Mapping in custom Service:
Normal : 1
Failed : All Other values

Status:
DellStatus (INTEGER) {other(1), unknown(2), ok(3), nonCritical(4), critical(5), nonRecoverable(6)

Current Mapping in custom Service:
Normal : 3
Warning : 4
Failed : All Other values

-----------------------------------------------------------------------------------------------------------------------------------------------------------------
6.
Name of Service: CPU status ( Dell iDRAC)

Custom Settings:

Status:
ObjectStatusEnum (INTEGER) {other(1), unknown(2), ok(3), nonCritical(4), critical(5), nonRecoverable(6) }

Current Mapping in custom Service:
Normal : 3
Warning : 4
Failed : All Other values

-------------------------------------------------------------------------------------------------------------------------------------------------------------------
7.
Name of Service: Memory  (Dell iDRAC)

Custom Settings:

Status:
ObjectStatusEnum (INTEGER) {other(1), unknown(2), ok(3), nonCritical(4), critical(5), nonRecoverable(6) }

Current Mapping in custom Service:
Normal : 3
Warning : 4
Failed : All Other values

-------------------------------------------------------------------------------------------------------------------------------------------------------------------
8.
Name of Service: BOIS  (Dell iDRAC)

Custom Settings:

Status:
ObjectStatusEnum (INTEGER) {other(1), unknown(2), ok(3), nonCritical(4), critical(5), nonRecoverable(6) }

Current Mapping in custom Service:
Normal : 3
Warning : 4
Failed : All Other values

---------------------------------------------------------------------------------------------------------------------------------------------------------------------
9.
Name of Service: Temperature probe (Dell iDRAC)

Custom Settings:

Status:
StatusProbeEnum (INTEGER) {other(1), unknown(2), ok(3), nonCriticalUpper(4), criticalUpper(5), nonRecoverableUpper(6), nonCriticalLower(7), criticalLower(8), nonRecoverableLower(9), failed(10) }

Current Mapping in custom Service:
Normal : 3
Failed : All Other values

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
10.
Name of Service: Physical Drive (Dell iDRAC)

State:
INTEGER {unknown(1),ready(2),online(3),foreign(4),offline(5),blocked(6),failed(7),non-raid(8),removed(9)}

Current Mapping in custom Service:
Normal : 3
Warning : 2
Failed : All Other values

Smart Alert:
Syntax	 BooleanType (INTEGER) (0..1)

Current Mapping in custom Service:
Normal : 0
Failed :  All Other values












