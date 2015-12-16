#include "mxrobotdefs.inc"
#include "networkdefs.inc"
#include "forcedefs.inc"

''==========================================================
''MODULE MAGNET CALIBRATION
''==========================================================

'Min step: currently only used in Z-FZ'
Real m_MinZStep

''variables used in several functions in post calibration
Boolean m_AllOK
Boolean m_IgnoreFZForNow

'' any tmp_ prefix means this varible cannot cross function call
''they can be used by any function.
Integer tmp_PIndex
Real tmp_Real
Real tmp_Real2
Real tmp_Real3
Real tmp_DX
Real tmp_DY
Real tmp_DZ
Real tmp_DU

''==========================================================
'' LOCAL varibles: because it crashes system when there are
'' a lot of local variables, many local variables are moved here
''=========================================================
Integer PCCalledTimes(6)    ''how many times each "reduce" function called
Real Old_U4MagnetHolder
Boolean PCCBottomTouched        ''dumbbell touched bottom
                                ''this is used to deal with dumbbell may not touch
                                ''bottom and with a very small FZ.

Real MagLevelError
Real PostLevelError
String Magnet_Warning$


''select force to reduce
Real weightFactor(6)
Real forceWeight(6)
Integer SForceIndex
Integer NumToSelect

''ReduceFZ
Real RFZOldZ
Real RFZOldFZ
Real RFZNewZ
Real RFZNewFZ
Integer RFZStepStart
Integer RFZStepTotal

''FindZPosition
Real FZPOldZ
Real FZPNewZ
Real FZPOldFZ
Real FZPONewZMinus  'Z at -g_ThresholdTZ'
Real FZPFZAtMinus
Real FZPZPerfect
Real FZPNewFZ
Real FZPScanRange
Real FZPThreshold
Integer FZPStepStart
Integer FZPStepTotal


''pikcer touch cradle
Real PKTSRange
Real PKTSX1
Real PKTSX2
Real PKTSY1
Real PKTSY2
Real PKTSOldAngle
Integer PKTSStepStart
Integer PKTSStepTotal

''PickerCalibration
Real PKCInitX
Real PKCInitY
Real PKCInitZ
Real PKCInitU

Real m_MAPAStartX
Real m_MAPAStartY

Real PKCRange

Integer PKCStepStart
Integer PKCStepTotal

''good for placer cal
Real ISP16IdealX
Real ISP16IdealY
Real ISP16IdealZ
Real ISP16IdealU

Real ISP16DX
Real ISP16DY
Real ISP16DZ
Real ISP16DU

''PlacerCalibration
Real CPCInitX
Real CPCInitY
Real CPCInitZ
Real CPCInitU
Real CPCFinalX
Real CPCFinalY
Real CPCFinalZ
Real CPCFinalU
Real CPCMiddleX
Real CPCMiddleY
Real CPCMiddleZ
Real CPCMiddleU
Real CPCStepSize(4)
Integer CPCStepStart
Integer CPCStepTotal

''ABCThetaToToolSet
Real TSX
Real TSY
Real TSZ
Real TSU
Real TSTWX  ''twist off center
Real TSTWY

''CalculateToolset
Real TSa
Real TSb
Real TSc
Real TStheta
Real TSAdjust
Real CVa
Real CVb

''find magnet
Real FMLeftX
Real FMLeftY
Real FMRightX
Real FMRightY

Real FMFinalX
Real FMFinalY
Real FMFinalZ
Real FMFinalU
Real FMDX
Real FMDY
Real FMDistance
Integer FMStepStart
Integer FMStepTotal
Integer FMWait

''parallel grippers and cradle (in find magnet)
Real PGCOldU
Real PGCOldForce
Real PGCGoodForce
Real PGCGoodU
Real PGCNewU
Real PGCNewForce
Integer PGCStepIndex
Integer PGCDirection
Integer PGCScanIndex
Integer PGCNumSteps
Real PGCStepSize
Integer StepIndex

''pull out Z (in find magnet)
Real POZOldX
Real POZOldY
Real POZOldZ
Real StepSize

''post calibration
''This function will try to reduce FZ, TX, TY ,TZ
Double PCCurrentForces(6)
Integer PCRepeatIndex
Integer forceToReduce
Integer PCPreFTR
Integer PCCntPreFTR

Double PCOldForces(6)
Real PCOldPosition(4)
Real PCPushX
Real PCPushY

Integer PCStepStart
Integer PCStepTotal


''FineTuneToolSet
Real FTTSDestX
Real FTTSDestY
Real FTTSX(2)
Real FTTSY(2)
Real FTTSA
Real FTTSB
Real FTTSC
Real FTTSTheta
Real FTTSIndex
Real FTTSBMC
Real FTTSDeltaU
Real FTTSAdjust
Real FTTSZ

Integer FTTStepStart
Integer FTTStepTotal

Real FTTScaleF1
Real FTTScaleF2


''DiffPickerPlacer
Real DPPPickerZ
Real DPPPlacerZ

''VB Wrapper
String VBMCTokens$(0)
Integer VBMCArgC

''CheckRigidness
Real CKRNF1
Real CKRNF2

Function MagnetCalibration As Boolean
    MagnetCalibration = False
    ''init result
    Magnet_Warning$ = ""
    g_RunResult$ = ""
	
    InitForceConstants
    
    ''are the global variables setup for Australian Synchrotron
	''Did the force sensor initialize ok 
	If Not CheckEnvironment Then
		''it is not safe to proceed
		Exit Function
	EndIf
    
    If Motor = Off Then
        Motor On
    EndIf
    If Power = 1 Then
        Power Low
    EndIf

    g_HoldMagnet = False
    
    ''send message
    UpdateClient(TASK_MSG, "toolset calibration", INFO_LEVEL)
    UpdateClient(TASK_PROG, "0 of 100", INFO_LEVEL)

    If g_IncludeFindMagnet Then
    	UpdateClient(TASK_MSG, "find magnet", INFO_LEVEL)
        ''find magnet
        g_CurrentSteps = 0
        g_Steps = 20
        If Not FindMagnet() Then
            g_RunResult$ = "Find magnet failed " + g_RunResult$
            UpdateClient(TASK_MSG, "find magnet failed", ERROR_LEVEL)
            UpdateClient(TASK_PROG, "100 of 100", INFO_LEVEL)
            Exit Function
        EndIf
        SetFastSpeed
        Move Here +Z(20)
        If Not Close_Gripper Then
            UpdateClient(TASK_MSG, "close gripper failed at magnet after finding it", ERROR_LEVEL)
            Move P6
            If Not Open_Gripper Then
                UpdateClient(TASK_MSG, "open gripper failed at aborting from magnet, NEED Reset", ERROR_LEVEL)
                g_RobotStatus = g_RobotStatus Or FLAG_NEED_RESET
                g_RobotStatus = g_RobotStatus Or FLAG_REASON_GRIPPER_JAM
                Motor Off
                Quit All
            EndIf
            Move P3
            LimZ 0
            Jump P1
            Close_Lid
            Jump P0
            MoveTongHome
            ''not need recovery
            g_SafeToGoHome = False
            Exit Function
        EndIf
        g_HoldMagnet = True
    Else
    	UpdateClient(TASK_MSG, "go to dumbbell post", INFO_LEVEL)
        If Not FromHomeToTakeMagnet Then
            g_RunResult$ = "FromHomeToTakeMagnet failed " + g_RunResult$
            UpdateClient(TASK_MSG, "failed in FromHomeToTakeMagnet", ERROR_LEVEL)
            UpdateClient(TASK_PROG, "100 of 100", INFO_LEVEL)
            Exit Function
        EndIf
    EndIf
    
        
    ''reset force sensor
    SetFastSpeed
    Wait TIME_WAIT_BEFORE_RESET * 2
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    Move Here -Z(15)
    SetVerySlowSpeed
    Move Here -Z(3)
    
    ''continue with calibration    
    UpdateClient(TASK_MSG, "dumbbell calibration", INFO_LEVEL)
    If g_IncludeFindMagnet Then
    	UpdateClient(TASK_PROG, "20 of 100", INFO_LEVEL)
        g_CurrentSteps = 20
        g_Steps = 30
    Else
        UpdateClient(TASK_PROG, "10 of 100", INFO_LEVEL)
        g_CurrentSteps = 10
        g_Steps = 33
    EndIf
    If Not PostCalibration() Then
        g_RunResult$ = "magnet holder calibration failed"
        UpdateClient(TASK_MSG, "dumbbell cal failed", ERROR_LEVEL)
        UpdateClient(TASK_PROG, "100 of 100", INFO_LEVEL)
        Exit Function
    EndIf
    
    If g_Quick Then
        If Abs(CX(P6) - CX(P86)) < 0.1 And Abs(CY(P6) - CY(P86)) < 0.3 And Abs(CZ(P6) - CZ(P86)) < 0.1 Then
            MoveTongHome
            
            MagnetCalibration = True
            g_RunResult$ = "normal OK quick"
            ''SPELCom_Return 0
            UpdateClient(TASK_PROG, "100 of 100", INFO_LEVEL)
            UpdateClient(TASK_MSG, "toolset cal done with quick option", INFO_LEVEL)
            Exit Function
        EndIf
    EndIf
    
    ''picker calibration    
    If g_IncludeFindMagnet Then
    	UpdateClient(TASK_PROG, "50 of 100", INFO_LEVEL)
        g_CurrentSteps = 50
        g_Steps = 15
    Else
    	UpdateClient(TASK_PROG, "43 of 100", INFO_LEVEL)
        g_CurrentSteps = 43
        g_Steps = 18
    EndIf
    UpdateClient(TASK_MSG, "picker calibration", INFO_LEVEL)
    If Not PickerCalibration() Then
        g_RunResult$ = "picker calibration failed"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        UpdateClient(TASK_PROG, "100 of 100", INFO_LEVEL)
        Exit Function
    EndIf
    If g_IncludeFindMagnet Then
    	UpdateClient(TASK_PROG, "65 of 100", INFO_LEVEL)
        g_CurrentSteps = 65
        g_Steps = 12
    Else
    	UpdateClient(TASK_PROG, "6 of 100", INFO_LEVEL)
        g_CurrentSteps = 43
        g_Steps = 14
    EndIf

	UpdateClient(TASK_MSG, "placer calibration", INFO_LEVEL)
    If Not PlacerCalibration() Then
        g_RunResult$ = "placer calibration failed"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        UpdateClient(TASK_PROG, "100 of 100", INFO_LEVEL)
        Exit Function
    EndIf

    If Not CalculateToolset() Then
        g_RunResult$ = "toolset failed"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
    EndIf

    If g_IncludeFindMagnet Then
    	UpdateClient(TASK_PROG, "77 of 100", INFO_LEVEL)
        g_CurrentSteps = 77
        g_Steps = 18
    Else
    	UpdateClient(TASK_PROG, "75 of 100", INFO_LEVEL)
        g_CurrentSteps = 75
        g_Steps = 20
    EndIf
    UpdateClient(TASK_MSG, "fine tune toolset", INFO_LEVEL)
    If Not FineTuneToolSet() Then
        g_RunResult$ = "fine tune toolset failed"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        UpdateClient(TASK_PROG, "100 of 100", INFO_LEVEL)
        Exit Function
    EndIf

    If g_IncludeStrip Then
    	UpdateClient(TASK_PROG, "95 of 100", INFO_LEVEL)
	    g_CurrentSteps = 95
	    g_Steps = 5
	    UpdateClient(TASK_MSG, "strip calibration", INFO_LEVEL)
	    If Not StripCalibration() Then
	        g_RunResult$ = "strip calibration failed"
	        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
	        UpdateClient(TASK_PROG, "100 of 100", INFO_LEVEL)
	        Exit Function
	    EndIf
	EndIf

	UpdateClient(TASK_MSG, "moving home", INFO_LEVEL)
	UpdateClient(TASK_PROG, "100 of 100", INFO_LEVEL)
    MoveTongHome
    
    MagnetCalibration = True
    g_RunResult$ = "normal OK"
	g_TS_Toolset$ = Date$ + " " + Time$
    ''SPELCom_Return 0
    UpdateClient(TASK_MSG, "toolset cal done ", INFO_LEVEL)

Fend

''09/02/03 Jinhu
''magnet is pushed to negative Y direction to hit the wall.
''This is because there is 0.5mm freedom in Y direction.
''We want the magnet move to one end, not seat in the middle of
''freedom.
Function PostCalibration As Boolean
	String msg$
    Tool 0
    
    PostCalibration = False
    
    msg$ = "Post calibration at " + Date$ + " " + Time$
	UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
    
    PCStepStart = g_CurrentSteps
    PCStepTotal = g_Steps

    ''log file
    g_FCntPost = g_FCntPost + 1
    WOpen "PostCal" + Str$(g_FCntPost) + ".Txt" As #LOG_FILE_NO
    Print #LOG_FILE_NO, "PostCalibration at ", Date$, " ", Time$

    PCCalledTimes(0) = 0         ''this will be the FindZPosition call
    PCCalledTimes(1) = 0
    PCCalledTimes(2) = 0
    PCCalledTimes(3) = 0
    PCCalledTimes(4) = 0
    PCCalledTimes(5) = 0
    PCCalledTimes(6) = 0

    InitForceConstants
    
    Init_Magnet_Constants
    PCCBottomTouched = False
    m_IgnoreFZForNow = False

    Old_U4MagnetHolder = g_U4MagnetHolder
    g_U4MagnetHolder = CU(Here)
    ''set to CU(P6) if not in calibration

    g_OnlyAlongAxis = True
    ''within this tolerance, we will change X only to reduce TY
    '' and change Y only to reduce TX

    SetupTSForMagnetCal
   
    m_AllOK = False

    ''save old values to print at the end
    PCOldPosition(1) = CX(Here)
    PCOldPosition(2) = CY(Here)
    PCOldPosition(3) = CZ(Here)
    PCOldPosition(4) = CU(Here)
    ReadForces(ByRef PCOldForces())

    'max repeat 12: we have 4 independant variables to reduce'
    'each will get 3 times average'

    ''For PCRepeatIndex = 1 To MAX_POST_CAL_STEP
    PCRepeatIndex = 1
    Do
        'read current forces'
        ReadForces(ByRef PCCurrentForces())
        
        msg$ = "step " + Str$(PCRepeatIndex)
        UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
        msg$ = " current forces: "
        UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)

        PrintForces(ByRef PCCurrentForces())
        
        ''log it
        Print #LOG_FILE_NO, "step ", PCRepeatIndex, " ", Date$, " ", Time$
        Print #LOG_FILE_NO, " current forces: "
        LogForces(ByRef PCCurrentForces())

        If g_FlagAbort Then
            If Not Open_Gripper Then
                g_RunResult$ = "Post Cal: aborting: Open_Gripper Failed, holding magnet, need Reset"
                UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
                g_RobotStatus = g_RobotStatus Or FLAG_NEED_RESET
                g_RobotStatus = g_RobotStatus Or FLAG_REASON_GRIPPER_JAM
                Motor Off
                Quit All
            EndIf
            SetFastSpeed
		    TongMove DIRECTION_MAGNET_TO_CAVITY, 20, False
            g_HoldMagnet = False
            g_SafeToGoHome = True
            Print #LOG_FILE_NO, " aborted by user"
            Close #LOG_FILE_NO
            Exit Function
        EndIf
        

        'check whether it is already in calbrated position'
        forceToReduce = SelectForceToReduce(ByRef PCCurrentForces())

        If g_AtLeastOnce And forceToReduce = 0 And PCCalledTimes(0) <> 0 Then
            If PCCalledTimes(FORCE_XTORQUE) = 0 Then
            	UpdateClient(TASK_MSG, "ADD call for XTorque", DEBUG_LEVEL)
                forceToReduce = FORCE_XTORQUE
            ElseIf PCCalledTimes(FORCE_YTORQUE) = 0 Then
            	UpdateClient(TASK_MSG, "ADD call for YTorque", DEBUG_LEVEL)
                forceToReduce = FORCE_YTORQUE
            ElseIf PCCalledTimes(FORCE_ZTORQUE) = 0 Then
            	UpdateClient(TASK_MSG, "ADD call for ZTorque", DEBUG_LEVEL)
                forceToReduce = FORCE_ZTORQUE
            EndIf
        EndIf

        ''compare with previous one
        If forceToReduce = PCPreFTR Then
            If forceToReduce = 0 Then
                ''check weather last time it touched bottom
                If PCCBottomTouched Then
                    PostCalibration = True
                    Exit Do
                EndIf
            Else
                PCCntPreFTR = PCCntPreFTR + 1
                If PCCntPreFTR > 1 Then
                	msg$ = "failed, try to reduce " + Str$(forceToReduce) + " in a row"
                	UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
                    Print #LOG_FILE_NO, "failed, try to reduce ", forceToReduce, " in a row"
                    Close #LOG_FILE_NO
                    Exit Function
                EndIf
                ''reset the force sensor
                   ResetForceSensor    ''this will move up 10mm more and back
            EndIf
        Else
            PCPreFTR = forceToReduce
            PCCntPreFTR = 0
        EndIf
        
        g_Steps = PCStepTotal / MAX_POST_CAL_STEP
        g_CurrentSteps = PCStepStart + (PCRepeatIndex - 1) * PCStepTotal / MAX_POST_CAL_STEP
                        
        Select forceToReduce
        Case 0
            PCCalledTimes(0) = PCCalledTimes(0) + 1
            UpdateClient(TASK_MSG, "Find Z Position", INFO_LEVEL)
            Print #LOG_FILE_NO, "Find Z Position"
            PCCBottomTouched = FindZPosition()
        Case FORCE_ZFORCE
        	UpdateClient(TASK_MSG, "dumbbell: reduce FZ", INFO_LEVEL)
            PCCalledTimes(FORCE_ZFORCE) = PCCalledTimes(FORCE_ZFORCE) + 1
            Print #LOG_FILE_NO, "reduce FZ"
            ReduceFZ
        Case FORCE_XTORQUE
        	UpdateClient(TASK_MSG, "dumbbell: reduce Tx", INFO_LEVEL)
            PCCalledTimes(FORCE_XTORQUE) = PCCalledTimes(FORCE_XTORQUE) + 1
            Print #LOG_FILE_NO, "reduce TX"
            g_Dumbbell_Free_Y = Abs(ForcedCutMiddle(FORCE_XTORQUE))
            If g_Dumbbell_Free_Y > ACCPT_THRHLD_MAGNET_FREE_Y Then
            	msg$ = "dumbbell has too big Y freedom in cradle " + Str$(g_Dumbbell_Free_Y)
				UpdateClient(TASK_MSG, msg$, WARNING_LEVEL)
				Print #LOG_FILE_NO, msg$
            EndIf
        Case FORCE_YTORQUE
        	UpdateClient(TASK_MSG, "dumbbell: reduce Ty", INFO_LEVEL)
            PCCalledTimes(FORCE_YTORQUE) = PCCalledTimes(FORCE_YTORQUE) + 1
            Print #LOG_FILE_NO, "reduce TY"
            ForcedCutMiddle FORCE_YTORQUE
        Case FORCE_ZTORQUE
        	UpdateClient(TASK_MSG, "dumbbell: reduce Tz", INFO_LEVEL)
            PCCalledTimes(FORCE_ZTORQUE) = PCCalledTimes(FORCE_ZTORQUE) + 1
            Print #LOG_FILE_NO, "reduce TZ"
            Tool 3
            ForcedCutMiddle FORCE_ZTORQUE
            Tool 0
        Send
        g_CurrentSteps = PCStepStart + PCRepeatIndex * PCStepTotal / MAX_POST_CAL_STEP
        msg$ = Str$(g_CurrentSteps) + " of 100"
        UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
        PCRepeatIndex = PCRepeatIndex + 1
    Loop Until PCRepeatIndex > MAX_POST_CAL_STEP
    If PCRepeatIndex > 12 Then
        UpdateClient(TASK_MSG, "FAILED: reached max retry before got the result", ERROR_LEVEL)
        Print #LOG_FILE_NO, "FAILED: reached max retry before got the result"
    EndIf
 
    UpdateClient(TASK_MSG, "reduce functions called times:", DEBUG_LEVEL)
    msg$ = "FZ: " + Str$(PCCalledTimes(FORCE_ZFORCE))
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    
    msg$ = "TX: " + Str$(PCCalledTimes(FORCE_XTORQUE))
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    
    msg$ = "TY: " + Str$(PCCalledTimes(FORCE_YTORQUE))
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    
    msg$ = "TZ: " + Str$(PCCalledTimes(FORCE_ZTORQUE))
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    
    msg$ = "Find Z Postion called " + Str$(PCCalledTimes(0))
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)

    ReadForces(ByRef PCCurrentForces())
    UpdateClient(TASK_MSG, "===================================================================", DEBUG_LEVEL)
    UpdateClient(TASK_MSG, "Forces changes:", DEBUG_LEVEL)
    msg$ = "FX: " + Str$(PCOldForces(1)) + " to " + Str$(PCCurrentForces(1))
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    msg$ = "FY: " + Str$(PCOldForces(2)) + " to " + Str$(PCCurrentForces(2))
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    msg$ = "FZ: " + Str$(PCOldForces(3)) + " to " + Str$(PCCurrentForces(3))
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    msg$ = "TX: " + Str$(PCOldForces(4)) + " to " + Str$(PCCurrentForces(4))
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    msg$ = "TY: " + Str$(PCOldForces(5)) + " to " + Str$(PCCurrentForces(5))
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    msg$ = "TZ: " + Str$(PCOldForces(6)) + " to " + Str$(PCCurrentForces(6))
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    UpdateClient(TASK_MSG, "===================================================================", DEBUG_LEVEL)
    UpdateClient(TASK_MSG, "Position changes:", DEBUG_LEVEL)
    msg$ = "FX: " + Str$(PCOldPosition(1)) + " to " + Str$(CX(Here))
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    msg$ = "FY: " + Str$(PCOldPosition(2)) + " to " + Str$(CY(Here))
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    msg$ = "FZ: " + Str$(PCOldPosition(3)) + " to " + Str$(CZ(Here))
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    msg$ = "TX: " + Str$(PCOldPosition(4)) + " to " + Str$(CU(Here))
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    UpdateClient(TASK_MSG, "===================================================================", DEBUG_LEVEL)

    Print #LOG_FILE_NO, "PostCalibration end at ", Date$, " ", Time$
    Print #LOG_FILE_NO, "reduce functions called times:"
    Print #LOG_FILE_NO, "FZ: ", PCCalledTimes(FORCE_ZFORCE)
    Print #LOG_FILE_NO, "TX: ", PCCalledTimes(FORCE_XTORQUE)
    Print #LOG_FILE_NO, "TY: ", PCCalledTimes(FORCE_YTORQUE)
    Print #LOG_FILE_NO, "TZ: ", PCCalledTimes(FORCE_ZTORQUE)
    Print #LOG_FILE_NO, "Find Z Postion called ", PCCalledTimes(0)
    Print #LOG_FILE_NO, "==================================================================="
    Print #LOG_FILE_NO, "Forces changes:"
    Print #LOG_FILE_NO, "FX: ", PCOldForces(1), " to ", PCCurrentForces(1)
    Print #LOG_FILE_NO, "FY: ", PCOldForces(2), " to ", PCCurrentForces(2)
    Print #LOG_FILE_NO, "FZ: ", PCOldForces(3), " to ", PCCurrentForces(3)
    Print #LOG_FILE_NO, "TX: ", PCOldForces(4), " to ", PCCurrentForces(4)
    Print #LOG_FILE_NO, "TY: ", PCOldForces(5), " to ", PCCurrentForces(5)
    Print #LOG_FILE_NO, "TZ: ", PCOldForces(6), " to ", PCCurrentForces(6)
    Print #LOG_FILE_NO, "==================================================================="
    Print #LOG_FILE_NO, "Position changes"
    Print #LOG_FILE_NO, "X: ", PCOldPosition(1), " to ", CX(Here)
    Print #LOG_FILE_NO, "Y: ", PCOldPosition(2), " to ", CY(Here)
    Print #LOG_FILE_NO, "Z: ", PCOldPosition(3), " to ", CZ(Here)
    Print #LOG_FILE_NO, "U: ", PCOldPosition(4), " to ", CU(Here)
    Print #LOG_FILE_NO, "==================================================================="

    ''save the result
    If PostCalibration Then
        P86 = P6
        P6 = Here
        msg$ = "P6 moved from (" + Str$(CX(P86)) + ", " + Str$(CY(P86)) + ", " + Str$(CZ(P86)) + ", " + Str$(CU(P86)) + ") "
        UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
		msg$ = "to (" + Str$(CX(P6)) + ", " + Str$(CY(P6)) + ", " + Str$(CZ(P6)) + ", " + Str$(CU(P6)) + ") "
		UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)

        Print #LOG_FILE_NO, "P6 moved from (", CX(P86), ", ", CY(P86), ", ", CZ(P86), ", ", CU(P86), ") ",
        Print #LOG_FILE_NO, "to (", CX(P6), ", ", CY(P6), ", ", CZ(P6), ", ", CU(P6), ") "
        
        msg$ = "Old P6 (" + Str$(CX(P86)) + ", " + Str$(CY(P86)) + ", " + Str$(CZ(P86)) + ", " + Str$(CU(P86)) + ")"
        UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
        
        msg$ = "New P6 (" + Str$(CX(P6)) + ", " + Str$(CY(P6)) + ", " + Str$(CZ(P6)) + ", " + Str$(CU(P6)) + ")"
        UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
        
        
        ''P3 is 20 mm from P6: cooling point
        tmp_Real = DegToRad(g_Perfect_Cradle_Angle + 90)
        P3 = P6 +X(20 * Cos(tmp_Real)) +Y(20 * Sin(tmp_Real))
        ''P2 is above P3
        P2 = P3 :Z(-2)
        g_U4MagnetHolder = CU(Here)
    Else
        ''restore old preserved global
        g_U4MagnetHolder = Old_U4MagnetHolder
    EndIf

#ifdef PUSH_MAGNET_ASIDE
    If PostCalibration Then
        PCPushX = CX(Here)
        PCPushY = CY(Here)
        If Not ForceTouch(DIRECTION_CAVITY_TAIL, 1, True) Then
            UpdateClient(TASK_MSG, "Failed in push magnet aside to reduce freedom in operation", WARNING_LEVEL)
            Print #LOG_FILE_NO, "Failed in push magnet aside to reduce freedom in operation"
        EndIf
    
    	msg$ = "Push Magnet to one side, X, Y moved from (" + Str$(PCPushX) + ", " + Str$(PCPushY) + ") to (" + Str$(CX(Here)) + ", " + Str$(CY(Here)) + ")"
    	UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
        Print #LOG_FILE_NO, "Push Magnet to one side, X, Y moved from (", PCPushX, ", ", PCPushY, ") to (", CX(Here), ", ", CY(Here), ")"

        If (GTCheckPoint(7)) Then
	        msg$ = "P7 moved from (" + Str$(CX(P7)) + ", " + Str$(CY(P7)) + ", " + Str$(CZ(P7)) + ", " + Str$(CU(P7)) + ") "
    	    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
        	Print #LOG_FILE_NO, "P7 moved from (", CX(P7), ", ", CY(P7), ", ", CZ(P7), ", ", CU(P7), ") ",
        EndIf
        P7 = Here
        msg$ = "to (" + Str$(CX(P7)) + ", " + Str$(CY(P7)) + ", " + Str$(CZ(P7)) + ", " + Str$(CU(P7)) + ") "
        UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
        Print #LOG_FILE_NO, "to (", CX(P7), ", ", CY(P7), ", ", CZ(P7), ", ", CU(P7), ") "
        
        Move P6

    EndIf
#endif ''PUSH_MAGNET_ASIDE

#ifdef AUTO_SAVE_POINT
    If PostCalibration Then
    	UpdateClient(TASK_MSG, "saving points to file.....", INFO_LEVEL)
        SavePoints "robot1.pts"
        UpdateClient(TASK_MSG, "Done!!", INFO_LEVEL)
        SavePointHistory 6, g_FCntPost
    EndIf
#endif

    Close #LOG_FILE_NO
    If g_FlagAbort Then
        If Not Open_Gripper Then
            g_RunResult$ = "after Post Cal: user abort: Open_Gripper Failed, holding magnet, need Reset"
            UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
            g_RobotStatus = g_RobotStatus Or FLAG_NEED_RESET
            g_RobotStatus = g_RobotStatus Or FLAG_REASON_GRIPPER_JAM
            Motor Off
            Quit All
        EndIf
        SetFastSpeed
	    TongMove DIRECTION_MAGNET_TO_CAVITY, 20, False
        g_HoldMagnet = False
        g_SafeToGoHome = True
    EndIf
Fend

'forces is array of (6), it is read only'
'The return will be [0,6]'
'0: means all forces are within minimum.'
'1-6, normally 3-6, means you should reduce that force first'
'It does not involve any hardware access'
''It checks XYZ torques first, if all of them are within minimun,
''then it will return 0 without checking FZ.
''Otherwise, it will include FZ to select the largest force to reduce
Function SelectForceToReduce(ByRef forces() As Double) As Integer

    'init weights for each force'
    weightFactor(FORCE_XFORCE) = 0 'ignore'
    weightFactor(FORCE_YFORCE) = 0 'ignore'
    weightFactor(FORCE_ZFORCE) = 4

    weightFactor(FORCE_XTORQUE) = 2
    weightFactor(FORCE_YTORQUE) = 3
    weightFactor(FORCE_ZTORQUE) = 16

    ''check torques frist
    SelectForceToReduce = 0
    NumToSelect = 0

    For SForceIndex = FORCE_XTORQUE To FORCE_ZTORQUE
        If Abs(forces(SForceIndex)) < GetForceMin(SForceIndex) Or weightFactor(SForceIndex) = 0 Then
            forceWeight(SForceIndex) = 0
        Else
            forceWeight(SForceIndex) = Abs(forces(SForceIndex)) * weightFactor(SForceIndex)
            SelectForceToReduce = SForceIndex
            NumToSelect = NumToSelect + 1
        EndIf
    Next

    ''if no torque, then return 0, the caller will call FindZPosition
    If NumToSelect = 0 Then Exit Function

    ''OK, we need to count in FZ now 
    ''ZFORCE is special: we compare with the threshold, not min
    If Not m_IgnoreFZForNow And forces(FORCE_ZFORCE) <= (0 - GetForceThreshold(FORCE_ZFORCE)) Then
        forceWeight(FORCE_ZFORCE) = Abs(forces(FORCE_ZFORCE)) * weightFactor(FORCE_ZFORCE)
        SelectForceToReduce = FORCE_ZFORCE
        NumToSelect = NumToSelect + 1
    Else
        forceWeight(FORCE_ZFORCE) = 0
    EndIf

    ''only 1 and it is not FZ
    If NumToSelect = 1 Then Exit Function


    'we have more than 1, so try to find the max weight'
    For SForceIndex = FORCE_XTORQUE To FORCE_ZTORQUE
        If forceWeight(SForceIndex) > forceWeight(SelectForceToReduce) Then SelectForceToReduce = SForceIndex
    Next
Fend

Function Init_Magnet_Constants
    m_MinZStep = 0.002 '20 microns'
Fend

Function ReduceFZ
	String msg$

    ''Init_Magnet_Constants
    RFZStepStart = g_CurrentSteps
    RFZStepTotal = g_Steps

    RFZOldZ = CZ(Here)

    'Find out current FZ situation'
    RFZOldFZ = ReadForce(FORCE_ZFORCE)
    UpdateClient(TASK_MSG, "Reduce FZ", INFO_LEVEL)
    msg$ = "old Z" + Str$(RFZOldZ) + " oldFZ " + Str$(RFZOldFZ)
    UpdateClient(TASK_MSG, msg$, INFO_LEVEL)

    If RFZOldFZ <= 0 And RFZOldFZ > -g_MinFZ Then
        UpdateClient(TASK_MSG, "no need to reduce FZ, already < -g_MinFZ", INFO_LEVEL)
        Print #LOG_FILE_NO, "no need to reduce FZ, already > -g_MinFZ"
        Exit Function
    EndIf

    g_Steps = RFZStepTotal /2
    If Not ForceCross(FORCE_ZFORCE, -g_ThresholdFZ, g_MaxRangeZ, g_ZNumSteps, False) Then
        RFZNewZ = CZ(Here)
        RFZNewFZ = ReadForce(FORCE_ZFORCE)
        m_IgnoreFZForNow = True ''we will deal with it in FindZPosition when all other forces are reduced.
        UpdateClient(TASK_MSG, "force sensor need reset, ignore FZ for now", INFO_LEVEL)
        Print #LOG_FILE_NO, "force sensor need reset, ignore FZ for now"
        msg$ = "FZRisingCross " + Str$(-g_ThresholdFZ) + " failed"
        UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
        Print #LOG_FILE_NO, "FZRisingCross ", -g_ThresholdFZ, "failed"
        msg$ = "ReduceFZ, Z moved from " + Str$(RFZOldZ) + " to " + Str$(RFZNewZ) + ", FZ from " + Str$(RFZOldFZ) + " to " + Str$(RFZNewFZ)
        UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
        Print #LOG_FILE_NO, "ReduceFZ, Z moved from ", RFZOldZ, " to ", RFZNewZ, ", FZ from ", RFZOldFZ, " to ", RFZNewFZ
        Exit Function
    EndIf

    g_Steps = RFZStepTotal /2
    g_CurrentSteps = FMStepStart + FMStepTotal /2
    msg$ = Str$(g_CurrentSteps) + " of 100"
    
    ForceCross FORCE_ZFORCE, -g_MinFZ, 2 * m_MinZStep, 2, False
    
    RFZNewZ = CZ(Here)
    RFZNewFZ = ReadForce(FORCE_ZFORCE)

    msg$ = "ReduceFZ, Z moved from " + Str$(RFZOldZ) + " to " + Str$(RFZNewZ) + ", FZ from " + Str$(RFZOldFZ) + " to " + Str$(RFZNewFZ)
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    Print #LOG_FILE_NO, "ReduceFZ, Z moved from ", RFZOldZ, " to ", RFZNewZ, ", FZ from ", RFZOldFZ, " to ", RFZNewFZ
Fend


''This function should only be called when other forces are already close to 0
Function FindZPosition As Boolean
	String msg$
    FindZPosition = False
    FZPStepStart = g_CurrentSteps
    FZPStepTotal = g_Steps

    ''Init_Magnet_Constants
    FZPOldZ = CZ(Here)

    'Find out current FZ situation'
    FZPOldFZ = ReadForce(FORCE_ZFORCE)
    msg$ = "FindZPosition: old Z" + Str$(FZPOldZ) + " FZPOldFZ " + Str$(FZPOldFZ)
    UpdateClient(TASK_MSG, msg$, INFO_LEVEL)

    ''reset force sensor
    m_IgnoreFZForNow = False
    Move Here +Z(2)
    UpdateClient(TASK_MSG, "dumbbell: resetting force sensor", INFO_LEVEL)
    ResetForceSensor    ''this will move up 10mm more and back
    g_Steps = FZPStepTotal /2
    g_CurrentSteps = FZPStepStart + g_Steps
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
    UpdateClient(TASK_MSG, "dumbbell: touching bottom", INFO_LEVEL)
    ''force down to TZTouchMin
    FindZPosition = ForceTouch(-FORCE_ZFORCE, 10, True)
    If Not FindZPosition Then
        UpdateClient(TASK_MSG, "not bottomed this time, try next time", INFO_LEVEL)
        Print #LOG_FILE_NO, "not bottomed this time, try next time"
    Else
        Move Here +Z(0.05)
    EndIf
Fend

''this function will set placer's init x to a module variable'
Function PickerTouchSeat As Boolean
	String msg$

    PKTSStepStart = g_CurrentSteps
    PKTSStepTotal = g_Steps
    
    PickerTouchSeat = False

    ''find init position to ping the holder of magnet
    ''derive init value from magnet transport P6
    ''some distance from the transport

    ''move from P6 to the init point
    ''open gripper
    If Not Open_Gripper Then
        g_RunResult$ = "Open_Gripper failed in picker touch seat, need Reset"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_RESET
        g_RobotStatus = g_RobotStatus Or FLAG_REASON_GRIPPER_JAM
        Motor Off
        Quit All
    EndIf

    ''move away from the post, the 20mm is safe buffer to turn the tong around
    SetFastSpeed
    ''Move P* -X(DISTANCE_FROM_SEAT + 20)
    TongMove DIRECTION_MAGNET_TO_CAVITY, DISTANCE_FROM_SEAT + SAFE_BUFFER_FOR_U_TURN, False

    g_HoldMagnet = False

    If Not Close_Gripper Then
        g_RunResult$ = "Close_Gripper failed in picker touch seat, aborting"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        MoveTongHome
        ''not need recovery
        g_SafeToGoHome = False
        Exit Function
    EndIf

    Wait 2 * TIME_WAIT_BEFORE_RESET
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at pickerTouchingSeat"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf

    Go Here -Z(35) -U(180)  ''lower arm so that cavity will be within the height of seat
                            ''rotate 180 so that cavity, not the magnet, will be close to seat
                            ''we take -180 not +180, because we want to arc in the future
                            ''between magnet position, picker position, placer position
    
    ''Move P* +X(20)
    TongMove DIRECTION_MAGNET_TO_CAVITY, SAFE_BUFFER_FOR_U_TURN, False
        
    SetVerySlowSpeed

    ''go to touch the seat
    ''in ideal situation, the distance detween cavity and seat is
    '' DISTANCE_FROM_SEAT + H_DISTANCE_CAVITY_TO_GRIPPER - 7.06(cavity radius) - 5(half of holder thickness
    '' we give some overshoot to make sure it will touch the seat
    PKTSRange = DISTANCE_FROM_SEAT + H_DISTANCE_CAVITY_TO_GRIPPER

    ''reset force sensor before moving for touch
    ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY)

    g_Steps = PKTSStepTotal /2
    If Not ForceTouch(DIRECTION_MAGNET_TO_CAVITY, PKTSRange, True) Then
        Print "touch seat failed at placer side"
        Exit Function
    EndIf
    g_Steps = PKTSStepTotal /2
    g_CurrentSteps = PKTSStepStart + g_Steps
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)

    msg$ = "cavity touched placer side of seat at (" + Str$(CX(Here)) + ", " + Str$(CY(Here)) + ")"
    UpdateClient(TASK_PROG, msg$, DEBUG_LEVEL)

    PKTSX1 = CX(Here)
    PKTSY1 = CY(Here)

    ''touch the other end: detach the seat, then move along 20 mm to touch the picker end
    SetFastSpeed
    ''Move P*-X(DISTANCE_FROM_SEAT)
    TongMove DIRECTION_CAVITY_TO_MAGNET, DISTANCE_FROM_SEAT, False

    Wait TIME_WAIT_BEFORE_RESET
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at pickerTouchingSeat other end"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    ''Move P* +Y(20)
    TongMove DIRECTION_CAVITY_TAIL, DISTANCE_BETWEEN_TWO_TOUCH, False
    ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY)
    
    SetVerySlowSpeed

    ''save start position
    PKTSX2 = CX(Here)
    PKTSY2 = CY(Here)
    If Not ForceTouch(DIRECTION_MAGNET_TO_CAVITY, PKTSRange, True) Then
        Print "touch seat failed at picker side for the first try"
        Move Here :X(PKTSX2) :Y(PKTSY2)
		If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
			g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
			g_RunResult$ = "force sensor reset failed at pickerTouchingSeat picker side"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf
        TongMove DIRECTION_CAVITY_HEAD, DISTANCE_BETWEEN_TWO_TOUCH / 2, False
        ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY)
    	If Not ForceTouch(DIRECTION_MAGNET_TO_CAVITY, PKTSRange, True) Then
    		g_RunResult$ = "failed to touch seat at picker side"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
	    	Print #LOG_FILE_NO, "failed to touch seat at picker side"
    	    Exit Function
    	EndIf
    EndIf

    PickerTouchSeat = True
    msg$ = "picker cavity touched seat at (" + Str$(CX(Here)) + ", " + Str$(CY(Here)) + ")"
	UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
			
    PKTSX2 = CX(Here)
    PKTSY2 = CY(Here)
    
    Print #LOG_FILE_NO, "touched seat at (", PKTSX1, ", ", PKTSY1, ") and (", PKTSX2, ", ", PKTSY2, ")"
    ''recheck
    If Abs(PKTSX1 - PKTSX2) > 2 Then
    	UpdateClient(TASK_MSG, "touching seat for picker may failed, please check", INFO_LEVEL)
        If PKTSX2 > PKTSX1 Then
            PKTSX2 = PKTSX1
            Move Here :X(PKTSX1)
            Print "X moved to ", PKTSX1
        EndIf
    EndIf
   
Fend

Function PickerCalibration As Boolean
	String msg$
	
    PKCStepStart = g_CurrentSteps
    PKCStepTotal = g_Steps

    Tool 0
    g_SafeToGoHome = True

    ''log file
    g_FCntPicker = g_FCntPicker + 1
    WOpen "PickerCal" + Str$(g_FCntPicker) + ".Txt" As #LOG_FILE_NO
    Print #LOG_FILE_NO, "picker calibration at ", Date$, " ", Time$
    msg$ = "Picker calibration at " + Date$ + " " + Time$
	UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    PickerCalibration = False

    ''safety check
    If Not isCloseToPoint(6) Then
    	UpdateClient(TASK_MSG, "PickerCalibration: Fail! Must start from P6 position", ERROR_LEVEL)
        Print #LOG_FILE_NO, "FAILED: It must start from P6 position"
        Close #LOG_FILE_NO
        Exit Function
    EndIf


    PKCInitX = CX(Here)
    PKCInitY = CY(Here)
    PKCInitZ = CZ(Here) + V_DISTANCE_CAVITY_TO_GRIPPER
    PKCInitU = CU(Here)

    InitForceConstants
    
    g_OnlyAlongAxis = True

    ''===========================================================
    ''Find roughly correct values for X, Y first,
    ''then we can touch to find Z
    ''then we can fine tune Y (reduce force)
    ''then fine tune X (reduce force)
    ''===========================================================

    ''find X by touching the seat using cavity
    g_Steps = PKCStepTotal /3
    UpdateClient(TASK_MSG, "picker cal: touching seat for X", INFO_LEVEL)
    If Not PickerTouchSeat Then
	    UpdateClient(TASK_MSG, "picker cal: Fail!  did not touch the holder seat", ERROR_LEVEL)
        Print #LOG_FILE_NO, "FAILED: did not touch the holder seat"
        Close #LOG_FILE_NO
        Exit Function
    EndIf

    g_Steps = PKCStepTotal /6
    g_CurrentSteps = PKCStepStart + 2 * g_Steps
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
    UpdateClient(TASK_MSG, "picker cal: touching head for Y", INFO_LEVEL)
    ''move cavity to touch magnet head: X will be finalX minus cavity Radius

    SetFastSpeed

    ''detach seat
    ''Move P*-X(2)
    TongMove DIRECTION_CAVITY_TO_MAGNET, SAFE_BUFFER_FOR_DETACH, False
    
    ''move along the holder to picker side    
    ''Move P* +Y(25) :Z(PKCInitZ)
    ''we know when the cavity hit the seat, it is still with in the seat a lot, 15mm is good
    PKCRange = SAFE_BUFFER_FOR_RESET_FORCE + 15
    TongMove DIRECTION_CAVITY_TAIL, PKCRange, False
    Move Here :Z(PKCInitZ)
    ''move the edge of cavity to the center of magnet head
    ''Move P* :X(PKCFinalX - CAVITY_RADIUS)
    TongMove DIRECTION_MAGNET_TO_CAVITY, SAFE_BUFFER_FOR_DETACH + HALF_OF_SEAT_THICKNESS, False
    SetVerySlowSpeed

    Wait TIME_WAIT_BEFORE_RESET
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at pickerCalibration"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    If Not ForceTouch(DIRECTION_CAVITY_HEAD, PKCRange, True) Then
    	UpdateClient(TASK_MSG, "picker cal: calibrate picker failed at touch magnet head", ERROR_LEVEL)
        Print #LOG_FILE_NO, "FAILED: calibrate picker failed at touch magnet head"
        Close #LOG_FILE_NO
        Exit Function
    EndIf
    Print #LOG_FILE_NO, "touched magnet head at (", CX(Here), ", ", CY(Here), ")"
    g_Steps = PKCStepTotal /6
    g_CurrentSteps = PKCStepStart + 3 * g_Steps
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
    UpdateClient(TASK_MSG, "picker cal: touching head for Z", INFO_LEVEL)

    ''now we have roughly X, Y, we can go above to find Z first
    ''move to above to touch Z
    SetFastSpeed
    ''Move P* +Y(10)
    TongMove DIRECTION_CAVITY_TAIL, SAFE_BUFFER_FOR_RESET_FORCE, False
    
    Move Here +Z(CAVITY_RADIUS + MAGNET_HEAD_RADIUS + SAFE_BUFFER_FOR_Z_TOUCH)
    ''Move P* :X(PKCFinalX) :Y(PKCFinalY)
    ''move cavity center to magnet center
    TongMove DIRECTION_MAGNET_TO_CAVITY, CAVITY_RADIUS, False
    ''mov to above magnet head
    TongMove DIRECTION_CAVITY_HEAD, SAFE_BUFFER_FOR_RESET_FORCE + OVER_LAP_FOR_Z_TOUCH, False

    SetVerySlowSpeed
    
    Wait TIME_WAIT_BEFORE_RESET
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at pickerCalibration before z"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    If Not ForceTouch(-FORCE_ZFORCE, SAFE_BUFFER_FOR_Z_TOUCH + 10, True) Then
    	UpdateClient(TASK_MSG, "FAILED: did not touch magnet head when lower the cavity for picker", ERROR_LEVEL)
        Print #LOG_FILE_NO, "FAILED: did not touch magnet head when lower the cavity for picker"
        Close #LOG_FILE_NO
        Exit Function
    EndIf
    
    Print #LOG_FILE_NO, "touch magnet head at Z=", CZ(Here)
    ''PKCFinalZ = CZ(P*) - CAVITY_RADIUS - MAGNET_HEAD_RADIUS
    ''move a little up 
    Move Here +Z(0.05)

    g_Steps = PKCStepTotal /6
    g_CurrentSteps = PKCStepStart + 4 * g_Steps
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
    UpdateClient(TASK_MSG, "picker cal: touching head for more accurate X", INFO_LEVEL)

    SetFastSpeed
    Move Here +Z(SAFE_BUFFER_FOR_DETACH)

    TongMove DIRECTION_CAVITY_TO_MAGNET, CAVITY_RADIUS + HALF_OF_SEAT_THICKNESS + SAFE_BUFFER_FOR_DETACH, False
    Move Here -Z(SAFE_BUFFER_FOR_DETACH + CAVITY_RADIUS + MAGNET_HEAD_RADIUS)
    m_MAPAStartX = CX(Here)
    m_MAPAStartY = CY(Here)
    SetVerySlowSpeed
    If Not ForceTouch(DIRECTION_MAGNET_TO_CAVITY, HALF_OF_SEAT_THICKNESS + SAFE_BUFFER_FOR_DETACH, True) Then
        UpdateClient(TASK_MSG, "Failed for accurate post angle: touching picker head", ERROR_LEVEL)
        Print #LOG_FILE_NO, "Failed for accurate post angle: touching picker head"
        g_PickerWallToHead = 0
        
        ''move to position for next step   
        SetFastSpeed
        Move Here :X(m_MAPAStartX) :Y(m_MAPAStartY)
        TongMove DIRECTION_CAVITY_TAIL, SAFE_BUFFER_FOR_RESET_FORCE + OVER_LAP_FOR_Z_TOUCH, False
        TongMove DIRECTION_MAGNET_TO_CAVITY, CAVITY_RADIUS + HALF_OF_SEAT_THICKNESS + SAFE_BUFFER_FOR_DETACH, False
    Else
        m_MAPAStartX = m_MAPAStartX - CX(Here)
        m_MAPAStartY = m_MAPAStartY - CY(Here)
        g_PickerWallToHead = Sqr(m_MAPAStartX * m_MAPAStartX + m_MAPAStartY * m_MAPAStartY) - SAFE_BUFFER_FOR_DETACH
        msg$ = "g_PickerWallToHead=" + Str$(g_PickerWallToHead)
        UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
        Print #LOG_FILE_NO, "g_PickerWallToHead=", g_PickerWallToHead
        
        ''move to ready position for next step
        SetFastSpeed
        TongMove DIRECTION_CAVITY_TO_MAGNET, SAFE_BUFFER_FOR_DETACH, False
        TongMove DIRECTION_CAVITY_TAIL, SAFE_BUFFER_FOR_RESET_FORCE + OVER_LAP_FOR_Z_TOUCH, False
        TongMove DIRECTION_MAGNET_TO_CAVITY, CAVITY_RADIUS + MAGNET_HEAD_RADIUS + SAFE_BUFFER_FOR_DETACH, False
    EndIf
    g_Steps = PKCStepTotal /6
    g_CurrentSteps = PKCStepStart + 5 * g_Steps
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
    UpdateClient(TASK_MSG, "picker cal: move in", INFO_LEVEL)
#ifdef FINE_TUNE_PICKER
    ''fine tune Y
    Wait TIME_WAIT_BEFORE_RESET
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at pickerCalibration find tune"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    ''move back to where we hit the magnet head
    TongMove DIRECTION_CAVITY_HEAD, SAFE_BUFFER_FOR_RESET_FORCE, False
    ''save data for toolset calibration
    g_Picker_X = CX(Here)
    g_Picker_Y = CY(Here)

    SetVerySlowSpeed
    
    ''head thickness is 3.55, with 1mm freedom, so 10 is enough to cover that
    If Not ForceTouch(DIRECTION_CAVITY_HEAD, 10, False) Then
    	UpdateClient(TASK_MSG, "failed to touch magnet in Y direction", ERROR_LEVEL)
        Print #LOG_FILE_NO, "FAILED: to touch magnet in Y direction"
        Close #LOG_FILE_NO
        
        Exit Function
    EndIf
    CutMiddle DIRECTION_CAVITY_HEAD
    CutMiddleWithArguments DIRECTION_MAGNET_TO_CAVITY, 0, GetForceBigThreshold(DIRECTION_MAGNET_TO_CAVITY), 3, 30
#else
    ''calculate final picker position from what we already have
    ''move back to where we hit the magnet head using cavity edge
    TongMove DIRECTION_CAVITY_HEAD, SAFE_BUFFER_FOR_RESET_FORCE, False
    ''save data for toolset calibration
    g_Picker_X = CX(Here)
    g_Picker_Y = CY(Here)

    SetVerySlowSpeed
    ''move in 3mm
    TongMove DIRECTION_CAVITY_HEAD, (PICKER_OVER_MAGNET_HEAD - g_Dumbbell_Free_Y / 2), False
    ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY)

#endif
	msg$ = "SUCCESS: Picker position (" + Str$(CX(Here)) + ", " + Str$(CY(Here)) + ", " + Str$(CZ(Here)) + ", " + Str$(CU(Here)) + ")"
	UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    Print #LOG_FILE_NO, "SUCCESS: Picker position (", CX(Here), ", ", CY(Here), ", ", CZ(Here), ", ", CU(Here), ")"
    Print #LOG_FILE_NO, "picker calibration end at ", Date$, " ", Time$

    If (GTCheckPoint(16)) Then
	    msg$ = "P16 moved from (" + Str$(CX(P16)) + ", " + Str$(CY(P16)) + ", " + Str$(CZ(P16)) + ", " + Str$(CU(P16)) + ") "
	    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
	    Print #LOG_FILE_NO, "P16 moved from (", CX(P16), ", ", CY(P16), ", ", CZ(P16), ", ", CU(P16), ") ",
	    msg$ = "Old P16 (" + Str$(CX(P16)) + ", " + Str$(CY(P16)) + ", " + Str$(CZ(P16)) + ", " + Str$(CU(P16)) + ")"
	    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
	EndIf
    P16 = Here
    msg$ = "to (" + Str$(CX(P16)) + ", " + Str$(CY(P16)) + ", " + Str$(CZ(P16)) + ", " + Str$(CU(P16)) + ") "
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    Print #LOG_FILE_NO, "to (", CX(P16), ", ", CY(P16), ", ", CZ(P16), ", ", CU(P16), ") "
	msg$ = "New P16 (" + Str$(CX(P16)) + ", " + Str$(CY(P16)) + ", " + Str$(CZ(P16)) + ", " + Str$(CU(P16)) + ")"
	UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)

#ifdef AUTO_SAVE_POINT
	UpdateClient(TASK_MSG, "saving points to file.....", INFO_LEVEL)
    SavePoints "robot1.pts"
    SavePointHistory 16, g_FCntPicker
   	UpdateClient(TASK_MSG, "Done!!", INFO_LEVEL)
#endif
    SetFastSpeed
    TongMove DIRECTION_CAVITY_TAIL, STANDBY_DISTANCE, False
    Close #LOG_FILE_NO
    
    If Not g_FlagAbort Then
        PickerCalibration = True
    EndIf
Fend
Function PlacerCalibration As Boolean
	String msg$
	
    CPCStepStart = g_CurrentSteps
    CPCStepTotal = g_Steps

    g_SafeToGoHome = True
    Tool 0

    ''log file
    g_FCntPlacer = g_FCntPlacer + 1
    WOpen "PlacerCal" + Str$(g_FCntPlacer) + ".Txt" As #LOG_FILE_NO
    Print #LOG_FILE_NO, "placer calibration at ", Date$, " ", Time$
    
    msg$ = "Placer calibration at " + Date$ + " " + Time$
	UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)

    InitForceConstants
    
    g_OnlyAlongAxis = True

    PlacerCalibration = False

    ''pre-condition: current position: cavity should be Picker's place +Y(10)'
    If Not isGoodForPlacerCal Then
    	UpdateClient(TASK_MSG, "not a good place to start placer calibration,  It should be P16 +Y(10)", ERROR_LEVEL)
        Print #LOG_FILE_NO, "FAILED: not a good place to start placer calibration,  It should be P16 +Y(10)"
        Close #LOG_FILE_NO
        
        Exit Function
    EndIf

	UpdateClient(TASK_MSG, "placer cal: arc to placer side", INFO_LEVEL)

    CPCInitX = CX(Here)
    CPCInitY = CY(Here)
    CPCInitZ = CZ(Here)
    CPCInitU = CU(Here)

    ''calculate the final position from P6:
    ''from P6 move from Cavity to magnet of distance of CAVITY_TO_MAGNET,
    ''then move to weak magnet end DISTANCE_PLACER_FROM_MAGNET
    CalculateStepSize(DIRECTION_CAVITY_TO_MAGNET, H_DISTANCE_CAVITY_TO_GRIPPER, CU(P6), ByRef CPCStepSize())
    CPCFinalX = CX(P6) + CPCStepSize(1)
    CPCFinalY = CY(P6) + CPCStepSize(2)

    ''in P6, the cavity tail is the direction where we want to move
    CalculateStepSize(DIRECTION_CAVITY_TAIL, DISTANCE_PLACER_FROM_MAGNET, CU(P6), ByRef CPCStepSize())
    CPCFinalX = CPCFinalX + CPCStepSize(1)
    CPCFinalY = CPCFinalY + CPCStepSize(2)

    CalculateStepSize(DIRECTION_MAGNET_TO_CAVITY, CAVITY_RADIUS, CU(P6), ByRef CPCStepSize())
    CPCFinalX = CPCFinalX + CPCStepSize(1)
    CPCFinalY = CPCFinalY + CPCStepSize(2)

    ''CPCFinalZ = CZ(P6) + V_DISTANCE_CAVITY_TO_GRIPPER
    CPCFinalZ = CZ(Here) ''in fact, this may  be better
    CPCFinalU = CU(P6)
    
    ''try to arc from picker to placer : turn +U(180)
    ''arc middle point
    CPCMiddleX = (CPCInitX + CPCFinalX + CPCFinalY - CPCInitY) /2
    CPCMiddleY = (CPCInitY + CPCFinalY + CPCInitX - CPCFinalX) /2
    CPCMiddleZ = (CPCInitZ + CPCFinalZ) /2
    CPCMiddleU = (CPCInitU + CPCFinalU) /2

    ''arc from picker to placer
    P51 = XY(CPCMiddleX, CPCMiddleY, CPCMiddleZ, CPCMiddleU)
    P52 = XY(CPCFinalX, CPCFinalY, CPCFinalZ, CPCFinalU)
	Hand P51, Hand(P6)
	Hand P52, Hand(P6)
	
	msg$ = "init (" + Str$(CPCInitX) + ", " + Str$(CPCInitY) + ") final (" + Str$(CPCFinalX) + ", " + Str$(CPCFinalY) + ")"
	UpdateClient(TASK_MSG, msg$, INFO_LEVEL)

    SetFastSpeed
    Arc P51, P52
    SetVerySlowSpeed

    g_Steps = CPCStepTotal /5
    g_CurrentSteps = CPCStepStart + g_Steps
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
    UpdateClient(TASK_MSG, "placer cal: touching head for Y", INFO_LEVEL)

    Wait TIME_WAIT_BEFORE_RESET
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at placerCalibration"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
	If Not ForceTouch(DIRECTION_CAVITY_HEAD, DISTANCE_PLACER_FROM_MAGNET, True) Then
    	UpdateClient(TASK_MSG, "FAILED: calibrate placer failed at touch magnet head", ERROR_LEVEL)
        Print #LOG_FILE_NO, "FAILED: calibrate placer failed at touch magnet head"
        Close #LOG_FILE_NO
        Exit Function
    EndIf

    Print #LOG_FILE_NO, "touched magnet head at (", CX(Here), ", ", CY(Here), ")"

    g_Steps = CPCStepTotal /5
    g_CurrentSteps = CPCStepStart + 2 * g_Steps
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
	UpdateClient(TASK_MSG, "placer cal: touching seat for X", INFO_LEVEL)

    ''try to touch seat for X with cavity.
    ''the free space here is very limited.
    SetFastSpeed
    TongMove DIRECTION_CAVITY_TAIL, SAFE_BUFFER_FOR_DETACH, False
    TongMove DIRECTION_MAGNET_TO_CAVITY, HALF_OF_SEAT_THICKNESS * 2, False    ''5 is the wall, another 5 for safety
    ''here we do not need to give very big safe buffer like in placer calibration.
    ''the error is no way too big.

    Move Here -Z(20)

    TongMove DIRECTION_CAVITY_HEAD, DISTANCE_TOUCH_ARM + SAFE_BUFFER_FOR_DETACH, False
    ''should be change too much.  It is determined by the tong shape.
    
    SetVerySlowSpeed

    Wait TIME_WAIT_BEFORE_RESET
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at placerCalibration before touching seat wall"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    If Not ForceTouch(DIRECTION_CAVITY_TO_MAGNET, HALF_OF_SEAT_THICKNESS * 2, True) Then
    	UpdateClient(TASK_MSG, "FAILED: to touch seat wall for placer", ERROR_LEVEL)
        Print #LOG_FILE_NO, "FAILED: to touch seat wall for placer"
        Close #LOG_FILE_NO
        TongMove DIRECTION_CAVITY_TAIL, DISTANCE_TOUCH_ARM + SAFE_BUFFER_FOR_DETACH, False
        Exit Function
    EndIf
    
    ''we touched the holder arm:
    msg$ = "cavity touched holder arm at (" + Str$(CX(Here)) + ", " + Str$(CY(Here)) + ")"
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    Print #LOG_FILE_NO, "cavity touched holder arm at (", CX(Here), ", ", CY(Here), ")"

    g_Steps = CPCStepTotal /5
    g_CurrentSteps = CPCStepStart + 3 * g_Steps
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
    UpdateClient(TASK_MSG, "placer cal: touching head for Z", INFO_LEVEL)
    
    ''now we have roughly X, Y, we can go above to find Z first
    ''move to above to touch Z
    SetFastSpeed
    TongMove DIRECTION_MAGNET_TO_CAVITY, SAFE_BUFFER_FOR_DETACH, False
    TongMove DIRECTION_CAVITY_TAIL, DISTANCE_TOUCH_ARM - OVER_LAP_FOR_Z_TOUCH, False
    Move Here +Z(20 + CAVITY_RADIUS + MAGNET_HEAD_RADIUS + SAFE_BUFFER_FOR_Z_TOUCH)

    ''move to above magnet head
    TongMove DIRECTION_CAVITY_TO_MAGNET, SAFE_BUFFER_FOR_DETACH + HALF_OF_SEAT_THICKNESS + CAVITY_RADIUS, False
    SetVerySlowSpeed

    Wait TIME_WAIT_BEFORE_RESET
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at placerCalibration before touching z"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
	If Not ForceTouch(-FORCE_ZFORCE, SAFE_BUFFER_FOR_Z_TOUCH + 10, True) Then
    	UpdateClient(TASK_MSG, "FAILED: did not touch magnet head when lower the cavity for picker", ERROR_LEVEL)
        Print #LOG_FILE_NO, "FAILED: did not touch magnet head when lower the cavity for placer"
        Close #LOG_FILE_NO
        Exit Function
    EndIf
    Print #LOG_FILE_NO, "touch magnet head at Z=", CZ(Here)
    ''CPCFinalZ = CZ(P*) - CAVITY_RADIUS - MAGNET_HEAD_RADIUS
    Move Here +Z(0.05)

    g_Steps = CPCStepTotal /5
    g_CurrentSteps = CPCStepStart + 4 * g_Steps
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
    UpdateClient(TASK_MSG, "placer cal: touching head for more accurate X", INFO_LEVEL)

    SetFastSpeed
    Move Here +Z(SAFE_BUFFER_FOR_DETACH)
	UpdateClient(TASK_MSG, "touch head in X direction to get more accurate position", INFO_LEVEL)
    TongMove DIRECTION_MAGNET_TO_CAVITY, CAVITY_RADIUS + HALF_OF_SEAT_THICKNESS + SAFE_BUFFER_FOR_DETACH, False
    Move Here -Z(SAFE_BUFFER_FOR_DETACH + CAVITY_RADIUS + MAGNET_HEAD_RADIUS)
    m_MAPAStartX = CX(Here)
    m_MAPAStartY = CY(Here)
    SetVerySlowSpeed
    If Not ForceTouch(DIRECTION_CAVITY_TO_MAGNET, HALF_OF_SEAT_THICKNESS + SAFE_BUFFER_FOR_DETACH, True) Then
        UpdateClient(TASK_MSG, "Failed for accurate post angle: touching picker head", ERROR_LEVEL)
        Print #LOG_FILE_NO, "Failed for accurate post angle: touching picker head"
        g_PlacerWallToHead = 0
        
        ''move to position for next step   
        SetFastSpeed
        Move Here :X(m_MAPAStartX) :Y(m_MAPAStartY)
        TongMove DIRECTION_CAVITY_TAIL, SAFE_BUFFER_FOR_RESET_FORCE + OVER_LAP_FOR_Z_TOUCH, False
        TongMove DIRECTION_CAVITY_TO_MAGNET, CAVITY_RADIUS + HALF_OF_SEAT_THICKNESS + SAFE_BUFFER_FOR_DETACH, False
    Else
        m_MAPAStartX = m_MAPAStartX - CX(Here)
        m_MAPAStartY = m_MAPAStartY - CY(Here)
        g_PlacerWallToHead = Sqr(m_MAPAStartX * m_MAPAStartX + m_MAPAStartY * m_MAPAStartY) - SAFE_BUFFER_FOR_DETACH
        msg$ = "g_PlacerWallToHead=" + Str$(g_PlacerWallToHead)
        UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
        Print #LOG_FILE_NO, "g_PlacerWallToHead=", g_PlacerWallToHead
        
        ''move to ready position for next step
        SetFastSpeed
        TongMove DIRECTION_MAGNET_TO_CAVITY, SAFE_BUFFER_FOR_DETACH, False
        TongMove DIRECTION_CAVITY_TAIL, SAFE_BUFFER_FOR_RESET_FORCE + OVER_LAP_FOR_Z_TOUCH, False
        TongMove DIRECTION_CAVITY_TO_MAGNET, CAVITY_RADIUS + MAGNET_HEAD_RADIUS + SAFE_BUFFER_FOR_DETACH, False
    EndIf
        
#ifdef FINE_TUNE_PLACER
    '' fine tune Y
    Wait TIME_WAIT_BEFORE_RESET
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at placerCalibration fine tune"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        UpdateClient(TASK_MSG, g_RunResult$)
        Exit Function
    EndIf
    
    TongMove DIRECTION_CAVITY_HEAD, SAFE_BUFFER_FOR_RESET_FORCE, False
    ''save data for toolset calibration
    g_Placer_X = CX(Here)
    g_Plaver_Y = CY(Here)
    
    SetVerySlowSpeed

    If Not ForceTouch(DIRECTION_CAVITY_HEAD, 10, False) Then
    	UpdateClient(TASK_MSG, "failed to touch magnet in Y direction", ERROR_LEVEL)
        Print #LOG_FILE_NO, "FAILED: to touch magnet in Y direction"
        Close #LOG_FILE_NO
        
        Exit Function
    EndIf
    CutMiddle DIRECTION_CAVITY_HEAD
    CutMiddleWithArguments DIRECTION_MAGNET_TO_CAVITY, 0, GetForceBigThreshold(DIRECTION_MAGNET_TO_CAVITY), 3, 30
#else
    ''move back to where we hit the magnet head with cavity edge
    TongMove DIRECTION_CAVITY_HEAD, SAFE_BUFFER_FOR_RESET_FORCE, False
    ''save data for toolset calibration
    g_Placer_X = CX(Here)
    g_Placer_Y = CY(Here)
    ''move in final position
    SetVerySlowSpeed
    TongMove DIRECTION_CAVITY_HEAD, PLACER_OVER_MAGNET_HEAD, False
    ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY)

#endif

	msg$ = "SUCCESS: Placer position (" + Str$(CX(Here)) + ", " + Str$(CY(Here)) + ", " + Str$(CZ(Here)) + ", " + Str$(CU(Here)) + ")"
	UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    Print #LOG_FILE_NO, "SUCCESS: Placer position (", CX(Here), ", ", CY(Here), ", ", CZ(Here), ", ", CU(Here), ")"
    Print #LOG_FILE_NO, "placer calibration end at ", Date$, " ", Time$

    If (GTCheckPoint(26)) Then
	    msg$ = "P26 moved from (" + Str$(CX(P26)) + ", " + Str$(CY(P26)) + ", " + Str$(CZ(P26)) + ", " + Str$(CU(P26)) + ") "
		UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
		Print #LOG_FILE_NO, "P26 moved from (", CX(P26), ", ", CY(P26), ", ", CZ(P26), ", ", CU(P26), ") ",
	    msg$ = "Old P26 (" + Str$(CX(P26)) + ", " + Str$(CY(P26)) + ", " + Str$(CZ(P26)) + ", " + Str$(CU(P26)) + ")"
    	UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
    EndIf
    P26 = Here
    msg$ = "to (" + Str$(CX(P26)) + ", " + Str$(CY(P26)) + ", " + Str$(CZ(P26)) + ", " + Str$(CU(P26)) + ") "
	UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    Print #LOG_FILE_NO, "to (", CX(P26), ", ", CY(P26), ", ", CZ(P26), ", ", CU(P26), ") "

#ifdef AUTO_SAVE_POINT
	UpdateClient(TASK_MSG, "saving points to file.....", INFO_LEVEL)
    SavePoints "robot1.pts"
    SavePointHistory 26, g_FCntPlacer
   	UpdateClient(TASK_MSG, "Done!!", INFO_LEVEL)
#endif
    SetFastSpeed
    TongMove DIRECTION_CAVITY_TAIL, STANDBY_DISTANCE, False

    ''check post level error
    PostLevelError = Abs(CZ(P16) - CZ(P26))
    msg$ = "post level error: " + Str$(PostLevelError) + "mm"
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    Print #LOG_FILE_NO, "post   level error: ", PostLevelError, "mm"
    If PostLevelError >= ACCPT_THRHLD_POST_LEVEL Then
        msg$ = "Warning: post level error exceeded threshold (" + Str$(ACCPT_THRHLD_POST_LEVEL) + "mm)"
        UpdateClient(TASK_MSG, msg$, WARNING_LEVEL)
        UpdateClient(TASK_MSG, msg$, WARNING_LEVEL)
        Print #LOG_FILE_NO, "Warning: post level error exceeded threshold (", ACCPT_THRHLD_POST_LEVEL, "mm)"
    EndIf

    Close #LOG_FILE_NO
    
    If Not g_FlagAbort Then
        PlacerCalibration = True
    EndIf
Fend

Function ABCThetaToToolSets(a As Real, b As Real, c As Real, theta As Real)
	String msg$
    TSU = NarrowAngle(theta)
#ifdef USE_OLD_TOOLSET_DIRECTION
    TSU = TSU - 90
#endif
    theta = DegToRad(theta)
    ''for picker
    TSX = a * Sin(theta) + b * Cos(theta)
    TSY = -a * Cos(theta) + b * Sin(theta)

    ''twist off toolset
    TSTWX = (a + MAGNET_HEAD_RADIUS) * Sin(theta) + (b - SAMPLE_PIN_DEPTH) * Cos(theta)
    TSTWY = (-a - MAGNET_HEAD_RADIUS) * Cos(theta) + (b - SAMPLE_PIN_DEPTH) * Sin(theta)

    TSZ = 0

    msg$ = "Toolset picker: (" + Str$(TSX) + ", " + Str$(TSY) + ", " + Str$(TSZ) + ", " + Str$(TSU) + ")"
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    Print #LOG_FILE_NO, "Toolset picker: (", TSX, ", ", TSY, ", ", TSZ, ", ", TSU, ")"
    
    P10 = XY(TSTWX, TSTWY, TSZ, TSU)
    msg$ = "picker twist off toolset: (" + Str$(TSTWX) + ", " + Str$(TSTWY) + ", " + Str$(TSZ) + ", " + Str$(TSU) + ")"
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    Print #LOG_FILE_NO, "picker twist off toolset: (", TSTWX, ", ", TSTWY, ", ", TSZ, ", ", TSU, ")"
#ifdef AUTO_SAVE_POINT
    If GTCheckTool(1) Then
    	   	P51 = TLSet(1)
		   	msg$ = "old picker: (" + Str$(CX(P51)) + ", " + Str$(CY(P51)) + ", " + Str$(CZ(P51)) + ", " + Str$(CU(P51)) + ")"
  		 	UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
 		  	Print #LOG_FILE_NO, "old picker: (", CX(P51), ", ", CY(P51), ", ", CZ(P51), ", ", CU(P51), ")"
    EndIf

    UpdateClient(TASK_MSG, "saving new picker...", INFO_LEVEL)
    TLSet 1, XY(TSX, TSY, TSZ, TSU)
    UpdateClient(TASK_MSG, "done!", INFO_LEVEL)
#endif
  
    TSU = TSU + 180
    TSX = a * Sin(theta) - c * Cos(theta)
    TSY = -a * Cos(theta) - c * Sin(theta)
    If GTCheckTool(2) Then
    	P51 = TLSet(2)
    	TSZ = CZ(P51) ''keep the old Z offset from last FineTineToolSet
    Else
    	TSZ = 0 ''Initial value
    EndIf

    ''twist off toolset
    TSTWX = (a + MAGNET_HEAD_RADIUS) * Sin(theta) - (c - SAMPLE_PIN_DEPTH) * Cos(theta)
    TSTWY = (-a - MAGNET_HEAD_RADIUS) * Cos(theta) - (c - SAMPLE_PIN_DEPTH) * Sin(theta)
    P11 = XY(TSTWX, TSTWY, TSZ, TSU)
    msg$ = "placer twist off toolset: (" + Str$(TSTWX) + ", " + Str$(TSTWY) + ", " + Str$(TSZ) + ", " + Str$(TSU) + ")"
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    Print #LOG_FILE_NO, "placer twist off toolset: (", TSTWX, ", ", TSTWY, ", ", TSZ, ", ", TSU, ")"

    msg$ = "Toolset placer: (" + Str$(TSX) + ", " + Str$(TSY) + ", " + Str$(TSZ) + ", " + Str$(TSU) + ")"
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    Print #LOG_FILE_NO, "Toolset placer: (", TSX, ", ", TSY, ", ", TSZ, ", ", TSU, ")"
#ifdef AUTO_SAVE_POINT
    If (GTCheckTool(2)) Then
    	P51 = TLSet(2)
    	msg$ = "old placer: (" + Str$(CX(P51)) + ", " + Str$(CY(P51)) + ", " + Str$(CZ(P51)) + ", " + Str$(CU(P51)) + ")"
    	UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
		Print #LOG_FILE_NO, "old placer: (", CX(P51), ", ", CY(P51), ", ", CZ(P51), ", ", CU(P51), ")"
    EndIf

    UpdateClient(TASK_MSG, "saving new placerr.....", INFO_LEVEL)
    TLSet 2, XY(TSX, TSY, TSZ, TSU)
    SavePoints "robot1.pts"
    UpdateClient(TASK_MSG, "done!", INFO_LEVEL)
#endif
Fend

Function CalCavityTwistOff(a As Real, b As Real, theta As Real)
	String msg$
    TSU = theta
#ifdef USE_OLD_TOOLSET_DIRECTION
    TSU = TSU - 90
#endif
    theta = DegToRad(theta)

    TSTWX = (-a + CAVITY_RADIUS) * Sin(theta) + b * Cos(theta)
    TSTWY = (a - CAVITY_RADIUS) * Cos(theta) + b * Sin(theta)
    P12 = P6
    P12 = XY(TSTWX, TSTWY, 0, TSU)
    msg$ = "cavity twist off toolset: (" + Str$(TSTWX) + ", " + Str$(TSTWY) + "0, " + Str$(TSU) + ")"
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL);
    Print #LOG_FILE_NO, "cavity twist off toolset: (", TSTWX, ", ", TSTWY, "0, ", TSU, ")"

    TSTWX = (-a - CAVITY_RADIUS) * Sin(theta) + b * Cos(theta)
    TSTWY = (a + CAVITY_RADIUS) * Cos(theta) + b * Sin(theta)
    P13 = P6
    P13 = XY(TSTWX, TSTWY, 0, TSU)
    msg$ = "cavity twist off toolset for left hand: (" + Str$(TSTWX) + ", " + Str$(TSTWY) + "0, " + Str$(TSU) + ")"
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL);
    Print #LOG_FILE_NO, "cavity twist off toolset for left hand: (", TSTWX, ", ", TSTWY, "0, ", TSU, ")"
Fend

Function CalculateToolset As Boolean
    String msg$
	
    CalculateToolset = False
    
    ''check data availability
    If g_Picker_X = 0 Or g_Picker_Y = 0 Or g_Placer_X = 0 Or g_Placer_X = 0 Or CY(P6) = 0 Then
        Print "do post, picker, and placer calibration first."
        Exit Function
    EndIf

    ''log file
    g_FCntToolRough = g_FCntToolRough + 1
    WOpen "ToolsetCal" + Str$(g_FCntToolRough) + ".Txt" As #LOG_FILE_NO
    Print #LOG_FILE_NO, "======================================================="
    Print #LOG_FILE_NO, "toolset calibration at ", Date$, " ", Time$

    ''print out old toolset
    P51 = TLSet(1)
    msg$ = "Old TLSet 1: (" + Str$(CX(P51)) + "," + Str$(CY(P51)) + "," + Str$(CZ(P51)) + "," + Str$(CU(P51)) + ")"
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    P51 = TLSet(2)
    msg$ = "Old TLSet 2: (" + Str$(CX(P51)) + "," + Str$(CY(P51)) + "," + Str$(CZ(P51)) + "," + Str$(CU(P51)) + ")"
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    
    ''adjust because the the direction we move is not exactly X or Y
    ''this is rough calculation, we ignore second order error
    
    NumToSelect = Int(g_Perfect_Cradle_Angle) Mod 180
        
    If NumToSelect <> 0 Then
	    TSAdjust = Sin(DegToRad(g_MagnetTransportAngle))
	    ''we use TSa as the center of magnet in Y dirction now
	    TSa = (g_Picker_Y + g_Placer_Y) /2.0
	    ''we use TSa as the difference beween magnet center and where U axis center
	    TSa = TSa - CY(P6)
	    TSa = TSa / TSAdjust
	    Print #LOG_FILE_NO, "center to hold: ", TSa
	    msg$ = "center to hold: " + Str$(TSa)
	    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
	    
	    TSb = MAGNET_LENGTH /2.0 + TSa
	    TSc = MAGNET_LENGTH /2.0 - TSa
	    
	    ''try to get TSa
	    ''we use TSX as distance between cavity and magnet
	    TSX = (g_Placer_X - CX(P6)) / TSAdjust
	    ''distance between cavity and U axis center
	    CVa = (g_Placer_X - g_Picker_X) /(2.0 * TSAdjust)
	    CVb = ((g_Picker_Y - g_Placer_Y) / TSAdjust - MAGNET_LENGTH) / 2.0
    Else
	    TSAdjust = -Cos(DegToRad(g_MagnetTransportAngle))
	    TSa = (g_Picker_X + g_Placer_X) /2.0
	    ''we use TSa as the difference beween magnet center and where U axis center
	    TSa = TSa - CX(P6)
	    TSa = TSa / TSAdjust
	    Print #LOG_FILE_NO, "center to hold: ", TSa
	    msg$ = "center to hold: " + Str$(TSa)
   	    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
	    
	    TSb = MAGNET_LENGTH /2.0 + TSa
	    TSc = MAGNET_LENGTH /2.0 - TSa
	    
	    ''try to get TSa
	    ''we use TSX as distance between cavity and magnet
	    TSX = (g_Placer_Y - CY(P6)) / TSAdjust
	    ''distance between cavity and U axis center
	    CVa = (g_Placer_Y - g_Picker_Y) /(2.0 * TSAdjust)
	    CVb = ((g_Placer_X - g_Picker_X) / TSAdjust - MAGNET_LENGTH) / 2.0
    EndIf
	TSa = TSX - CVa
	TStheta = g_MagnetTransportAngle - g_U4MagnetHolder
       
    msg$ = "a=" + Str$(TSa) + ", b=" + Str$(TSb) + ", c=" + Str$(TSc) + ", theta=" + Str$(TStheta)
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    Print #LOG_FILE_NO, "a=", TSa, ", b=", TSb, ", c=", TSc, ", theta=", TStheta

    ''save info
    Print #LOG_FILE_NO, "Old toolset A:", g_ToolSet_A, ", B:", g_ToolSet_B, ", C:", g_ToolSet_C, ", Theta:", g_ToolSet_Theta
	msg$ = "Old Toolset A:" + Str$(g_ToolSet_A) + ", B:" + Str$(g_ToolSet_B) + ", C:" + Str$(g_ToolSet_C) + ", Theta:" + Str$(g_ToolSet_Theta)
	UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)

    g_ToolSet_A = TSa
    g_ToolSet_B = TSb
    g_ToolSet_C = TSc
    g_ToolSet_Theta = TStheta

    ''cavity twist off toolset
    CalCavityTwistOff CVa, CVb, TStheta

    ABCThetaToToolSets TSa, TSb, TSc, TStheta
    
    Close #LOG_FILE_NO

    SavePointHistory 12, g_FCntToolRough

    CalculateToolset = True
    Exit Function
Fend

Function isGoodForPlacerCal As Boolean

    isGoodForPlacerCal = True

	tmp_Real = DegToRad(g_Perfect_Cradle_Angle)
        
    ISP16IdealX = CX(P16) + STANDBY_DISTANCE * Cos(tmp_Real)
    ISP16IdealY = CY(P16) + STANDBY_DISTANCE * Sin(tmp_Real)
    ISP16IdealZ = CZ(P16)
    ISP16IdealU = CU(P16)
    
    
    ISP16DX = CX(Here) - ISP16IdealX
    ISP16DY = CY(Here) - ISP16IdealY
    ISP16DZ = CZ(Here) - ISP16IdealZ
    ISP16DU = CU(Here) - ISP16IdealU

    If Abs(ISP16DU) > 2 Then
        isGoodForPlacerCal = False
    EndIf

    If Abs(ISP16DZ) > 2 Then
        isGoodForPlacerCal = False
    EndIf

    If Sqr(ISP16DX * ISP16DX + ISP16DY * ISP16DY) > 2 Then
        isGoodForPlacerCal = False
    EndIf

    ''more safe, check against P6 also
    ISP16DU = Abs(CU(Here) - CU(P6))
    ISP16DU = ISP16DU - 180
    If Abs(ISP16DU) > 2 Then
        isGoodForPlacerCal = False
    EndIf
    
Fend

Function ParallelGripperAndCradle As Boolean
	String msg$
    ParallelGripperAndCradle = False

    PGCOldU = CU(Here)
    PGCOldForce = ReadForce(DIRECTION_CAVITY_TO_MAGNET)
    msg$ = "ParallelGripperAndCradle: old U=" + Str$(PGCOldU) + ", old force=" + Str$(PGCOldForce)
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    
    PGCGoodU = PGCOldU
    PGCGoodForce = Abs(PGCOldForce)

    ''scan twice, first stepsize = 1 degree, second time stepsize = 0.1 degree    
    For PGCScanIndex = 1 To 2
        Select PGCScanIndex
        Case 1
            PGCStepSize = PGC_INIT_STEPSIZE
            PGCNumSteps = PGC_MAX_SCAN_U
        Case 2
            PGCStepSize = PGC_FINAL_STEPSIZE
            PGCNumSteps = PGC_INIT_STEPSIZE / PGC_FINAL_STEPSIZE
        Send
    
        ''scan both direction
        For PGCDirection = 1 To 2
            For PGCStepIndex = 1 To PGCNumSteps
                If g_FlagAbort Then
                    Go Here :U(PGCOldU)
                    Exit Function
                EndIf
                Select PGCDirection
                Case 1
                    Go Here +U(PGCStepSize)
                Case 2
                    Go Here -U(PGCStepSize)
                Send
                PGCNewU = CU(Here)
                PGCNewForce = ReadForce(DIRECTION_CAVITY_TO_MAGNET)
                PGCNewForce = Abs(PGCNewForce)
                
                If PGCNewForce >= PGCGoodForce Then
                    Exit For
                Else
                    PGCGoodU = PGCNewU;
                    PGCGoodForce = PGCNewForce
                EndIf
            Next ''For PGCStepIndex = 1 to PGCNumSteps
            If PGCStepIndex > PGCNumSteps Then
                Print "U moved out of range without reach min force"
                Go Here :U(PGCOldU)
                Exit Function
            EndIf
            msg$ = Str$(g_CurrentSteps + (PGCScanIndex * 2 + PGCDirection - 2) * g_Steps / 4) + " of 100"
            UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
        Next ''For PGCDirection = 1 To 2
        Go Here :U(PGCGoodU)
    Next ''For PGCScanIndex = 1 to 2
    
    ParallelGripperAndCradle = True
    msg$ = "U moved from " + Str$(PGCOldU) + " to " + Str$(PGCGoodU) + ", force reduced from " + Str$(PGCOldForce) + " to " + Str$(PGCGoodForce)
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
Fend
Function PullOutZ As Boolean
	String msg$
    PullOutZ = False
    
    POZOldX = CX(Here)
    POZOldY = CY(Here)
    POZOldZ = CZ(Here)

    For StepIndex = 1 To POZ_MAX_STEPS
        Move Here +Z(POZ_STEPSIZE)
        g_Steps = 0 ''to prevent ForceTouch update progress bar
        If Not ForceTouch(DIRECTION_CAVITY_TO_MAGNET, 2 * SAFE_BUFFER_FOR_DETACH, False) Then
            Move Here +Z(POZ_STEPSIZE) ''one more step for safety
            If Not g_FlagAbort Then
                PullOutZ = True
                msg$ = "got Z at " + Str$(CZ(Here))
                UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
            Else
                TongMove DIRECTION_MAGNET_TO_CAVITY, 20, False
            EndIf
            Exit Function
        EndIf
          Move Here :X(POZOldX) :Y(POZOldY)
    Next
    
    UpdateClient(TASK_MSG, "not got top of cradle", INFO_LEVEL)
Fend

''09/02/03 Jinhu:
''FindMagnet now will utilize existing P6.  So, it should only be used
''after initial calibration.
''It will start from anyplace that can jump to P3
''It should work as long as DX < 5mm, DY < 5mm, DZ < 5mm, DU < 10 degree.
Function FindMagnet As Boolean
	String msg$
	
	''are the global variables setup for Australian Synchrotron
	''Did the force sensor initialize ok 
	If Not CheckEnvironment Then
		''it is not safe to proceed
		Exit Function
	EndIf
	
    msg$ = "Findmagnet calibration at " + Date$ + " " + Time$
	UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
	
	UpdateClient(TASK_MSG, "find magnet: move tong to dewar", INFO_LEVEL)

    Tool 0

    FMStepStart = g_CurrentSteps
    FMStepTotal = g_Steps

    g_SafeToGoHome = True
    g_HoldMagnet = False

    FindMagnet = False

    InitForceConstants
    
    g_OnlyAlongAxis = True

    If Motor = Off Then
        Motor On
    EndIf
    If Power = 1 Then
        Power Low
    EndIf

    ''check conditions
    ''check current position
    If (Not isCloseToPoint(0)) And (Not isCloseToPoint(1)) Then
        g_RunResult$ = "must start from home"
        g_SafeToGoHome = False
        msg$ = "aborted " + g_RunResult$
        UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
        UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
        Exit Function
    EndIf
    
    ''Calibrate the force sensor and check its readback health
	If Not ForceCalibrateAndCheck(HIGH_SENSITIVITY, HIGH_SENSITIVITY) Then
		UpdateClient(TASK_MSG + TASK_MSG, "Force sensor calibration failed, stopping FindMagnet..", ERROR_LEVEL)
		''problem with force sensor so exit
		Exit Function
	EndIf

    If Not Check_Gripper Then
    	UpdateClient(TASK_MSG + TASK_MSG, "find magnet: abort: check gripper failed", ERROR_LEVEL)
        ''not need recovery
        g_SafeToGoHome = False
        Exit Function
    EndIf
    If Not Close_Gripper Then
    	UpdateClient(TASK_MSG + TASK_MSG, "find magnet: abort: failed to close gripper", ERROR_LEVEL)
        ''not need recovery
        g_SafeToGoHome = False
        Exit Function
    EndIf

    If Not Open_Lid Then
    	UpdateClient(TASK_MSG + TASK_MSG, "find magnet: abort: failed to open Dewar lid", ERROR_LEVEL)
        ''not need recovery
        g_SafeToGoHome = False
        Exit Function
    EndIf
    
    SetFastSpeed
    LimZ 0
    Jump P1
    
    If g_FlagAbort Then
		Close_Lid
		Jump P0
		Exit Function
    EndIf

	''start position is 30 mm away from old position and shift so fingers are at center of cradle.
	tmp_Real = DegToRad(g_Perfect_Cradle_Angle + 90)
	tmp_Real2 = DegToRad(g_Perfect_Cradle_Angle)
	tmp_DX = 30 * Cos(tmp_Real) + Y_FROM_CRADLE_TO_MAGNET * Cos(tmp_Real2)
	tmp_DY = 30 * Sin(tmp_Real) + Y_FROM_CRADLE_TO_MAGNET * Sin(tmp_Real2)
	Jump P6 +X(tmp_DX) +Y(tmp_DY)
	
    Move Here -Z(Z_FROM_CRADLE_TO_MAGNET + FIND_MAGNET_Z_DOWN)
    
    SetVerySlowSpeed

    If g_LN2LevelHigh Then
    	UpdateClient(TASK_MSG, "find magnet cooling tongs until LN2 boiling becomes undetectable", INFO_LEVEL)
        msg$ = "Cooled tong for " + Str$(WaitLN2BoilingStop(SENSE_TIMEOUT, HIGH_SENSITIVITY, HIGH_SENSITIVITY)) + " seconds"
        UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
        ''MagLevelError used here as relative depth
        MagLevelError = CZ(P6) - STRIP_PLACER_Z_OFFSET - CZ(Here)
        If g_IncludeStrip Then
			Move Here +Z(MagLevelError)
        EndIf
        If g_IncludeStrip Then
			Move Here -Z(MagLevelError)
        EndIf
    Else
        Wait TIME_WAIT_BEFORE_RESET
    EndIf
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at findMagnet before touching seat"
        UpdateClient(TASK_MSG + TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    
    ''try to touch the cradle using the gripper
    UpdateClient(TASK_MSG, "find magnet: touching seat", INFO_LEVEL)
    g_Steps = FMStepTotal /10
    If Not ForceTouch(DIRECTION_CAVITY_TO_MAGNET, 50, False) Then
        TongMove DIRECTION_MAGNET_TO_CAVITY, 2, False
        Print "Not find the cradle in 10 cm, give up"
        UpdateClient(TASK_MSG, "Not find the cradle in 10 cm, give up", ERROR_LEVEL)
        Exit Function
    Else
    	UpdateClient(TASK_MSG, "Touched seat with gripper OK", INFO_LEVEL)
    EndIf
    g_CurrentSteps = FMStepStart + FMStepTotal /10
    g_Steps = FMStepTotal /5
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
	UpdateClient(TASK_MSG, "find magnet: parallel gripper with cradle", INFO_LEVEL)
    ''press it against the wall strongly
    TongMove DIRECTION_CAVITY_TO_MAGNET, 2, False
    ''try to get gripper parallel with cradle
    If Not ParallelGripperAndCradle Then
        g_RunResult$ = "ParallelGripperAndCradle failed"
        UpdateClient(TASK_MSG, g_RunResult$, WARNING_LEVEL)
    Else
    	UpdateClient(TASK_MSG, "ParrallelGripperAndCradle success", INFO_LEVEL)
    EndIf
    g_CurrentSteps = FMStepStart + 3 * FMStepTotal / 10
    g_Steps = FMStepTotal /10
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)

    ''try to get the position of cradle
    TongMove DIRECTION_MAGNET_TO_CAVITY, 5, False
    If Not ForceTouch(DIRECTION_CAVITY_TO_MAGNET, 7, True) Then
        TongMove DIRECTION_MAGNET_TO_CAVITY, 10, False
        UpdateClient(TASK_MSG, "Strange, not touched the cradle after we detach it", ERROR_LEVEL)
        Exit Function
    Else
    	UpdateClient(TASK_MSG, "Got position of cradle OK", INFO_LEVEL)
    EndIf
        
    ''try to find the horizontal edges of cradle
    ''detach
    SetFastSpeed
    TongMove DIRECTION_MAGNET_TO_CAVITY, SAFE_BUFFER_FOR_DETACH, False

    g_CurrentSteps = FMStepStart + 2 * FMStepTotal / 5
    g_Steps = FMStepTotal /10
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
    UpdateClient(TASK_MSG, "find magnet: touching left side", INFO_LEVEL)

    ''move along cradle to one end
    TongMove DIRECTION_CAVITY_HEAD, CRADLE_WIDTH + SAFE_BUFFER_FOR_DETACH, False
    ''move grapper in line with cradle
    TongMove DIRECTION_CAVITY_TO_MAGNET, OVERLAP_GRAPPER_CRADLE + SAFE_BUFFER_FOR_DETACH, False
    ''touch it
    SetVerySlowSpeed

    Wait 2
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at findMagnet before touching left side"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    
    ''Try touching left end of cradle
    If Not ForceTouch(DIRECTION_CAVITY_TAIL, CRADLE_WIDTH, True) Then
        TongMove DIRECTION_CAVITY_HEAD, 10, False
        UpdateClient(TASK_MSG, "failed to touch left end", ERROR_LEVEL)
        Exit Function
    Else
    	UpdateClient(TASK_MSG, "Touched left end OK", INFO_LEVEL)
    EndIf
    
    FMLeftX = CX(Here)
    FMLeftY = CY(Here)
    
    ''try to touch the other end
    g_CurrentSteps = FMStepStart + FMStepTotal /2
    g_Steps = FMStepTotal /10
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
    
	UpdateClient(TASK_MSG, "find magnet: touching right side", INFO_LEVEL)
	
    SetFastSpeed
    TongMove DIRECTION_CAVITY_HEAD, SAFE_BUFFER_FOR_DETACH, False
    TongMove DIRECTION_MAGNET_TO_CAVITY, OVERLAP_GRAPPER_CRADLE + SAFE_BUFFER_FOR_DETACH, False
    TongMove DIRECTION_CAVITY_TAIL, CRADLE_WIDTH + GRIPPER_WIDTH + 2 * SAFE_BUFFER_FOR_DETACH, False
    TongMove DIRECTION_CAVITY_TO_MAGNET, OVERLAP_GRAPPER_CRADLE + SAFE_BUFFER_FOR_DETACH, False
    SetVerySlowSpeed

    ''touch it
    Wait 2
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at findMagnet before touching right side"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    If Not ForceTouch(DIRECTION_CAVITY_HEAD, CRADLE_WIDTH, True) Then
        TongMove DIRECTION_CAVITY_TAIL, 10, False
        UpdateClient(TASK_MSG, "failed to touch right end", ERROR_LEVEL)
        Exit Function
    Else
    	UpdateClient(TASK_MSG, "Touched right end OK", INFO_LEVEL)
    EndIf
    FMRightX = CX(Here)
    FMRightY = CY(Here)
    FMDX = FMLeftX - FMRightX
    FMDY = FMLeftY - FMRightY
    FMDistance = Sqr(FMDX * FMDX + FMDY * FMDY)
    
    ''move to center of cradle
    g_CurrentSteps = FMStepStart + 3 * FMStepTotal / 5
    g_Steps = FMStepTotal /5
    msg$ = Str$(g_CurrentSteps)
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
    
    UpdateClient(TASK_MSG, "find magnet: pull out Z", INFO_LEVEL)
    
    SetFastSpeed
    TongMove DIRECTION_CAVITY_TAIL, SAFE_BUFFER_FOR_DETACH, False
    TongMove DIRECTION_MAGNET_TO_CAVITY, OVERLAP_GRAPPER_CRADLE + SAFE_BUFFER_FOR_DETACH, False
    TongMove DIRECTION_CAVITY_HEAD, FMDistance / 2 + SAFE_BUFFER_FOR_DETACH, False
    Move Here +Z(FIND_MAGNET_Z_DOWN + 1)
    SetVerySlowSpeed

    ''pull up until force disappear
    Wait 2
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at findMagnet before pulling out"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
	UpdateClient(TASK_MSG, "Pull up until force disappear", INFO_LEVEL)
    If Not PullOutZ Then
    	UpdateClient(TASK_MSG, "Pull up failed", ERROR_LEVEL)
        Exit Function
    Else
    	UpdateClient(TASK_MSG, "Pull up Z OK", INFO_LEVEL)
    EndIf
    
    FMFinalX = (FMLeftX + FMRightX) /2
    FMFinalY = (FMLeftY + FMRightY) /2
    Move Here :X(FMFinalX) :Y(FMFinalY)
    SetVerySlowSpeed
    
    ''try to find Z by touching out the top edge of cradle holder.
    g_CurrentSteps = FMStepStart + 4 * FMStepTotal / 5
    g_Steps = FMStepTotal /10
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
    UpdateClient(TASK_MSG, "find magnet: touching top", INFO_LEVEL)
    Wait 2
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at findMagnet before touching top"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    Wait 20
    If Not ForceTouch(-FORCE_ZFORCE, 10, True) Then
        TongMove DIRECTION_MAGNET_TO_CAVITY, 20, False
        UpdateClient(TASK_MSG, "Failed to Z touch the cradle", ERROR_LEVEL)
        Exit Function
    Else
    	UpdateClient(TASK_MSG, "Z touch the cradle OK", ERROR_LEVEL)
    EndIf
    
    FMFinalZ = CZ(Here)
    FMFinalU = CU(Here)
    
    ''adjust and move to P6
    g_CurrentSteps = FMStepStart + 9 * FMStepTotal / 10
    g_Steps = FMStepTotal /10
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
    
    UpdateClient(TASK_MSG, "find magnet: found it, move in", INFO_LEVEL)
    SetFastSpeed
    Move Here +Z(SAFE_BUFFER_FOR_DETACH)
    TongMove DIRECTION_MAGNET_TO_CAVITY, OVERLAP_GRAPPER_CRADLE + SAFE_BUFFER_FOR_DETACH, False
    TongMove DIRECTION_CAVITY_TAIL, Y_FROM_CRADLE_TO_MAGNET, False
    Move Here +Z(Z_FROM_CRADLE_TO_MAGNET - SAFE_BUFFER_FOR_DETACH)
    
    If Not Open_Gripper Then
        g_RunResult$ = "After find magnet, Open_Gripper Failed"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    
    ''move in
    TongMove DIRECTION_CAVITY_TO_MAGNET, OVERLAP_GRAPPER_CRADLE + SAFE_BUFFER_FOR_DETACH, False
    
    ''give a little bit of safety buffer in Z,
    ''we will easily touch bottom in post calibration
    Move Here +Z(0.5)
    
    If Not CheckMagnet Then
		Exit Function
    EndIf
    
    
    If g_FlagAbort Then
        TongMove DIRECTION_MAGNET_TO_CAVITY, OVERLAP_GRAPPER_CRADLE + SAFE_BUFFER_FOR_DETACH, False
    Else
        FindMagnet = True
    EndIf
Fend

Function FineTuneToolSet As Boolean
	String msg$
	
    FTTStepStart = g_CurrentSteps
    FTTStepTotal = g_Steps

    ''log file
    g_FCntToolFine = g_FCntToolFine + 1
    WOpen "ToolsetFine" + Str$(g_FCntToolFine) + ".Txt" As #LOG_FILE_NO
    Print #LOG_FILE_NO, "======================================================="
    Print #LOG_FILE_NO, "toolset FineTune ", Date$, " ", Time$

    Tool 0
    
    LimZ g_Jump_LimZ_Magnet

    g_SafeToGoHome = True
    FineTuneToolSet = False

    InitForceConstants
    
    g_OnlyAlongAxis = True

    If Motor = Off Then
        Motor On
    EndIf
    If Power = 1 Then
        Power Low
    EndIf

    ''==================get the magnet=================
    UpdateClient(TASK_MSG, "fine tune toolset: take magnet", INFO_LEVEL)

    SetFastSpeed
    Jump P3
    If Not Open_Gripper Then
        g_RunResult$ = "fine tune ToolSet: Open_Gripper Failed at beginning"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Print #LOG_FILE_NO, g_RunResult$
        Close #LOG_FILE_NO
        Exit Function
    EndIf

    If g_FlagAbort Then
        Print #LOG_FILE_NO, "user abort at home"
        Close #LOG_FILE_NO
        Exit Function
    EndIf

    Move P6

    Move Here +Z(20)

    If Not Close_Gripper Then
        UpdateClient(TASK_MSG, "fine tune toolset: close gripper failed", ERROR_LEVEL)
        Move P6
        If Not Open_Gripper Then
            UpdateClient(TASK_MSG, "open gripper failed at aborting from magnet", ERROR_LEVEL)
            g_RobotStatus = g_RobotStatus Or FLAG_NEED_RESET
            g_RobotStatus = g_RobotStatus Or FLAG_REASON_GRIPPER_JAM
            Print #LOG_FILE_NO, "need reset in tlsetfinetune"
            Close #LOG_FILE_NO
            Motor Off
            Quit All
        EndIf
        Move P3
        LimZ 0
        Jump P1
        Close_Lid
        Jump P0
        MoveTongHome
        Print #LOG_FILE_NO, "aborted: cannot close gripper"
        Close #LOG_FILE_NO
        Exit Function
    EndIf

    g_HoldMagnet = True

    LimZ g_Jump_LimZ_Magnet
    ''====================get absolute position of finger====================
    Tool 2
    ''dest point is the cradle's right holder center.
    ''it is used again in b-c
    tmp_Real = DegToRad(g_Perfect_Cradle_Angle)
    FTTSDestX = CX(Here) + (MAGNET_HEAD_THICKNESS + FINGER_THICKNESS / 2.0) * Cos(tmp_Real)
    FTTSDestY = CY(Here) + (MAGNET_HEAD_THICKNESS + FINGER_THICKNESS / 2.0) * Sin(tmp_Real)
    
    ''standby point is away from cradle with magnet head align with finger
    tmp_Real = DegToRad(g_Perfect_Cradle_Angle + 90)
    tmp_DX = (SAFE_BUFFER_FOR_DETACH + MAGNET_HEAD_RADIUS + HALF_OF_SEAT_THICKNESS) * Cos(tmp_Real)
    tmp_DY = (SAFE_BUFFER_FOR_DETACH + MAGNET_HEAD_RADIUS + HALF_OF_SEAT_THICKNESS) * Sin(tmp_Real)

    tmp_Real2 = DegToRad(g_Perfect_Cradle_Angle + 180.0)
    tmp_DX = tmp_DX + MAGNET_HEAD_THICKNESS /2.0 * Cos(tmp_Real2)
    tmp_DY = tmp_DY + MAGNET_HEAD_THICKNESS /2.0 * Sin(tmp_Real2)

	P51 = XY((FTTSDestX + tmp_DX), (FTTSDestY + tmp_DY), CZ(P6), (g_Perfect_Cradle_Angle + 180.0))
	Hand P51, Hand(P6)

    g_Steps = FTTStepTotal /8
    g_CurrentSteps = FTTStepStart + g_Steps
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
    UpdateClient(TASK_MSG, "fine tune toolset: touching for angle", INFO_LEVEL)
    ''===================== get theta first ========================
    ''this is fine tune, so theta almost there.
    ''we will try to see how much off by touch the dest point
    ''P51 will be standby position
    
    SetFastSpeed
    Tool 2
    Jump P51
    
    Wait TIME_WAIT_BEFORE_RESET
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at fineTuneToolset before theta"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    SetVerySlowSpeed
    Tool 0
    If Not ForceTouch(DIRECTION_CAVITY_TO_MAGNET, (2 * SAFE_BUFFER_FOR_DETACH), True) Then
    	g_RunResult$ = "placer failed to touch dest in theta"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Print #LOG_FILE_NO, "placer failed to touch dest in theta"
        Close #LOG_FILE_NO
        Exit Function
    EndIf
    g_Steps = FTTStepTotal /8
    g_CurrentSteps = FTTStepStart + 2 * FTTStepTotal / 8
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
    
    FTTSX(1) = CX(Here)
    FTTSY(1) = CY(Here)
    SetFastSpeed
    
    ''get side scale factor for placer
    FTTScaleF1 = ReadForce(DIRECTION_CAVITY_TO_MAGNET)
    TongMove DIRECTION_CAVITY_TO_MAGNET, 1, False
    FTTScaleF2 = ReadForce(DIRECTION_CAVITY_TO_MAGNET)
    g_SideScale_Placer = FTTScaleF2 - FTTScaleF1
    TongMove DIRECTION_MAGNET_TO_CAVITY, 1, False
    Print #LOG_FILE_NO, "sideScale for placer ", g_SideScale_Placer

    ''move picker to the standby position by shift magnet length
    ''detach
    tmp_Real = DegToRad(g_Perfect_Cradle_Angle + 90)
    Move Here +X(SAFE_BUFFER_FOR_DETACH * Cos(tmp_Real)) +Y(SAFE_BUFFER_FOR_DETACH * Sin(tmp_Real))
    ''shift
    tmp_Real = DegToRad(g_Perfect_Cradle_Angle + 180)
    tmp_DX = (MAGNET_LENGTH - MAGNET_HEAD_THICKNESS) * Cos(tmp_Real)
    tmp_DY = (MAGNET_LENGTH - MAGNET_HEAD_THICKNESS) * Sin(tmp_Real)
   	Move Here +X(tmp_DX) +Y(tmp_DY)

    Wait TIME_WAIT_BEFORE_RESET
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at fineTuneToolset during touching for theta"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    SetVerySlowSpeed
    If Not ForceTouch(DIRECTION_CAVITY_TO_MAGNET, (2 * SAFE_BUFFER_FOR_DETACH), True) Then
        g_RunResult$ = "picker failed to touch dest in theta"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Print #LOG_FILE_NO, "picker failed to touch dest in theta"
        Close #LOG_FILE_NO
        Exit Function
    EndIf
    FTTSX(2) = CX(Here)
    FTTSY(2) = CY(Here)
    
    ''get side scale factor for picker
    FTTScaleF1 = ReadForce(DIRECTION_CAVITY_TO_MAGNET)
    TongMove DIRECTION_CAVITY_TO_MAGNET, 1, False
    FTTScaleF2 = ReadForce(DIRECTION_CAVITY_TO_MAGNET)
    g_SideScale_Picker = FTTScaleF2 - FTTScaleF1
    TongMove DIRECTION_MAGNET_TO_CAVITY, 1, False
    Print #LOG_FILE_NO, "sideScale for picker ", g_SideScale_Picker

    SetFastSpeed
    tmp_Real = DegToRad(g_Perfect_Cradle_Angle + 90)
    Move Here +X(SAFE_BUFFER_FOR_DETACH * Cos(tmp_Real)) +Y(SAFE_BUFFER_FOR_DETACH * Sin(tmp_Real))

    ''calculate theta
    ''touch moving direction
    tmp_Real = DegToRad(g_Perfect_Cradle_Angle - 90)
    tmp_Real2 = Cos(tmp_Real)
    tmp_Real3 = Sin(tmp_Real)
    
    FTTSDeltaU = (FTTSX(1) - FTTSX(2)) * tmp_Real2 + (FTTSY(1) - FTTSY(2)) * tmp_Real3
    FTTSDeltaU = FTTSDeltaU /(MAGNET_LENGTH - MAGNET_HEAD_THICKNESS)
	''here is the one easy to understand   
    ''If g_Perfect_Cradle_Angle = 0 Then
	''    FTTSDeltaU = (FTTSY(2) - FTTSY(1)) / (MAGNET_LENGTH - MAGNET_HEAD_THICKNESS)
    ''ElseIf g_Perfect_Cradle_Angle = 90 Then
	''    FTTSDeltaU = (FTTSX(1) - FTTSX(2)) / (MAGNET_LENGTH - MAGNET_HEAD_THICKNESS)
    ''ElseIf g_Perfect_Cradle_Angle = 180 Then
	''    FTTSDeltaU = (FTTSY(1) - FTTSY(2)) / (MAGNET_LENGTH - MAGNET_HEAD_THICKNESS)
    ''ElseIf g_Perfect_Cradle_Angle = -90 Then
	''    FTTSDeltaU = (FTTSX(2) - FTTSX(1)) / (MAGNET_LENGTH - MAGNET_HEAD_THICKNESS)
    ''Else
    ''    g_RunResult$ = "Cradle must be along one of axes"
    ''    SPELCom_Event TASK_MSG, g_RunResult$
    ''    SPELCom_Event EVTNO_HARDWARE_LOG_SEVERE, g_RunResult$
    ''    Print g_RunResult$
    ''    Print #LOG_FILE_NO, g_RunResult$
    ''    Close #LOG_FILE_NO
    ''    Quit All
    ''EndIf
    
    FTTSDeltaU = Atan(FTTSDeltaU)
    FTTSAdjust = Cos(FTTSDeltaU)
    FTTSDeltaU = RadToDeg(FTTSDeltaU)
    
    msg$ = "theta off: " + Str$(FTTSDeltaU) + " degree"
    UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
    
    FTTSTheta = g_Perfect_Cradle_Angle - FTTSDeltaU  ''now theta is the magnet angle
    
    FTTSTheta = FTTSTheta - CU(Here)
    ''adjust global variable
    msg$ = "Old g_MagnetTransportAngle =" + Str$(g_MagnetTransportAngle)
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    Print #LOG_FILE_NO, "Old g_MagnetTransportAngle =", g_MagnetTransportAngle
    g_MagnetTransportAngle = FTTSTheta + g_U4MagnetHolder
    g_MagnetTransportAngle = NarrowAngle(g_MagnetTransportAngle)
    msg$ = "new g_MagnetTransportAngle=" + Str$(g_MagnetTransportAngle)
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    Print #LOG_FILE_NO, "new g_MagnetTransportAngle=", g_MagnetTransportAngle
    
    ''================get b, c====================
    UpdateClient(TASK_MSG, "fine tune toolset: touching for b-c", INFO_LEVEL)

    tmp_Real = DegToRad(g_Perfect_Cradle_Angle + 90)
    tmp_DX = (SAFE_BUFFER_FOR_DETACH + HALF_OF_SEAT_THICKNESS) * Cos(tmp_Real)
    tmp_DY = (SAFE_BUFFER_FOR_DETACH + HALF_OF_SEAT_THICKNESS) * Sin(tmp_Real)

	P51 = XY((FTTSDestX + tmp_DX), (FTTSDestY + tmp_DY), CZ(P6), (g_Perfect_Cradle_Angle - 90.0 + FTTSDeltaU))
	Hand P51, Hand(P6)

    For FTTSIndex = 1 To 2
        g_Steps = FTTStepTotal /8
        g_CurrentSteps = FTTStepStart + (2 + FTTSIndex) * FTTStepTotal / 8
        msg$ = Str$(g_CurrentSteps) + " of 100"
		UpdateClient(TASK_PROG, msg$, INFO_LEVEL)

        Tool FTTSIndex
        Jump P51
        Tool 0

        Wait TIME_WAIT_BEFORE_RESET * 2
		If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
			g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
			g_RunResult$ = "force sensor reset failed at fineTuneToolset during touching for b c"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf
        SetVerySlowSpeed
        Select FTTSIndex
            Case 1
            	If Not ForceTouch(DIRECTION_CAVITY_HEAD, (SAFE_BUFFER_FOR_DETACH * 2), True) Then
                    msg$ = "tool[" + Str$(FTTSIndex) + "] failed to touch dest"
                    UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
                    Print #LOG_FILE_NO, "tool[", FTTSIndex, "] failed to touch dest"
                    Close #LOG_FILE_NO
                    Exit Function
                EndIf
		        FTTSX(FTTSIndex) = CX(Here)
		        FTTSY(FTTSIndex) = CY(Here)
                FTTScaleF1 = ReadForce(DIRECTION_CAVITY_HEAD)
                TongMove DIRECTION_CAVITY_HEAD, 1, False
                FTTScaleF2 = ReadForce(DIRECTION_CAVITY_HEAD)
                g_TQScale_Picker = FTTScaleF2 - FTTScaleF1
            Case 2
            	If Not ForceTouch(DIRECTION_CAVITY_TAIL, (SAFE_BUFFER_FOR_DETACH * 2), True) Then
            		msg$ = "tool[" + Str$(FTTSIndex) + "] failed to touch dest"
            		UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
                    Print #LOG_FILE_NO, "tool[", FTTSIndex, "] failed to touch dest"
                    Close #LOG_FILE_NO
                    Exit Function
                EndIf
		        FTTSX(FTTSIndex) = CX(Here)
		        FTTSY(FTTSIndex) = CY(Here)
                FTTScaleF1 = ReadForce(DIRECTION_CAVITY_TAIL)
                TongMove DIRECTION_CAVITY_TAIL, 1, False
                FTTScaleF2 = ReadForce(DIRECTION_CAVITY_TAIL)
                g_TQScale_Placer = FTTScaleF2 - FTTScaleF1
        Send
        Tool FTTSIndex
        SetFastSpeed
        Move P51
    Next
    ''touch moving direction
    tmp_Real = DegToRad(g_Perfect_Cradle_Angle - 90)
    tmp_Real2 = Cos(tmp_Real)
    tmp_Real3 = Sin(tmp_Real)
    FTTSBMC = (FTTSX(2) - FTTSX(1)) * tmp_Real2 + (FTTSY(2) - FTTSY(1)) * tmp_Real3
    ''easy to understand
    ''If g_Perfect_Cradle_Angle = 0 Then
	''    FTTSBMC = FTTSY(1) - FTTSY(2)
    ''ElseIf g_Perfect_Cradle_Angle = 90 Then
	''    FTTSBMC = FTTSX(2) - FTTSX(1)
    ''ElseIf g_Perfect_Cradle_Angle = 180 Then
	''    FTTSBMC = FTTSY(2) - FTTSY(1)
    ''ElseIf g_Perfect_Cradle_Angle = -90 Then
	''    FTTSBMC = FTTSX(1) - FTTSX(2)
    ''Else
    ''    g_RunResult$ = "Cradle must be along one of axes"
    ''    SPELCom_Event TASK_MSG, g_RunResult$
    ''    SPELCom_Event EVTNO_HARDWARE_LOG_SEVERE, g_RunResult$
    ''    Print g_RunResult$
    ''    Print #LOG_FILE_NO, g_RunResult$
    ''    Close #LOG_FILE_NO
    ''    Quit All
    ''EndIf
    
    FTTSB = (MAGNET_LENGTH + FTTSBMC) /2.0
    FTTSC = (MAGNET_LENGTH - FTTSBMC) /2.0
    
    ''================try to find a===============================
    g_Steps = FTTStepTotal /8
    g_CurrentSteps = FTTStepStart + 5 * g_Steps
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
    UpdateClient(TASK_MSG, "fine tune toolset: touching for a", INFO_LEVEL)

    Tool 0
    ''we use improved b, c, and theta with old a to get better toolset first
    If g_ToolSet_A <> 0 Then
        ABCThetaToToolSets g_ToolSet_A, FTTSB, FTTSC, FTTSTheta
    EndIf
    
    ''we will rotate 180 and put magback into cradle
    SetFastSpeed
    Jump P6 +Z(20)
    Wait TIME_WAIT_BEFORE_RESET
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at fineTuneToolset before touching for a"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    Move P6 +Z(2)    ''the 2mm here is because both cradle and the magnet hold by tong may not level
    FTTSZ = CZ(Here)
    
    SetVerySlowSpeed
    If Not ForceTouch(DIRECTION_MAGNET_TO_CAVITY, 2, True) Then
        g_RunResult$ = "failed to touch in cradle for a in P6"
        UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
        Print #LOG_FILE_NO, "failed to touch in cradle for a in P6"
        Close #LOG_FILE_NO
        Exit Function
    EndIf
    FTTSX(1) = CX(Here)
    FTTSY(1) = CY(Here)

    g_Steps = FTTStepTotal /8
    g_CurrentSteps = FTTStepStart + 6 * g_Steps
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
    ''you can calculate the position, but with toolset, you can easily let robot do that for you:
    ''you just want picker and placer switch places.
    SetFastSpeed
    Move P6 +Z(2)
    Tool 1
    P51 = Here
    Tool 2
    Jump P51 +Z(18)

    Wait TIME_WAIT_BEFORE_RESET
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at fineTuneToolset during touching for a"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    Tool 0
    Move Here :Z(FTTSZ)
    CutMiddle FORCE_XTORQUE
    
    SetVerySlowSpeed
    If Not ForceTouch(DIRECTION_CAVITY_TO_MAGNET, 2, True) Then
        msg$ = "failed to touch in cradle for a in P51"
        UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
        Print #LOG_FILE_NO, "failed to touch in cradle for a in P51"
        Close #LOG_FILE_NO
        Exit Function
    EndIf
    
    FTTSX(2) = CX(Here)
    FTTSY(2) = CY(Here)
        
	tmp_Real2 = FTTSX(2) - FTTSX(1)
	tmp_Real3 = FTTSY(2) - FTTSY(1)
	tmp_Real = tmp_Real2 * tmp_Real2 + tmp_Real3 * tmp_Real3 - FTTSBMC * FTTSBMC
	If tmp_Real < 0 Then
        msg$ = "square of A less then 0 " + Str$(tmp_Real)
        UpdateClient(TASK_MSG, msg$, WARNING_LEVEL)
        Print #LOG_FILE_NO, "square of A less then 0 ", tmp_Real
        tmp_Real = 0
	EndIf
	tmp_Real = Sqr(tmp_Real) / 2.0
	
    tmp_Real2 = Cos(DegToRad(g_MagnetTransportAngle))
    tmp_Real3 = Sin(DegToRad(g_MagnetTransportAngle))
	FTTSA = ((FTTSX(2) - FTTSX(1)) * tmp_Real3 - (FTTSY(2) - FTTSY(1)) * tmp_Real2) / 2.0
    ''double check
    If Abs(FTTSA * FTTSA - tmp_Real * tmp_Real) > 0.001 Then
        msg$ = "A not match: from square: " + Str$(tmp_Real) + ", from individual case: " + Str$(FTTSA)
        UpdateClient(TASK_MSG, msg$, WARNING_LEVEL)
        Print #LOG_FILE_NO, "A not match: from square: ", tmp_Real, ", from individual case: ", FTTSA
    EndIf

    msg$ = "new a:" + Str$(FTTSA) + ", b:" + Str$(FTTSB) + ", c:" + Str$(FTTSC) + ", theta:" + Str$(FTTSTheta)
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    msg$ = "old a:" + Str$(g_ToolSet_A) + ", b:" + Str$(g_ToolSet_B) + ", c:" + Str$(g_ToolSet_C) + ", theta:" + Str$(g_ToolSet_Theta)
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)

    Print #LOG_FILE_NO, "new a:", FTTSA, ", b:", FTTSB, ", c:", FTTSC, ", theta:", FTTSTheta
    Print #LOG_FILE_NO, "old a:", g_ToolSet_A, ", b:", g_ToolSet_B, ", c:", g_ToolSet_C, ", theta:", g_ToolSet_Theta

	''give warning if changes are too big to be true.
	If g_ToolSet_A <> 0 And g_ToolSet_B <> 0 And g_ToolSet_C <> 0 Then
		If Abs(g_ToolSet_A - FTTSA) > 2 Then
			msg$ = "Toolset A changes too big to be true"
			UpdateClient(TASK_MSG, msg$, WARNING_LEVEL)
			Print #LOG_FILE_NO, "Toolset A changes too big to be true"
		EndIf
		If Abs(g_ToolSet_B - FTTSB) > 2 Then
			msg$ = "Toolset B changes too big to be true"
			UpdateClient(TASK_MSG, msg$, WARNING_LEVEL)
			Print #LOG_FILE_NO, "Toolset B changes too big to be true"
		EndIf
		If Abs(g_ToolSet_C - FTTSC) > 2 Then
			msg$ = "Toolset C changes too big to be true"
			UpdateClient(TASK_MSG, msg$, WARNING_LEVEL)
			Print #LOG_FILE_NO, "Toolset C changes too big to be true"
		EndIf
		If Abs(NarrowAngle(g_ToolSet_Theta - FTTSTheta)) > 10 Then
			msg$ = "Toolset Theta changes too big to be true"
			UpdateClient(TASK_MSG, msg$, WARNING_LEVEL)
			Print #LOG_FILE_NO, "Toolset Theta changes too big to be true"
		EndIf
	EndIf

    g_ToolSet_A = FTTSA
    g_ToolSet_B = FTTSB
    g_ToolSet_C = FTTSC
    g_ToolSet_Theta = FTTSTheta
    msg$ = "New Toolset A:" + Str$(g_ToolSet_A) + ", B:" + Str$(g_ToolSet_B) + ", C:" + Str$(g_ToolSet_C) + ", Theta:" + Str$(g_ToolSet_Theta)
	UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    ''========================== calculate ========================
    ABCThetaToToolSets FTTSA, FTTSB, FTTSC, FTTSTheta
    
    ''======================putback magnet=======================
    g_Steps = FTTStepTotal /8
    g_CurrentSteps = FTTStepStart + 7 * g_Steps
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
    UpdateClient(TASK_MSG, "fine tune toolset: Touching Z for Toolset 2", INFO_LEVEL)

    Tool 0
    SetFastSpeed
    Jump P6

    ''save absolute position of magnet so we can decide whether deware moved or tong bended
    If (GTCheckPoint(56)) Then
    	msg$ = "old (absolute magnet position) P56," + Str$(CX(P56)) + "," + Str$(CY(P56)) + "," + Str$(CZ(P56)) + "," + Str$(CU(P56))
	    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    	Print #LOG_FILE_NO, "old (absolute magnet position) P56,", CX(P56), ",", CY(P56), ",", CZ(P56), ",", CU(P56)
    EndIf
    
    Tool 1
    P56 = Here
    msg$ = "new P56," + Str$(CX(P56)) + "," + Str$(CY(P56)) + "," + Str$(CZ(P56)) + "," + Str$(CU(P56)) + " " + Date$ + " " + Time$
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    Print #LOG_FILE_NO, "new P56,", CX(P56), ",", CY(P56), ",", CZ(P56), ",", CU(P56), " ", Date$, " ", Time$

    ''==============================Z offset for placer==========================
    ''get the center of cradle to touch Z
    Tool 2
    P51 = Here + P56
    P51 = XY((CX(P51) / 2), (CY(P51) / 2), (CZ(P51) / 2), (CU(P51) / 2))
    ''move out 3 mm to give more space to the fingers.
    tmp_Real = DegToRad(g_Perfect_Cradle_Angle + 90)
    tmp_DX = 3 * Cos(tmp_Real)
    tmp_DY = 3 * Sin(tmp_Real)
    P51 = P51 +X(tmp_DX) +Y(tmp_DY)
    Hand P51, Hand(P6)
    
    ''touch using picker
    Tool 1
    SetFastSpeed
    CU(P51) = CU(P6) - 60
    Jump P51
    Tool 0
    Wait TIME_WAIT_BEFORE_RESET
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at fineTuneToolset before touching picker Z"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    SetVerySlowSpeed
    If Not ForceTouch(-FORCE_ZFORCE, 20, True) Then
        UpdateClient(TASK_MSG, "failed to touch cradle for Z by picker", ERROR_LEVEL)
        Close #LOG_FILE_NO
        Exit Function
    EndIf
    FTTSZ = CZ(Here) ''save picker's Z
    msg$ = "picker touched cradle at Z=" + Str$(CZ(Here))
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    
    If Not CheckRigidness Then
        UpdateClient(TASK_MSG, "Gripper finger loose at picker side", ERROR_LEVEL)
        Print #LOG_FILE_NO, "Gripper finger loose at picker side"
        Close #LOG_FILE_NO
        Exit Function
    EndIf
    
    Tool 2
    SetFastSpeed
    CU(P51) = CU(P6) + 240
    Jump P51
    Tool 0
    Wait TIME_WAIT_BEFORE_RESET
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at fineTuneToolset before touching placer Z"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    SetVerySlowSpeed
    If Not ForceTouch(-FORCE_ZFORCE, 20, True) Then
        UpdateClient(TASK_MSG, "failed to touch cradle for Z by placer", ERROR_LEVEL)
        Print #LOG_FILE_NO, "failed to touch cradle for Z by placer"
        Close #LOG_FILE_NO
        Exit Function
    EndIf
    msg$ = "placer touched cradle at Z=" + Str$(CZ(Here))
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    FTTSZ = FTTSZ - CZ(Here)

    If Not CheckRigidness Then
        UpdateClient(TASK_MSG, "Gripper finger loose at place side", ERROR_LEVEL)
        Print #LOG_FILE_NO, "Gripper finger loose at placer side"
        Close #LOG_FILE_NO
        Exit Function
    EndIf

    SetFastSpeed
    Jump P6

    ''save Zoffset for placer toolset    
    P51 = TLSet(2)
    TLSet 2, P51 :Z(FTTSZ)

    ''print out old toolset
    P51 = TLSet(1)
    msg$ = "New TLSet 1: (" + Str$(CX(P51)) + "," + Str$(CY(P51)) + "," + Str$(CZ(P51)) + "," + Str$(CU(P51)) + ")"
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    P51 = TLSet(2)
    msg$ = "New TLSet 2: (" + Str$(CX(P51)) + "," + Str$(CY(P51)) + "," + Str$(CZ(P51)) + "," + Str$(CU(P51)) + ")"
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)

#ifdef AUTO_SAVE_POINT
    UpdateClient(TASK_MSG, "saving points to file.....", INFO_LEVEL)
    SavePoints "robot1.pts"
    SaveToolSetHistory 1, g_FCntToolFine
    SaveToolSetHistory 2, g_FCntToolFine
    SavePointHistory 10, g_FCntToolFine
    SavePointHistory 11, g_FCntToolFine
    SavePointHistory 56, g_FCntToolFine
    UpdateClient(TASK_MSG, "done!!", INFO_LEVEL)
    msg$ = "new P56: (" + Str$(CX(P56)) + ", " + Str$(CY(P56)) + ", " + Str$(CZ(P56)) + ", " + Str$(CU(P56)) + ")"
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
#endif

    If Not Open_Gripper Then
        g_RunResult$ = "fine tune toolset: Open_Gripper Failed, holding magnet, need Reset"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Print #LOG_FILE_NO, g_RunResult$
        Close #LOG_FILE_NO
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_RESET
        g_RobotStatus = g_RobotStatus Or FLAG_REASON_GRIPPER_JAM
        Motor Off
        Quit All
    EndIf

    Move P3
    g_HoldMagnet = False

    ''check magnet level error
    MagLevelError = Abs(FTTSZ)
    Print #LOG_FILE_NO, "magnet level error: ", MagLevelError, "mm"
    msg$ = "level errors: magnet " + Str$(MagLevelError) + "mm, post " + Str$(PostLevelError) + "mm"
    UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
    If MagLevelError >= ACCPT_THRHLD_MAGNET_LEVEL Then
        msg$ = "Warning: magnet level error exceeded threshold (" + Str$(ACCPT_THRHLD_MAGNET_LEVEL) + "mm)"
        UpdateClient(TASK_MSG, msg$, WARNING_LEVEL)
        Print #LOG_FILE_NO, "Warning: magnet level error exceeded threshold (", ACCPT_THRHLD_MAGNET_LEVEL, "mm)"
    EndIf
    
    Close_Gripper

    Close #LOG_FILE_NO
    
    LimZ 0
    
    FineTuneToolSet = True
Fend

Function RunABCTheta
    WOpen "ABCTheta.Txt" As #LOG_FILE_NO
    Print #LOG_FILE_NO, "======================================================="
    
    ABCThetaToToolSets g_ToolSet_A, g_ToolSet_B, g_ToolSet_C, g_ToolSet_Theta
    Close #LOG_FILE_NO
    
Fend
Function SetupTSForMagnetCal
	If GTCheckTool(1) And GTCheckTool(2) Then
		P51 = TLSet(1)
		P52 = TLSet(2)
		TLSet 3, XY(((CX(P51) + CX(P52)) / 2), ((CY(P51) + CY(P52)) / 2), ((CZ(P51) + CZ(P52)) / 2), CU(P51))
	Else
		TLSet 3, XY(-2, -15.75, 0, (g_MagnetTransportAngle - g_U4MagnetHolder))
	EndIf
Fend

Function DiffPickerPlacer As Real
	String msg$
	
    InitForceConstants
    
    Init_Magnet_Constants

    g_HoldMagnet = True
    g_SafeToGoHome = True

    DiffPickerPlacer = 0.0

    If Motor = Off Then
        Motor On
    EndIf
    If Power = 1 Then
        Power Low
    EndIf
    
    Wait 2 * TIME_WAIT_BEFORE_RESET
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at DiffPickerPlacer"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf

    ''touch using picker
    If Not g_FlagAbort Then
        Tool 1
        P51 = Here
        Tool 0
        SetVerySlowSpeed
        If Not ForceTouch(-FORCE_ZFORCE, 20, True) Then
        	UpdateClient(TASK_MSG, "failed to touch a bottom in 20 mm", ERROR_LEVEL)
            Exit Function
        EndIf
        DPPPickerZ = CZ(Here)
        SetFastSpeed
        Move Here +Z(5)
        msg$ = "picker touched at " + Str$(DPPPickerZ)
        UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    EndIf

    ''touch using placer
    Wait 2 * TIME_WAIT_BEFORE_RESET
    ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY)
    If Not g_FlagAbort Then
        Tool 2
        Go P51
        Tool 0
        SetVerySlowSpeed
        If Not ForceTouch(-FORCE_ZFORCE, 20, True) Then
        	UpdateClient(TASK_MSG, "failed to touch a bottom in 20 mm", ERROR_LEVEL)
            Exit Function
        EndIf
        DPPPlacerZ = CZ(Here)
        SetFastSpeed
        Move Here +Z(5)
        msg$ = "placer touched at " + Str$(DPPPlacerZ)
        UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    EndIf
    
    ''calculate
    DiffPickerPlacer = DPPPickerZ - DPPPlacerZ
    If DiffPickerPlacer < 0 Then
    	msg$ = "Picker is higher than Placer by " + Str$(-DiffPickerPlacer) + "mm"
    	UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    Else
    	msg$ = "Picker is lower than Placer by " + Str$(DiffPickerPlacer) + "mm"
	   	UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    EndIf

    P52 = TLSet(2)
    msg$ = "old Z for Toolset 2: " + Str$(CZ(P52))
    UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)

    ''go back to original place
    If Not g_FlagAbort Then
        Tool 1
        Go P51
        Tool 0
    EndIf
    Motor Off
Fend
Function VB_MagnetCal
    ''init result
    g_RunResult$ = ""
    
    ''parse argument from global
    ParseStr g_RunArgs$, VBMCTokens$(), " "
    ''check argument
    VBMCArgC = UBound(VBMCTokens$) + 1

    If VBMCArgC > 0 Then
        Select VBMCTokens$(0)
        Case "0"
               g_IncludeFindMagnet = False
        Case "1"
               g_IncludeFindMagnet = True
        Send
    EndIf
    If VBMCArgC > 1 Then
        Select VBMCTokens$(1)
        Case "0"
            g_Quick = False
        Case "1"
            g_Quick = True
        Send
    EndIf
    
    If Motor = Off Then
        Motor On
    EndIf
    If Power = 1 Then
        Power Low
    EndIf

    If Not MagnetCalibration() Then
        If g_FlagAbort Then
            g_RunResult$ = "User Abort"
        EndIf
        Recovery
        ''SPELCom_Return 1
    EndIf
    ''SPELCom_Return 0
Fend

Function StripCalibration As Boolean
	String msg$
    CPCStepStart = g_CurrentSteps
    CPCStepTotal = g_Steps

    ''prevent sub functions to update progress bar
    g_Steps = 0

	StripCalibration = False

    InitForceConstants
    
    g_OnlyAlongAxis = True
    g_SafeToGoHome = True

    ''log file
    g_FCntStrip = g_FCntStrip + 1
    WOpen "StripPosition" + Str$(g_FCntStrip) + ".Txt" As #LOG_FILE_NO
    Print #LOG_FILE_NO, "strip position calibration at ", Date$, " ", Time$
    Print "strip position calibration at ", Date$, " ", Time$


    ''safety check
    Tool 0
    If Not isCloseToPoint(3) Then
        Print "FAILED: It must start from P3 position"
        Print #LOG_FILE_NO, "FAILED: It must start from P3 position"
        Close #LOG_FILE_NO
        Exit Function
    EndIf
    
    g_HoldMagnet = False
    ''take magnet
    ''==================get the magnet=================
    UpdateClient(TASK_MSG, "strip cal: take magnet", INFO_LEVEL)

    SetFastSpeed
    Go P3
    If Not Open_Gripper Then
        g_RunResult$ = "strip cal: Open_Gripper Failed at beginning"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Print #LOG_FILE_NO, g_RunResult$
        Close #LOG_FILE_NO
        Exit Function
    EndIf

    If g_FlagAbort Then
        Print #LOG_FILE_NO, "user abort at home"
        Close #LOG_FILE_NO
        Exit Function
    EndIf

    Move P6

    Move Here +Z(20)

    If Not Close_Gripper Then
        UpdateClient(TASK_MSG, "strip cal: abort: close gripper failed at magnet", ERROR_LEVEL)
        Move P6
        If Not Open_Gripper Then
            msg$ = "open gripper failed at aborting from magnet"
            UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
            g_RobotStatus = g_RobotStatus Or FLAG_NEED_RESET
            g_RobotStatus = g_RobotStatus Or FLAG_REASON_GRIPPER_JAM
            Print #LOG_FILE_NO, "need reset in tlsetfinetune"
            Close #LOG_FILE_NO
            Motor Off
            Quit All
        EndIf
        Move P3
        LimZ 0
        Jump P1
        Close_Lid
        Jump P0
        MoveTongHome
        Print #LOG_FILE_NO, "aborted: cannot close gripper"
        Close #LOG_FILE_NO
        Exit Function
    EndIf

    g_HoldMagnet = True

    LimZ g_Jump_LimZ_Magnet
    
    g_CurrentSteps = CPCStepStart + CPCStepTotal /5
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)

	''==================calculate the position first===============
	''move away from cradle STRIP_PLACER_X_OFFSET
	''shift to left STRIP_PLACER_Y_OFFSET
	tmp_Real = DegToRad(g_Perfect_Cradle_Angle + 90)
	tmp_DX = STRIP_PLACER_X_OFFSET * Cos(tmp_Real)
	tmp_DY = STRIP_PLACER_X_OFFSET * Sin(tmp_Real)

	tmp_Real2 = DegToRad(g_Perfect_Cradle_Angle)
	tmp_DX = tmp_DX + STRIP_PLACER_Y_OFFSET * Cos(tmp_Real2)
	tmp_DY = tmp_DY + STRIP_PLACER_Y_OFFSET * Sin(tmp_Real2)
	Tool 2
	''here 20 is from we moved tong to P6+20
	P8 = Here +X(tmp_DX) +Y(tmp_DY) -Z(STRIP_PLACER_Z_OFFSET + 20) +U(90)
	''P80 is standby point, away 10 mm
	tmp_DX = STANDBY_DISTANCE * Cos(tmp_Real)
	tmp_DY = STANDBY_DISTANCE * Sin(tmp_Real)
	P80 = P8 +X(tmp_DX) +Y(tmp_DY) +Z(STRIP_PLACER_LIFT_Z)

	''=================== calibration============================
	''touch out X first,
	''then try to moving and touch out Z
	''Y: we may touch out or we just use the calculation
	''U: we will use the calculation

	''touching X
	Jump P80
    Wait 2 * TIME_WAIT_BEFORE_RESET
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at StripCalibration"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    If Not g_FlagAbort Then
    	UpdateClient(TASK_MSG, "strip cal: touching for X", INFO_LEVEL)
	    g_SafeToGoHome = False
        SetVerySlowSpeed
        If Not ForceTouch(DIRECTION_CAVITY_TAIL, 14, True) Then
			msg$ = "failed to touch the strip X"
			UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
			Print #LOG_FILE_NO, "failed to touch strip X"
			Close #LOG_FILE_NO
			
			Move P80
		    g_SafeToGoHome = True
			Exit Function
        EndIf
        CPCInitX = CX(Here)
        CPCInitY = CY(Here)
        ''detach
        SetFastSpeed
        TongMove DIRECTION_CAVITY_HEAD, SAFE_BUFFER_FOR_DETACH, False
        Move Here -Z(STRIP_PLACER_LIFT_Z)
        P81 = Here
        CPCInitZ = CZ(Here)
        CPCInitU = CU(Here)
        Print "strip X touched at ", CPCInitX
    EndIf

    g_CurrentSteps = CPCStepStart + 2 * CPCStepTotal / 5
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
    
    ''=========touch out Z===========
    ''try to move in first, if failed, scan it
    If Not g_FlagAbort Then
    	UpdateClient(TASK_MSG, "strip cal: touching for Z", INFO_LEVEL)
        If ForceTouch(DIRECTION_CAVITY_TAIL, SAFE_BUFFER_FOR_DETACH + 3, False) Then
			UpdateClient(TASK_MSG, "need to scan Z for strip position", INFO_LEVEL)
			Print #LOG_FILE_NO, "scan Z for strip position"
			Move P81
			Move Here -Z(STRIP_PULL_OUT_Z_RANGE / 2.0)
			Wait 2
			If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
				g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
				g_RunResult$ = "force sensor reset failed at StripCalibration during touch out z"
				UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
				Exit Function
			EndIf
			If Not FindZForStripper Then
				UpdateClient(TASK_MSG, "failed to scan strip Z", ERROR_LEVEL)
				Print #LOG_FILE_NO, "failed to scan strip Z"

				Move P80
				g_SafeToGoHome = True
				Close #LOG_FILE_NO
				Exit Function
			EndIf
        EndIf
		CPCInitZ = CZ(Here)
    EndIf

    g_CurrentSteps = CPCStepStart + 3 * CPCStepTotal / 5
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)

    ''fine tune Z
    If Not g_FlagAbort Then
    	UpdateClient(TASK_MSG, "strip cal: fine tune for Z", INFO_LEVEL)
    	msg$ = "moved in Z=" + Str$(CPCInitZ) + "and fine tune Z"
    	UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
		Print #LOG_FILE_NO, "moved in at Z=", CPCInitZ, "fine tune Z"
		Move Here :X(CPCInitX)
		TongMove DIRECTION_CAVITY_TAIL, MAGNET_HEAD_THICKNESS / 2, False
		''ForcedCutMiddle FORCE_ZFORCE
    	CutMiddleWithArguments FORCE_ZFORCE, 0, GetForceThreshold(FORCE_ZFORCE), 2, 20
    EndIf

    g_CurrentSteps = CPCStepStart + 4 * CPCStepTotal / 5
    msg$ = Str$(g_CurrentSteps) + " of 100"
    UpdateClient(TASK_PROG, msg$, INFO_LEVEL)
    
    ''OK
    If Not g_FlagAbort Then
		TongMove DIRECTION_CAVITY_HEAD, MAGNET_HEAD_THICKNESS / 2, False
		P8 = Here
        SavePoints "robot1.pts"

	    SavePointHistory 8, g_FCntStrip
		StripCalibration = True
		msg$ = "done, new P8=" + StringPoint$(8)
		UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
		Print #LOG_FILE_NO, "moved in at Z=", CPCInitZ, "fine tune Z"

		TongMove DIRECTION_CAVITY_HEAD, SAFE_BUFFER_FOR_DETACH, False
		UpdateClient(TASK_MSG, "strip cal: done", INFO_LEVEL)
    EndIf

    If Not StripCalibration Then
	    If Not g_FlagAbort Then
			Print "Strip Cal failed"
	    Else
			Print "Strip Cal user abort"
	    EndIf
	EndIf

	''put magnet back
	Move P80
    g_SafeToGoHome = True
	Tool 0
	SetFastSpeed
	Jump P6

    If Not Open_Gripper Then
        g_RunResult$ = "Open_Gripper Failed, holding magnet, need Reset"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Print #LOG_FILE_NO, g_RunResult$
        Close #LOG_FILE_NO
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_RESET
        g_RobotStatus = g_RobotStatus Or FLAG_REASON_GRIPPER_JAM
        Motor Off
        Quit All
    EndIf

    Move P3
    g_HoldMagnet = False
	Close #LOG_FILE_NO
Fend

''modified from PullOutZ
Function FindZForStripper As Boolean
	String msg$
	UpdateClient(TASK_MSG, "strip cal: pull out Z", INFO_LEVEL)
    FindZForStripper = False
    
    POZOldX = CX(Here)
    POZOldY = CY(Here)
    POZOldZ = CZ(Here)

	''step size
	stepSize = STRIP_PULL_OUT_Z_RANGE / STRIP_PULL_OUT_Z_STEP

    For StepIndex = 1 To STRIP_PULL_OUT_Z_STEP
        Move Here +Z(stepSize)
        If Not ForceTouch(DIRECTION_CAVITY_TAIL, SAFE_BUFFER_FOR_DETACH + 3, False) Then
            If Not g_FlagAbort Then
                FindZForStripper = True
                msg$ = "got Z at " + Str$(CZ(Here))
                UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
            Else
                TongMove DIRECTION_CAVITY_HEAD, 20, False
            EndIf
            Exit Function
        EndIf
        Move Here :X(POZOldX) :Y(POZOldY)
    Next
    
Fend

Function CheckRigidness As Boolean
	''Raise 1 mm
	''reset force sensor
	''come back
	''pressure for 0.05mm
	''save the force and position then back off
	
	Move Here +Z(1)
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at CheckRigidness"
        ''SPELCom_Return 1
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    
    Move Here -Z(1)
    CKRNF1 = ReadForce(FORCE_ZFORCE)
    
    Move Here -Z(0.05)
    CKRNF2 = ReadForce(FORCE_ZFORCE)
  	Move Here +Z(0.05)
  
  	''calculate the rigidness
  	If Abs(CKRNF2 - CKRNF1) < 1 Then
  		CheckRigidness = False
  	Else
  		CheckRigidness = True
  	EndIf
Fend

Function TestRigid
	String msg$
	Real dimension(4)
	
    InitForceConstants
    
    Init_Magnet_Constants

    g_HoldMagnet = True
    g_SafeToGoHome = True

    If Motor = Off Then
        Motor On
    EndIf
    If Power = 1 Then
        Power Low
    EndIf
    
    Wait 2 * TIME_WAIT_BEFORE_RESET
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at TestRidid"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf

    ''touch using picker
    If Not g_FlagAbort Then
        Tool 1
        P51 = Here
        Tool 0
        SetVerySlowSpeed
        If Not ForceTouch(-FORCE_ZFORCE, 20, True) Then
            UpdateClient(TASK_MSG, "failed to touch a bottom in 20 mm", ERROR_LEVEL)
            Exit Function
        EndIf
        DPPPickerZ = CZ(Here)
        If Not CheckRigidness Then
        	UpdateClient(TASK_MSG, "failed to touch a bottom in 20 mm", WARNING_LEVEL)
        EndIf
        SetFastSpeed
        Move Here +Z(5)
        msg$ = "picker touched at " + Str$(DPPPickerZ)
        UpdateClient(TASK_MSG, msg$, DEBUG_LEVEL)
    EndIf

    ''touch using placer
    Wait 2 * TIME_WAIT_BEFORE_RESET
    If Not ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY) Then
        g_RobotStatus = g_RobotStatus Or FLAG_NEED_CAL_MAGNET
        g_RunResult$ = "force sensor reset failed at testRigid for placer"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    If Not g_FlagAbort Then
        Tool 2
        Go P51
        Tool 0
        SetVerySlowSpeed
        If Not ForceTouch(-FORCE_ZFORCE, 20, True) Then
            Print "failed to touch a bottom in 20 mm"
            Exit Function
        EndIf
        DPPPlacerZ = CZ(Here)
        If Not CheckRigidness Then
        	Print "check rigidness failed"
        EndIf
        SetFastSpeed
        Move Here +Z(5)
        Print "placer touched at ", DPPPlacerZ
    EndIf
    
    ''go back to original place
    If Not g_FlagAbort Then
        Tool 1
        Go P51
        Tool 0
    EndIf
    Motor Off
	
Fend

