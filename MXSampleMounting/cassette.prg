#include "mxrobotdefs.inc"
#include "networkdefs.inc"
#include "forcedefs.inc"

''my test comment


''================================
'' module variable
''================================
Boolean m_IsCalibrationCassette

''LOCAL variables
''cassette XY
Real CXYTouch(4, 2)
Real CXYDirection
Real CXYNewX
Real CXYNewY
Integer CXYIndex
Integer CXYTouchDirection
Integer CXYStepStart
Integer CXYStepTotal
Real CXYRadius
String CCName$

''cassette Z
Real CCZTouch(4)
Real CCZPlacerZ
Real CCZCassetteHeight
Integer CCZIndex
Integer CCZStepStart
Integer CCZStepTotal

''cassette angle
Real CCATouch(4, 2) ''4 points (X, Y)
Real AFromYEdge
Real AFromXEdge
Integer CCAIndex

Integer CCAStepStart
Integer CCAStepTotal


''normal cassette angle
Real CCAInDeg
Real CCAInRad
Real CCACos
Real CCASin
Real CCAOldZ
Real CCANewZ

''cassette calibration
Real CenterX
Real CenterY
Real BottomZ
Real Angle
Real desiredZ
Integer CCXYIndex
Integer cassette
Integer CSTIndex
Integer CCTotalCAS
String OneCassette$
Real CCTempX(3)
Real CCTempY(3)
Real CCDeltaCenter
Integer TopPoint
Integer BottomPoint
Boolean AngleResult
Real CCTilt
String Cassette_Warning$

Integer CassetteOrientation

''VB_CassetteCAL
Boolean VBCCInit
String VBCCTokens$(0)
Integer VBCCArgC

''temp
Real tmp_Real
Real tmp_Real2
Real tmp_DX
Real tmp_DY
Real tmp_DZ

''we will touch from 4 sides, along x and y axes, so orientation does not matter
Function CassetteXY() As Boolean
	String msg$

    CassetteXY = False
    CXYStepStart = g_CurrentSteps
    CXYStepTotal = g_Steps

    ''touch the cassette from all 4 direction
    msg$ = "CentreX = " + Str$(CenterX)
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    msg$ = "CentreY = " + Str$(CenterY)
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    msg$ = "DesiredZ = " + Str$(desiredZ)
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    P51 = XY((CenterX - CASSETTE_STANDBY_DISTANCE), CenterY, desiredZ, 0)

    ''use picker head
    If Tool = 0 Then
        Tool 1
    EndIf

    If Tool = 1 Then
        CXYTouchDirection = DIRECTION_CAVITY_HEAD
    Else
        CXYTouchDirection = DIRECTION_CAVITY_TAIL
    EndIf
    
    SetFastSpeed
    
    ''ensure LimZ high enough to clear the cassette
    If (BottomZ + 142) > g_Jump_LimZ_LN2 Then
        msg$ = "g_Jump_LimZ_LN2 is set lower than cassette top height.  Please increase g_Jump_LimZ_LN2"
        UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    	msg$ = "g_Jump_LimZ_LN2 is:" + Str$(g_Jump_LimZ_LN2)
    	UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    	msg$ = "Cassette Top is:" + Str$(BottomZ + 142)
     	UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    	Exit Function
    EndIf
    
    LimZ g_Jump_LimZ_LN2
    ''Print "CassetteOrientation needs to be 1 (Righty) and it is =", CassetteOrientation
   	''Hand P51, CassetteOrientation
 	Jump P51
    
    For CXYIndex = 1 To 4
        g_CurrentSteps = CXYStepStart + (CXYIndex - 1) * CXYStepTotal / 4
        g_Steps = CXYStepTotal /4
        
        If CXYIndex > 1 Then
        	''update interested clients
        	msg$ = Str$(g_CurrentSteps) + " of 100"
        	UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
        EndIf
        
        SetVerySlowSpeed
        Wait TIME_WAIT_BEFORE_RESET
		If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
			g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_CASSETTE
			g_RunResult$ = "force sensor reset failed at CassetteXY"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf
        If Not ForceTouch(CXYTouchDirection, CASSETTE_STANDBY_DISTANCE / 2, True) Then
        	g_RunResult$ = "failed to touch cassette in XY"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
            Exit Function
        EndIf
        CXYTouch(CXYIndex, 1) = CX(RealPos)
        CXYTouch(CXYIndex, 2) = CY(RealPos)
        
        SetFastSpeed
        Move P51

        ''arc to next point        
        If CXYIndex < 4 Then
            CXYDirection = DegToRad(90 * (CXYIndex + 2))
            P51 = XY((CenterX + CASSETTE_STANDBY_DISTANCE * Cos(CXYDirection)), (CenterY + CASSETTE_STANDBY_DISTANCE * Sin(CXYDirection)), desiredZ, (CU(RealPos) + 90))

            CXYDirection = DegToRad(90 * (CXYIndex + 1.5))
            P52 = XY((CenterX + CASSETTE_STANDBY_DISTANCE * Cos(CXYDirection)), (CenterY + CASSETTE_STANDBY_DISTANCE * Sin(CXYDirection)), desiredZ, (CU(RealPos) + 45))
            Hand P51, CassetteOrientation
            Hand P52, CassetteOrientation
            Arc P52, P51
        Else
        	''arc back to standby position to avoid jam the cables on robot top
        	''this P51 is the same at the beginning of this function.
		    P51 = XY((CenterX - CASSETTE_STANDBY_DISTANCE), CenterY, desiredZ, 0)

            CXYDirection = DegToRad(90 * 3.5)
            P52 = XY((CenterX + CASSETTE_STANDBY_DISTANCE * Cos(CXYDirection)), (CenterY + CASSETTE_STANDBY_DISTANCE * Sin(CXYDirection)), desiredZ, (CU(RealPos) - 135))
            Hand P51, CassetteOrientation
            Hand P52, CassetteOrientation
            Arc P52, P51
        EndIf
    Next
    ''calculate
    CXYNewX = (CXYTouch(1, 1) + CXYTouch(3, 1)) /2
    CXYNewY = (CXYTouch(2, 2) + CXYTouch(4, 2)) /2
    
    msg$ = "center moved from (" + Str$(CenterX) + ", " + Str$(CenterY) + ") to (" + Str$(CXYNewX) + ", " + Str$(CXYNewY) + ")"
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    
    CenterX = CXYNewX
    CenterY = CXYNewY
    
    If g_LN2LevelHigh Then
        CXYRadius = CASSETTE_RADIUS * CASSETTE_SHRINK_IN_LN2
    Else
        CXYRadius = CASSETTE_RADIUS
    EndIf
    
    For CXYIndex = 1 To 4
        CXYNewX = CXYTouch(CXYIndex, 1) - CenterX
        CXYNewY = CXYTouch(CXYIndex, 2) - CenterY
        CXYNewX = Sqr(CXYNewX * CXYNewX + CXYNewY * CXYNewY)
        msg$ = "touch point[" + Str$(CXYIndex) + "]" + "to center distance=" + Str$(CXYNewX)
        UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
        Print "CXYNewX -CXYRadius=", Abs(CXYNewX - CXYRadius)
        If Abs(CXYNewX - CXYRadius) > 1 Then
            g_RunResult$ = "cassette cal: failed, toolset calibration is way too off"
            UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
            g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
            g_RobotStatus = g_RobotStatus Or FLAG_REASON_TOLERANCE
            CassetteXY = False
            Exit Function
        EndIf
    Next
    
    CassetteXY = True
Fend

''we need to touch top as following A, D, G, J
Function CassetteZ() As Boolean
	String msg$
    CassetteZ = False
    CCZStepStart = g_CurrentSteps
    CCZStepTotal = g_Steps
        
    Tool 1
    For CCZIndex = 1 To 4
        ''update progress bar
        g_CurrentSteps = CCZStepStart + (CCZIndex - 1) * CCZStepTotal / 4
        g_Steps = CCZStepTotal /4
        If CCZIndex > 1 Then
        	msg$ = Str$(g_CurrentSteps) + " of 100"
        	UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
        EndIf
        
        ''define where we will go
        ''first point is around column A, second column D, then G, last J
        tmp_Real = DegToRad(g_Perfect_Cassette_Angle + 90 * (CCZIndex - 1))
        tmp_Real2 = CASSETTE_RADIUS - OVER_LAP_FOR_Z_TOUCH
        tmp_DX = tmp_Real2 * Cos(tmp_Real)
        tmp_DY = tmp_Real2 * Sin(tmp_Real)
        
        ''now tmp_Real is for U, here +45 is for make more clearance for the dumbbell head
        tmp_Real = g_Perfect_Cassette_Angle - 180 + 45 + 90 * (CCZIndex - 1)
       	P60 = XY((CenterX + tmp_DX), (CenterY + tmp_DY), (BottomZ + CASSETTE_HEIGHT / 2), tmp_Real)
        Hand P60, CassetteOrientation

        ''go above
        SetFastSpeed
        If CCZIndex = 1 Then
            ''first one, big buffer 20 mm
            Jump P60 :Z(BottomZ + CASSETTE_CAL_HEIGHT + MAGNET_HEAD_RADIUS + 20)
        Else
            LimZ CCZTouch(1) + 20
   	        Jump P60 :Z(CCZTouch(1) + 5)
        EndIf

        ''touch
        SetVerySlowSpeed
        Wait TIME_WAIT_BEFORE_RESET
		If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
			g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_CASSETTE
			g_RunResult$ = "force sensor reset failed at CassetteZ"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf

        If Not ForceTouch(-FORCE_ZFORCE, CASSETTE_HEIGHT / 2 + MAGNET_HEAD_RADIUS + 20, True) Then
        	g_RunResult$ = "Failed to touch cassette top by picker at i =" + Str$(CCZIndex)
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
            Exit Function
        EndIf
        
        CCZTouch(CCZIndex) = CZ(RealPos)
        msg$ = "picker touch at Z=" + Str$(CZ(RealPos))
        UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
        Print #LOG_FILE_NO, "picker touched at (", CX(RealPos), ", ", CY(RealPos), ", ", CZ(RealPos), ")"
    Next
    CassetteZ = True
    
    msg$ = "Z touched at " + Str$(CCZTouch(1)) + ", " + Str$(CCZTouch(2)) + ", " + Str$(CCZTouch(3)) + ", " + Str$(CCZTouch(4))
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    Print #LOG_FILE_NO, "Z touched at ", CCZTouch(1), ", ", CCZTouch(2), ", ", CCZTouch(3), ", ", CCZTouch(4)

    ''check whether this is a calibration cassette
    If Abs(CCZTouch(2) - CCZTouch(1)) > (CASSETTE_EDGE_HEIGHT / 2) Then
        If g_LN2LevelHigh Then
            BottomZ = (CCZTouch(1) + CCZTouch(2) + CCZTouch(3) + CCZTouch(4) + 2 * CASSETTE_SHRINK_IN_LN2 * CASSETTE_EDGE_HEIGHT) / 4
        Else
            BottomZ = (CCZTouch(1) + CCZTouch(2) + CCZTouch(3) + CCZTouch(4) + 2 * CASSETTE_EDGE_HEIGHT) / 4
        EndIf
        CCZCassetteHeight = CASSETTE_CAL_HEIGHT
        m_IsCalibrationCassette = True
        Print #LOG_FILE_NO, "calibration cassette"
    Else
        BottomZ = (CCZTouch(1) + CCZTouch(2) + CCZTouch(3) + CCZTouch(4)) /4
        CCZCassetteHeight = CASSETTE_HEIGHT
        m_IsCalibrationCassette = False
        Print #LOG_FILE_NO, "normal cassette"
    EndIf
    Print #LOG_FILE_NO, "average=", BottomZ
    msg$ = "average=" + Str$(BottomZ)
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    
    If g_LN2LevelHigh Then
        BottomZ = BottomZ - CASSETTE_SHRINK_IN_LN2 * CCZCassetteHeight - MAGNET_HEAD_RADIUS
    Else
        BottomZ = BottomZ - CCZCassetteHeight - MAGNET_HEAD_RADIUS
    EndIf
Fend

Function CalCassetteAngle(ByVal cutOutZ As Real) As Boolean
    String msg$
    CalCassetteAngle = False

    CCAStepStart = g_CurrentSteps
    CCAStepTotal = g_Steps

    Tool 1
    For CCAIndex = 1 To 4
        ''update progress bar
        g_CurrentSteps = CCAStepStart + (CCAIndex - 1) * CCAStepTotal / 4
        g_Steps = CCAStepTotal /4
        If CCAIndex > 1 Then
        	msg$ = Str$(g_CurrentSteps) + " of 100"
        	UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
        EndIf

        ''move to standby point
        ''35 here is something bigger than CASSETTE_EDGE_DISTANCE = 23.5
        SetFastSpeed

        Select CCAIndex
        Case 1
        	tmp_Real = DegToRad(g_Perfect_Cassette_Angle + 180)
        	tmp_DX = 35 * Cos(tmp_Real)
        	tmp_DY = 35 * Sin(tmp_Real)
        	tmp_Real2 = DegToRad(g_Perfect_Cassette_Angle - 90)
        	tmp_DX = tmp_DX + 15 * Cos(tmp_Real2)
        	tmp_DY = tmp_DY + 15 * Sin(tmp_Real2)
        	
        	''U
        	tmp_Real = g_Perfect_Cassette_Angle
        	P60 = XY((CenterX + tmp_DX), (CenterY + tmp_DY), cutOutZ, tmp_Real)
			Hand P60, CassetteOrientation
			
            Jump P60
        Case 2
        	tmp_Real = DegToRad(g_Perfect_Cassette_Angle + 180)
        	tmp_DX = 30 * Cos(tmp_Real)
        	tmp_DY = 30 * Sin(tmp_Real)
        	tmp_Real2 = DegToRad(g_Perfect_Cassette_Angle + 90)
        	tmp_DX = tmp_DX + 15 * Cos(tmp_Real2)
        	tmp_DY = tmp_DY + 15 * Sin(tmp_Real2)
        	
        	''U
        	tmp_Real = g_Perfect_Cassette_Angle
        	P60 = XY((CenterX + tmp_DX), (CenterY + tmp_DY), cutOutZ, tmp_Real)
			Hand P60, CassetteOrientation

            Move P60
        Case 3
        	tmp_Real = DegToRad(g_Perfect_Cassette_Angle + 90)
        	tmp_DX = 35 * Cos(tmp_Real)
        	tmp_DY = 35 * Sin(tmp_Real)
        	tmp_Real2 = DegToRad(g_Perfect_Cassette_Angle + 180)
        	tmp_DX = tmp_DX + 15 * Cos(tmp_Real2)
        	tmp_DY = tmp_DY + 15 * Sin(tmp_Real2)
        	
        	''U
        	tmp_Real = g_Perfect_Cassette_Angle - 90
        	P60 = XY((CenterX + tmp_DX), (CenterY + tmp_DY), cutOutZ, tmp_Real)
			Hand P60, CassetteOrientation
            LimZ (cutOutZ + 30)

            Jump P60
            LimZ g_Jump_LimZ_LN2
        Case 4
        	tmp_Real = DegToRad(g_Perfect_Cassette_Angle + 90)
        	tmp_DX = 35 * Cos(tmp_Real)
        	tmp_DY = 35 * Sin(tmp_Real)
        	tmp_Real2 = DegToRad(g_Perfect_Cassette_Angle)
        	tmp_DX = tmp_DX + 15 * Cos(tmp_Real2)
        	tmp_DY = tmp_DY + 15 * Sin(tmp_Real2)
        	
        	''U
        	tmp_Real = g_Perfect_Cassette_Angle - 90
        	P60 = XY((CenterX + tmp_DX), (CenterY + tmp_DY), cutOutZ, tmp_Real)
			Hand P60, CassetteOrientation
            Move P60
        Send
        
        ''touch it
        SetVerySlowSpeed
        Wait TIME_WAIT_BEFORE_RESET
		If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
			g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_CASSETTE
			g_RunResult$ = "force sensor reset failed at CassetteAngle"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf

        If Not ForceTouch(DIRECTION_CAVITY_HEAD, 20, True) Then
        	g_RunResult$ = "failed to touch edge at " + Str$(CCAIndex)
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
            Exit Function
        EndIf
        
        msg$ = "Touched edge at (" + Str$(CX(RealPos)) + ", " + Str$(CY(RealPos)) + ")"
        UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
        Print #LOG_FILE_NO, "Touched edge at (", CX(RealPos), ", ", CY(RealPos), ")"
        CCATouch(CCAIndex, 1) = CX(RealPos)
        CCATouch(CCAIndex, 2) = CY(RealPos)
        
        ''move back to standby point
        SetFastSpeed
        Move P60
    Next
    CalCassetteAngle = True
    
    CCAIndex = Int(Abs(g_Perfect_Cassette_Angle)) Mod 180
    
    If CCAIndex = 90 Then
    	AFromYEdge = (CCATouch(2, 2) - CCATouch(1, 2)) /(CCATouch(2, 1) - CCATouch(1, 1))
    	AFromYEdge = Atan(AFromYEdge)
    	AFromYEdge = RadToDeg(AFromYEdge)
    	
	    AFromXEdge = (CCATouch(4, 1) - CCATouch(3, 1)) /(CCATouch(4, 2) - CCATouch(3, 2))
    	AFromXEdge = Atan(AFromXEdge)
    	AFromXEdge = 0 - RadToDeg(AFromXEdge)
    ElseIf CCAIndex = 0 Then
	    AFromYEdge = (CCATouch(2, 1) - CCATouch(1, 1)) /(CCATouch(2, 2) - CCATouch(1, 2))
    	AFromYEdge = Atan(AFromYEdge)
    	AFromYEdge = 0 - RadToDeg(AFromYEdge)
    
    	AFromXEdge = (CCATouch(4, 2) - CCATouch(3, 2)) /(CCATouch(4, 1) - CCATouch(3, 1))
    	AFromXEdge = Atan(AFromXEdge)
    	AFromXEdge = RadToDeg(AFromXEdge)
    Else
        g_RunResult$ = "cassette cal: failed, cassette must be along one of axes"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Print #LOG_FILE_NO, g_RunResult$
        Close #LOG_FILE_NO
        Quit All
    EndIf
        
    msg$ = "angle from horizontal edge =" + Str$(AFromYEdge)
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    msg$ = "angle from vertical edge =" + Str$(AFromXEdge)
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    Print #LOG_FILE_NO, "angle from horizontal edge =", AFromYEdge
    Print #LOG_FILE_NO, "angle from vertical edge =", AFromXEdge

    Angle = (AFromXEdge + AFromYEdge) /2
    msg$ = "final Angle =" + Str$(angle)
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    Print #LOG_FILE_NO, "final Angle =", angle
Fend

''normal cassette used in calibration, we will probe port A1 to find the angle
Function NorCassetteAngle(ByVal XCenter As Real, ByVal YCentre As Real) As Boolean
	String msg$
	
    CCAStepStart = g_CurrentSteps
    CCAStepTotal = g_Steps

    NorCassetteAngle = False
    ''got standby position for port A1
    CCAInDeg = g_Perfect_Cassette_Angle + Angle
    CCAInRad = DegToRad(CCAInDeg)
    CCACos = Cos(CCAInRad)
    CCASin = Sin(CCAInRad)
    If g_LN2LevelHigh Then
        CCAOldZ = BottomZ + CASSETTE_SHRINK_IN_LN2 * CASSETTE_A1_HEIGHT
    Else
        CCAOldZ = BottomZ + CASSETTE_A1_HEIGHT
    EndIf
    
    ''magnet points into center not from center
    CCAInDeg = CCAInDeg + 180
   
    P52 = XY((XCenter + (CASSETTE_RADIUS + SAFE_BUFFER_FOR_DETACH) * CCACos), (YCentre + (CASSETTE_RADIUS + SAFE_BUFFER_FOR_DETACH) * CCASin), CCAOldZ, CCAInDeg)
    P53 = XY((XCenter + (CASSETTE_RADIUS - 4) * CCACos), (YCentre + (CASSETTE_RADIUS - 4) * CCASin), CCAOldZ, CCAInDeg)
	Hand P52, CassetteOrientation
	Hand P53, CassetteOrientation
	
    ''setup new parameters for cut middle
    For CCAIndex = 1 To 2
        ''update progress bar
        g_CurrentSteps = CCAStepStart + (CCAIndex - 1) * CCAStepTotal / 2
        g_Steps = CCAStepTotal /2
        If CCAIndex > 1 Then
        	msg$ = Str$(g_CurrentSteps) + " of 100"
        	UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
        EndIf

        SetFastSpeed
        Tool CCAIndex
        Jump P52
        SetVerySlowSpeed
        Wait TIME_WAIT_BEFORE_RESET
		If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
			g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_CASSETTE
			g_RunResult$ = "force sensor reset failed at normal Cassette Angle"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf
        Move P53
        Print #LOG_FILE_NO, "start at A1:(", CX(RealPos), ", ", CY(RealPos), ", ", CZ(RealPos), ", ", CU(RealPos), ")"
    
        ''find Y    
        If Not g_FlagAbort Then
            CutMiddleWithArguments FORCE_YTORQUE, 0, GetForceThreshold(FORCE_YTORQUE), 6, 12
            Print #LOG_FILE_NO, "after cut middle for Y (", CX(RealPos), ", ", CY(RealPos), ", ", CZ(RealPos), ", ", CU(RealPos), ")"
    
            ''calculate new angle and adjust our U
            CCAInRad = Atan((CY(RealPos) - YCentre) / (CX(RealPos) - XCenter))
            Select CCAIndex
            Case 1
                AFromYEdge = RadToDeg(CCAInRad)
                Print #LOG_FILE_NO, "new angle from picker:", AFromYEdge
            Case 2
                AFromXEdge = RadToDeg(CCAInRad)
                Print #LOG_FILE_NO, "new angle from placer:", AFromXEdge
            Send
        EndIf
        SetFastSpeed
        Move P52
    Next
    Angle = (AFromYEdge + AFromXEdge) /2
    NorCassetteAngle = True
Fend
Function CassetteCalibration(ByVal cassettes$ As String, Init As Boolean) As Boolean
	String msg$
	Cls

    CassetteCalibration = False
    g_SafeToGoHome = False

    InitForceConstants
    
    ''are the global variables setup for Australian Synchrotron
	''Did the force sensor initialize ok 
	If Not CheckEnvironment Then
		''it is not safe to proceed
		Exit Function
	EndIf
    
    g_OnlyAlongAxis = True
	
	msg$ = "Cassette calibration start at " + Date$ + " " + Time$
	UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
	
    ''log file
    g_FCntCassette = g_FCntCassette + 1
    WOpen "CassetteCal" + Str$(g_FCntCassette) + ".Txt" As #LOG_FILE_NO
    Print #LOG_FILE_NO, "======================================================="
    Print #LOG_FILE_NO, "Cassette calibration at ", Date$, " ", Time$

    cassettes$ = LTrim$(cassettes$)
    cassettes$ = RTrim$(cassettes$)
    CCTotalCAS = Len(cassettes$)

    If (CCTotalCAS < 1) Or (CCTotalCAS > 3) Then
        g_RunResult$ = "Bad first arg, string length is not [1-3]"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Print #LOG_FILE_NO, g_RunResult$
        Print #LOG_FILE_NO, "arg[1]=[", cassettes$, "]"
        Close #LOG_FILE_NO
        Exit Function
    EndIf

    If (CCTotalCAS > 1) And Init Then
        g_RunResult$ = "Bad input, Init=true only apply with 1 cassette"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Print #LOG_FILE_NO, g_RunResult$
        Close #LOG_FILE_NO
        Exit Function
    EndIf
    
    ''check input
    For CSTIndex = 1 To CCTotalCAS
        OneCassette$ = Mid$(cassettes$, CSTIndex, 1)
        Select OneCassette$
#ifndef LEFT_CASSETTE_NOT_EXIST
			Case "l"
#endif
#ifndef MIDDLE_CASSETTE_NOT_EXIST
			Case "m"
#endif
#ifndef RIGHT_CASSETTE_NOT_EXIST
			Case "r"
#endif
			Default
				g_RunResult$ = "Bad input for one cassette, should be one of rlm"
        		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
				Print #LOG_FILE_NO, g_RunResult$
				Print #LOG_FILE_NO, "index=", CSTIndex, ", cassette letter=", OneCassette$
				Close #LOG_FILE_NO
				Exit Function
        Send
    Next
    
    UpdateClient(TASK_PROG, "0 of 100", INFO_LEVEL)
    
    If Motor = Off Then
        Motor On
    EndIf
    If Power = 1 Then
        Power Low
    EndIf


    ''do it
    If Not Init Then
        UpdateClient(TASK_MSG, "cassette cal: take magnet", INFO_LEVEL)
        g_SafeToGoHome = True
        If Not FromHomeToTakeMagnet Then
            g_RunResult$ = "FromHomeToTakeMagnet failed " + g_RunResult$
            UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
            Print #LOG_FILE_NO, g_RunResult$
            Close #LOG_FILE_NO
            
            ''SPELCom_Return 4
            Exit Function
        EndIf

        If g_FlagAbort Then
            UpdateClient(TASK_MSG, "cassette cal: user abort", ERROR_LEVEL)
            g_RunResult$ = "user abort"
            Print #LOG_FILE_NO, g_RunResult$
            Close #LOG_FILE_NO
            Exit Function
        EndIf
    Else
        ''we are sitting at the center top of the cassette
        g_HoldMagnet = True
        Tool 1
        CenterX = CX(RealPos)
        CenterY = CY(RealPos)
        BottomZ = CZ(RealPos) - 142
        Angle = 0
    EndIf

    LimZ -100

    Cassette_Warning$ = ""
    For CSTIndex = 1 To CCTotalCAS
        OneCassette$ = Mid$(cassettes$, CSTIndex, 1)
        Select OneCassette$
        Case "l"
			CCName$ = "left cassette"
        Case "m"
			CCName$ = "middle cassette"
        Case "r"
			CCName$ = "right cassette"
        Send

        If Init Then
	        Print #LOG_FILE_NO, CCName$, "inital calibration"
        Else
	        Print #LOG_FILE_NO, CCName$, "calibration"
        EndIf
          
        If Not GTCheckTool(1) Then
        	g_RunResult$ = "Must calibrate toolset before cassette calibration"
        	UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        	Print #LOG_FILE_NO, "Must calibrate toolset before cassette calibration"
            Close #LOG_FILE_NO
            Exit Function
        Else
        	P51 = TLSet(1)
        EndIf
              
        Select OneCassette$
        Case "l"
            BottomPoint = 41
            TopPoint = 44
            g_Perfect_Cassette_Angle = g_Perfect_LeftCassette_Angle
        Case "m"
            BottomPoint = 42
            TopPoint = 45
            g_Perfect_Cassette_Angle = g_Perfect_MiddleCassette_Angle
        Case "r"
            BottomPoint = 43
            TopPoint = 46
            g_Perfect_Cassette_Angle = g_Perfect_RightCassette_Angle
        Send
        
        ''when init set to righty as default, when not init we override anyhow
        CassetteOrientation = Righty

        If Not Init Then
            Select OneCassette$
            Case "l"
            	If Not GTCheckPoint(34) Then
	            	UpdateClient(TASK_MSG, "Left cassette XY centre not defined", ERROR_LEVEL)
	            	Exit Function
            	EndIf
                CenterX = CX(P34)
                CenterY = CY(P34)
                BottomZ = CZ(P34)
                Angle = CU(P34)
                CassetteOrientation = Hand(P34)
            Case "m"
            	If Not GTCheckPoint(35) Then
	            	UpdateClient(TASK_MSG, "Middle cassette XY centre not defined", ERROR_LEVEL)
	            	Exit Function
            	EndIf
                CenterX = CX(P35)
                CenterY = CY(P35)
                BottomZ = CZ(P35)
                Angle = CU(P35)
                CassetteOrientation = Hand(P35)
            Case "r"
            	If Not GTCheckPoint(36) Then
	            	UpdateClient(TASK_MSG, "Right cassette XY centre not defined", ERROR_LEVEL)
	            	Exit Function
            	EndIf
                CenterX = CX(P36)
                CenterY = CY(P36)
                BottomZ = CZ(P36)
                Angle = CU(P36)
                CassetteOrientation = Hand(P36)
            Default
                Close #LOG_FILE_NO
                
                ''SPELCom_Return 22
                Exit Function
            Send

			msg$ = "Old position (" + Str$(CenterX) + ", " + Str$(CenterY) + ", " + Str$(BottomZ) + ", " + Str$(Angle) + ")"
			UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
            Print #LOG_FILE_NO, "Old position (", CenterX, ", ", CenterY, ", ", BottomZ, ", ", Angle, ")"
                       
            ''Print old BottomPoint only if it exists
			If PDef(P(BottomPoint)) Then
	            msg$ = "old Bottom (" + Str$(CX(P(BottomPoint))) + ", " + Str$(CY(P(BottomPoint))) + ", " + Str$(CZ(P(BottomPoint))) + ")"
	  			UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
	            Print #LOG_FILE_NO, "Old Bottom (", CX(P(BottomPoint)), ", ", CY(P(BottomPoint)), ", ", CZ(P(BottomPoint)), ")"
			EndIf
			
			''Print old TopPoint only if it exists
			If PDef(P(TopPoint)) Then
				msg$ = "old Top (" + Str$(CX(P(TopPoint))) + ", " + Str$(CY(P(TopPoint))) + ", " + Str$(CZ(P(TopPoint))) + ")"
	  			UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
	  			Print #LOG_FILE_NO, "old Top (", CX(P(TopPoint)), ", ", CY(P(TopPoint)), ", ", CZ(P(TopPoint)), ")"
			EndIf
        EndIf
        
        g_Steps = 60 / CCTotalCAS
        g_CurrentSteps = (100 * CSTIndex - 100) / CCTotalCAS
        msg$ = Str$(g_CurrentSteps) + " of 100"
        UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
        For CCXYIndex = 1 To 3
            g_Steps = 20 / CCTotalCAS
            g_CurrentSteps = (100 * CSTIndex + CCXYIndex * 20 - 120) / CCTotalCAS
            msg$ = Str$(g_CurrentSteps) + " of 100"
            UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
            Select CCXYIndex
                Case 1
                    msg$ = "cassette cal: touch bottom center of " + CCName$
                    UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
                    desiredZ = BottomZ + 12 + 15 / 2
                    Tool 2
                Case 2
                    msg$ = "cassette cal: touch top center of " + CCName$
                    UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
                    desiredZ = BottomZ + CASSETTE_A1_HEIGHT + 15 / 2
                    Tool 2
                Case 3
                    msg$ = "cassette cal: touch middle center of " + CCName$
                    UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
                    desiredZ = BottomZ + CASSETTE_HEIGHT /2
                    Tool 2
            Send
            If Not CassetteXY() Then
                g_RunResult$ = "Failed: maybe there is no cassette"
                UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
                Print #LOG_FILE_NO, g_RunResult$
                Close #LOG_FILE_NO
                Exit Function
            EndIf
            CCTempX(CCXYIndex) = CenterX
            CCTempY(CCXYIndex) = CenterY
            Print #LOG_FILE_NO, "Center (Z=", desiredZ, ") XY position (", CenterX, ", ", CenterY, ")"
            msg$ = "Center (Z=" + Str$(desiredZ) + ") XY position (" + Str$(CenterX) + ", " + Str$(CenterY) + ")"
            UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
            Select CCXYIndex
                Case 1
                    If BottomPoint > 0 Then
                        P(BottomPoint) = XY(CenterX, CenterY, desiredZ, 0)
                        UpdateClient(TASK_MSG, "CassetteCal BottomPoint", INFO_LEVEL)
                        msg$ = "CentreX=" + Str$(CenterX)
                        UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
                        msg$ = "CentreY=" + Str$(CenterY)
                        UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
                        msg$ = "desiredZ=" + Str$(desiredZ)
                        UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
                        SavePointHistory BottomPoint, g_FCntCassette
                    EndIf
                Case 2
                    If TopPoint > 0 Then
                        P(TopPoint) = XY(CenterX, CenterY, desiredZ, 0)
                        UpdateClient(TASK_MSG, "CassetteCal TopPoint", INFO_LEVEL)
                        msg$ = "CentreX=" + Str$(CenterX)
                        UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
                        msg$ = "CentreY=" + Str$(CenterY)
                        UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
                        msg$ = "desiredZ=" + Str$(desiredZ)
                        UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
                        SavePointHistory TopPoint, g_FCntCassette
                    EndIf
                    ''calculate the distance between bottom center and top center
                    CCTempX(1) = CCTempX(1) - CCTempX(2)
                    CCTempY(1) = CCTempY(1) - CCTempY(2)
                    CCDeltaCenter = Sqr(CCTempX(1) * CCTempX(1) + CCTempY(1) * CCTempY(1))
                    Print #LOG_FILE_NO, "distance between center of top row and bottomt row: ", CCDeltaCenter
                    msg$ = "distance between center of top row and bottomt row: " + Str$(CCDeltaCenter)
                    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
                    CCTilt = CCDeltaCenter /(CASSETTE_A1_HEIGHT - 12)
                    CCTilt = Atan(CCTilt)
                    CCTilt = RadToDeg(CCTilt)
                    If CCTilt >= ACCPT_THRHLD_CASSETTE_TILT Then
                        msg$ = "casstte " + OneCassette$ + " tilt " + Str$(CCTilt) + " exceed threshold " + Str$(ACCPT_THRHLD_CASSETTE_TILT) + "degree"
                        Print #LOG_FILE_NO, "casstte ", OneCassette$, " tilt exceed threshold ", ACCPT_THRHLD_CASSETTE_TILT, "degree"
                        UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
                    EndIf
            Send
        Next

        g_Steps = 20 / CCTotalCAS
        g_CurrentSteps = (100 * CSTIndex - 40) / CCTotalCAS
        msg$ = Str$(g_CurrentSteps) + " of 100"
        UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
        msg$ = "cassette cal: touching Z of" + CCName$
        UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
        
        If Not CassetteZ() Then
            g_RunResult$ = "Z failed"
            UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
            Print #LOG_FILE_NO, g_RunResult$
            Close #LOG_FILE_NO
            
            ''SPELCom_Return 5
            Exit Function
        EndIf
        
        Print #LOG_FILE_NO, "BottomZ = ", BottomZ
        msg$ = "BottomZ = " + Str$(BottomZ)
        UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)

        g_Steps = 20 / CCTotalCAS
        g_CurrentSteps = (100 * CSTIndex - 20) / CCTotalCAS
        msg$ = Str$(g_CurrentSteps) + " of 100"
        UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
        msg$ = "cassette cal: touching angle offset of" + CCName$
        UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
        
        If m_IsCalibrationCassette Then
        	''Get angle correction using calibration cassette
            AngleResult = CalCassetteAngle(BottomZ + CASSETTE_CAL_HEIGHT)
        Else
        	''Get angle correction using normal cassette
            AngleResult = NorCassetteAngle(CCTempX(2), CCTempY(2))
        EndIf
        
        If Not AngleResult Then
            g_RunResult$ = "angle failed"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
            Print #LOG_FILE_NO, g_RunResult$
            Close #LOG_FILE_NO
            
            ''SPELCom_Return 6
            Exit Function
        EndIf

        Print #LOG_FILE_NO, "new position (", CenterX, ", ", CenterY, ", ", BottomZ, ", ", Angle, ")"
        msg$ = "new position (" + Str$(CenterX) + ", " + Str$(CenterY) + ", " + Str$(BottomZ) + ", " + Str$(Angle) + ")"
        UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
        ''save data
        Select OneCassette$
        Case "l"
            P34 = XY(CenterX, CenterY, BottomZ, Angle)
			Hand P34, Hand(P6)
            SavePointHistory 34, g_FCntCassette
            UpdateClient(TASK_MSG, "saving points to file.....", INFO_LEVEL)
			SavePoints "robot1.pts"
			g_TS_Left_Cassette$ = Date$ + " " + Time$
        Case "m"
            P35 = XY(CenterX, CenterY, BottomZ, Angle)
			Hand P35, Hand(P6)
            SavePointHistory 35, g_FCntCassette
			UpdateClient(TASK_MSG, "saving points to file.....", INFO_LEVEL)
			SavePoints "robot1.pts"
			g_TS_Middle_Cassette$ = Date$ + " " + Time$
        Case "r"
            P36 = XY(CenterX, CenterY, BottomZ, Angle)
			Hand P36, Hand(P6)
            SavePointHistory 36, g_FCntCassette
			UpdateClient(TASK_MSG, "saving points to file.....", INFO_LEVEL)
			SavePoints "robot1.pts"
			g_TS_Right_Cassette$ = Date$ + " " + Time$
        Send
    Next
    
    CassetteCalibration = True
    
    msg$ = "Cassette calibration finished OK at " + Date$ + " " + Time$
    UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
    Print #LOG_FILE_NO, "Cassette calibration finished OK at ", Date$, " ", Time$
    
    Close #LOG_FILE_NO
    UpdateClient(TASK_PROG, "100 of 100", INFO_LEVEL)

    If Not Init Then
        ''put back magnet
        UpdateClient(TASK_MSG, "cassette cal: put back magnet and go home", INFO_LEVEL)
        
        Tool 0
        LimZ g_Jump_LimZ_LN2
        Jump P6
        
        If Not Open_Gripper Then
            g_RunResult$ = "cassette cal: Open_Gripper Failed, holding magnet, need Reset"
            UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
            g_RobotStatus = g_RobotStatus Or FLAG_NEED_RESET
            g_RobotStatus = g_RobotStatus Or FLAG_REASON_GRIPPER_JAM
            Motor Off
            Quit All
        EndIf

        Move P3
        g_HoldMagnet = False

        SetFastSpeed
        MoveTongHome
    EndIf
    
    UpdateClient(TASK_MSG, "cassette cal: Done", INFO_LEVEL)
	
    g_RunResult$ = "normal OK"
    Tool 0
Fend
Function VB_CassetteCal
    ''init result
    g_RunResult$ = ""
    
    ''parse argument from global
    ParseStr g_RunArgs$, VBCCTokens$(), " "
    ''check argument
    VBCCArgC = UBound(VBCCTokens$) + 1
    If VBCCArgC < 1 Or VBCCArgC > 2 Then
        g_RunResult$ = "bad argument.  should be lrm or l TRUE"
        ''SPELCom_Return 1
        Exit Function
    EndIf
    
    VBCCInit = False
    If VBCCArgC = 2 Then
        Select VBCCTokens$(1)
        Case "1"
            VBCCInit = True
        Case "TRUE"
            VBCCInit = True
        Case "true"
            VBCCInit = True
        Case "True"
            VBCCInit = True
        Send
    EndIf

    If Motor = Off Then
        Motor On
    EndIf
    If Power = 1 Then
        Power Low
    EndIf
    
    ''call function
    Print VBCCTokens$(0)
    
    If Not CassetteCalibration(VBCCTokens$(0), VBCCInit) Then
        If g_FlagAbort Then
            g_RunResult$ = "User Abort"
        EndIf
        ''Recovery
        ''SPELCom_Return 2
        Exit Function
    EndIf
    ''SPELCom_Return 0
Fend


