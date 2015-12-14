#include "networkdefs.inc"
#include "genericdefs.inc"
#include "cassettedefs.inc"
#include "superpuckdefs.inc"

Function GTgetCassettePosition(cassetteChar$ As String, ByRef cassette_position As Integer) As Boolean
	cassetteChar$ = UCase$(cassetteChar$)
	Select cassetteChar$
		Case "L"
			cassette_position = LEFT_CASSETTE
		Case "M"
			cassette_position = MIDDLE_CASSETTE
		Case "R"
			cassette_position = RIGHT_CASSETTE
		Default
			cassette_position = UNKNOWN_POSITION
			GTgetCassettePosition = False
			Exit Function
	Send
	GTgetCassettePosition = True
Fend

Function GTProbeCassetteType(cassette_position As Integer) As Boolean
	Integer standbyPointNum
	Real scanZdistance
	Real cassette_top_Z_value, scanned_cassette_height
	Integer guessedCassetteType
	Real guessedCassetteType_height_error
	String msg$
	
	standbyPointNum = 52
	
	Tool PICKER_TOOL
	
	GTSetScanCassetteTopStandbyPoint(cassette_position, standbyPointNum, 0, ByRef scanZdistance)
	
	If GTScanCassetteTop(standbyPointNum, scanZdistance, ByRef cassette_top_Z_value) Then
		scanned_cassette_height = cassette_top_Z_value - g_BottomZ(cassette_position)
		msg$ = "GTProbeCassetteType->GTScanCassetteTop completed.  Detected Cassette Height = " + Str$(scanned_cassette_height)
		UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
	Else
		g_RunResult$ = "error GTProbeCassetteType->GTScanCassetteTop"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		GTProbeCassetteType = False
		Exit Function
	EndIf

	If Not GTCassetteTypeFromHeight(cassette_position, scanned_cassette_height, ByRef guessedCassetteType, ByRef guessedCassetteType_height_error) Then
		If guessedCassetteType_height_error > MAX_ERR_FOR_SCAN_CAS_TYPE_RTRY Then
			g_RunResult$ = "GTProbeCassetteType->GTCassetteTypeFromHeight failed: guessedCassetteType_height_error > MAX_ERR_FOR_SCAN_CAS_TYPE_RTRY!"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			GTProbeCassetteType = False
			Exit Function
		Else
			UpdateClient(TASK_MSG, "GTProbeCassetteType->GTCassetteTypeFromHeight: guessedCassetteType_height_error < MAX_ERR_FOR_SCAN_CAS_TYPE_RTRY. Starting comprehensive scan for Cassette Type", INFO_LEVEL)
			Real averageCassetteHeight
			If GTfindAverageCassetteHeight(cassette_position, scanned_cassette_height, guessedCassetteType, ByRef averageCassetteHeight) Then
				If Not GTCassetteTypeFromHeight(cassette_position, averageCassetteHeight, ByRef guessedCassetteType, ByRef guessedCassetteType_height_error) Then
					g_RunResult$ = "error GTProbeCassetteType->GTCassetteTypeFromHeight: averageHeight > ACCPT_ERROR_IN_CASSETTE_HEIGHT"
					UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
					GTProbeCassetteType = False
					Exit Function
				EndIf
			Else
				g_RunResult$ = "error GTProbeCassetteType->GTfindAverageCassetteHeight!"
				UpdateClient(TASK_MSG, "GTProbeCassetteType failed: error in GTfindAverageCassetteHeight!", ERROR_LEVEL)
				GTProbeCassetteType = False
				Exit Function
			EndIf
		EndIf
	EndIf
	
	g_RunResult$ = "normal OK"
	GTProbeCassetteType = True
Fend

Function GTProbeAllPorts(cassette_position As Integer) As Boolean
	If g_CassetteType(cassette_position) = SUPERPUCK_CASSETTE Then
		Integer puckIndex
		For puckIndex = 0 To NUM_PUCKS - 1
			g_RunResult$ = "progress GTProbeAllPorts->GTprobeAllPortsInPuck(" + GTCassetteName$(cassette_position) + "," + GTpuckName$(puckIndex) + ")"
			GTprobeAllPortsInPuck(cassette_position, puckIndex)
		Next
	ElseIf (g_CassetteType(cassette_position) = CALIBRATION_CASSETTE) Or (g_CassetteType(cassette_position) = NORMAL_CASSETTE) Then
		Integer columnIndex
		For columnIndex = 0 To NUM_COLUMNS - 1
			g_RunResult$ = "progress GTProbeAllPorts->GTprobeAllPortsInColumn(" + GTCassetteName$(cassette_position) + ",col=" + GTcolumnName$(columnIndex) + ")"
			GTprobeAllPortsInColumn(cassette_position, columnIndex)
		Next
	Else
		g_RunResult$ = "error GTProbeAllPorts: " + GTCassetteName$(cassette_position) + " type is unknown/absent!"
		GTProbeAllPorts = False
		Exit Function
	EndIf

	g_RunResult$ = "success GTProbeAllPorts(" + GTCassetteName$(cassette_position) + ")"
	GTProbeAllPorts = True
Fend

Function GTResetCassette(cassette_position As Integer)
	If g_CassetteType(cassette_position) = SUPERPUCK_CASSETTE Then
		Integer puckIndex
		For puckIndex = 0 To NUM_PUCKS - 1
			GTResetPuck(cassette_position, puckIndex)
		Next
	Else
		Integer columnIndex
		For columnIndex = 0 To NUM_COLUMNS - 1
			GTResetColumn(cassette_position, columnIndex)
		Next
	EndIf
Fend
