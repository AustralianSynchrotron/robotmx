#include "forcedefs.inc"
#include "mxrobotdefs.inc"
#include "GTCassettedefs.inc"
#include "GTReporterdefs.inc"

Function GTSetScanCassetteTopStandbyPoint(cassette_position As Integer, pointNum As Integer, ByRef scanZdistance As Real)
	Real radiusToCircleCassette, standbyPointU, standbyZoffsetFromCassetteBottom
	
	radiusToCircleCassette = CASSETTE_RADIUS * CASSETTE_SHRINK_IN_LN2 - 3.0
	standbyPointU = g_UForNormalStandby(cassette_position) + GTBoundAngle(-180, 180, (g_AngleOfFirstColumn(cassette_position) - g_UForNormalStandby(cassette_position)))
	
	'' 15mm above Maximum Cassette Height = SUPERPUCK_HEIGHT
	standbyZoffsetFromCassetteBottom = CASSETTE_SHRINK_IN_LN2 * SUPERPUCK_HEIGHT + 15.0

	'' Internally sets P(pointNum) to CircumferencePointFromU
	GTSetCircumferencePointFromU(cassette_position, standbyPointU, radiusToCircleCassette, standbyZoffsetFromCassetteBottom, pointNum)

	'' Rotate 30 degrees to give cavity some space
	P(pointNum) = P(pointNum) +U(30.0)
	
	'' Maximum distance in Z-axis to scan for Cassette using TouchCassetteTop = 30mm
	scanZdistance = 30.0
Fend

Function GTScanCassetteTop(standbyPointNum As Integer, maxZdistanceToScan As Real, ByRef cassetteTopZvalue As Real) As Boolean
	GTUpdateClient(TASK_ENTERED_REPORT, HIGH_LEVEL_FUNCTION, "GTScanCassetteTop entered with standbyPoint=P" + Str$(standbyPointNum) + ", maxZdistanceToScan=" + Str$(maxZdistanceToScan))
	
	LimZ g_Jump_LimZ_LN2
	Jump P(standbyPointNum)

	InitForceConstants
	''ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY)
	
	If Not (ForceTouch(-FORCE_ZFORCE, maxZdistanceToScan, False)) Then
		GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTScanCassetteTop: ForceTouch failed to detect Cassette!")
		GTScanCassetteTop = False
		Exit Function
	EndIf
	
	cassetteTopZvalue = CZ(Here) - MAGNET_HEAD_RADIUS
	
	SetVerySlowSpeed
	Move P(standbyPointNum)
	
	GTUpdateClient(TASK_DONE_REPORT, HIGH_LEVEL_FUNCTION, "GTScanCassetteTop successfully completed. cassetteTopZvalue=" + Str$(cassetteTopZvalue))
	GTScanCassetteTop = True
Fend

