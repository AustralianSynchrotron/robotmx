#include "genericdefs.inc"
#include "cassettedefs.inc"

'' This .prg file contains generic cassette utilities i.e. routines used by normal, calibration and superpuck cassettes

Function GTCassetteName$(cassette_position As Integer) As String
	If cassette_position = LEFT_CASSETTE Then
		GTCassetteName$ = "left_cassette"
	ElseIf cassette_position = MIDDLE_CASSETTE Then
		GTCassetteName$ = "middle_cassette"
	ElseIf cassette_position = RIGHT_CASSETTE Then
		GTCassetteName$ = "right_cassette"
	EndIf
Fend

Function GTapplyTiltToOffsets(cassette_position As Integer, PerfectXoffset As Real, PerfectYoffset As Real, PerfectZoffset As Real, ByRef Actualoffsets() As Real)
	Actualoffsets(0) = PerfectXoffset + PerfectZoffset * g_tiltDX(cassette_position)
	Actualoffsets(1) = PerfectYoffset + PerfectZoffset * g_tiltDY(cassette_position)
	Actualoffsets(2) = PerfectZoffset - (PerfectXoffset * g_tiltDX(cassette_position) + PerfectYoffset * g_tiltDY(cassette_position))
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
	
	Real ActualOffsetsFromCassetteCenter(3)
	GTapplyTiltToOffsets(cassette_position, PerfectXoffsetFromCassetteCenter, PerfectYoffsetFromCassetteCenter, ZoffsetFromBottom, ByRef ActualOffsetsFromCassetteCenter())
	'' Set Absolute X,Y,Z Coordinates after GTapplyTiltToOffsets
	AbsoluteXafterTiltAjdust = g_CenterX(cassette_position) + ActualOffsetsFromCassetteCenter(0)
	AbsoluteYafterTiltAjdust = g_CenterY(cassette_position) + ActualOffsetsFromCassetteCenter(1)
	AbsoluteZafterTiltAjdust = g_BottomZ(cassette_position) + ActualOffsetsFromCassetteCenter(2)
	
	P(pointNum) = XY(AbsoluteXafterTiltAjdust, AbsoluteYafterTiltAjdust, AbsoluteZafterTiltAjdust, U) /R '' Hand = Righty
Fend


Function GTadjustUAngle(cassette_position As Integer, UAngle As Real) As Real
	GTadjustUAngle = g_UForNormalStandby(cassette_position) + GTBoundAngle(-180, 180, (UAngle - g_UForNormalStandby(cassette_position)))
Fend


