#include "GTGenericdefs.inc"
#include "GTCassettedefs.inc"
#include "GTSuperPuckdefs.inc"
#include "GTReporterdefs.inc"

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
	
	standbyPointNum = 52
	
	Tool PICKER_TOOL
	
	g_RunResult$ = "progress GTProbeCassetteType->GTSetScanCassetteTopStandbyPoint"
	GTSetScanCassetteTopStandbyPoint(cassette_position, standbyPointNum, 0, ByRef scanZdistance)
	
	g_RunResult$ = "progress GTProbeCassetteType->GTScanCassetteTop"
	If GTScanCassetteTop(standbyPointNum, scanZdistance, ByRef cassette_top_Z_value) Then
		scanned_cassette_height = cassette_top_Z_value - g_BottomZ(cassette_position)
		GTUpdateClient(TASK_MESSAGE_REPORT, HIGH_LEVEL_FUNCTION, "GTProbeCassetteType->GTScanCassetteTop completed.  Detected Cassette Height = " + Str$(scanned_cassette_height))
	Else
		GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTProbeCassetteType failed: error in GTScanCassetteTop!")
		g_RunResult$ = "error GTProbeCassetteType->GTScanCassetteTop"
		GTProbeCassetteType = False
		Exit Function
	EndIf

	g_RunResult$ = "progress GTProbeCassetteType->GTCassetteTypeFromHeight"
	If Not GTCassetteTypeFromHeight(cassette_position, scanned_cassette_height, ByRef guessedCassetteType, ByRef guessedCassetteType_height_error) Then
		If guessedCassetteType_height_error > MAX_ERR_FOR_SCAN_CAS_TYPE_RTRY Then
			GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTProbeCassetteType->GTCassetteTypeFromHeight failed: guessedCassetteType_height_error > MAX_ERR_FOR_SCAN_CAS_TYPE_RTRY!")
			g_RunResult$ = "error GTProbeCassetteType->GTCassetteTypeFromHeight: guessedCassetteType_height_error > MAX_ERR_FOR_SCAN_CAS_TYPE_RTRY"
			GTProbeCassetteType = False
			Exit Function
		Else
			GTUpdateClient(TASK_MESSAGE_REPORT, HIGH_LEVEL_FUNCTION, "GTProbeCassetteType->GTCassetteTypeFromHeight: guessedCassetteType_height_error < MAX_ERR_FOR_SCAN_CAS_TYPE_RTRY. Starting comprehensive scan for Cassette Type")

			g_RunResult$ = "progress GTProbeCassetteType->GTfindAverageCassetteHeight"
			Real averageCassetteHeight
			If GTfindAverageCassetteHeight(cassette_position, scanned_cassette_height, guessedCassetteType, ByRef averageCassetteHeight) Then
				If Not GTCassetteTypeFromHeight(cassette_position, averageCassetteHeight, ByRef guessedCassetteType, ByRef guessedCassetteType_height_error) Then
					g_RunResult$ = "error GTProbeCassetteType->GTCassetteTypeFromHeight: averageHeight > ACCPT_ERROR_IN_CASSETTE_HEIGHT"
					GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTProbeCassetteType->GTCassetteTypeFromHeight failed: guessedCassetteType_height_error=" + Str$(guessedCassetteType_height_error) + " for averageCassetteHeight=" + Str$(averageCassetteHeight))
					GTProbeCassetteType = False
					Exit Function
				EndIf
			Else
				g_RunResult$ = "error GTProbeCassetteType->GTfindAverageCassetteHeight!"
				GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTProbeCassetteType failed: error in GTfindAverageCassetteHeight!")
				GTProbeCassetteType = False
				Exit Function
			EndIf
		EndIf
	EndIf
	
	g_RunResult$ = "success GTProbeCassetteType"
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

Function ResetPorts(cassette_position As Integer)
	If g_CassetteType(cassette_position) = SUPERPUCK_CASSETTE Then
		Integer puckIndex, portIndex
		For puckIndex = 0 To NUM_ROWS - 1
			g_PuckPresent(cassette_position, puckIndex) = False
			For portIndex = 0 To NUM_PUCK_PORTS - 1
				g_SampleDistancefromPuckSurface(cassette_position, puckIndex, portIndex) = 0.0
				g_SP_SamplePresent(cassette_position, puckIndex, NUM_PUCK_PORTS) = False
			Next
		Next
	Else
		Integer columnIndex, rowIndex
		For columnIndex = 0 To NUM_COLUMNS - 1
			For rowIndex = 0 To NUM_ROWS - 1
				g_SampleDistancefromCASSurface(cassette_position, rowIndex, columnIndex) = 0.0
				g_CAS_SamplePresent(cassette_position, rowIndex, columnIndex) = False
			Next
		Next
	EndIf
Fend

