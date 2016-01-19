#include "networkdefs.inc"
#include "genericdefs.inc"
#include "cassettedefs.inc"
#include "superpuckdefs.inc"
#include "jsondefs.inc"

Global String g_PortsRequestString$(NUM_CASSETTES)

Function debugProbeNormal(cassette_position As Integer)
	Integer cassetteIndex
	For cassetteIndex = 0 To NUM_CASSETTES - 1
		g_PortsRequestString$(cassetteIndex) = ""
	Next
	
	Integer rowIndex, ColumnIndex
	For ColumnIndex = 0 To NUM_COLUMNS - 1
		For rowIndex = 0 To NUM_ROWS - 1
			g_PortsRequestString$(cassette_position) = g_PortsRequestString$(cassette_position) + "1"
		Next
	Next

	ProbeCassettes
Fend

Function debugProbeCalib(cassette_position As Integer)
	Integer cassetteIndex
	For cassetteIndex = 0 To NUM_CASSETTES - 1
		g_PortsRequestString$(cassetteIndex) = ""
	Next
	
	Integer rowIndex, ColumnIndex
	For ColumnIndex = 0 To NUM_COLUMNS - 1
		g_PortsRequestString$(cassette_position) = g_PortsRequestString$(cassette_position) + "1"
		For rowIndex = 1 To NUM_ROWS - 2
			g_PortsRequestString$(cassette_position) = g_PortsRequestString$(cassette_position) + "0"
		Next
		g_PortsRequestString$(cassette_position) = g_PortsRequestString$(cassette_position) + "1"
	Next

	ProbeCassettes
Fend

Function debugProbePuck(cassette_position As Integer, puckIndexToProbe As Integer)

	Integer cassetteIndex
	For cassetteIndex = 0 To NUM_CASSETTES - 1
		g_PortsRequestString$(cassetteIndex) = ""
	Next
		
	Integer puckIndex, puckPortIndex
	For puckIndex = PUCK_A To puckIndexToProbe - 1
		For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
			g_PortsRequestString$(cassette_position) = g_PortsRequestString$(cassette_position) + "0"
		Next
	Next

	puckIndex = puckIndexToProbe
	For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
		g_PortsRequestString$(cassette_position) = g_PortsRequestString$(cassette_position) + "1"
	Next

	For puckIndex = puckIndexToProbe + 1 To PUCK_D
		For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
			g_PortsRequestString$(cassette_position) = g_PortsRequestString$(cassette_position) + "0"
		Next
	Next
	
	ProbeCassettes
Fend

Function ProbeCassettes
	Cls
    Print "GTProbeCassettes entered at ", Date$, " ", Time$
    
    ''Ensure moves are not restricted to XY plane for probe
    g_OnlyAlongAxis = False

	''init result
    g_RunResult$ = ""
    
	'' Initialize all constants
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
	
		'' Here probeStingLengthToCheck is also the number of ports to probe
		probeStringLengthToCheck = Len(g_PortsRequestString$(cassette_position))
		If MAXIMUM_NUM_PORTS < probeStringLengthToCheck Then probeStringLengthToCheck = MAXIMUM_NUM_PORTS
		For portIndex = 0 To probeStringLengthToCheck - 1
			PortProbeRequestChar$ = Mid$(g_PortsRequestString$(cassette_position), portIndex + 1, 1)
			If PortProbeRequestChar$ = "1" Then
				''If even 1 port has to be probed, set probeThisCassette to True
				probeThisCassette = True
				Exit For
			EndIf
		Next
		
		If probeThisCassette Then
			If GTProbeCassetteType(cassette_position) Then
            	''only the ports that are to be probed are reset to unknown before probing.
            	''GTResetSpecificPorts is only called here because the user might forget to call it before probing
				GTResetSpecificPorts(cassette_position)
				If Not GTProbeSpecificPorts(cassette_position) Then
					g_RunResult$ = "GTProbeSpecificPorts Failed"
					UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
					Exit Function
				EndIf
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

Function JSONDataRequest
	
	String RequestTokens$(0)
	Integer RequestArgC
    
    ''parse argument from global
    ParseStr g_RunArgs$, RequestTokens$(), " "
    ''check argument
    RequestArgC = UBound(RequestTokens$) + 1

	Integer strIndex
	String cassetteChar$
	Integer cassette_position

	Integer jsonDataToSend, jsonDataToSendStrIndex
    If RequestArgC = 2 Then
    	For strIndex = 1 To Len(RequestTokens$(0))
			cassetteChar$ = Mid$(RequestTokens$(0), strIndex, 1)

			Select UCase$(cassetteChar$)
				Case "L"
					cassette_position = LEFT_CASSETTE
				Case "M"
					cassette_position = MIDDLE_CASSETTE
				Case "R"
					cassette_position = RIGHT_CASSETTE
				Default
					cassette_position = UNKNOWN_CASSETTE
			Send

			For jsonDataToSendStrIndex = 1 To Len(RequestTokens$(1))
				Select UCase$(Mid$(RequestTokens$(1), jsonDataToSendStrIndex, 1))
					Case "P"
						jsonDataToSend = puck_states
					Case "S"
						jsonDataToSend = PORT_STATES
					Case "D"
						jsonDataToSend = sample_distances
					Case "C"
						jsonDataToSend = cassette_type
					Default
						Exit Function
				Send
				
				GTsendCassetteData(jsonDataToSend, cassette_position)
			Next
		Next
    EndIf
Fend

Function GTMountSamplePort
	Cls
    Print "GTMountSamplePort entered at ", Date$, " ", Time$
    
    ''Ensure moves are not restricted to XY plane for probe
    g_OnlyAlongAxis = False

	''init result
    g_RunResult$ = ""
    
	'' Initialize all constants
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
		
	
	String RequestTokens$(0)
	Integer RequestArgC
    
    ''parse argument from global
    ParseStr g_RunArgs$, RequestTokens$(), " "
    ''check argument
    RequestArgC = UBound(RequestTokens$) + 1


	String cassetteChar$
	Integer cassette_position
	String columnOrPuckChar$
	Integer columnPuckIndex
	String rowOrPuckPortChar$
	Integer rowPuckPortIndex


    If RequestArgC = 3 Then
		cassetteChar$ = Mid$(RequestTokens$(0), 1, 1)
		Select UCase$(cassetteChar$)
			Case "L"
				cassette_position = LEFT_CASSETTE
			Case "M"
				cassette_position = MIDDLE_CASSETTE
			Case "R"
				cassette_position = RIGHT_CASSETTE
			Default
				cassette_position = UNKNOWN_CASSETTE
				g_RunResult$ = "GTMountSamplePort: Invalid Cassette Position supplied in g_RunArgs$"
				UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
				Exit Function
		Send

		columnOrPuckChar$ = Mid$(RequestTokens$(1), 1, 1)
		rowOrPuckPortChar$ = Mid$(RequestTokens$(2), 1, 1)
		
		If (g_CassetteType(cassette_position) = NORMAL_CASSETTE) Or (g_CassetteType(cassette_position) = CALIBRATION_CASSETTE) Then
			If Not GTParseColumnIndex(columnOrPuckChar$, ByRef columnPuckIndex) Then
				g_RunResult$ = "GTMountSamplePort: Invalid Column Name supplied in g_RunArgs$"
				UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
				Exit Function
			EndIf
			
			rowPuckPortIndex = Val(rowOrPuckPortChar$) - 1
			If rowPuckPortIndex < 0 Or rowPuckPortIndex > NUM_ROWS - 1 Then
				g_RunResult$ = "GTMountSamplePort: Invalid Row Position supplied in g_RunArgs$"
				UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
				Exit Function
			EndIf
		ElseIf g_CassetteType(cassette_position) = SUPERPUCK_CASSETTE Then
			If Not GTParsePuckIndex(columnOrPuckChar$, ByRef columnPuckIndex) Then
				g_RunResult$ = "GTMountSamplePort: Invalid Puck Name supplied in g_RunArgs$"
				UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
				Exit Function
			EndIf
			rowPuckPortIndex = Val(rowOrPuckPortChar$) - 1
			If rowPuckPortIndex < 0 Or rowPuckPortIndex > NUM_PUCK_PORTS - 1 Then
				g_RunResult$ = "GTMountSamplePort: Invalid Puck Port supplied in g_RunArgs$"
				UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
				Exit Function
			EndIf
		Else
			g_RunResult$ = "GTMountSamplePort: Invalid CassetteType Detected! Please probe this cassette again"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf
	EndIf
	
	If Not GTsetInterestPoint(cassette_position, columnPuckIndex, rowPuckPortIndex) Then
		g_RunResult$ = "GTMountSamplePort: No Sample Present in Port or Invalid Port Position supplied in g_RunArgs$"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	GTMountInterestedPort
	
	g_RunResult$ = "success GTMountSamplePort"
    Print "GTMountSamplePort finished at ", Date$, " ", Time$
Fend


Function debugJSONNormal(cassette_position As Integer)
	Integer cassetteIndex
	Integer rowIndex, ColumnIndex
	
	For cassetteIndex = 0 To NUM_CASSETTES - 1
		g_CassetteType(cassetteIndex) = UNKNOWN_CASSETTE
		For ColumnIndex = 0 To NUM_COLUMNS - 1
			For rowIndex = 0 To NUM_ROWS - 1
				g_CASSampleDistanceError(cassetteIndex, rowIndex, ColumnIndex) = -1.234
                g_CAS_PortStatus(cassetteIndex, rowIndex, ColumnIndex) = PORT_VACANT
			Next
		Next
	Next
	
	g_CassetteType(cassette_position) = NORMAL_CASSETTE
	For ColumnIndex = 0 To NUM_COLUMNS - 1
		For rowIndex = 0 To NUM_ROWS - 1
			g_CASSampleDistanceError(cassette_position, rowIndex, ColumnIndex) = -5.678
			g_CAS_PortStatus(cassette_position, rowIndex, ColumnIndex) = PORT_OCCUPIED
		Next
	Next

	JSONDataRequest
Fend

Function debugJSONCalib(cassette_position As Integer)
	Integer cassetteIndex
	Integer rowIndex, ColumnIndex
	For cassetteIndex = 0 To NUM_CASSETTES - 1
		g_CassetteType(cassetteIndex) = UNKNOWN_CASSETTE
		For ColumnIndex = 0 To NUM_COLUMNS - 1
			For rowIndex = 1 To NUM_ROWS - 2
				g_CASSampleDistanceError(cassetteIndex, rowIndex, ColumnIndex) = -1.234
				g_CAS_PortStatus(cassetteIndex, rowIndex, ColumnIndex) = PORT_VACANT
			Next
		Next
	Next
	
	g_CassetteType(cassette_position) = CALIBRATION_CASSETTE
	For ColumnIndex = 0 To NUM_COLUMNS - 1
		g_CASSampleDistanceError(cassette_position, rowIndex, ColumnIndex) = -5.678
		rowIndex = 0
		g_CAS_PortStatus(cassette_position, rowIndex, ColumnIndex) = PORT_OCCUPIED
		For rowIndex = 1 To NUM_ROWS - 2
			g_CAS_PortStatus(cassette_position, rowIndex, ColumnIndex) = PORT_UNKNOWN
		Next
		g_CASSampleDistanceError(cassette_position, rowIndex, ColumnIndex) = -5.678
		g_CAS_PortStatus(cassette_position, rowIndex, ColumnIndex) = PORT_OCCUPIED
	Next

	JSONDataRequest
Fend

Function debugJSONPuck(cassette_position As Integer, puckIndexToProbe As Integer)
	Integer cassetteIndex
	Integer puckIndex, puckPortIndex
	
	For cassetteIndex = 0 To NUM_CASSETTES - 1
		g_CassetteType(cassetteIndex) = UNKNOWN_CASSETTE
		For puckIndex = 0 To NUM_PUCKS - 1
			g_PuckStatus(cassetteIndex, puckIndex) = PUCK_ABSENT
			For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
				g_SPSampleDistanceError(cassetteIndex, puckIndex, puckPortIndex) = -1.234
				g_SP_PortStatus(cassetteIndex, puckIndex, puckPortIndex) = PORT_VACANT
			Next
		Next
	Next
	
	g_CassetteType(cassette_position) = SUPERPUCK_CASSETTE
	For puckIndex = PUCK_A To puckIndexToProbe - 1
		g_PuckStatus(cassette_position, puckIndex) = PUCK_ABSENT
		For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
			g_SPSampleDistanceError(cassette_position, puckIndex, puckPortIndex) = -1.234
			g_SP_PortStatus(cassette_position, puckIndex, puckPortIndex) = PORT_VACANT
		Next
	Next

	puckIndex = puckIndexToProbe
	g_PuckStatus(cassette_position, puckIndex) = PUCK_PRESENT
	For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
		g_SPSampleDistanceError(cassette_position, puckIndex, puckPortIndex) = -5.678
		g_SP_PortStatus(cassette_position, puckIndex, puckPortIndex) = PORT_OCCUPIED
	Next

	For puckIndex = puckIndexToProbe + 1 To PUCK_D
		For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
			g_SPSampleDistanceError(cassette_position, puckIndex, puckPortIndex) = -9.012
			g_SP_PortStatus(cassette_position, puckIndex, puckPortIndex) = PORT_VACANT
		Next
	Next
	
	JSONDataRequest
Fend


