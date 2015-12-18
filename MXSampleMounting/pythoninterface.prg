#include "networkdefs.inc"
#include "genericdefs.inc"
#include "cassettedefs.inc"
#include "superpuckdefs.inc"

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
	GTRetrievePortsProperty
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
	GTRetrievePortsProperty
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
	GTRetrievePortsProperty
Fend

Function ProbeCassettes
	Cls
    Print "GTProbeCassettes entered at ", Date$, " ", Time$

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

Function GTRetrievePortsProperty
	
	String RequestTokens$(0)
	Integer RequestArgC
    
    ''parse argument from global
    ParseStr g_RunArgs$, RequestTokens$(), " "
    ''check argument
    RequestArgC = UBound(RequestTokens$) + 1

	Integer strIndex
	String cassetteChar$
	Integer cassette_position
    String JSONResponse$
	Integer portsPerJSONPacket, numJSONPackets, responseJSONPacketIndex
	Integer startPortIndex, endPortIndex, portIndex
	Integer columnIndex, rowIndex, puckIndex, puckPortIndex
    If RequestArgC > 0 Then
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

			If (g_CassetteType(cassette_position) = NORMAL_CASSETTE) Or (g_CassetteType(cassette_position) = CALIBRATION_CASSETTE) Then
				portsPerJSONPacket = 24
				numJSONPackets = (NUM_ROWS * NUM_COLUMNS) / portsPerJSONPacket
				
				For responseJSONPacketIndex = 0 To numJSONPackets - 1
					startPortIndex = responseJSONPacketIndex * portsPerJSONPacket
					endPortIndex = (responseJSONPacketIndex + 1) * portsPerJSONPacket - 1
					
					JSONResponse$ = "{'set':'sample_distance_error','type':" + Str$(g_CassetteType(cassette_position))
					JSONResponse$ = JSONResponse$ + ",'start':" + Str$(startPortIndex) + ",'end':" + Str$(endPortIndex) + ",'value':["
					For portIndex = startPortIndex To endPortIndex
						columnIndex = portIndex / NUM_ROWS
						rowIndex = portIndex - (columnIndex * NUM_ROWS)
						
						JSONResponse$ = JSONResponse$ + FmtStr$(g_CASSampleDistanceError(cassette_position, rowIndex, columnIndex), "0.000") + ","
					Next
					JSONResponse$ = JSONResponse$ + "]}"

					UpdateClient(CLIENT_UPDATE, JSONResponse$, INFO_LEVEL)
				Next

			ElseIf g_CassetteType(cassette_position) = SUPERPUCK_CASSETTE Then
				portsPerJSONPacket = 16 '' One packet for each puck
				numJSONPackets = NUM_PUCKS
				
				For responseJSONPacketIndex = 0 To numJSONPackets - 1
					startPortIndex = responseJSONPacketIndex * portsPerJSONPacket
					endPortIndex = (responseJSONPacketIndex + 1) * portsPerJSONPacket - 1
					
					JSONResponse$ = "{'set':'sample_distance_error','type':" + Str$(g_CassetteType(cassette_position))
					JSONResponse$ = JSONResponse$ + ",'start':" + Str$(startPortIndex) + ",'end':" + Str$(endPortIndex) + ",'value':["
					puckIndex = responseJSONPacketIndex
					For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
						JSONResponse$ = JSONResponse$ + FmtStr$(g_SPSampleDistanceError(cassette_position, puckIndex, puckPortIndex), "0.000") + ","
					Next
					JSONResponse$ = JSONResponse$ + "]}"

					UpdateClient(CLIENT_UPDATE, JSONResponse$, INFO_LEVEL)
				Next
			EndIf
		Next
    EndIf
Fend

