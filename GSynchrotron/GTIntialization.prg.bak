#include "GTReporterdefs.inc"

#define CLOSE_DISTANCE 10

Function GTInitialize()
	Motor On
	
	InitForceConstants
	
	initSuperPuckConstants
	initGTReporter
	
	g_RunResult$ = "progress GTInitialize->GTInitAllPoints"
	If Not GTInitAllPoints Then
		GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTInitAllPoints failed")
		g_RunResult$ = "error GTInitAllPoints"
		Exit Function
	EndIf
	
	
	g_RunResult$ = "progress GTInitialize: Grabbing Magnet from Cradle routine"
	If Dist(RealPos, P0) < CLOSE_DISTANCE Then
		Jump P1
	EndIf
	
	'' If Tong is closed, then assume magnet not in tong
	If (Not IN_GRIP_CLOSE) And IN_GRIP_OPEN Then
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
Fend

