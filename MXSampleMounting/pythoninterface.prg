#include "networkdefs.inc"
#include "genericdefs.inc"
#include "cassettedefs.inc"
#include "superpuckdefs.inc"
#include "jsondefs.inc"
#include "mountingdefs.inc"

Global String g_PortsRequestString$(NUM_CASSETTES)

Function GTParseCassettePosition(cassetteChar$ As String, ByRef cassette_position As Integer) As Boolean
	Select UCase$(cassetteChar$)
		Case "L"
			cassette_position = LEFT_CASSETTE
		Case "M"
			cassette_position = MIDDLE_CASSETTE
		Case "R"
			cassette_position = RIGHT_CASSETTE
		Default
			cassette_position = UNKNOWN_CASSETTE
			UpdateClient(TASK_MSG, "GTParseCassettePosition: Invalid Cassette Position supplied!", ERROR_LEVEL)
			GTParseCassettePosition = False
			Exit Function
	Send
	GTParseCassettePosition = True
Fend

Function GTParsePortIndex(cassette_position As Integer, columnOrPuckChar$ As String, rowOrPuckPortChar$ As String, ByRef columnPuckIndex As Integer, ByRef rowPuckPortIndex As Integer) As Boolean
	GTParsePortIndex = False
	If (g_CassetteType(cassette_position) = NORMAL_CASSETTE) Or (g_CassetteType(cassette_position) = CALIBRATION_CASSETTE) Then
		If Not GTParseColumnIndex(columnOrPuckChar$, ByRef columnPuckIndex) Then
			UpdateClient(TASK_MSG, "GTParsePortIndex: Invalid Column Name supplied!", ERROR_LEVEL)
			Exit Function
		EndIf
		
		rowPuckPortIndex = Val(rowOrPuckPortChar$) - 1
		If rowPuckPortIndex < 0 Or rowPuckPortIndex > NUM_ROWS - 1 Then
			UpdateClient(TASK_MSG, "GTParsePortIndex: Invalid Row Position supplied!", ERROR_LEVEL)
			Exit Function
		EndIf
	ElseIf g_CassetteType(cassette_position) = SUPERPUCK_CASSETTE Then
		If Not GTParsePuckIndex(columnOrPuckChar$, ByRef columnPuckIndex) Then
			UpdateClient(TASK_MSG, "GTParsePortIndex: Invalid Puck Name supplied!", ERROR_LEVEL)
			Exit Function
		EndIf
		rowPuckPortIndex = Val(rowOrPuckPortChar$) - 1
		If rowPuckPortIndex < 0 Or rowPuckPortIndex > NUM_PUCK_PORTS - 1 Then
			UpdateClient(TASK_MSG, "GTParsePortIndex: Invalid Puck Port supplied!", ERROR_LEVEL)
			Exit Function
		EndIf
	Else
		UpdateClient(TASK_MSG, "GTParsePortIndex: Invalid CassetteType Detected! Please probe this cassette again", ERROR_LEVEL)
		Exit Function
	EndIf
	GTParsePortIndex = True
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
	
	GTStartRobot
	
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
    If RequestArgC > 0 Then
    	For jsonDataToSendStrIndex = 1 To Len(RequestTokens$(0))
			Select UCase$(Mid$(RequestTokens$(0), jsonDataToSendStrIndex, 1))
				Case "C"
					jsonDataToSend = CASSETTE_TYPE
				Case "A"
					jsonDataToSend = PUCK_STATES
				Case "P"
					jsonDataToSend = PORT_STATES
				Case "D"
					jsonDataToSend = SAMPLE_DISTANCES
				Case "F"
					jsonDataToSend = PORT_FORCES
				Case "S"
					jsonDataToSend = SAMPLE_STATE
					GTsendSampleStateJSON
					GoTo endOfThisForLoop
				Case "M"
					jsonDataToSend = MAGNET_STATE
					GTsendMagnetStateJSON
					GoTo endOfThisForLoop
				Default
					Exit Function
			Send
			
			For strIndex = 1 To Len(RequestTokens$(1))
				cassetteChar$ = Mid$(RequestTokens$(1), strIndex, 1)
				
				If Not GTParseCassettePosition(cassetteChar$, ByRef cassette_position) Then
					cassette_position = UNKNOWN_CASSETTE
					UpdateClient(TASK_MSG, "Invalid cassette position in g_RunArgs$!", ERROR_LEVEL)
					''Exit Function '' Donot exit function because python doesn't know the error unless we send JSON data for error
				EndIf
				GTsendCassetteData(jsonDataToSend, cassette_position)
			Next

			endOfThisForLoop:
		Next
    EndIf
Fend

Function MountSamplePort
    Print "MountSamplePort entered at ", Date$, " ", Time$
    
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
	
	''Before you start parsing the g_RunArgs$, 
	''check the gonio to see whether there is already a sample mounted
	''If mounted, then dismount it first then mount the new sample
	If g_InterestedSampleStatus = SAMPLE_IN_GONIO Then
		''Notice that the input parameters are the global variables which are already set. Only recheck is done here.
	 	If Not GTsetDismountPort(g_InterestedCassettePosition, g_InterestedPuckColumnIndex, g_InterestedRowPuckPortIndex) Then
			g_RunResult$ = "MountSamplePort->GTsetDismountPort: Sample already Present in Port or Invalid Port Position supplied in g_RunArgs$"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf
		
		''Only after all the input checks are successful start moving the robot
		GTStartRobot
		
		If Not GTCheckMagnetForDismount Then
			g_RunResult$ = "Error in MountSamplePort->GTCheckMagnetForDismount: Check log for further details"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf
	
	
		If Not GTDismountToInterestedPort Then
			g_RunResult$ = "Error in MountSamplePort->GTDismountToInterestedPort: Check log for further details"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf
	EndIf
	
	
	''Actual mounting process starts here 
	
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
		If Not GTParseCassettePosition(cassetteChar$, ByRef cassette_position) Then
			cassette_position = UNKNOWN_CASSETTE
			g_RunResult$ = "MountSamplePort: Invalid Cassette Position supplied in g_RunArgs$"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf

		columnOrPuckChar$ = Mid$(RequestTokens$(1), 1, 1)
		rowOrPuckPortChar$ = RequestTokens$(2)
		
		If Not GTParsePortIndex(cassette_position, columnOrPuckChar$, rowOrPuckPortChar$, ByRef columnPuckIndex, ByRef rowPuckPortIndex) Then
			g_RunResult$ = "MountSamplePort: GTParsePortIndex failed! Please check log for further details"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf
	EndIf
	
	If Not GTsetMountPort(cassette_position, columnPuckIndex, rowPuckPortIndex) Then
		g_RunResult$ = "MountSamplePort->GTsetMountPort: No Sample Present in Port or Invalid Port Position supplied in g_RunArgs$"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	''Only after all the input checks are successful start moving the robot
	GTStartRobot
	
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
	
	If Not GTMountInterestedPort Then
		g_RunResult$ = "Error in MountSamplePort->GTMountInterestedPort: Check log for further details"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	g_RunResult$ = "success MountSamplePort"
    Print "MountSamplePort finished at ", Date$, " ", Time$
Fend

Function DismountSample
    Print "DismountSample entered at ", Date$, " ", Time$
    
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
		If Not GTParseCassettePosition(cassetteChar$, ByRef cassette_position) Then
			cassette_position = UNKNOWN_CASSETTE
			g_RunResult$ = "DismountSample: Invalid Cassette Position supplied in g_RunArgs$"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf

		columnOrPuckChar$ = Mid$(RequestTokens$(1), 1, 1)
		rowOrPuckPortChar$ = RequestTokens$(2)
		
		If Not GTParsePortIndex(cassette_position, columnOrPuckChar$, rowOrPuckPortChar$, ByRef columnPuckIndex, ByRef rowPuckPortIndex) Then
			g_RunResult$ = "DismountSample: GTParsePortIndex failed! Please check log for further details"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf
	EndIf
	
	If Not GTsetDismountPort(cassette_position, columnPuckIndex, rowPuckPortIndex) Then
		g_RunResult$ = "DismountSample->GTsetDismountPort: Sample already Present in Port or Invalid Port Position supplied in g_RunArgs$"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	''Only after all the input checks are successful start moving the robot
	GTStartRobot
	
	If Not GTCheckMagnetForDismount Then
		g_RunResult$ = "Error in DismountSample->GTCheckMagnetForDismount: Check log for further details"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf


	If Not GTDismountToInterestedPort Then
		g_RunResult$ = "Error in DismountSample->GTDismountToInterestedPort: Check log for further details"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	'' Put dumbbell in Cradle and go Home (P0)
	If Not GTReturnMagnetAndGoHome Then
		g_RunResult$ = "GTReturnMagnet failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	g_RunResult$ = "success DismountSample"
    Print "DismountSample finished at ", Date$, " ", Time$
Fend


