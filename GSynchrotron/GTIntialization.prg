#include "GTGenericdefs.inc"
#include "GTReporterdefs.inc"

#define CLOSE_DISTANCE 10

Global Boolean m_GTInitialized

Function GTInitialize() As Boolean
	If m_GTInitialized Then
		GTInitialize = True
		Exit Function
	Else
		'' This is the first call of GTInitialize() function
		GTInitialize = False
		m_GTInitialized = False
	EndIf

	InitForceConstants
	
	initSuperPuckConstants
	initGTReporter
	
	g_RunResult$ = "progress GTInitialize->GTInitAllPoints"
	If Not GTInitAllPoints Then
		GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTInitialize:GTInitAllPoints failed")
		g_RunResult$ = "error GTInitialize->GTInitAllPoints"
		Exit Function
	EndIf
	
	Motor On
	Tool 0
	GTsetRobotSpeedMode(FAST_SPEED)
	
	g_RunResult$ = "progress GTInitialize: Grabbing Magnet from Cradle routine"
	If Dist(RealPos, P0) < CLOSE_DISTANCE Then
		Jump P1
	EndIf
	
''	If GTIsDumbbellInsideCassette Then
''		GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTInitialize:GTIsDumbbellInsideCassette dectected dumbbell inside cassette")
''		g_RunResult$ = "error GTInitialize->GTIsDumbbellInsideCassette"
''		Exit Function
''	EndIf

	If GTIsMagnetInTong Then
		GTUpdateClient(TASK_MESSAGE_REPORT, HIGH_LEVEL_FUNCTION, "GTInitialize:GTIsMagnetInTong found magnet on tong.")
	Else
		Jump P3
		If Not Open_Gripper Then
			GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTInitialize:Open_Gripper failed")
			Exit Function
		EndIf
		Move P6
		If Not Close_Gripper Then
			GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTInitialize:Close_Gripper failed")
			Exit Function
		EndIf
		Jump P3
	EndIf
	
	g_RunResult$ = "success GTInitialize"
	GTInitialize = True
	m_GTInitialized = True
Fend

