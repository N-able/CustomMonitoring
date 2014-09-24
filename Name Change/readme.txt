
 Service name: 	Name Change
      Purpose: 	Monitor for when the name of a device changes at the device end
      Authors: 	VBS - Tim Wiser, Orchid IT
	       	AMP - Wim Lamot, Accel Computer Service
	      	XML - Tim Wiser, Wim Lamot


 Description:	This service is intended to provide an alert when a device (server, workstation or
		laptop) is renamed by the end user.  As N-central does not currently have the ability
		to automatically update the Name field on a device (only Discovered Name) this can
		result in the device names shown in All Devices gradually becoming more and more 
		inaccurate.


Implementation:	Schedule the AMP (for N-central v9 onwards) or VBS (any version of N-central) to run
		on devices every day or every few hours.  Once the script runs it will pick up the
		current name of the device and store it.  The next time the script runs it compares
		the current name with the stored name and if they differ it will cause the "Name Change"
		service in N-central to transition to a fail state.

Recommendation:	We recommend that you configure a notification against this service with a 0 minute 
		delay and the option to "Notify on return to Normal" option DISABLED.  Once the 
		service is in a fail state it will return to normal the next time the script runs. 


       Contact: Tim Wiser, twiser@orchidit.com
		Wim Lamot, wim.lamot@accel.be


