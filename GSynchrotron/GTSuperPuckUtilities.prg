#include "forcedefs.inc"
#include "mxrobotdefs.inc"
#include "GTCassettedefs.inc"
#include "GTReporterdefs.inc"

Real m_SP_Alpha(NUM_PUCKS)
Real m_SP_Puck_Radius(NUM_PUCKS)
Real m_SP_Puck_Thickness(NUM_PUCKS)
Real m_SP_PuckCenter_Height(NUM_PUCKS)
Real m_SP_Puck_RotationAngle(NUM_PUCKS)
Real m_SP_Ports_1_5_Circle_Radius
Real m_SP_Ports_6_16_Circle_Radius

Real m_adaptorAngleError(NUM_CASSETTES)

Function initSuperPuckConstants()
	m_SP_Alpha(PUCK_A) = 45.0
	m_SP_Alpha(PUCK_B) = 45.0
	m_SP_Alpha(PUCK_C) = -45.0
	m_SP_Alpha(PUCK_D) = -45.0

	m_SP_Puck_Radius(PUCK_A) = 32.5
	m_SP_Puck_Radius(PUCK_B) = 32.5
	m_SP_Puck_Radius(PUCK_C) = 32.5
	m_SP_Puck_Radius(PUCK_D) = 32.5
	
	m_SP_Puck_Thickness(PUCK_A) = 29.0
	m_SP_Puck_Thickness(PUCK_B) = 29.0
	m_SP_Puck_Thickness(PUCK_C) = -29.0
	m_SP_Puck_Thickness(PUCK_D) = -29.0
	
	m_SP_PuckCenter_Height(PUCK_A) = 102.5
	m_SP_PuckCenter_Height(PUCK_B) = 34.5
	m_SP_PuckCenter_Height(PUCK_C) = 102.5
	m_SP_PuckCenter_Height(PUCK_D) = 34.5
	
	m_SP_Puck_RotationAngle(PUCK_A) = 0.0
	m_SP_Puck_RotationAngle(PUCK_B) = 0.0
	m_SP_Puck_RotationAngle(PUCK_C) = 180.0
	m_SP_Puck_RotationAngle(PUCK_D) = 180.0
	
	m_SP_Ports_1_5_Circle_Radius = 12.12
	m_SP_Ports_6_16_Circle_Radius = 26.31
Fend

'' distanceFromPuckSurface > 0 is the offset away from the puck
'' distanceFromPuckSurface < 0 is the offset into the puck (port)
Function GTperfectPuckOffset(cassette_position As Integer, portIndex As Integer, puckIndex As Integer, distanceFromPuckSurface As Real, ByRef dx As Real, ByRef dy As Real, ByRef dz As Real, ByRef u As Real)
	'' Horizontal angle from Cassette Center to Puck Center
	Real angle_to_puck_center
	angle_to_puck_center = g_AngleOffset(cassette_position) + g_AngleOfFirstColumn(cassette_position) + m_SP_Alpha(puckIndex) + m_adaptorAngleError(cassette_position)
	
	If (puckIndex = PUCK_A Or puckIndex = PUCK_B) Then
		u = g_UForNormalStandby(cassette_position) + GTBoundAngle(-180, 180, ((angle_to_puck_center - 90) - g_UForNormalStandby(cassette_position)))
	Else	''(puckIndex = PUCK_C Or puckIndex = PUCK_D) Then
		u = g_UForNormalStandby(cassette_position) + GTBoundAngle(-180, 180, ((angle_to_puck_center + 90) - g_UForNormalStandby(cassette_position)))
	EndIf
	
	Real puck_center_x, puck_center_y, puck_center_z
	puck_center_x = m_SP_Puck_Radius(puckIndex) * Cos(DegToRad(angle_to_puck_center))
	puck_center_y = m_SP_Puck_Radius(puckIndex) * Sin(DegToRad(angle_to_puck_center))
	puck_center_z = m_SP_PuckCenter_Height(puckIndex)
	
	Real portCircleRadius, angleBetweenConsecutivePorts
	Real portIndexInCircle
	If portIndex < 5 Then
		portCircleRadius = m_SP_Ports_1_5_Circle_Radius
		angleBetweenConsecutivePorts = 360.0 / 5
		portIndexInCircle = portIndex
	Else
		portCircleRadius = m_SP_Ports_6_16_Circle_Radius
		angleBetweenConsecutivePorts = 360.0 / 11
		portIndexInCircle = portIndex - 5
	EndIf

	'' Vertical angle from Puck Center to Sample Port Center
	Real portAnglefromPuckCenter
	Real HorzDistancePuckCenterToPort, VerticalDistancePuckCenterToPort
	portAnglefromPuckCenter = angleBetweenConsecutivePorts * portIndexInCircle + m_SP_Puck_RotationAngle(puckIndex)
	HorzDistancePuckCenterToPort = portCircleRadius * Cos(DegToRad(portAnglefromPuckCenter))
	VerticalDistancePuckCenterToPort = portCircleRadius * Sin(DegToRad(portAnglefromPuckCenter))
	
	'' Project to World Coordinates
	Real puckCenterToPortCenter_X, puckCenterToPortCenter_Y, puckCenterToPortCenter_Z
	If (puckIndex = PUCK_A Or puckIndex = PUCK_B) Then
		puckCenterToPortCenter_X = HorzDistancePuckCenterToPort * Cos(DegToRad(angle_to_puck_center + 180))
		puckCenterToPortCenter_Y = HorzDistancePuckCenterToPort * Sin(DegToRad(angle_to_puck_center + 180))
	Else	''(puckIndex = PUCK_C Or puckIndex = PUCK_D) Then
		puckCenterToPortCenter_X = HorzDistancePuckCenterToPort * Cos(DegToRad(angle_to_puck_center))
		puckCenterToPortCenter_Y = HorzDistancePuckCenterToPort * Sin(DegToRad(angle_to_puck_center))
	EndIf
	puckCenterToPortCenter_Z = VerticalDistancePuckCenterToPort

	Real offsetFromPortDeepEnd, offsetXfromPortDeepEnd, offsetYfromPortDeepEnd
	If (puckIndex = PUCK_A Or puckIndex = PUCK_B) Then
		offsetFromPortDeepEnd = m_SP_Puck_Thickness(puckIndex) + distanceFromPuckSurface
	Else	''(puckIndex = PUCK_C Or puckIndex = PUCK_D) Then
		offsetFromPortDeepEnd = m_SP_Puck_Thickness(puckIndex) - distanceFromPuckSurface
	EndIf
	offsetXfromPortDeepEnd = offsetFromPortDeepEnd * Cos(DegToRad(angle_to_puck_center + 90))
	offsetYfromPortDeepEnd = offsetFromPortDeepEnd * Sin(DegToRad(angle_to_puck_center + 90))
	
	dx = puck_center_x + puckCenterToPortCenter_X + offsetXfromPortDeepEnd
	dy = puck_center_y + puckCenterToPortCenter_Y + offsetYfromPortDeepEnd
	dz = puck_center_z + puckCenterToPortCenter_Z
Fend

'' distanceFromPuckSurface > 0 is the offset away from the puck
'' distanceFromPuckSurface < 0 is the offset into the puck (port)
Function GTsetSPPortPoint(cassette_position As Integer, portIndex As Integer, puckIndex As Integer, distanceFromPuckSurface As Real, pointNum As Integer)
	Real U
	Real PerfectXoffsetFromCassetteCenter, PerfectYoffsetFromCassetteCenter, PerfectZoffsetFromBottom
	Real AbsoluteXafterTiltAjdust, AbsoluteYafterTiltAjdust, AbsoluteZafterTiltAjdust
	
	GTperfectPuckOffset(cassette_position, portIndex, puckIndex, distanceFromPuckSurface, ByRef PerfectXoffsetFromCassetteCenter, ByRef PerfectYoffsetFromCassetteCenter, ByRef PerfectZoffsetFromBottom, ByRef U)

	GTsetTiltOffsets(cassette_position, PerfectXoffsetFromCassetteCenter, PerfectYoffsetFromCassetteCenter, PerfectZoffsetFromBottom)
	'' Set Absolute X,Y,Z Coordinates after GTsetTiltOffsets
	AbsoluteXafterTiltAjdust = g_CenterX(cassette_position) + g_TiltOffsets(0)
	AbsoluteYafterTiltAjdust = g_CenterY(cassette_position) + g_TiltOffsets(1)
	AbsoluteZafterTiltAjdust = g_BottomZ(cassette_position) + g_TiltOffsets(2)

	P(pointNum) = XY(AbsoluteXafterTiltAjdust, AbsoluteYafterTiltAjdust, AbsoluteZafterTiltAjdust, U) /R
Fend

Function GTgetAdaptorAngleErrorProbePoint(cassette_position As Integer, perfectPointNum As Integer, standbyPointNum As Integer, destinationPointNum As Integer)
	Real angle_to_puck_center
	angle_to_puck_center = g_AngleOffset(cassette_position) + g_AngleOfFirstColumn(cassette_position) + m_SP_Alpha(PUCK_A)
	
	Real perfectU
	perfectU = g_UForNormalStandby(cassette_position) + GTBoundAngle(-180, 180, ((angle_to_puck_center - 90) - g_UForNormalStandby(cassette_position)))
	
	Real superpuck_edge_x, superpuck_edge_y, superpuck_edge_z
	superpuck_edge_x = SUPERPUCK_WIDTH * Cos(DegToRad(angle_to_puck_center))
	superpuck_edge_y = SUPERPUCK_WIDTH * Sin(DegToRad(angle_to_puck_center))
	superpuck_edge_z = m_SP_PuckCenter_Height(PUCK_A)
	
	Real offsetfromPortDeepEnd, offsetXfromPortDeepEnd, offsetYfromPortDeepEnd
	offsetfromPortDeepEnd = m_SP_Puck_Thickness(PUCK_A)
	offsetXfromPortDeepEnd = offsetfromPortDeepEnd * Cos(DegToRad(angle_to_puck_center + 90))
	offsetYfromPortDeepEnd = offsetfromPortDeepEnd * Sin(DegToRad(angle_to_puck_center + 90))
	
	Real dx, dy, dz
	dx = (superpuck_edge_x + offsetXfromPortDeepEnd) * CASSETTE_SHRINK_IN_LN2
	dy = (superpuck_edge_y + offsetYfromPortDeepEnd) * CASSETTE_SHRINK_IN_LN2
	dz = superpuck_edge_z * CASSETTE_SHRINK_IN_LN2
	
	'' Set perfect point	
	Real perfectX, perfectY, perfectZ
	GTsetTiltOffsets(cassette_position, dx, dy, dz)
	perfectX = g_CenterX(cassette_position) + g_TiltOffsets(0)
	perfectY = g_CenterY(cassette_position) + g_TiltOffsets(1)
	perfectZ = g_BottomZ(cassette_position) + g_TiltOffsets(2)
	P(perfectPointNum) = XY(perfectX, perfectY, perfectZ, perfectU) /R


	Real sinU, cosU
	sinU = Sin(DegToRad(perfectU)); cosU = Cos(DegToRad(perfectU))
	'' Set standby point
	Real standbyXoffset, standbyYoffset
	standbyXoffset = PROBE_STANDBY_DISTANCE * cosU
	standbyYoffset = PROBE_STANDBY_DISTANCE * sinU
	P(standbyPointNum) = XY(perfectX - standbyXoffset, perfectY - standbyYoffset, perfectZ, perfectU) /R
	
	'' Set destination point
	Real destinationXoffset, destinationYoffset
	destinationXoffset = PROBE_ADAPTOR_DISTANCE * cosU
	destinationYoffset = PROBE_ADAPTOR_DISTANCE * sinU
	P(destinationPointNum) = XY(perfectX + destinationXoffset, perfectY + destinationYoffset, perfectZ, perfectU) /R
Fend


Function GTprobeAdaptorAngleCorrection(cassette_position As Integer) As Boolean
	GTUpdateClient(TASK_ENTERED_REPORT, MID_LEVEL_FUNCTION, "GTprobeAdaptorAngleCorrection(" + GTCassetteName$(cassette_position) + ")")

	Integer standbyPoint, perfectPoint, destinationPoint

	standbyPoint = 52
	perfectPoint = 102
	destinationPoint = 103
	GTgetAdaptorAngleErrorProbePoint(cassette_position, perfectPoint, standbyPoint, destinationPoint)

	Tool 2
	LimZ g_Jump_LimZ_LN2
	
	Jump P(standbyPoint)
	
	Real scanDistance
	scanDistance = PROBE_STANDBY_DISTANCE + PROBE_ADAPTOR_DISTANCE
	
	InitForceConstants
	ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY)
	If Not ForceTouch(DIRECTION_CAVITY_TAIL, scanDistance, True) Then
		GTUpdateClient(TASK_FAILURE_REPORT, MID_LEVEL_FUNCTION, "GTprobeAdaptorAngleCorrection failed: error in ForceTouch!")
		GTprobeAdaptorAngleCorrection = False
		Exit Function
	EndIf

	SetVerySlowSpeed
	Move P(standbyPoint)
	
	Real error_from_perfectPoint_in_mm
	error_from_perfectPoint_in_mm = Dist(Here, P(perfectPoint))
	
	'' Determine sign of error_from_perfectPoint_in_mm
	'' If cassette is touched before reaching perfectPoint, then -(minus) sign
	'' ElseIf cassette is touched only going further after perfectPoint, then +(plus) sign
	Real distance_here_to_destination, distance_perfect_to_destination
	distance_here_to_destination = Dist(Here, P(destinationPoint))
	distance_perfect_to_destination = Dist(P(perfectPoint), P(destinationPoint))
	If distance_here_to_destination > distance_perfect_to_destination Then
		error_from_perfectPoint_in_mm = -error_from_perfectPoint_in_mm
	EndIf
	
	GTUpdateClient(TASK_MESSAGE_REPORT, MID_LEVEL_FUNCTION, "GTprobeAdaptorAngleCorrection: error_from_perfectPoint_in_mm=" + Str$(error_from_perfectPoint_in_mm))
	
	If Not GTsetupAdaptorAngleCorrection(cassette_position, error_from_perfectPoint_in_mm) Then
		GTUpdateClient(TASK_FAILURE_REPORT, MID_LEVEL_FUNCTION, "GTprobeAdaptorAngleCorrection failed: error in GTsetupAdaptorAngleCorrection!")
		GTprobeAdaptorAngleCorrection = False
		Exit Function
	EndIf
	
	GTUpdateClient(TASK_DONE_REPORT, MID_LEVEL_FUNCTION, "GTprobeAdaptorAngleCorrection:(" + GTCassetteName$(cassette_position) + ") completed.")
	GTprobeAdaptorAngleCorrection = True
Fend

Function GTsetupAdaptorAngleCorrection(cassette_position As Integer, error_from_perfectPoint_in_mm As Real) As Boolean
	m_adaptorAngleError(cassette_position) = 0
	
	Real adaptorAngleError
	If (error_from_perfectPoint_in_mm >= 0) Then
		adaptorAngleError = RadToDeg(-error_from_perfectPoint_in_mm / (SUPERPUCK_WIDTH - MAGNET_HEAD_RADIUS))
	Else
		adaptorAngleError = RadToDeg(-error_from_perfectPoint_in_mm / SUPERPUCK_WIDTH)
	EndIf
		
	If Abs(adaptorAngleError) > 1.02 Then
		GTUpdateClient(TASK_FAILURE_REPORT, LOW_LEVEL_FUNCTION, "GTsetupAdaptorAngleCorrection: For Superpuck " + GTCassetteName$(cassette_position) + " adaptorAngleError=" + Str$(adaptorAngleError) + "> 1.02 degrees")
		GTsetupAdaptorAngleCorrection = False
		Exit Function
	EndIf
	
	m_adaptorAngleError(cassette_position) = adaptorAngleError
	GTUpdateClient(TASK_DONE_REPORT, LOW_LEVEL_FUNCTION, "GTsetupAdaptorAngleCorrection: For Superpuck " + GTCassetteName$(cassette_position) + " adaptorAngleError=" + Str$(adaptorAngleError))
	GTsetupAdaptorAngleCorrection = True
Fend

