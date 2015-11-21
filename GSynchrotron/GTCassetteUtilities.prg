#include "forcedefs.inc"
#include "mxrobotdefs.inc"
#include "GTCassettedefs.inc"
#include "GTReporterdefs.inc"

Global Real g_SampleDistancefromCASSurface(NUM_CASSETTES, NUM_ROWS, NUM_COLUMNS)
Global Boolean g_CAS_SamplePresent(NUM_CASSETTES, NUM_ROWS, NUM_COLUMNS)

Global Real g_TiltOffsets(3)
Function GTsetTiltOffsets(cassette_position As Integer, PerfectXoffset As Real, PerfectYoffset As Real, PerfectZoffset As Real)
	g_TiltOffsets(0) = PerfectXoffset + PerfectZoffset * g_tiltDX(cassette_position)
	g_TiltOffsets(1) = PerfectYoffset + PerfectZoffset * g_tiltDY(cassette_position)
	g_TiltOffsets(2) = PerfectZoffset - (PerfectXoffset * g_tiltDX(cassette_position) + PerfectYoffset * g_tiltDY(cassette_position))
	
Fend

'' To get a point on the circumference of the circle with radius taken from the cassette center [cassette's bottom center's (X,Y) location]
Function GTSetCircumferencePointFromU(cassette_position As Integer, U As Real, radius As Real, ZoffsetFromBottom As Real, pointNum As Integer)
	Real theta
	Real PerfectXoffsetFromCassetteCenter, PerfectYoffsetFromCassetteCenter
	Real AbsoluteXafterTiltAjdust, AbsoluteYafterTiltAjdust, AbsoluteZafterTiltAjdust

	'' theta is the angle subtended on the cassette center from the positive x-axis.
	'' Since U orients the magnet towards center, theta = U + 180 degrees
	theta = DegToRad(U + 180)

	'' Get Perfect X, Y coordinates offsets of the point on the circumference of the circle with radius from cassette's bottom center
	PerfectXoffsetFromCassetteCenter = radius * Cos(theta)
	PerfectYoffsetFromCassetteCenter = radius * Sin(theta)
	
	GTsetTiltOffsets(cassette_position, PerfectXoffsetFromCassetteCenter, PerfectYoffsetFromCassetteCenter, ZoffsetFromBottom)
	'' Set Absolute X,Y,Z Coordinates after GTsetTiltOffsets
	AbsoluteXafterTiltAjdust = g_CenterX(cassette_position) + g_TiltOffsets(0)
	AbsoluteYafterTiltAjdust = g_CenterY(cassette_position) + g_TiltOffsets(1)
	AbsoluteZafterTiltAjdust = g_BottomZ(cassette_position) + g_TiltOffsets(2)
	
	P(pointNum) = XY(AbsoluteXafterTiltAjdust, AbsoluteYafterTiltAjdust, AbsoluteZafterTiltAjdust, U) /R '' Hand = Righty
Fend

Function rowName$(rowIndex As Integer)
	rowName$ = Chr$(Asc("A") + rowIndex)
Fend

Function GTprobeCassettePort(cassette_position As Integer, rowIndex As Integer, columnIndex As Integer)
	Integer standbyPoint
	standbyPoint = 52
	
	Real CAScolumnAngleOffset, Uangle, adjustedU
	CAScolumnAngleOffset = (columnIndex * 360.0) / NUM_COLUMNS
	Uangle = g_AngleOfFirstColumn(cassette_position) + g_AngleOffset(cassette_position) + CAScolumnAngleOffset + 180
	adjustedU = g_UForNormalStandby(cassette_position) + GTBoundAngle(-180, 180, (Uangle - g_UForNormalStandby(cassette_position)))

	Real ZoffsetFromBottom
	ZoffsetFromBottom = (CASSETTE_A1_HEIGHT + CASSETTE_ROW_HEIGHT * rowIndex) * CASSETTE_SHRINK_IN_LN2

	Real standby_circle_radius
	standby_circle_radius = CASSETTE_RADIUS * CASSETTE_SHRINK_IN_LN2 + PROBE_STANDBY_DISTANCE
	
	GTSetCircumferencePointFromU(cassette_position, adjustedU, standby_circle_radius, ZoffsetFromBottom, standbyPoint)
			
	Real maxDistanceToScan
	maxDistanceToScan = PROBE_STANDBY_DISTANCE + OVERPRESS_DISTANCE_FOR_CAS + PIN_DEEP_IN_CAS_DISTANCE
	
	Jump P(standbyPoint)
		
	InitForceConstants
	ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY)
	
	g_CAS_SamplePresent(cassette_position, rowIndex, columnIndex) = SAMPLE_ABSENT
	If ForceTouch(DIRECTION_CAVITY_TAIL, maxDistanceToScan, True) Then
	
		g_SampleDistancefromCASSurface(cassette_position, rowIndex, columnIndex) = Dist(P(standbyPoint), RealPos) - PROBE_STANDBY_DISTANCE
		
		If g_SampleDistancefromCASSurface(cassette_position, rowIndex, columnIndex) < OVERPRESS_DISTANCE_FOR_CAS - PROBE_DISTANCE_TOLERANCE Then
			GTUpdateClient(TASK_WARNING_REPORT, MID_LEVEL_FUNCTION, "GTprobeCassettePort: ForceTouch on " + rowName$(rowIndex) + ":" + Str$(columnIndex + 1) + " stopped before reaching sample surface.")
		ElseIf g_SampleDistancefromCASSurface(cassette_position, rowIndex, columnIndex) < OVERPRESS_DISTANCE_FOR_CAS + PROBE_DISTANCE_TOLERANCE Then
			g_CAS_SamplePresent(cassette_position, rowIndex, columnIndex) = SAMPLE_PRESENT
			GTUpdateClient(TASK_MESSAGE_REPORT, MID_LEVEL_FUNCTION, "GTprobeCassettePort: ForceTouch detected Sample at" + rowName$(rowIndex) + ":" + Str$(columnIndex + 1))
		Else
			GTUpdateClient(TASK_WARNING_REPORT, MID_LEVEL_FUNCTION, "GTprobeCassettePort: ForceTouch on" + rowName$(rowIndex) + ":" + Str$(columnIndex + 1) + " moved beyond sample surface.")
		EndIf
	Else
		GTUpdateClient(TASK_WARNING_REPORT, MID_LEVEL_FUNCTION, "GTprobeCassettePort: ForceTouch failed to detect " + rowName$(rowIndex) + ":" + Str$(columnIndex + 1) + "!")
	EndIf
Fend

