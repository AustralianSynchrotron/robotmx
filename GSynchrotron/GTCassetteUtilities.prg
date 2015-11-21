#include "mxrobotdefs.inc"
#include "GTCassettedefs.inc"

Real m_TiltOffsets(3)

Function GTsetTiltOffsets(cassette_position As Integer, PerfectXoffset As Real, PerfectYoffset As Real, PerfectZoffset As Real)
	m_TiltOffsets(0) = PerfectXoffset + PerfectZoffset * g_tiltDX(cassette_position)
	m_TiltOffsets(1) = PerfectYoffset + PerfectZoffset * g_tiltDY(cassette_position)
	m_TiltOffsets(2) = PerfectZoffset - (PerfectXoffset * g_tiltDX(cassette_position) + PerfectYoffset * g_tiltDY(cassette_position))
	
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
	AbsoluteXafterTiltAjdust = g_CenterX(cassette_position) + m_TiltOffsets(0)
	AbsoluteYafterTiltAjdust = g_CenterY(cassette_position) + m_TiltOffsets(1)
	AbsoluteZafterTiltAjdust = g_BottomZ(cassette_position) + m_TiltOffsets(2)
	
	P(pointNum) = XY(AbsoluteXafterTiltAjdust, AbsoluteYafterTiltAjdust, AbsoluteZafterTiltAjdust, U) /R '' Hand = Righty
Fend

