#include "forcedefs.inc"
#include "mxrobotdefs.inc"
#include "GTGenericdefs.inc"
#include "GTSuperPuckdefs.inc"
#include "GTCassettedefs.inc"
#include "GTReporterdefs.inc"

Function GTIsMagnetInTong() As Boolean
	GTIsMagnetInTong = False

	Tool 0

	'' Closing Gripper only matters because if Gripper is open we might loose magnet while hitting the cradle
	Close_Gripper
	
	Jump P3

	Real probeDistanceFromCradleCenter
	probeDistanceFromCradleCenter = ((MAGNET_LENGTH /2) + (CRADLE_WIDTH /2) - (MAGNET_HEAD_THICKNESS /2)) * CASSETTE_SHRINK_FACTOR
	Integer standbyPoint
	standbyPoint = 52
	P(standbyPoint) = P3 -X(probeDistanceFromCradleCenter * g_dumbbell_Perfect_cosValue) -Y(probeDistanceFromCradleCenter * g_dumbbell_Perfect_sinValue)

	Move P(standbyPoint)
	
	Real maxDistanceToScan
	maxDistanceToScan = DISTANCE_P3_TO_P6 + MAGNET_PROBE_DISTANCE_TOLERANCE
	
	GTsetRobotSpeedMode(VERY_SLOW_SPEED)
	
	ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY)
	If ForceTouch(DIRECTION_CAVITY_TO_MAGNET, maxDistanceToScan, False) Then
		'' Distance error from perfect magnet position
		Real distErrorFromPerfectMagnetPoint
		distErrorFromPerfectMagnetPoint = Dist(P(standbyPoint), RealPos) - (DISTANCE_P3_TO_P6 - (MAGNET_AXIS_TO_CRADLE_EDGE + MAGNET_HEAD_RADIUS))
		
		If distErrorFromPerfectMagnetPoint < -MAGNET_PROBE_DISTANCE_TOLERANCE Then
			GTUpdateClient(TASK_WARNING_REPORT, MID_LEVEL_FUNCTION, "IsMagnetInTong: ForceTouch stopped " + Str$(distErrorFromPerfectMagnetPoint) + "mm before reaching theoretical magnet position.")
		ElseIf distErrorFromPerfectMagnetPoint < MAGNET_PROBE_DISTANCE_TOLERANCE Then
			GTIsMagnetInTong = True
			GTUpdateClient(TASK_MESSAGE_REPORT, MID_LEVEL_FUNCTION, "IsMagnetInTong: ForceTouch detected magnet in tong with distance error =" + Str$(distErrorFromPerfectMagnetPoint) + ".")
		Else
			GTUpdateClient(TASK_WARNING_REPORT, MID_LEVEL_FUNCTION, "IsMagnetInTong: ForceTouch moved " + Str$(distErrorFromPerfectMagnetPoint) + "mm beyond theoretical magnet position.")
		EndIf
	Else
		GTUpdateClient(TASK_WARNING_REPORT, MID_LEVEL_FUNCTION, "IsMagnetInTong: ForceTouch failed to detect magnet in tong even after travelling maximum scan distance!")
	EndIf
	
	GTLoadPreviousRobotSpeedMode
	
	Move P(standbyPoint)
Fend

Function GTCheckAndPickMagnet As Boolean
	GTCheckAndPickMagnet = False
	
	Tool 0
	
	If GTIsMagnetInTong Then
		GTUpdateClient(TASK_MESSAGE_REPORT, MID_LEVEL_FUNCTION, "GTCheckAndPickMagnet:GTIsMagnetInTong found magnet on tong.")
	Else
		Jump P3
		If Not Open_Gripper Then
			GTUpdateClient(TASK_FAILURE_REPORT, MID_LEVEL_FUNCTION, "GTCheckAndPickMagnet:Open_Gripper failed")
			Exit Function
		EndIf
		Move P6
		If Not Close_Gripper Then
			GTUpdateClient(TASK_FAILURE_REPORT, MID_LEVEL_FUNCTION, "GTCheckAndPickMagnet:Close_Gripper failed")
			Exit Function
		EndIf
		Jump P3
	EndIf
	
	GTCheckAndPickMagnet = True
Fend

Function GTReturnMagnet As Boolean
	GTReturnMagnet = False
	
	Tool 0
	
	Jump P6

	If Not Open_Gripper Then
		GTUpdateClient(TASK_FAILURE_REPORT, MID_LEVEL_FUNCTION, "GTReturnMagnet:Open_Gripper failed")
		Exit Function
	EndIf

	Move P3
	
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
		GTUpdateClient(TASK_FAILURE_REPORT, MID_LEVEL_FUNCTION, "GTReturnMagnetAndGoHome:GTReturnMagnet failed")
		Exit Function
	EndIf

	'' Return Home and Close Lid
	LimZ 0
	Jump P1
	Jump P0
	Close_Lid
	
	GTReturnMagnetAndGoHome = True
Fend


#define CLOSE_DISTANCE 10

Function GTJumpHomeToCoolingPointAndWait As Boolean
	GTJumpHomeToCoolingPointAndWait = False

	If Not Open_Lid Then
		GTUpdateClient(TASK_FAILURE_REPORT, MID_LEVEL_FUNCTION, "GTJumpHomeToCoolingPointAndWait:Open_Lid failed")
        Exit Function
    EndIf
   
   	Motor On
	Tool 0
	GTsetRobotSpeedMode(FAST_SPEED)

	If (Dist(RealPos, P0) < CLOSE_DISTANCE) Then Jump P1
	
	Jump P3
	
	If g_LN2LevelHigh Then
		GTUpdateClient(TASK_PROGRESS_REPORT, MID_LEVEL_FUNCTION, "GTJumpHomeToCoolingPointAndWait->WaitLN2BoilingStop initiated")
		Integer timeTakenToCoolTong
		timeTakenToCoolTong = WaitLN2BoilingStop(SENSE_TIMEOUT, HIGH_SENSITIVITY, HIGH_SENSITIVITY)
		GTUpdateClient(TASK_MESSAGE_REPORT, MID_LEVEL_FUNCTION, "GTJumpHomeToCoolingPointAndWait: Cooled tong for " + Str$(timeTakenToCoolTong) + " seconds")
	EndIf
	
	GTJumpHomeToCoolingPointAndWait = True
Fend

'' errorFromPerfectSamplePosition is the distance between Actual sample position and Perfect sample position
Function GTTwistOffMagnet(cassette_type As Integer, errorFromPerfectSamplePosition As Real)
	Real currentUAngle
	currentUAngle = CU(RealPos)
	
	Integer currentTool
	currentTool = Tool()
	
	'' perfectDistanceSampleToSurface is the distance to reach back to the cassette surface (or puck surface in case of superpuck)
	Real perfectDistanceSampleToSurface
	Select cassette_type
		Case SUPERPUCK_CASSETTE
			perfectDistanceSampleToSurface = SAMPLE_DIST_PIN_DEEP_IN_PUCK + errorFromPerfectSamplePosition
		Default
			perfectDistanceSampleToSurface = SAMPLE_DIST_PIN_DEEP_IN_CAS + errorFromPerfectSamplePosition
	Send
	
	Real travelToSurfaceDistanceX, travelToSurfaceDistanceY
	travelToSurfaceDistanceX = -perfectDistanceSampleToSurface * Cos(DegToRad(currentUAngle))
	travelToSurfaceDistanceY = -perfectDistanceSampleToSurface * Sin(DegToRad(currentUAngle))
	
	Real AngleToArc
	Select currentTool
		Case PICKER_TOOL
			AngleToArc = 60 ''degrees
		Case PLACER_TOOL
			AngleToArc = -60 ''degrees
		Default
			Exit Function
	Send
	
	'' Move half way inside the sample port and then turn U angle for the rest half distance to reach the cassette/puck surface
	Move RealPos +X(travelToSurfaceDistanceX / 2) +Y(travelToSurfaceDistanceY / 2)
	Go RealPos +X(travelToSurfaceDistanceX / 2) +Y(travelToSurfaceDistanceY / 2) +U(AngleToArc)
Fend

