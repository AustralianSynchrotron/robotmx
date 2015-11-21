#include "forcedefs.inc"
#include "mxrobotdefs.inc"
#include "GTGenericdefs.inc"
#include "GTReporterdefs.inc"

#define CLOSE_DISTANCE 10
#define DISTANCE_P3_TO_P6 20 ''mm
#define MAGNET_AXIS_TO_CRADLE_EDGE 2.8 'mm
#define MAGNET_PROBE_DISTANCE_TOLERANCE (MAGNET_HEAD_RADIUS + 0.1)

Function GTIsMagnetInTong() As Boolean
	GTIsMagnetInTong = False

	Integer previousTool
	previousTool = Tool()
	Tool 0

	'' Closing Gripper only matters because if Gripper is open we might loose magnet while hitting the cradle
	Close_Gripper
	
	Jump P3

	Real probeDistanceFromCradleCenter
	probeDistanceFromCradleCenter = (MAGNET_LENGTH /2) + (CRADLE_WIDTH /2) - (MAGNET_HEAD_THICKNESS /2)
	Integer standbyPoint
	standbyPoint = 52
	P(standbyPoint) = P3 -X(probeDistanceFromCradleCenter * g_dumbbell_Perfect_cosValue) -Y(probeDistanceFromCradleCenter * g_dumbbell_Perfect_sinValue)

	Move P(standbyPoint)
	
	Real maxDistanceToScan
	maxDistanceToScan = DISTANCE_P3_TO_P6 + MAGNET_PROBE_DISTANCE_TOLERANCE
	
	SetVerySlowSpeed
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
	SetFastSpeed
	
	Move P(standbyPoint)
	Tool previousTool
Fend

Function GTInitialize() As Boolean

	InitForceConstants
	
	initSuperPuckConstants
	initGTReporter
	
	g_RunResult$ = "progress GTInitialize->GTInitAllPoints"
	If Not GTInitAllPoints Then
		GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTInitAllPoints failed")
		g_RunResult$ = "error GTInitAllPoints"
		GTInitialize = False
		Exit Function
	EndIf
	
	Motor On
	Tool 0
	
	g_RunResult$ = "progress GTInitialize: Grabbing Magnet from Cradle routine"
	If Dist(RealPos, P0) < CLOSE_DISTANCE Then
		Jump P1
	EndIf
	

	If GTIsMagnetInTong Then
		GTUpdateClient(TASK_MESSAGE_REPORT, HIGH_LEVEL_FUNCTION, "GTInitialize:GTIsMagnetInTong found magnet on tong.")
	Else
		Jump P3
		If Not Open_Gripper Then
			GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTInitialize:Open_Gripper failed")
			GTInitialize = False
			Exit Function
		EndIf
		Move P6
		If Not Close_Gripper Then
			GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTInitialize:Close_Gripper failed")
			GTInitialize = False
			Exit Function
		EndIf
		Jump P3
	EndIf
	
	g_RunResult$ = "success GTInitialize"
	GTInitialize = True
Fend

