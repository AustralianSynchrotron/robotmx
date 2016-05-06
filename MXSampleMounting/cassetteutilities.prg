#include "genericdefs.inc"
#include "cassettedefs.inc"
#include "jsondefs.inc"
#include "networkdefs.inc"
#include "superpuckdefs.inc"

'' This .prg file contains generic cassette utilities i.e. routines used by normal, calibration and superpuck cassettes

Function GTCassettePosition$(cassette_position As Integer) As String
	If cassette_position = LEFT_CASSETTE Then
		GTCassettePosition$ = "left"
	ElseIf cassette_position = MIDDLE_CASSETTE Then
		GTCassettePosition$ = "middle"
	ElseIf cassette_position = RIGHT_CASSETTE Then
		GTCassettePosition$ = "right"
	Else
		GTCassettePosition$ = "unknown"
	EndIf
Fend

Function GTCassetteName$(cassette_position As Integer) As String
	GTCassetteName$ = GTCassettePosition$(cassette_position) + "_cassette"
Fend

Function GTResetCassette(cassette_position As Integer)
	'' Reset Cassette Type to Unknown Cassette
	g_CassetteType(cassette_position) = UNKNOWN_CASSETTE
	
	''If CassetteType is unknown, GTResetSpecificPorts resets all the ports
	GTResetSpecificPorts(cassette_position)
	
	GTsendCassetteData(CASSETTE_TYPE, cassette_position)
	GTsendCassetteData(PUCK_STATES, cassette_position)
	GTsendCassetteData(PORT_STATES, cassette_position)
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


Function GTParseCassettePosition(cassetteChar$ As String, ByRef cassette_position As Integer) As Boolean
	Select UCase$(cassetteChar$)
		Case "L"
			cassette_position = LEFT_CASSETTE
		Case "M"
			cassette_position = MIDDLE_CASSETTE
		Case "R"
			cassette_position = RIGHT_CASSETTE
		Default
			cassette_position = UNKNOWN_CASSETTE
			g_RunResult$ = "error GTParseCassettePosition: Invalid Cassette Position supplied!"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			GTParseCassettePosition = False
			Exit Function
	Send
	GTParseCassettePosition = True
Fend

Function GTParsePortIndex(cassette_position As Integer, columnOrPuckChar$ As String, rowOrPuckPortChar$ As String, ByRef columnPuckIndex As Integer, ByRef rowPuckPortIndex As Integer) As Boolean
	GTParsePortIndex = False
	If g_CassetteType(cassette_position) = NORMAL_CASSETTE Then
		If Not GTParseColumnIndex(columnOrPuckChar$, ByRef columnPuckIndex) Then
			UpdateClient(TASK_MSG, "GTParsePortIndex: Invalid Column Name supplied!", ERROR_LEVEL)
			Exit Function
		EndIf
		
		rowPuckPortIndex = Val(rowOrPuckPortChar$) - 1
		If rowPuckPortIndex < 0 Or rowPuckPortIndex > NUM_ROWS - 1 Then
			g_RunResult$ = "error GTParsePortIndex: Invalid Row Position supplied!"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf
	ElseIf g_CassetteType(cassette_position) = CALIBRATION_CASSETTE Then
		If Not GTParseColumnIndex(columnOrPuckChar$, ByRef columnPuckIndex) Then
			UpdateClient(TASK_MSG, "GTParsePortIndex: Invalid Column Name supplied!", ERROR_LEVEL)
			Exit Function
		EndIf
		
		rowPuckPortIndex = Val(rowOrPuckPortChar$) - 1
		If rowPuckPortIndex <> 0 And rowPuckPortIndex <> (NUM_ROWS - 1) Then
			g_RunResult$ = "error GTParsePortIndex: Invalid Row Position supplied for Calibration Cassette!"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf
	ElseIf g_CassetteType(cassette_position) = SUPERPUCK_CASSETTE Then
		If Not GTParsePuckIndex(columnOrPuckChar$, ByRef columnPuckIndex) Then
			UpdateClient(TASK_MSG, "GTParsePortIndex: Invalid Puck Name supplied!", ERROR_LEVEL)
			Exit Function
		EndIf
		rowPuckPortIndex = Val(rowOrPuckPortChar$) - 1
		If rowPuckPortIndex < 0 Or rowPuckPortIndex > NUM_PUCK_PORTS - 1 Then
			g_RunResult$ = "error GTParsePortIndex: Invalid Puck Port supplied!"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf
	Else
		g_RunResult$ = "error GTParsePortIndex: Invalid CassetteType Detected! Please probe this cassette again"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	GTParsePortIndex = True
Fend


