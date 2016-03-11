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
	If g_CassetteType(cassette_position) = NORMAL_CASSETTE Then
		If Not GTParseColumnIndex(columnOrPuckChar$, ByRef columnPuckIndex) Then
			UpdateClient(TASK_MSG, "GTParsePortIndex: Invalid Column Name supplied!", ERROR_LEVEL)
			Exit Function
		EndIf
		
		rowPuckPortIndex = Val(rowOrPuckPortChar$) - 1
		If rowPuckPortIndex < 0 Or rowPuckPortIndex > NUM_ROWS - 1 Then
			UpdateClient(TASK_MSG, "GTParsePortIndex: Invalid Row Position supplied!", ERROR_LEVEL)
			Exit Function
		EndIf
	ElseIf g_CassetteType(cassette_position) = CALIBRATION_CASSETTE Then
		If Not GTParseColumnIndex(columnOrPuckChar$, ByRef columnPuckIndex) Then
			UpdateClient(TASK_MSG, "GTParsePortIndex: Invalid Column Name supplied!", ERROR_LEVEL)
			Exit Function
		EndIf
		
		rowPuckPortIndex = Val(rowOrPuckPortChar$) - 1
		If rowPuckPortIndex <> 0 And rowPuckPortIndex <> (NUM_ROWS - 1) Then
			UpdateClient(TASK_MSG, "GTParsePortIndex: Invalid Row Position supplied for Calibration Cassette!", ERROR_LEVEL)
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
		''Problem detected
		Exit Function
	EndIf
	
	If Not GTJumpHomeToCoolingPointAndWait Then
		''Problem detected
		Exit Function
	EndIf

	If Not GTCheckAndPickMagnet Then
		''Problem detected
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
				'' Only if the cassette type is known at cassette_position start probing inside the cassette
            	''only the ports that are to be probed are reset to unknown before probing.
            	''GTResetSpecificPorts is only called here because the user might forget to call it before probing
				GTResetSpecificPorts(cassette_position)
				If Not GTProbeSpecificPorts(cassette_position) Then
					UpdateClient(TASK_MSG, "GTProbeSpecificPorts Failed", ERROR_LEVEL)
					Exit Function
				EndIf
			EndIf
		EndIf

	Next
	
	'' Return Magnet To Cradle And Go to Home Position
	If Not GTReturnMagnetAndGoHome Then
		UpdateClient(TASK_MSG, "GTReturnMagnetAndGoHome failed", ERROR_LEVEL)
		Exit Function
	EndIf
	
	g_RunResult$ = "OK GTProbeCassettes"
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
				Case "T"
					jsonDataToSend = TRIGGER_PORT_FORCES
				Case "F"
					jsonDataToSend = FINAL_PORT_FORCES
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
		UpdateClient(TASK_MSG, "GTInitialize failed", ERROR_LEVEL)
		Exit Function
	EndIf
	
	''Before you start parsing the g_RunArgs$, 
	''check the gonio to see whether there is already a sample mounted
	''If mounted, then dismount it first then mount the new sample
	If g_InterestedSampleStatus = SAMPLE_IN_GONIO Then
		''Notice that the input parameters are the global variables which are already set. Only recheck is done here.
	 	If Not GTsetDismountPort(g_InterestedCassettePosition, g_InterestedPuckColumnIndex, g_InterestedRowPuckPortIndex) Then
			UpdateClient(TASK_MSG, "MountSamplePort->GTsetDismountPort: Sample already Present in Port or Invalid Port Position supplied in g_RunArgs$", ERROR_LEVEL)
			Exit Function
		EndIf
		
		If Not GTJumpHomeToCoolingPointAndWait Then
			Exit Function
		EndIf
		
		If Not GTCheckMagnetForDismount Then
			UpdateClient(TASK_MSG, "Error in MountSamplePort->GTCheckMagnetForDismount: Check log for further details", ERROR_LEVEL)
			Exit Function
		EndIf
	
	
		If Not GTDismountToInterestedPort Then
			UpdateClient(TASK_MSG, "Error in MountSamplePort->GTDismountToInterestedPort: Check log for further details", ERROR_LEVEL)
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
			UpdateClient(TASK_MSG, "MountSamplePort: Invalid Cassette Position supplied in g_RunArgs$", ERROR_LEVEL)
			Exit Function
		EndIf

		columnOrPuckChar$ = Mid$(RequestTokens$(1), 1, 1)
		rowOrPuckPortChar$ = RequestTokens$(2)
		
		If Not GTParsePortIndex(cassette_position, columnOrPuckChar$, rowOrPuckPortChar$, ByRef columnPuckIndex, ByRef rowPuckPortIndex) Then
			UpdateClient(TASK_MSG, "MountSamplePort: GTParsePortIndex failed! Please check log for further details", ERROR_LEVEL)
			Exit Function
		EndIf
	EndIf
	
	If Not GTsetMountPort(cassette_position, columnPuckIndex, rowPuckPortIndex) Then
		UpdateClient(TASK_MSG, "MountSamplePort->GTsetMountPort: No Sample Present in Port or Invalid Port Position supplied in g_RunArgs$", ERROR_LEVEL)
		Exit Function
	EndIf
	
	If Not GTJumpHomeToCoolingPointAndWait Then
		Exit Function
	EndIf

	If Not GTCheckAndPickMagnet Then
		Exit Function
	EndIf
	
	If Not GTMountInterestedPort Then
		UpdateClient(TASK_MSG, "Error in MountSamplePort->GTMountInterestedPort: Check log for further details", ERROR_LEVEL)
		Exit Function
	EndIf
	
	g_RunResult$ = "OK MountSamplePort"
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
		UpdateClient(TASK_MSG, "GTInitialize failed", ERROR_LEVEL)
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
			UpdateClient(TASK_MSG, "DismountSample: Invalid Cassette Position supplied in g_RunArgs$", ERROR_LEVEL)
			Exit Function
		EndIf

		columnOrPuckChar$ = Mid$(RequestTokens$(1), 1, 1)
		rowOrPuckPortChar$ = RequestTokens$(2)
		
		If Not GTParsePortIndex(cassette_position, columnOrPuckChar$, rowOrPuckPortChar$, ByRef columnPuckIndex, ByRef rowPuckPortIndex) Then
			UpdateClient(TASK_MSG, "DismountSample: GTParsePortIndex failed! Please check log for further details", ERROR_LEVEL)
			Exit Function
		EndIf
	EndIf
	
	If Not GTsetDismountPort(cassette_position, columnPuckIndex, rowPuckPortIndex) Then
		UpdateClient(TASK_MSG, "DismountSample->GTsetDismountPort: Sample already Present in Port or Invalid Port Position supplied in g_RunArgs$", ERROR_LEVEL)
		Exit Function
	EndIf

	If Not GTJumpHomeToCoolingPointAndWait Then
		Exit Function
	EndIf
		
	If Not GTCheckMagnetForDismount Then
		UpdateClient(TASK_MSG, "Error in DismountSample->GTCheckMagnetForDismount: Check log for further details", ERROR_LEVEL)
		Exit Function
	EndIf

	If Not GTDismountToInterestedPort Then
		UpdateClient(TASK_MSG, "Error in DismountSample->GTDismountToInterestedPort: Check log for further details", ERROR_LEVEL)
		Exit Function
	EndIf
	
	'' Put dumbbell in Cradle and go Home (P0)
	If Not GTReturnMagnetAndGoHome Then
		UpdateClient(TASK_MSG, "GTReturnMagnet failed", ERROR_LEVEL)
		Exit Function
	EndIf
	
	g_RunResult$ = "OK DismountSample"
    Print "DismountSample finished at ", Date$, " ", Time$
Fend

''Find Centers
Function FindPortCenters
	Cls
    Print "FindPortCenters entered at ", Date$, " ", Time$
    
    ''Ensure moves are not restricted to XY plane for probe
    g_OnlyAlongAxis = False

	''init result
    g_RunResult$ = ""
    
	'' Initialize all constants
	If Not GTInitialize Then
		UpdateClient(TASK_MSG, "GTInitialize failed", ERROR_LEVEL)
		Exit Function
	EndIf
	
	If Not GTJumpHomeToCoolingPointAndWait Then
		Exit Function
	EndIf

	If Not GTCheckAndPickMagnet Then
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
				'' Only if the cassette type is known at cassette_position start probing inside the cassette
				If Not GTFindPortCentersInSuperPuck(cassette_position) Then
					UpdateClient(TASK_MSG, "GTFindPortCentersInSuperPuck Failed", ERROR_LEVEL)
					Exit Function
				EndIf
			EndIf
		EndIf

	Next
	
	'' Return Magnet To Cradle And Go to Home Position
	If Not GTReturnMagnetAndGoHome Then
		UpdateClient(TASK_MSG, "GTReturnMagnetAndGoHome failed", ERROR_LEVEL)
		Exit Function
	EndIf
	
	g_RunResult$ = "OK FindPortCenters"
    Print "FindPortCenters finished at ", Date$, " ", Time$
Fend

