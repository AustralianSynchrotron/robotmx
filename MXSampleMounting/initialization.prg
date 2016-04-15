#include "networkdefs.inc"
#include "genericdefs.inc"

''True if GTInitialize has been called
Boolean m_GTInitialized

Function GTInitialize() As Boolean
	''Set return value to false
	GTInitialize = False
	
	''Check global variable status
	If Not CheckEnvironment Then
		''SetGlobals
		Motor Off
		''Problem detected
        Exit Function
   	EndIf

	'' g_Jump_LimZ_LN2 should only be set in SetGlobals (called inside CheckEnvironment) - remove after debugging
	g_Jump_LimZ_LN2 = -102
	'' g_Jump_LimZ_LN2 should only be set in SetGlobals - remove after debugging
	
	''Flag to ensure function is ran once
	If m_GTInitialized Then
		GTInitialize = True
		Exit Function
	EndIf

	''Initialize the force constants
	InitForceConstants
	
	''Initialize constants for superpuck
	initSuperPuckConstants
	''Initialize updateclient print level.  Controls prints to spel run window
	GTInitPrintLevel
	
	''Set default dumbbell status to unknown
	GTsetDumbbellStatus(DUMBBELL_STATUS_UNKNOWN)
	
	''Check points database
	If Not GTInitAllPoints Then
		''Problem with points database
		Exit Function
	EndIf
	
	''Startup default is tool 0
	Tool 0
	
	''Startup default speed
	GTsetRobotSpeedMode(OUTSIDE_LN2_SPEED)
	
	''Set flags showing initialize done
	GTInitialize = True
	m_GTInitialized = True
Fend

