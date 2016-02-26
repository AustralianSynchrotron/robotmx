#include "genericdefs.inc"
#include "cassettedefs.inc"
#include "superpuckdefs.inc"
#include "forcedefs.inc"
#include "mxrobotdefs.inc"
#include "networkdefs.inc"

Function testTong
		
	Real distArray(20)

	GTInitialize
	
	Real Uangle
	Uangle = 156.313
	Real sinVal, cosVal
	sinVal = Sin(DegToRad(Uangle))
	cosVal = Cos(DegToRad(Uangle))

	'' The XY and U coordinates for Robot P1 post (manually checked) for placer tool
	P450 = XY(251.707, 236.774, 0, Uangle) /R /0
	'' The XY and U coordinates for Robot P1 post (manually checked) for picker tool	
	''P450 = XY(292.011, 232.864, 0, -25.727) /R /0
	
	Real standbyDistance
	standbyDistance = 10

	Power Low
	GTsetRobotSpeedMode(PROBE_SPEED)
	Tool PLACER_TOOL
	
	P453 = P450 -X(standbyDistance * cosVal) -Y(standbyDistance * sinVal)
	Jump P453

	Real maxDistanceToScan
	maxDistanceToScan = standbyDistance + 3.0 '' Tolerance
	
	Integer standbyPoint
	standbyPoint = 456

	ForceCalibrateAndCheck(HIGH_SENSITIVITY, HIGH_SENSITIVITY)

	Integer zIndex
	For zIndex = 0 To 20
		P(standbyPoint) = P453 '':Z(zIndex * -10.0)
		Move P(standbyPoint)
		
		If ForceTouch(DIRECTION_CAVITY_TAIL, maxDistanceToScan, False) Then
			'' Distance from perfect position
			distArray(zIndex) = Dist(P(standbyPoint), RealPos) - PROBE_STANDBY_DISTANCE
		EndIf
	Next
	
	For zIndex = 0 To 20
		Print distArray(zIndex)
	Next
	
	Move P0
Fend


Function debugProbeAllCassettes
	Integer cassetteIndex
	For cassetteIndex = 0 To NUM_CASSETTES - 1
		g_PortsRequestString$(cassetteIndex) = ""
	Next
	
	Integer rowIndex, ColumnIndex
	For cassetteIndex = 0 To NUM_CASSETTES - 1
		For ColumnIndex = 0 To NUM_COLUMNS - 1
			For rowIndex = 0 To NUM_ROWS - 1
				g_PortsRequestString$(cassetteIndex) = g_PortsRequestString$(cassetteIndex) + "1"
			Next
		Next
	Next

	ProbeCassettes
Fend

Function debugProbeCassette(cassette_position As Integer)
	Integer cassetteIndex
	For cassetteIndex = 0 To NUM_CASSETTES - 1
		g_PortsRequestString$(cassetteIndex) = ""
	Next
	
	Integer rowIndex, ColumnIndex
	For ColumnIndex = 0 To NUM_COLUMNS - 1
		For rowIndex = 0 To NUM_ROWS - 1
			g_PortsRequestString$(cassette_position) = g_PortsRequestString$(cassette_position) + "1"
		Next
	Next

	ProbeCassettes
Fend

Function debugProbeCalib(cassette_position As Integer)
	Integer cassetteIndex
	For cassetteIndex = 0 To NUM_CASSETTES - 1
		g_PortsRequestString$(cassetteIndex) = ""
	Next
	
	Integer rowIndex, ColumnIndex
	For ColumnIndex = 0 To NUM_COLUMNS - 1
		g_PortsRequestString$(cassette_position) = g_PortsRequestString$(cassette_position) + "1"
		For rowIndex = 1 To NUM_ROWS - 2
			g_PortsRequestString$(cassette_position) = g_PortsRequestString$(cassette_position) + "0"
		Next
		g_PortsRequestString$(cassette_position) = g_PortsRequestString$(cassette_position) + "1"
	Next

	ProbeCassettes
Fend

Function debugProbePuck(cassette_position As Integer, puckIndexToProbe As Integer)

	Integer cassetteIndex
	For cassetteIndex = 0 To NUM_CASSETTES - 1
		g_PortsRequestString$(cassetteIndex) = ""
	Next
		
	Integer puckIndex, puckPortIndex
	For puckIndex = PUCK_A To puckIndexToProbe - 1
		For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
			g_PortsRequestString$(cassette_position) = g_PortsRequestString$(cassette_position) + "0"
		Next
	Next

	puckIndex = puckIndexToProbe
	For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
		g_PortsRequestString$(cassette_position) = g_PortsRequestString$(cassette_position) + "1"
	Next

	For puckIndex = puckIndexToProbe + 1 To PUCK_D
		For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
			g_PortsRequestString$(cassette_position) = g_PortsRequestString$(cassette_position) + "0"
		Next
	Next
	
	ProbeCassettes
Fend

Function debugProbeAllPucks(cassette_position As Integer)

	Integer cassetteIndex
	For cassetteIndex = 0 To NUM_CASSETTES - 1
		g_PortsRequestString$(cassetteIndex) = ""
	Next
		
	Integer puckIndex, puckPortIndex
	For puckIndex = PUCK_A To PUCK_D
		For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
			g_PortsRequestString$(cassette_position) = g_PortsRequestString$(cassette_position) + "1"
		Next
	Next
	
	ProbeCassettes
Fend
''' *** JSON *** '''
Function debugJSONNormal(cassette_position As Integer)
	Integer cassetteIndex
	Integer rowIndex, ColumnIndex
	
	For cassetteIndex = 0 To NUM_CASSETTES - 1
		g_CassetteType(cassetteIndex) = UNKNOWN_CASSETTE
		For ColumnIndex = 0 To NUM_COLUMNS - 1
			For rowIndex = 0 To NUM_ROWS - 1
				g_CASSampleDistanceError(cassetteIndex, rowIndex, ColumnIndex) = -1.234
                g_CAS_PortStatus(cassetteIndex, rowIndex, ColumnIndex) = PORT_VACANT
			Next
		Next
	Next
	
	g_CassetteType(cassette_position) = NORMAL_CASSETTE
	For ColumnIndex = 0 To NUM_COLUMNS - 1
		For rowIndex = 0 To NUM_ROWS - 1
			g_CASSampleDistanceError(cassette_position, rowIndex, ColumnIndex) = -5.678
			g_CAS_PortStatus(cassette_position, rowIndex, ColumnIndex) = PORT_OCCUPIED
		Next
	Next

	JSONDataRequest
Fend

Function debugJSONCalib(cassette_position As Integer)
	Integer cassetteIndex
	Integer rowIndex, ColumnIndex
	For cassetteIndex = 0 To NUM_CASSETTES - 1
		g_CassetteType(cassetteIndex) = UNKNOWN_CASSETTE
		For ColumnIndex = 0 To NUM_COLUMNS - 1
			For rowIndex = 1 To NUM_ROWS - 2
				g_CASSampleDistanceError(cassetteIndex, rowIndex, ColumnIndex) = -1.234
				g_CAS_PortStatus(cassetteIndex, rowIndex, ColumnIndex) = PORT_VACANT
			Next
		Next
	Next
	
	g_CassetteType(cassette_position) = CALIBRATION_CASSETTE
	For ColumnIndex = 0 To NUM_COLUMNS - 1
		g_CASSampleDistanceError(cassette_position, rowIndex, ColumnIndex) = -5.678
		rowIndex = 0
		g_CAS_PortStatus(cassette_position, rowIndex, ColumnIndex) = PORT_OCCUPIED
		For rowIndex = 1 To NUM_ROWS - 2
			g_CAS_PortStatus(cassette_position, rowIndex, ColumnIndex) = PORT_UNKNOWN
		Next
		g_CASSampleDistanceError(cassette_position, rowIndex, ColumnIndex) = -5.678
		g_CAS_PortStatus(cassette_position, rowIndex, ColumnIndex) = PORT_OCCUPIED
	Next

	JSONDataRequest
Fend

Function debugJSONPuck(cassette_position As Integer, puckIndexToProbe As Integer)
	Integer cassetteIndex
	Integer puckIndex, puckPortIndex
	
	For cassetteIndex = 0 To NUM_CASSETTES - 1
		g_CassetteType(cassetteIndex) = UNKNOWN_CASSETTE
		For puckIndex = 0 To NUM_PUCKS - 1
			g_PuckStatus(cassetteIndex, puckIndex) = PUCK_ABSENT
			For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
				g_SPSampleDistanceError(cassetteIndex, puckIndex, puckPortIndex) = -1.234
				g_SP_PortStatus(cassetteIndex, puckIndex, puckPortIndex) = PORT_VACANT
			Next
		Next
	Next
	
	g_CassetteType(cassette_position) = SUPERPUCK_CASSETTE
	For puckIndex = PUCK_A To puckIndexToProbe - 1
		g_PuckStatus(cassette_position, puckIndex) = PUCK_ABSENT
		For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
			g_SPSampleDistanceError(cassette_position, puckIndex, puckPortIndex) = -1.234
			g_SP_PortStatus(cassette_position, puckIndex, puckPortIndex) = PORT_VACANT
		Next
	Next

	puckIndex = puckIndexToProbe
	g_PuckStatus(cassette_position, puckIndex) = PUCK_PRESENT
	For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
		g_SPSampleDistanceError(cassette_position, puckIndex, puckPortIndex) = -5.678
		g_SP_PortStatus(cassette_position, puckIndex, puckPortIndex) = PORT_OCCUPIED
	Next

	For puckIndex = puckIndexToProbe + 1 To PUCK_D
		For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
			g_SPSampleDistanceError(cassette_position, puckIndex, puckPortIndex) = -9.012
			g_SP_PortStatus(cassette_position, puckIndex, puckPortIndex) = PORT_VACANT
		Next
	Next
	
	JSONDataRequest
Fend

''' *** Mount/Dismount *** '''
Function StressTestSuperPuck(cassette_position As Integer, puckIndex As Integer, startPortIndex As Integer) As Boolean
	StressTestSuperPuck = False

	''debugProbePuck(cassette_position, puckIndex)
	
	Integer puckPortIndex
	For puckPortIndex = startPortIndex To NUM_PUCK_PORTS
		g_RunArgs$ = GTCassetteName$(cassette_position) + " "
		g_RunArgs$ = g_RunArgs$ + GTpuckName$(puckIndex) + " "
		g_RunArgs$ = g_RunArgs$ + Str$(puckPortIndex)
		
		MountSamplePort
		
		''if Here is not within 10mm from P18, it tells us that there was an error in mounting
		If Not (Dist(P18, Here) < 10) Then
			If Not GTCheckAndPickMagnet Then
				'' This means either sample is on picker or dumbbell lost
				UpdateClient(TASK_MSG, "StressTestSuperPuck:GTCheckAndPickMagnet failed!", ERROR_LEVEL)
				Exit Function
			EndIf
				
			If Not GTIsMagnetInGripper Then
				'' This means either sample is on picker or dumbbell lost
				UpdateClient(TASK_MSG, "StressTestSuperPuck:GTIsMagnetInGripper failed!", ERROR_LEVEL)
				Exit Function
			EndIf
		EndIf
		
		DismountSample
	Next
	
	StressTestSuperPuck = True
Fend

Function StressTestSuperPucks
	Cls
	
	Integer cassette_position, puckIndex
	For cassette_position = MIDDLE_CASSETTE To NUM_CASSETTES - 1
		For puckIndex = 0 To NUM_PUCKS - 1
			If Not StressTestSuperPuck(cassette_position, puckIndex, 1) Then
				UpdateClient(TASK_MSG, "StressTestSuperPuck failed!", ERROR_LEVEL)
				Exit Function
			EndIf
		Next
	Next
Fend
''Find Port Centers
Function debugAllPucksFindCenters(cassette_position As Integer)

	Integer cassetteIndex
	For cassetteIndex = 0 To NUM_CASSETTES - 1
		g_PortsRequestString$(cassetteIndex) = ""
	Next
		
	Integer puckIndex, puckPortIndex
	For puckIndex = PUCK_A To PUCK_D
		For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
			g_PortsRequestString$(cassette_position) = g_PortsRequestString$(cassette_position) + "1"
		Next
	Next
	
	FindPortCenters
Fend

