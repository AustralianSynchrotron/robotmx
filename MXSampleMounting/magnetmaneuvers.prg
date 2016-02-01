#include "networkdefs.inc"
#include "forcedefs.inc"
#include "mxrobotdefs.inc"
#include "genericdefs.inc"
#include "superPuckdefs.inc"
#include "cassettedefs.inc"

#define CLOSE_DISTANCE 10

Function GTJumpHomeToCoolingPointAndWait As Boolean
	String msg$
	
	GTJumpHomeToCoolingPointAndWait = False

	If Not Open_Lid Then
		UpdateClient(TASK_MSG, "GTJumpHomeToCoolingPointAndWait:Open_Lid failed", ERROR_LEVEL)
        Exit Function
    EndIf
   
   	Motor On
   	Power High ''For debugging use low power mode
   	
	Tool 0
	GTsetRobotSpeedMode(OUTSIDE_LN2_SPEED)

	If (Dist(RealPos, P0) < CLOSE_DISTANCE) Then Jump P1
	
	Jump P3
	
	'' for testing only, should be put inside the below if statement
	GTsetRobotSpeedMode(INSIDE_LN2_SPEED)
	
	If g_LN2LevelHigh Then
		Integer timeTakenToCoolTong
		timeTakenToCoolTong = WaitLN2BoilingStop(SENSE_TIMEOUT, HIGH_SENSITIVITY, HIGH_SENSITIVITY)
		msg$ = "GTJumpHomeToCoolingPointAndWait: Cooled tong for " + Str$(timeTakenToCoolTong) + " seconds"
		UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
	EndIf
	
	GTJumpHomeToCoolingPointAndWait = True
Fend

Function GTIsMagnetInGripper As Boolean
	String msg$
	GTIsMagnetInGripper = False

	Tool 0

	'' Closing Gripper only matters because if Gripper is open we might loose magnet while hitting the cradle
	Close_Gripper

	Real probeDistanceFromCradleCenter
	probeDistanceFromCradleCenter = ((MAGNET_LENGTH /2) + (CRADLE_WIDTH /2) - (MAGNET_HEAD_THICKNESS /2)) * CASSETTE_SHRINK_FACTOR
	Integer standbyPoint
	standbyPoint = 52
	P(standbyPoint) = P3 -X(probeDistanceFromCradleCenter * g_dumbbell_Perfect_cosValue) -Y(probeDistanceFromCradleCenter * g_dumbbell_Perfect_sinValue)

	Jump P(standbyPoint)
	
	Real maxDistanceToScan
	maxDistanceToScan = DISTANCE_P3_TO_P6 + MAGNET_PROBE_DISTANCE_TOLERANCE
	
	GTsetRobotSpeedMode(PROBE_SPEED)
	
	ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY)
	If ForceTouch(DIRECTION_CAVITY_TO_MAGNET, maxDistanceToScan, False) Then
		'' Distance error from perfect magnet position
		Real distErrorFromPerfectMagnetPoint
		distErrorFromPerfectMagnetPoint = Dist(P(standbyPoint), RealPos) - (DISTANCE_P3_TO_P6 - (MAGNET_AXIS_TO_CRADLE_EDGE + MAGNET_HEAD_RADIUS))
		
		If distErrorFromPerfectMagnetPoint < -MAGNET_PROBE_DISTANCE_TOLERANCE Then
			msg$ = "IsMagnetInTong: ForceTouch stopped " + Str$(distErrorFromPerfectMagnetPoint) + "mm before reaching theoretical magnet position."
			UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
		ElseIf distErrorFromPerfectMagnetPoint < MAGNET_PROBE_DISTANCE_TOLERANCE Then
			GTIsMagnetInGripper = True
			msg$ = "IsMagnetInTong: ForceTouch detected magnet in tong with distance error =" + Str$(distErrorFromPerfectMagnetPoint) + "."
			UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
		Else
            msg$ = "IsMagnetInTong: ForceTouch moved " + Str$(distErrorFromPerfectMagnetPoint) + "mm beyond theoretical magnet position."
            UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
		EndIf
	Else
		msg$ = "IsMagnetInTong: ForceTouch failed to detect magnet in tong even after travelling maximum scan distance!"
        UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
	EndIf
	
	GTLoadPreviousRobotSpeedMode
	
	Move P(standbyPoint)
Fend

Function GTPickMagnet As Boolean
	GTPickMagnet = False

	Tool 0
	
	Jump P3 '' Cooling Point in front of cradle
	If Not Open_Gripper Then
		UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:Open_Gripper failed", ERROR_LEVEL)
		Exit Function
	EndIf
	Move P6 '' gripper catches the magnet in cradle
	If Not Close_Gripper Then
		UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:Close_Gripper failed", ERROR_LEVEL)
		Exit Function
	EndIf
	Move P4 '' point directly above cradle : P4 can be thought of as ready for action point = Instead of jump to p3, move to p4

	GTPickMagnet = True
Fend

Function GTCheckAndPickMagnet As Boolean
	GTCheckAndPickMagnet = False
	
	If GTIsMagnetInGripper Then ''CheckMagnet
		UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:GTIsMagnetInGripper found magnet on tong.", INFO_LEVEL)
	Else
		UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:GTIsMagnetInGripper did not find magnet on tong.", INFO_LEVEL)
		If Not GTPickMagnet Then
			UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:GTPickMagnet failed!", ERROR_LEVEL)
			Exit Function
		EndIf
	EndIf
	
	GTCheckAndPickMagnet = True
Fend

Function GTReturnMagnet As Boolean
	GTReturnMagnet = False
	
	Tool 0
	
	Jump P4 '' point directly above cradle

	Move P6 '' gripper catches the magnet in cradle
	
	If Not Open_Gripper Then
		UpdateClient(TASK_MSG, "GTReturnMagnet:Open_Gripper failed", INFO_LEVEL)
		Exit Function
	EndIf

	Move P3 '' Cooling Point in front of cradle
	
	'' No need to close gripper
	''If Not Close_Gripper Then
	''	GTUpdateClient(TASK_FAILURE_REPORT, MID_LEVEL_FUNCTION, "GTReturnMagnet:Close_Gripper failed")
	''	Exit Function
	''EndIf
	
	GTReturnMagnet = True
Fend

Function GTReturnMagnetAndGoHome As Boolean
	GTReturnMagnetAndGoHome = False

	If Not GTReturnMagnet Then
		UpdateClient(TASK_MSG, "GTReturnMagnetAndGoHome:GTReturnMagnet failed", ERROR_LEVEL)
		Exit Function
	EndIf

	'' Return Home and Close Lid
	LimZ 0
	GTsetRobotSpeedMode(OUTSIDE_LN2_SPEED)
	Jump P1
	Jump P0
	Close_Lid
	
	GTReturnMagnetAndGoHome = True
Fend

Function GTTwistOffMagnet
	Real currentUAngle
	currentUAngle = CU(RealPos)
	
	Integer currentTool
	currentTool = Tool()
		
	Real twistOffAngle
	twistOffAngle = 60 ''degrees

	''Safe distance for magnet to twist (otherwise the magnet head front edge would overpress the sample)
	Real twistMagnetRadiusSafeDistance, twistMagnetRadiusSafeDistanceX, twistMagnetRadiusSafeDistanceY
	twistMagnetRadiusSafeDistance = MAGNET_HEAD_RADIUS * Sin(DegToRad(twistOffAngle)) ''Note:If samples are falling only in LN2, then we need multiply CASSETTE_SHRINK_FACTOR to MAGNET_HEAD_RADIUS
	twistMagnetRadiusSafeDistanceX = -twistMagnetRadiusSafeDistance * Cos(DegToRad(currentUAngle))
	twistMagnetRadiusSafeDistanceY = -twistMagnetRadiusSafeDistance * Sin(DegToRad(currentUAngle))

	''Safe distance for magnet to twist (otherwise the magnet head back edge would hit the port edge)
	Real twistMagnetHeadSafeDistance, twistMagnetHeadSafeDistanceX, twistMagnetHeadSafeDistanceY
	twistMagnetHeadSafeDistance = MAGNET_HEAD_THICKNESS

	Real twistAngleInGlobalCoordinates
	Select currentTool
		Case PICKER_TOOL
			twistAngleInGlobalCoordinates = twistOffAngle ''degrees
			twistMagnetHeadSafeDistanceX = MAGNET_HEAD_THICKNESS * Cos(DegToRad(currentUAngle + 90))
			twistMagnetHeadSafeDistanceY = MAGNET_HEAD_THICKNESS * Sin(DegToRad(currentUAngle + 90))
		Case PLACER_TOOL
			twistAngleInGlobalCoordinates = -twistOffAngle ''degrees
			twistMagnetHeadSafeDistanceX = MAGNET_HEAD_THICKNESS * Cos(DegToRad(currentUAngle - 90))
			twistMagnetHeadSafeDistanceY = MAGNET_HEAD_THICKNESS * Sin(DegToRad(currentUAngle - 90))
		Default
			''If other toolsets are used, do not perform twistoff moves (just return before moving)
			Exit Function
	Send
		
	''Move safe distance before twistoff so that there is no overpress of sample due to magnet radius
	Move RealPos +X(twistMagnetRadiusSafeDistanceX) +Y(twistMagnetRadiusSafeDistanceY)
	
	''Perform the twistoff, (If the following XY move is not added, then the back of the magnet head's backedge hits the port edge)
	Move RealPos +X(twistMagnetHeadSafeDistanceX) +Y(twistMagnetHeadSafeDistanceY) +U(twistAngleInGlobalCoordinates)
Fend

Function GTJumpHomeToGonioDewarSide As Boolean
	String msg$
	
	GTJumpHomeToGonioDewarSide = False

	If Not Open_Lid Then
		UpdateClient(TASK_MSG, "GTJumpHomeToGonioDewarSide:Open_Lid failed", ERROR_LEVEL)
        Exit Function
    EndIf
   
   	Motor On
   	Power Low ''For debugging use low power mode
   	
	Tool 0
	GTsetRobotSpeedMode(OUTSIDE_LN2_SPEED)

	If (Dist(RealPos, P0) < CLOSE_DISTANCE) Then Jump P1
	
	Jump P18
	
	GTJumpHomeToGonioDewarSide = True
Fend

