#include "genericdefs.inc"
#include "cassettedefs.inc"
#include "superpuckdefs.inc"
#include "forcedefs.inc"
#include "mxrobotdefs.inc"
#include "networkdefs.inc"
#include "mountingdefs.inc"

Function testTong
		
	Real distArray(20)
	Real largest
	Real smallest

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

	''Power Low
	GTsetRobotSpeedMode(PROBE_SPEED)
	Tool PLACER_TOOL
	
	P453 = P450 -X(standbyDistance * cosVal) -Y(standbyDistance * sinVal)
	LimZ 0
	Jump P453

	Real maxDistanceToScan
	maxDistanceToScan = standbyDistance + 2.0 '' Tolerance
	
	Integer standbyPoint
	standbyPoint = 456

	ForceCalibrateAndCheck(HIGH_SENSITIVITY, HIGH_SENSITIVITY)

	Integer zIndex
	For zIndex = 0 To 20
		P(standbyPoint) = P453 '':Z(zIndex * -10.0)
		Go P(standbyPoint)
		
		''Wait 5
		
		If ForceTouch(DIRECTION_CAVITY_TAIL, maxDistanceToScan, False) Then
			'' Distance from perfect position
			distArray(zIndex) = Dist(P(standbyPoint), RealPos) - standbyDistance
		EndIf
	Next
	
	largest = -1000
	smallest = 10000
	For zIndex = 0 To 20
		If (distArray(zIndex) > largest) Then
			largest = distArray(zIndex)
		EndIf
		If (distArray(zIndex) < smallest) Then
			smallest = distArray(zIndex)
		EndIf
	Next
	
	For zIndex = 0 To 20
		Print distArray(zIndex)
	Next
	Print "largest=" + Str$(largest)
	Print "smallest=" + Str$(smallest)
	Print "Diff=" + Str$(largest - smallest)
	
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
	For puckPortIndex = startPortIndex To NUM_PUCK_PORTS - 1
		g_RunArgs$ = GTCassetteName$(cassette_position) + " "
		g_RunArgs$ = g_RunArgs$ + GTpuckName$(puckIndex) + " "
		g_RunArgs$ = g_RunArgs$ + Str$(puckPortIndex + 1)
		
		MountSamplePort
		''DismountSample
	Next
	
	StressTestSuperPuck = True
Fend

Function StressTestNormalCassette(cassette_position As Integer, columnIndex As Integer, startRowIndex As Integer) As Boolean
	StressTestNormalCassette = False

	''debugProbeCassette(cassette_position)
	
	Integer rowIndex
	For rowIndex = startRowIndex To NUM_ROWS - 1
		g_RunArgs$ = GTCassetteName$(cassette_position) + " "
		g_RunArgs$ = g_RunArgs$ + GTcolumnName$(columnIndex) + " "
		g_RunArgs$ = g_RunArgs$ + Str$(rowIndex + 1)
		
		MountSamplePort
		''DismountSample
	Next
	
	StressTestNormalCassette = True
Fend

Function StressTestCassette(cassette_position As Integer, puckColumnStartIndex As Integer) As Boolean
	StressTestCassette = False
	
	Integer puckIndex, columnIndex
	If g_CassetteType(cassette_position) = SUPERPUCK_CASSETTE Then
		For puckIndex = puckColumnStartIndex To NUM_PUCKS - 1
			If Not StressTestSuperPuck(cassette_position, puckIndex, 0) Then
				UpdateClient(TASK_MSG, "StressTestSuperPuck failed!", ERROR_LEVEL)
				Exit Function
			EndIf
		Next
	Else
		For columnIndex = puckColumnStartIndex To NUM_COLUMNS - 1
			If Not StressTestNormalCassette(cassette_position, columnIndex, 0) Then
				UpdateClient(TASK_MSG, "StressTestNormalCassette failed!", ERROR_LEVEL)
				Exit Function
			EndIf
		Next
	EndIf
	
	StressTestCassette = True
Fend

Function StressTestAllCassettes
	Cls
	
	''Comment the following line if you don't want to probing
	''debugProbeAllCassettes
	
	Integer cassette_position


	For cassette_position = LEFT_CASSETTE To NUM_CASSETTES - 1
		If Not StressTestCassette(cassette_position, 0) Then
			UpdateClient(TASK_MSG, "StressTestCassette failed!", ERROR_LEVEL)
			Exit Function
		EndIf
	Next
	
	If isCloseToPoint(3) Or isCloseToPoint(4) Then
		GTGoHome
	EndIf
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

