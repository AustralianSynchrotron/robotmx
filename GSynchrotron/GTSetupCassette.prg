#include "mxrobotdefs.inc"
#include "GTCassettedefs.inc"
#include "GTReporterdefs.inc"

'' Angles and U for Each Cassette
Global Real g_AngleOfFirstColumn(NUM_CASSETTES)
Global Real g_UForNormalStandby(NUM_CASSETTES)
Global Real g_UForSecondaryStandby(NUM_CASSETTES)
Global Real g_UForPuckStandby(NUM_CASSETTES)

'' Tilt Information for Each Cassette
Global Real g_tiltDX(NUM_CASSETTES)
Global Real g_tiltDY(NUM_CASSETTES)

'' Actual Cassette Center's X,Y Coordinates obtained using tilt information
Global Real g_CenterX(NUM_CASSETTES)
Global Real g_CenterY(NUM_CASSETTES)
Global Real g_BottomZ(NUM_CASSETTES)

Global Real g_AngleOffset(NUM_CASSETTES)

Function GTCassetteName$(cassette_position As Integer) As String
	If cassette_position = LEFT_CASSETTE Then
		GTCassetteName$ = "left_cassette"
	ElseIf cassette_position = MIDDLE_CASSETTE Then
		GTCassetteName$ = "middle_cassette"
	ElseIf cassette_position = RIGHT_CASSETTE Then
		GTCassetteName$ = "right_cassette"
	EndIf
Fend

Function GTSetupDirection(cassette_position As Integer, column_A_Angle As Real, standbyU As Real, secondaryStandbyU As Real)
	g_AngleOfFirstColumn(cassette_position) = column_A_Angle
	g_UForNormalStandby(cassette_position) = standbyU
	g_UForSecondaryStandby(cassette_position) = secondaryStandbyU
	g_UForPuckStandby(cassette_position) = (standbyU + secondaryStandbyU) / 2.0
Fend

Function GTSetupCoordinates(cassette_position As Integer, pointNum As Integer)
	g_CenterX(cassette_position) = CX(P(pointNum))
	g_CenterY(cassette_position) = CY(P(pointNum))
	g_BottomZ(cassette_position) = CZ(P(pointNum))
	g_AngleOffset(cassette_position) = CU(P(pointNum))
	PLabel pointNum, GTCassetteName$(cassette_position)
Fend

Function GTSetupTilt(cassette_position As Integer, topPointNum As Integer, bottomPointNum As Integer) As Boolean
	GTUpdateClient(TASK_ENTERED_REPORT, MID_LEVEL_FUNCTION, "GTSetupTilt(cassette_position=" + GTCassetteName$(cassette_position) + ", toppoint=P" + Str$(topPointNum) + ", bottompoint=P" + Str$(bottomPointNum) + ")")
	
	Real deltaZ
	deltaZ = CZ(P(topPointNum)) - CZ(P(bottomPointNum))
	
	If (deltaZ < CASSETTE_HEIGHT / 2.0) Then
		GTUpdateClient(TASK_FAILURE_REPORT, MID_LEVEL_FUNCTION, "GTSetupTilt: " + GTCassetteName$(cassette_position) + "'s deltaZ is less than half of Normal Cassette Height!")
		GTSetupTilt = False
		Exit Function
	EndIf

	Real deltaX, deltaY
	deltaX = CX(P(topPointNum)) - CX(P(bottomPointNum))
	deltaY = CY(P(topPointNum)) - CY(P(bottomPointNum))
	
	Real distance, tiltAngle
	distance = Sqr((deltaX * deltaX) + (deltaY * deltaY))
	tiltAngle = RadToDeg(Atan(distance / deltaZ))
	
	'' Check whether tiltAngle is less than 1 degree
	If (tiltAngle > 1) Then
		GTUpdateClient(TASK_FAILURE_REPORT, MID_LEVEL_FUNCTION, "GTSetupTilt: " + GTCassetteName$(cassette_position) + " has a tiltAngle of " + Str$(tiltAngle) + " degrees!")
		GTSetupTilt = False
		Exit Function
	EndIf
	
	g_tiltDX(cassette_position) = deltaX / deltaZ
	g_tiltDY(cassette_position) = deltaY / deltaZ
	
	g_CenterX(cassette_position) = CX(P(bottomPointNum)) + g_tiltDX(cassette_position) * (g_BottomZ(cassette_position) - CZ(P(bottomPointNum)))
	g_CenterY(cassette_position) = CY(P(bottomPointNum)) + g_tiltDY(cassette_position) * (g_BottomZ(cassette_position) - CZ(P(bottomPointNum)))
	
	GTUpdateClient(TASK_DONE_REPORT, MID_LEVEL_FUNCTION, "GTSetupTilt completed.")
	GTSetupTilt = True
Fend

Function GTSetupCassetteAllProperties(cassette_position As Integer) As Boolean
	GTUpdateClient(TASK_ENTERED_REPORT, MID_LEVEL_FUNCTION, "GTSetupCassetteAllProperties(cassette_position=" + GTCassetteName$(cassette_position) + ")")

	Real standbyU, secondaryStandbyU
	'' Cassette_ProbeTopPoint, Cassette_ProbeBottomPoint are points where cassette is probed in cassette calibration
	Integer Cassette_BottomCenterPoint, Cassette_ProbeTopPoint, Cassette_ProbeBottomPoint
	Real column_A_Angle
	
	'' Set StandbyU to be dumbbell's perfect orientation angle + 90 degrees bounded by (-180,180]
	standbyU = g_dumbbell_Perfect_Angle + 90
	standbyU = CU(P6) + GTBoundAngle(-180, 180, standbyU - CU(P6))
	
	Select cassette_position
		Case LEFT_CASSETTE
			column_A_Angle = g_Perfect_LeftCassette_Angle
			Cassette_BottomCenterPoint = 34
			Cassette_ProbeTopPoint = 44
			Cassette_ProbeBottomPoint = 41
			secondaryStandbyU = standbyU - 90
		Case MIDDLE_CASSETTE
			column_A_Angle = g_Perfect_MiddleCassette_Angle
			Cassette_BottomCenterPoint = 35
			Cassette_ProbeTopPoint = 45
			Cassette_ProbeBottomPoint = 42
			secondaryStandbyU = standbyU
		Case RIGHT_CASSETTE
			column_A_Angle = g_Perfect_RightCassette_Angle
			Cassette_BottomCenterPoint = 36
			Cassette_ProbeTopPoint = 46
			Cassette_ProbeBottomPoint = 43
			secondaryStandbyU = standbyU + 90
	Send

	GTSetupDirection cassette_position, column_A_Angle, standbyU, secondaryStandbyU
	GTSetupCoordinates cassette_position, Cassette_BottomCenterPoint
	
	If Not GTSetupTilt(cassette_position, Cassette_ProbeTopPoint, Cassette_ProbeBottomPoint) Then
		GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTSetupCassetteAllProperties: error in GTSetupTilt!")
		GTSetupCassetteAllProperties = False
		Exit Function
	EndIf
	
	GTUpdateClient(TASK_DONE_REPORT, MID_LEVEL_FUNCTION, "GTSetupCassetteAllProperties completed.")
	GTSetupCassetteAllProperties = True
Fend

