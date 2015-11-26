#include "GTGenericdefs.inc"
#include "GTReporterdefs.inc"

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
		Exit Function
	EndIf
	
	GTInitialize = True
	m_GTInitialized = True
Fend

