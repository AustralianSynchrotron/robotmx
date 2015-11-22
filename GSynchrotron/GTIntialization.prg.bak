#include "GTGenericdefs.inc"
#include "GTReporterdefs.inc"

#define CLOSE_DISTANCE 10

Function GTInitialize() As Boolean

	InitForceConstants
	
	initSuperPuckConstants
	initGTReporter
	
	g_RunResult$ = "progress GTInitialize->GTInitAllPoints"
	If Not GTInitAllPoints Then
		GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTInitialize:GTInitAllPoints failed")
		g_RunResult$ = "error GTInitAllPoints"
		GTInitialize = False
		Exit Function
	EndIf
	
	Motor On
	Tool 0
	GTsetRobotSpeedMode(FAST_SPEED)
	
	g_RunResult$ = "progress GTInitialize: Grabbing Magnet from Cradle routine"
	If Dist(RealPos, P0) < CLOSE_DISTANCE Then
		Jump P1
	EndIf
	
	If GTIsDumbbellInsideCassette Then
		GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTInitialize:GTIsDumbbellInsideCassette dectected dumbbell inside cassette")
		g_RunResult$ = "error GTInitialize->GTIsDumbbellInsideCassette"
		GTInitialize = False
		Exit Function
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

