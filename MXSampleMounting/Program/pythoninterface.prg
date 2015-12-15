#include "networkdefs.inc"
#include "genericdefs.inc"
#include "cassettedefs.inc"
#include "superpuckdefs.inc"

Global String g_ProbeRequestString$(NUM_CASSETTES)

Function debugProbePuck(cassette_position As Integer, puckIndexToProbe As Integer)

	Integer cassetteIndex
	For cassetteIndex = 0 To NUM_CASSETTES - 1
		g_ProbeRequestString$(cassetteIndex) = ""
	Next
	
	Integer puckIndex, puckPortIndex
	
	For puckIndex = PUCK_A To puckIndexToProbe - 1
		For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
			g_ProbeRequestString$(cassette_position) = g_ProbeRequestString$(cassette_position) + "0"
		Next
	Next

	puckIndex = puckIndexToProbe
	For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
		g_ProbeRequestString$(cassette_position) = g_ProbeRequestString$(cassette_position) + "1"
	Next

	For puckIndex = puckIndexToProbe + 1 To PUCK_D
		For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
			g_ProbeRequestString$(cassette_position) = g_ProbeRequestString$(cassette_position) + "0"
		Next
	Next
	
	ProbeCassettes
Fend

Function ProbeCassettes
	Cls
    Print "GTProbeCassettes entered at ", Date$, " ", Time$

	''init result
    g_RunResult$ = ""
    
	If Not GTInitialize Then
		g_RunResult$ = "error GTInitialize failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	If Not GTJumpHomeToCoolingPointAndWait Then
		g_RunResult$ = "GTJumpHomeToCoolingPointAndWait failed"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf

	g_RunResult$ = "progress GTCheckAndPickMagnet: Grabbing Magnet from Cradle"
	If Not GTCheckAndPickMagnet Then
		g_RunResult$ = "GTCheckAndPickMagnet: Grabbing magnet failed"
    	UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
		
	Integer cassette_position
	Integer probeStringLengthToCheck
	String PortProbeRequestChar$
	Integer portIndex
	Boolean probeThisCassette
	
	For cassette_position = 0 To NUM_CASSETTES - 1
		probeThisCassette = False
	
		probeStringLengthToCheck = Len(g_ProbeRequestString$(cassette_position))
		If MAXIMUM_NUM_PORTS < probeStringLengthToCheck Then probeStringLengthToCheck = MAXIMUM_NUM_PORTS
		For portIndex = 0 To probeStringLengthToCheck - 1
			PortProbeRequestChar$ = Mid$(g_ProbeRequestString$(cassette_position), portIndex + 1, 1)
			If PortProbeRequestChar$ = "1" Then
				probeThisCassette = True
				Exit For
			EndIf
		Next
		
		If probeThisCassette Then
			GTResetCassette(cassette_position)
	
			If GTProbeCassetteType(cassette_position) Then
                Select g_CassetteType(cassette_position)
					Case SUPERPUCK_CASSETTE
						If Not GTProbeSpecificPortsInSuperPuck(cassette_position) Then
							g_RunResult$ = "GTProbeSpecificPortsInSuperPuck failed"
							UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
							Exit Function
						EndIf
					Case NORMAL_CASSETTE
						If Not GTProbeSpecificPortsInCassette(cassette_position) Then
							g_RunResult$ = "GTProbeSpecificPortsInCassette failed"
							UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
							Exit Function
						EndIf
					Case CALIBRATION_CASSETTE
						If Not GTProbeSpecificPortsInCassette(cassette_position) Then
							g_RunResult$ = "GTProbeSpecificPortsInCassette failed"
							UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
							Exit Function
						EndIf
					Default
						g_RunResult$ = "No " + GTCassetteName$(cassette_position) + " found"
						UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
				Send
			Else
				'' Instead of exit function, can also be changed to check the next cassette	(Next)
				Exit Function
			EndIf
		EndIf
	Next
	
	'' Return Magnet To Cradle And Go to Home Position
	g_RunResult$ = "progress GTReturnMagnetAndGoHome"
	If Not GTReturnMagnetAndGoHome Then
		g_RunResult$ = "GTReturnMagnetAndGoHome failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	g_RunResult$ = "success GTProbeCassettes"
    Print "GTProbeCassettes finished at ", Date$, " ", Time$
Fend

Function GTProbeSpecificPortsInSuperPuck(cassette_position As Integer) As Boolean
	'' Check whether it is really a superpuck adaptor
	If g_CassetteType(cassette_position) = SUPERPUCK_CASSETTE Then
		Integer probeStringLengthToCheck
		Integer puckIndex, puckPortIndex
		String PortProbeRequestChar$
		Boolean probeThisPuck
		For puckIndex = 0 To NUM_PUCKS - 1
			'' probeStringLengthToCheck is also the number of ports in this puck to check
			probeStringLengthToCheck = Len(g_ProbeRequestString$(cassette_position)) - puckIndex * NUM_PUCK_PORTS
			If NUM_PUCK_PORTS < probeStringLengthToCheck Then probeStringLengthToCheck = NUM_PUCK_PORTS

			'' Initial check through probe request string to check whether there is a request by user, to probe any port in this puck
			probeThisPuck = False
			For puckPortIndex = 0 To probeStringLengthToCheck - 1
				PortProbeRequestChar$ = Mid$(g_ProbeRequestString$(cassette_position), puckIndex * NUM_PUCK_PORTS + puckPortIndex + 1, 1)
				If PortProbeRequestChar$ = "1" Then
					probeThisPuck = True
					'' If a port is requested to probe, we don't have to check further, just exit for this for loop and start probing
					Exit For
				EndIf
			Next
			
			'' If there is a request to probe a port in this puck
			If probeThisPuck Then
				UpdateClient(TASK_MSG, "GTProbeSpecificPortsInSuperPuck->GTprobeSPPuck(" + GTCassetteName$(cassette_position) + "," + GTpuckName$(puckIndex) + ")", INFO_LEVEL)
				GTprobeSPPuck(cassette_position, puckIndex, True)
			
				If g_PuckPresent(cassette_position, puckIndex) Then
					''Run adaptor angle correction for this puck only if puck is present, this reduces time to finish probing
					UpdateClient(TASK_MSG, "GTProbeSpecificPortsInSuperPuck->GTprobePuckAngleCorrection(" + GTCassetteName$(cassette_position) + "," + GTpuckName$(puckIndex) + ")", INFO_LEVEL)
					If Not GTprobeAdaptorAngleCorrection(cassette_position, puckIndex, False) Then
						g_RunResult$ = "error GTProbeSpecificPortsInSuperPuck->GTprobeAdaptorAngleCorrection!"
						UpdateClient(TASK_MSG, "GTProbeSpecificPortsInSuperPuck failed: error in GTprobeAdaptorAngleCorrection!", ERROR_LEVEL)
						GTProbeSpecificPortsInSuperPuck = False
						Exit Function
					EndIf
			
					For puckPortIndex = 0 To probeStringLengthToCheck - 1
						'' Probe the superpuck ports corresponding to 1's in probeRequestString
						PortProbeRequestChar$ = Mid$(g_ProbeRequestString$(cassette_position), puckIndex * NUM_PUCK_PORTS + puckPortIndex + 1, 1)
						If PortProbeRequestChar$ = "1" Then
							''UpdateClient(TASK_MSG, "GTProbeSpecificPortsInSuperPuck->GTprobeSPPort(" + GTCassetteName$(cassette_position) + "," + GTpuckName$(puckIndex) + "," + Str$(puckPortIndex + 1) + ")", INFO_LEVEL)
							GTprobeSPPort(cassette_position, puckIndex, puckPortIndex, False)
						EndIf
					Next
				EndIf
			EndIf
		Next
	Else
		UpdateClient(TASK_MSG, "GTProbeSpecificPortsInSuperPuck failed: " + GTCassetteName$(cassette_position) + " is not SuperPuck Adaptor!", ERROR_LEVEL)
		GTProbeSpecificPortsInSuperPuck = False
		Exit Function
	EndIf

	GTProbeSpecificPortsInSuperPuck = True
Fend

Function GTProbeSpecificPortsInCassette(cassette_position As Integer) As Boolean
	Integer columnIndex, rowIndex
	Integer probeStringLengthToCheck
	Integer rowsToStep
	String PortProbeRequestChar$
	Boolean probeThisColumn
	Boolean jumpToStandbyPoint

	'' Check whether it is really a normal cassette OR calibration cassette
	'' This also sets rowsToStep for the following "for" loops in this function
	Select g_CassetteType(cassette_position)
		Case NORMAL_CASSETTE
			rowsToStep = 1
		Case CALIBRATION_CASSETTE
			rowsToStep = NUM_ROWS - 1
		Default
			UpdateClient(TASK_MSG, "GTProbeSpecificPortsInCassette failed: " + GTCassetteName$(cassette_position) + " is not a Normal Cassette!", ERROR_LEVEL)
			GTProbeSpecificPortsInCassette = False
			Exit Function
	Send

	For columnIndex = 0 To NUM_COLUMNS - 1
		'' probeStringLengthToCheck is also the number of ports in this column to check
		probeStringLengthToCheck = Len(g_ProbeRequestString$(cassette_position)) - columnIndex * NUM_ROWS
		If NUM_ROWS < probeStringLengthToCheck Then probeStringLengthToCheck = NUM_ROWS

		'' Initial check through probe request string to check whether there is a request by user, to probe any port in this column
		probeThisColumn = False
		For rowIndex = 0 To probeStringLengthToCheck - 1 Step rowsToStep
			PortProbeRequestChar$ = Mid$(g_ProbeRequestString$(cassette_position), columnIndex * NUM_ROWS + rowIndex + 1, 1)
			If PortProbeRequestChar$ = "1" Then
				probeThisColumn = True
				'' If a port is requested to probe, we don't have to check further, just exit for this for loop and start probing
				Exit For
			EndIf
		Next
		
		'' If there is a request to probe a port in this column
		If probeThisColumn Then
			'' jump to standy point when probing the first time in a column
			jumpToStandbyPoint = True
			
			For rowIndex = 0 To probeStringLengthToCheck - 1 Step rowsToStep
				PortProbeRequestChar$ = Mid$(g_ProbeRequestString$(cassette_position), columnIndex * NUM_ROWS + rowIndex + 1, 1)
				If PortProbeRequestChar$ = "1" Then
					''UpdateClient(TASK_MSG, "GTProbeSpecificPortsInCassette->GTprobeCassettePort(" + GTCassetteName$(cassette_position) + ",row=" + Str$(rowIndex + 1) + ",col=" + GTcolumnName$(columnIndex) + ")", INFO_LEVEL)
					GTprobeCassettePort(cassette_position, rowIndex, columnIndex, jumpToStandbyPoint)
					'' Once jumped to a column, no more jumps are required for probing ports in the same column
					jumpToStandbyPoint = False
				EndIf
			Next
		EndIf
	Next
	
	GTProbeSpecificPortsInCassette = True
Fend


