#include "networkdefs.inc"
#include "genericdefs.inc"
#include "cassettedefs.inc"
#include "superpuckdefs.inc"

'' GTResetSpecificPorts can be called independent of CASSETTE_TYPE
Function GTResetSpecificPorts(cassette_position As Integer)
	'' For each cassette_position, two arrays needs to be reset (the superpuck array and the cassette array)

	'' if this function (GTResetSpecificPorts) is called after probing cassettetype and 
	'' if the casettetype is SuperPuck, Cassette Array is completely reset (and vice versa)

	'' Reset the superpuck array, corresponding to cassette_position
	GTResetSpecificPortsInSuperPuck(cassette_position)
	
	'' Reset the cassette array, corresponding to cassette_position
	GTResetSpecificPortsInCassette(cassette_position)
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

'' This function is called independent of CASSETTE_TYPE after probing
Function GTProbeSpecificPorts(cassette_position As Integer) As Boolean
	GTProbeSpecificPorts = False '' If the function breaks before finishing completely, return false

	'' Based on the type of cassette, call the corresponding function to probe according to that cassette's geometry
    	If g_CassetteType(cassette_position) = SUPERPUCK_CASSETTE Then
			If Not GTProbeSpecificPortsInSuperPuck(cassette_position) Then
				g_RunResult$ = "GTProbeSpecificPortsInSuperPuck failed"
				UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
				Exit Function
			EndIf
		ElseIf (g_CassetteType(cassette_position) = NORMAL_CASSETTE) Or (g_CassetteType(cassette_position) = CALIBRATION_CASSETTE) Then
			If Not GTProbeSpecificPortsInCassette(cassette_position) Then
				g_RunResult$ = "GTProbeSpecificPortsInCassette failed"
				UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
				Exit Function
			EndIf
		Else
			g_RunResult$ = "No " + GTCassetteName$(cassette_position) + " found"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		EndIf
	
	GTProbeSpecificPorts = True
Fend


