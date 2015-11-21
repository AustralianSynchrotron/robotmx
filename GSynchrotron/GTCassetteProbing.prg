#include "mxrobotdefs.inc"
#include "GTCassettedefs.inc"
#include "forcedefs.inc"

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

Function GTScanCassetteTop(standbyPointNum As Integer, maxZdistanceToScan As Real, ByRef cassetteTopZvalue As Real, ByRef StatusStringToAppend$ As String) As Boolean
	LimZ g_Jump_LimZ_LN2
	Jump P(standbyPointNum)
	
	If Not (ForceTouch(-FORCE_ZFORCE, maxZdistanceToScan, False)) Then
		StatusStringToAppend$ = StatusStringToAppend$ + "GTScanCassetteTop: ForceTouch failed to detect Cassette!"
		GTScanCassetteTop = False
		Exit Function
	EndIf
	
	cassetteTopZvalue = CZ(Here) - MAGNET_HEAD_RADIUS
	
	SetVerySlowSpeed
	Move P(standbyPointNum)
	
	GTScanCassetteTop = True
Fend

Function GTtestCassetteScan()
	Integer standbyPointNum
	Real scanZdistance, cassetteHeight
	String status$
	
	GTInitAllPoints
	
	standbyPointNum = 52
	
	Tool 1
	
	GTSetScanCassetteTopStandbyPoint(LEFT_CASSETTE, standbyPointNum, ByRef scanZdistance)
	InitForceConstants
	''ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY)
	If GTScanCassetteTop(standbyPointNum, scanZdistance, ByRef cassetteHeight, ByRef status$) Then
		g_RunResult$ = "GTtestCassetteScan ran successfully. Detected Cassette Height = " + Str$(cassetteHeight)
	Else
		g_RunResult$ = status$
	EndIf
Fend

