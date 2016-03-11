#include "networkdefs.inc"
#include "genericdefs.inc"

''True if GTInitialize has been called
Boolean m_GTInitialized

Function GTInitialize() As Boolean
	''Flag to ensure function is ran once
	If m_GTInitialized Then
		GTInitialize = True
		Exit Function
	Else
		'' This is the first call of GTInitialize() function
		GTInitialize = False
		m_GTInitialized = False
	EndIf
	
	''Check global variable status
	If Not CheckEnvironment Then
		''Problem detected
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
	
	''If the motors are off, turn them on
	If Motor = Off Then
		Motor On
	EndIf
	
	''Until properly tested, startup default for power is low
	Power High
	
	''Startup default is tool 0
	Tool 0
	
	''Startup default speed
	GTsetRobotSpeedMode(OUTSIDE_LN2_SPEED)
	
	''Set flags showing initialize done
	GTInitialize = True
	m_GTInitialized = True
Fend

