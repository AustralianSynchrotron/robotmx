#include "networkdefs.inc"
#include "genericdefs.inc"
#include "cassettedefs.inc"
#include "superpuckdefs.inc"

'' GTResetSpecificPorts can be called independent of cassette_type
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
	GTProbeCassetteType = False
		
	Integer standbyPointNum
	Real scanZdistance
	Real cassette_top_Z_value, scanned_cassette_height
	Integer guessedCassetteType
	Real guessedCassetteType_height_error
	String msg$
	
	standbyPointNum = 52
	
	Tool PICKER_TOOL
	GTsetRobotSpeedMode(INSIDE_LN2_SPEED)

	GTSetScanCassetteTopStandbyPoint(cassette_position, standbyPointNum, 0, ByRef scanZdistance)
	
	If GTScanCassetteTop(standbyPointNum, scanZdistance, ByRef cassette_top_Z_value) Then
		scanned_cassette_height = cassette_top_Z_value - g_BottomZ(cassette_position)
		msg$ = "GTProbeCassetteType->GTScanCassetteTop completed.  Detected Cassette Height = " + Str$(scanned_cassette_height)
		UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
		
		guessedCassetteType = GTCassetteTypeFromHeight(cassette_position, scanned_cassette_height, ByRef guessedCassetteType_height_error)

		If guessedCassetteType_height_error < ACCPT_ERROR_IN_CASSETTE_HEIGHT Then
			g_CassetteType(cassette_position) = guessedCassetteType
			msg$ = "GTScanCassetteTop completed. GTCassetteTypeFromHeight reports " + GTCassetteName$(cassette_position) + " CassetteType=" + GTCassetteType$(guessedCassetteType) + " with height_error=" + Str$(guessedCassetteType_height_error)
			UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
			GTProbeCassetteType = True
		ElseIf guessedCassetteType_height_error < MAX_ERR_FOR_SCAN_CAS_TYPE_RTRY Then
			UpdateClient(TASK_MSG, "GTProbeCassetteType->GTCassetteTypeFromHeight: guessedCassetteType_height_error < MAX_ERR_FOR_SCAN_CAS_TYPE_RTRY. Starting Average Cassette Height scan for Cassette Type", INFO_LEVEL)
			
			Real averageCassetteHeight
            If GTfindAverageCassetteHeight(cassette_position, scanned_cassette_height, guessedCassetteType, ByRef averageCassetteHeight) Then
				msg$ = "GTProbeCassetteType-GTfindAverageCassetteHeight completed.  Detected Average Cassette Height = " + Str$(averageCassetteHeight)
				UpdateClient(TASK_MSG, msg$, INFO_LEVEL)

				guessedCassetteType = GTCassetteTypeFromHeight(cassette_position, averageCassetteHeight, ByRef guessedCassetteType_height_error)
				If guessedCassetteType_height_error < ACCPT_ERROR_IN_CASSETTE_HEIGHT Then
					g_CassetteType(cassette_position) = guessedCassetteType
					msg$ = "GTfindAverageCassetteHeight completed. GTCassetteTypeFromHeight reports " + GTCassetteName$(cassette_position) + " CassetteType=" + GTCassetteType$(guessedCassetteType) + " with height_error=" + Str$(guessedCassetteType_height_error)
					UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
					GTProbeCassetteType = True
				Else
					g_CassetteType(cassette_position) = UNKNOWN_CASSETTE
					g_RunResult$ = "error GTfindAverageCassetteHeight for " + GTCassetteName$(cassette_position) + " found min_height_error=" + Str$(guessedCassetteType_height_error) + ">ACCPT_ERROR_IN_CASSETTE_HEIGHT =" + Str$(ACCPT_ERROR_IN_CASSETTE_HEIGHT)
					UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
				EndIf
			Else
				UpdateClient(TASK_MSG, "GTProbeCassetteType failed: error in GTfindAverageCassetteHeight!", ERROR_LEVEL)
				g_CassetteType(cassette_position) = UNKNOWN_CASSETTE
			EndIf
		Else
			g_CassetteType(cassette_position) = UNKNOWN_CASSETTE
			g_RunResult$ = "error GTProbeCassetteType->GTCassetteTypeFromHeight failed: guessedCassetteType_height_error > MAX_ERR_FOR_SCAN_CAS_TYPE_RTRY!"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		EndIf
	Else
		''May be Cassette Not found in this position
		g_CassetteType(cassette_position) = UNKNOWN_CASSETTE
		g_RunResult$ = "error GTProbeCassetteType->GTScanCassetteTop could not find the cassette top. " + GTCassetteName$(cassette_position) + " may be absent."
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
	EndIf

	g_min_height_errors(cassette_position) = guessedCassetteType_height_error
	
	'' Client Update after probing decision has been made
	msg$ = "{'set':'cassette_type', 'position':'" + GTCassettePosition$(cassette_position) + "', 'min_height_error':" + Str$(guessedCassetteType_height_error) + ", 'value':'" + GTCassetteType$(g_CassetteType(cassette_position)) + "'}"
	UpdateClient(CLIENT_UPDATE, msg$, INFO_LEVEL)
Fend

'' This function is called independent of cassette_type after probing
Function GTProbeSpecificPorts(cassette_position As Integer) As Boolean
	GTProbeSpecificPorts = False '' If the function breaks before finishing completely, return false

	'' Based on the type of cassette, call the corresponding function to probe according to that cassette's geometry
    	If g_CassetteType(cassette_position) = SUPERPUCK_CASSETTE Then
			If Not GTProbeSpecificPortsInSuperPuck(cassette_position) Then
				UpdateClient(TASK_MSG, "GTProbeSpecificPortsInSuperPuck failed", ERROR_LEVEL)
				Exit Function
			EndIf
		ElseIf (g_CassetteType(cassette_position) = NORMAL_CASSETTE) Or (g_CassetteType(cassette_position) = CALIBRATION_CASSETTE) Then
			If Not GTProbeSpecificPortsInCassette(cassette_position) Then
				UpdateClient(TASK_MSG, "GTProbeSpecificPortsInCassette failed", ERROR_LEVEL)
				Exit Function
			EndIf
		Else
			g_RunResult$ = "error " + GTCassetteName$(cassette_position) + " is unknown type!"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		EndIf
	
	GTProbeSpecificPorts = True
Fend


