#include "mxrobotdefs.inc"
#include "networkdefs.inc"
#include "genericdefs.inc"
#include "mountingdefs.inc"

Global Preserve Integer g_InterestedCassettePosition
Global Preserve Integer g_InterestedPuckColumnIndex
Global Preserve Integer g_InterestedRowPuckPortIndex
Global Preserve Integer g_InterestedSampleStatus

Function GTGonioReachable As Boolean
	'' Check if robot can reach goniometer
	GTGonioReachable = True
Fend

Function GTSetGoniometerPoints(dx As Real, dy As Real, dz As Real, du As Real) As Boolean

	'' P21 is the real goniometer point which will be used for robot movement
	P21 = P20 +X(dx) +Y(dy) +Z(dz) +U(du)

	'' P24 is the point	to move to detach goniometer head along gonio orientation
	Real detachDX, detachDY
	detachDX = GONIO_MOUNT_STANDBY_DISTANCE * g_goniometer_cosValue
	detachDY = GONIO_MOUNT_STANDBY_DISTANCE * g_goniometer_sinValue
	P24 = P21 +X(detachDX) +Y(detachDY)

	'' P23 downstream shift from P21. P23 is the dismount standby point
	Real sideStepDX, sideStepDY
	sideStepDX = GONIO_DISMOUNT_SIDEMOVE_DISTANCE * g_goniometer_cosValue
	sideStepDY = GONIO_DISMOUNT_SIDEMOVE_DISTANCE * g_goniometer_sinValue
	P23 = P21 +X(sideStepDX) +Y(sideStepDY)
	
	'' X,Y coordinates of P22 is the corner of the rectangle P24-P21-P23
	'' P22 is the Mount/Dismount point on Gonio
	P23 = P21 +X(detachDX + sideStepDX) +Y(detachDY + sideStepDY) :Z(-1)
	
	If Not GTGonioReachable Then
		String msg$
		msg$ = "GTSetGoniometerPoints: GTGonioReachable returned false!"
		UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
		GTSetGoniometerPoints = False
		Exit Function
	EndIf

	GTSetGoniometerPoints = True
Fend

Function GTsetMountPort(cassette_position As Integer, puckColumnIndex As Integer, rowPuckPortIndex As Integer) As Boolean
	'' This function returns false if the port supplied is Invalid or if there is no sample in that port
	GTsetMountPort = False
	
	g_InterestedCassettePosition = cassette_position
	g_InterestedPuckColumnIndex = puckColumnIndex
	g_InterestedRowPuckPortIndex = rowPuckPortIndex
	g_InterestedSampleStatus = SAMPLE_STATUS_UNKNOWN
	
	If (g_CassetteType(cassette_position) = NORMAL_CASSETTE) Or (g_CassetteType(cassette_position) = CALIBRATION_CASSETTE) Then
		If g_CAS_PortStatus(cassette_position, rowPuckPortIndex, puckColumnIndex) = PORT_OCCUPIED Then
			g_InterestedSampleStatus = SAMPLE_IN_CASSETTE
			GTsetMountPort = True
		EndIf
	ElseIf g_CassetteType(cassette_position) = SUPERPUCK_CASSETTE Then
		If g_SP_PortStatus(cassette_position, puckColumnIndex, rowPuckPortIndex) = PORT_OCCUPIED Then
			g_InterestedSampleStatus = SAMPLE_IN_CASSETTE
			GTsetMountPort = True
		EndIf
	EndIf
	
	GTsendSampleStateJSON
Fend

Function GTMoveToInterestPortStandbyPoint
	'' GTMoveTo<___>MountPortStandbyPoint sets the standby points and intermediate points
	If (g_CassetteType(g_InterestedCassettePosition) = NORMAL_CASSETTE) Or (g_CassetteType(g_InterestedCassettePosition) = CALIBRATION_CASSETTE) Then
		GTMoveToCASMountPortStandbyPoint(g_InterestedCassettePosition, g_InterestedRowPuckPortIndex, g_InterestedPuckColumnIndex)
	ElseIf g_CassetteType(g_InterestedCassettePosition) = SUPERPUCK_CASSETTE Then
		GTMoveToSPMountPortStandbyPoint(g_InterestedCassettePosition, g_InterestedPuckColumnIndex, g_InterestedRowPuckPortIndex)
	EndIf
Fend

Function GetSampleFromInterestPort As Boolean
	Integer portStandbyPoint
	Integer portStatusBeforePickerCheck
	
	portStandbyPoint = 52

	If (g_CassetteType(g_InterestedCassettePosition) = NORMAL_CASSETTE) Or (g_CassetteType(g_InterestedCassettePosition) = CALIBRATION_CASSETTE) Then
		GTPickerCheckCASPortStatus(g_InterestedCassettePosition, g_InterestedRowPuckPortIndex, g_InterestedPuckColumnIndex, portStandbyPoint, ByRef portStatusBeforePickerCheck)
	ElseIf g_CassetteType(g_InterestedCassettePosition) = SUPERPUCK_CASSETTE Then
		GTPickerCheckSPPortStatus(g_InterestedCassettePosition, g_InterestedPuckColumnIndex, g_InterestedRowPuckPortIndex, portStandbyPoint, ByRef portStatusBeforePickerCheck)
	EndIf

	GetSampleFromInterestPort = False
	If portStatusBeforePickerCheck = PORT_OCCUPIED Then
		g_InterestedSampleStatus = SAMPLE_IN_PICKER
		GetSampleFromInterestPort = True
	ElseIf portStatusBeforePickerCheck = PORT_VACANT Then
		g_InterestedSampleStatus = SAMPLE_STATUS_UNKNOWN
	Else
		''If portStatusBeforePickerCheck = PORT_ERROR Then
		g_InterestedSampleStatus = SAMPLE_STATUS_UNKNOWN
	EndIf
	
	GTsendSampleStateJSON
Fend

Function GTMoveBackToCassetteStandbyPoint
	'' GTMoveTo<___>MountPortStandbyPoint sets the standby points and intermediate points
	If (g_CassetteType(g_InterestedCassettePosition) = NORMAL_CASSETTE) Or (g_CassetteType(g_InterestedCassettePosition) = CALIBRATION_CASSETTE) Then
		GTMoveBackToCASStandbyPoint
	ElseIf g_CassetteType(g_InterestedCassettePosition) = SUPERPUCK_CASSETTE Then
		GTMoveBackToSPStandbyPoint
	EndIf
Fend

Function GTMoveCassetteStandbyToCradle
	Tool 0
	GTsetRobotSpeedMode(INSIDE_LN2_SPEED)
	
	Real desiredX, desiredY, desiredZ
	desiredX = (CX(P4) + CX(RealPos)) / 2.0
	desiredY = (CY(P4) + CY(RealPos)) / 2.0
	
	'' desiredZ = maximum of CZ(P4) and CZ(RealPos)
	If CZ(P4) > CZ(RealPos) Then
		desiredZ = CZ(P4)
	Else
		desiredZ = CZ(RealPos)
	EndIf
	
	LimZ desiredZ + 5.0
	
	P49 = XY(desiredX, desiredY, desiredZ, CU(RealPos)) /R
	
	Move P49
	Jump P4
	
	LimZ g_Jump_LimZ_LN2
Fend

Function GTCavityGripSampleFromPicker As Boolean
	''GripSample in Cavity From Picker of dumbbell in cradle
	''Starts from P3

	GTCavityGripSampleFromPicker = False
	
	''GTCheckSampleInCradlePicker closes gripper before checking
	''If GTCheckSampleInCradlePicker Then
		If Not Open_Gripper Then
			UpdateClient(TASK_MSG, "GTCavityGripSampleFromPicker:Open_Gripper failed", ERROR_LEVEL)
			Exit Function
		EndIf
		
		Arc P15, P16

		If Not Close_Gripper Then
			UpdateClient(TASK_MSG, "GTCavityGripSampleFromPicker:Close_Gripper failed", ERROR_LEVEL)
			Exit Function
		EndIf
		
		TwistRelease
		
		g_InterestedSampleStatus = SAMPLE_IN_CAVITY
		GTsendSampleStateJSON
		GTCavityGripSampleFromPicker = True
	''EndIf
Fend

Function GTReleaseSampleToGonio As Boolean
	''Releases sample from cavity to Goniometer
	''starts from P22
	GTReleaseSampleToGonio = False

	'' Probe speed is the slowest speed so use it around GONIO
	GTsetRobotSpeedMode(PROBE_SPEED)

	Move P24
	Move P21
	
	If Not Open_Gripper Then
		UpdateClient(TASK_MSG, "GTReleaseSampleToGonio:Open_Gripper failed", ERROR_LEVEL)
		Exit Function
	EndIf
		
	g_InterestedSampleStatus = SAMPLE_IN_GONIO
	GTsendSampleStateJSON
	
	'' if tongConflict code not included here
	
	Move P23

	'' move closer to robot to avoid directly above sample and disturbing the air
	'' move away from goniometer by 40mm while raising to P22
	Move P22 +X(40.0 * g_goniometer_cosValue) +Y(40.0 * g_goniometer_sinValue)
	
	'' Close_Gripper check is not required because it is moving to heater after this step anyway
	Close_Gripper
	
	GTReleaseSampleToGonio = True
Fend

Function GTMountInterestedPort As Boolean
	'' GTMountInterestedPort should start with dumbbell in gripper usually from P3
	
	GTMountInterestedPort = False
	
	Tool PICKER_TOOL
	GTsetRobotSpeedMode(INSIDE_LN2_SPEED)
	
	'' GTMoveToInterestPortStandbyPoint sets the standby points and intermediate points
	GTMoveToInterestPortStandbyPoint
	
	If Not GetSampleFromInterestPort Then
		g_RunResult$ = "GetSampleFromInterestPort failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
		
	GTMoveBackToCassetteStandbyPoint
	GTMoveCassetteStandbyToCradle
	
	'' Put dumbbell in Cradle
	If Not GTReturnMagnet Then
		g_RunResult$ = "GTReturnMagnet failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	''GripSample in Cavity From Picker of dumbbell in cradle
	If Not GTCavityGripSampleFromPicker Then
		g_RunResult$ = "GTCavityGripSampleFromPicker failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	If Not GTMoveToGoniometer Then
		g_RunResult$ = "GTMoveToGoniometer failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	If Not GTReleaseSampleToGonio Then
		g_RunResult$ = "GTReleaseSampleToGonio failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	If Not GTMoveGoniometerToDewarSide Then
		g_RunResult$ = "GTMoveGoniometerToDewarSide failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	''Return Home
	GTGoHome
	
	GTMountInterestedPort = True
Fend

''' *** Dismounting Code Starts Here *** '''

Function GTsetDismountPort(cassette_position As Integer, puckColumnIndex As Integer, rowPuckPortIndex As Integer) As Boolean
	'' This function returns false if the port supplied is Invalid or if there is no sample in that port
	GTsetDismountPort = False
	
	g_InterestedCassettePosition = cassette_position
	g_InterestedPuckColumnIndex = puckColumnIndex
	g_InterestedRowPuckPortIndex = rowPuckPortIndex
	g_InterestedSampleStatus = SAMPLE_STATUS_UNKNOWN
	
	If (g_CassetteType(cassette_position) = NORMAL_CASSETTE) Or (g_CassetteType(cassette_position) = CALIBRATION_CASSETTE) Then
		If g_CAS_PortStatus(cassette_position, rowPuckPortIndex, puckColumnIndex) = PORT_VACANT Then
			g_InterestedSampleStatus = SAMPLE_IN_GONIO
			GTsetDismountPort = True
		EndIf
	ElseIf g_CassetteType(cassette_position) = SUPERPUCK_CASSETTE Then
		If g_SP_PortStatus(cassette_position, puckColumnIndex, rowPuckPortIndex) = PORT_VACANT Then
			g_InterestedSampleStatus = SAMPLE_IN_GONIO
			GTsetDismountPort = True
		EndIf
	EndIf
	
	GTsendSampleStateJSON
Fend

Function GTCavityGripSampleFromGonio As Boolean
	''GripSample in Cavity From Goniometer
	''Starts from P22

	GTCavityGripSampleFromGonio = False
	
	Move P23
	
	If Not Open_Gripper Then
		UpdateClient(TASK_MSG, "GTCavityGripSampleFromGonio:Open_Gripper failed", ERROR_LEVEL)
		Exit Function
	EndIf

	'' if tongConflict code not included here

	Move P21

	If Not Close_Gripper Then
		UpdateClient(TASK_MSG, "GTCavityGripSampleFromGonio:Close_Gripper failed", ERROR_LEVEL)
		Exit Function
	EndIf
	
	g_InterestedSampleStatus = SAMPLE_IN_CAVITY
	GTsendSampleStateJSON
	
	Move P24
	
	Move P22
	
	GTCavityGripSampleFromGonio = True
Fend

Function GTMoveGoniometerToPlacer
	If Not Close_Gripper Then
		UpdateClient(TASK_MSG, "GTMoveGoniometerToPlacer:Close_Gripper failed", ERROR_LEVEL)
		Exit Function
	EndIf
	
	GTsetRobotSpeedMode(OUTSIDE_LN2_SPEED)
	
   	Move P18 CP
	
	Move P27 :Z(0)
	
	GTsetRobotSpeedMode(INSIDE_LN2_SPEED)

	Move P27
Fend

Function GTReleaseSampleToPlacer As Boolean
	''Releases sample from cavity to Placer on cradle
	''starts from P27
	GTReleaseSampleToPlacer = False

	GTsetRobotSpeedMode(INSIDE_LN2_SPEED)

	Move P26
	
	If Not Open_Gripper Then
		UpdateClient(TASK_MSG, "GTReleaseSampleToPlacer:Open_Gripper failed", ERROR_LEVEL)
		Exit Function
	EndIf
		
	g_InterestedSampleStatus = SAMPLE_IN_PLACER
	GTsendSampleStateJSON
	
	Arc P25, P94 CP

	'' move to
	Move P3
	
	GTReleaseSampleToPlacer = True
Fend

Function GTPutSampleIntoInterestPort As Boolean
	Integer portStandbyPoint
	portStandbyPoint = 52

	If (g_CassetteType(g_InterestedCassettePosition) = NORMAL_CASSETTE) Or (g_CassetteType(g_InterestedCassettePosition) = CALIBRATION_CASSETTE) Then
		GTPutSampleIntoInterestPort = GTPutSampleIntoCASPort(g_InterestedCassettePosition, g_InterestedRowPuckPortIndex, g_InterestedPuckColumnIndex, portStandbyPoint)
	ElseIf g_CassetteType(g_InterestedCassettePosition) = SUPERPUCK_CASSETTE Then
		GTPutSampleIntoInterestPort = GTPutSampleIntoSPPort(g_InterestedCassettePosition, g_InterestedPuckColumnIndex, g_InterestedRowPuckPortIndex, portStandbyPoint)
	EndIf
	
	GTsendSampleStateJSON
Fend

Function GTDismountToInterestedPort As Boolean
	'' GTDismountToInterestedPort should start without dumbbell in gripper usually from P18
	
	GTDismountToInterestedPort = False

	Tool 0
	GTsetRobotSpeedMode(OUTSIDE_LN2_SPEED)
	
	If Not GTMoveToGoniometer Then
		g_RunResult$ = "GTDismountToInterestedPort->GTMoveToGoniometer failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
		
	'' Probe speed is the slowest speed so use it around GONIO
	GTsetRobotSpeedMode(PROBE_SPEED)
	
	''GripSample in Cavity From Goniometer
	If Not GTCavityGripSampleFromGonio Then
		g_RunResult$ = "GTDismountToInterestedPort->GTCavityGripSampleFromGonio failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	GTMoveGoniometerToPlacer
		
	If Not GTReleaseSampleToPlacer Then
		g_RunResult$ = "GTDismountToInterestedPort->GTReleaseSampleToPlacer failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
			
	If Not GTPickMagnet Then
		g_RunResult$ = "GTDismountToInterestedPort->GTPickMagnet failed!"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	Tool PLACER_TOOL
	'' GTMoveToInterestPortStandbyPoint sets the standby points and intermediate points
	GTMoveToInterestPortStandbyPoint
		
	If Not GTPutSampleIntoInterestPort Then
		g_RunResult$ = "GTDismountToInterestedPort->GTPutSampleIntoInterestPort failed! Check log for further details."
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	GTMoveBackToCassetteStandbyPoint
	GTMoveCassetteStandbyToCradle
	
	GTDismountToInterestedPort = True
Fend

''*** Manually TroubleShooting Mounting/Dismounting errors ***

''This function puts the sample on placer (in cradle) back into interested port (Used when there are errors in mounting)
Function PutCradlePlacerSampleIntoPort As Boolean
	PutCradlePlacerSampleIntoPort = False
	
	Tool 0
	GTsetRobotSpeedMode(INSIDE_LN2_SPEED)
	
	If Not GTCheckAndPickMagnet Then
		g_RunResult$ = "PutCradlePlacerSampleIntoPort->GTCheckAndPickMagnet failed!"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	Tool PLACER_TOOL
	'' GTMoveToInterestPortStandbyPoint sets the standby points and intermediate points
	GTMoveToInterestPortStandbyPoint
		
	If Not GTPutSampleIntoInterestPort Then
		g_RunResult$ = "PutCradlePlacerSampleIntoPort->GTPutSampleIntoInterestPort failed! Check log for further details."
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	PutCradlePlacerSampleIntoPort = True
Fend

Function TransportSamplePickerToPlacer As Boolean
	TransportSamplePickerToPlacer = False
	
	'' Put dumbbell in Cradle
	If Not GTReturnMagnet Then
		g_RunResult$ = "TransportSamplePickerToPlacer->GTReturnMagnet failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	''GripSample in Cavity From Picker of dumbbell in cradle
	If Not GTCavityGripSampleFromPicker Then
		g_RunResult$ = "TransportSamplePickerToPlacer->GTCavityGripSampleFromPicker failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf

	''Arc via Cool Point to Placer Standby Point
	Arc P3, P27 CP
	
	If Not GTReleaseSampleToPlacer Then
		g_RunResult$ = "TransportSamplePickerToPlacer->GTReleaseSampleToPlacer failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	TransportSamplePickerToPlacer = True
Fend

