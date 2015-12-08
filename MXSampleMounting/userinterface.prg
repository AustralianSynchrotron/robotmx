#include "networkdefs.inc"
#include "genericdefs.inc"
#include "cassettedefs.inc"
#include "superpuckdefs.inc"
#include "reporterdefs.inc"

Function GTProbeCassettes
	Cls
    Print "GTProbeCassettes entered at ", Date$, " ", Time$

	''init result
    g_RunResult$ = ""
    
	String GTProbeCassettesTokens$(0)
	Integer GTProbeCassettesArgC
    
    ParseStr g_RunArgs$, GTProbeCassettesTokens$(), " "
    ''check argument
    GTProbeCassettesArgC = UBound(GTProbeCassettesTokens$) + 1
    If GTProbeCassettesArgC < 1 Or GTProbeCassettesArgC > 2 Then
        g_RunResult$ = "bad format of argument in g_RunArgs$: should be in the format [lmr]{1,3} [0-1]"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf

	If Not GTInitialize Then
		g_RunResult$ = "error GTInitialize failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	If Not GTJumpHomeToCoolingPointAndWait Then
		g_RunResult$ = "GTJumpHomeToCoolingPointAndWait failed"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf

	g_RunResult$ = "progress GTCheckAndPickMagnet: Grabbing Magnet from Cradle"
	If Not GTCheckAndPickMagnet Then
		g_RunResult$ = "GTCheckAndPickMagnet: Grabbing magnet failed"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
    String cassettesString$
    Integer NumCassettesToProbe
    cassettesString$ = LTrim$(GTProbeCassettesTokens$(0))
    cassettesString$ = RTrim$(cassettesString$)
    NumCassettesToProbe = Len(cassettesString$)

    If (NumCassettesToProbe < 1) Or (NumCassettesToProbe > NUM_CASSETTES) Then
        g_RunResult$ = "Bad argument in g_RunArgs$ NumCassettesToProbe is not [1-3]"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf

	Integer cassetteStringIndex
	String OneCassetteChar$
	Integer cassette_position
	For cassetteStringIndex = 1 To NumCassettesToProbe
		OneCassetteChar$ = Mid$(cassettesString$, cassetteStringIndex, 1)
	
		If Not GTgetCassettePosition(OneCassetteChar$, ByRef cassette_position) Then
			g_RunResult$ = "Illegal cassette position in g_RunArgs$:" + OneCassetteChar$
	        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf

		GTResetCassette(cassette_position)

		If GTProbeCassetteType(cassette_position) Then
			If GTProbeCassettesArgC = 2 Then
				If GTProbeCassettesTokens$(1) = "1" Then
					GTProbeAllPorts(cassette_position)
				EndIf
			EndIf
		Else
			'' Instead of exit function, can also be changed to check the next cassette	(Next)
			Exit Function
		EndIf
	Next
	
	'' Return Magnet To Cradle And Go to Home Position
	g_RunResult$ = "progress GTReturnMagnetAndGoHome"
	If Not GTReturnMagnetAndGoHome Then
		g_RunResult$ = "GTReturnMagnetAndGoHome failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	g_RunResult$ = "success GTProbeCassettes"
    Print "GTProbeCassettes finished at ", Date$, " ", Time$
Fend

Function GTProbePucks
    Print "GTProbePucks entered at ", Date$, " ", Time$
	''init result
    g_RunResult$ = ""
    
	String GTProbePucksTokens$(0)
	Integer GTProbePucksArgC
    ParseStr g_RunArgs$, GTProbePucksTokens$(), " "
    ''check argument
    GTProbePucksArgC = UBound(GTProbePucksTokens$) + 1
    If GTProbePucksArgC <> 2 Then
        g_RunResult$ = "bad puck specified in g_RunArgs$"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf

	If Not GTInitialize Then
		g_RunResult$ = "GTInitialize failed"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	If Not GTJumpHomeToCoolingPointAndWait Then
		g_RunResult$ = "GTJumpHomeToCoolingPointAndWait failed"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	If Not GTCheckAndPickMagnet Then
		g_RunResult$ = "GTCheckAndPickMagnet failed"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf

    String cassettesString$
    Integer NumCassettesToProbe
    cassettesString$ = LTrim$(GTProbePucksTokens$(0))
    cassettesString$ = RTrim$(cassettesString$)
    NumCassettesToProbe = Len(cassettesString$)

    If (NumCassettesToProbe <> 1) Then
        g_RunResult$ = "Bad cassette argument in g_RunArgs$"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf

	String OneCassetteChar$
	Integer cassette_position
	OneCassetteChar$ = cassettesString$
	If GTgetCassettePosition(OneCassetteChar$, ByRef cassette_position) Then
		If g_CassetteType(cassette_position) <> SUPERPUCK_CASSETTE Then
			g_RunResult$ = "There is no superpuck adaptor at cassette position in g_RunArgs$:" + OneCassetteChar$
	        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf
	Else
		g_RunResult$ = "Illegal Cassette Position in g_RunArgs$:" + OneCassetteChar$
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf

    String pucksString$
    Integer NumPucksToProbe
    pucksString$ = LTrim$(GTProbePucksTokens$(1))
    pucksString$ = RTrim$(pucksString$)
    NumPucksToProbe = Len(pucksString$)

    If (NumPucksToProbe < 1) Or (NumPucksToProbe > NUM_PUCKS) Then
        g_RunResult$ = "Bad number of pucks to probe in g_RunArgs$"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf

	Integer puckStringIndex
	String OnePuckChar$
	Integer puckIndex
	For puckStringIndex = 1 To NumPucksToProbe
		OnePuckChar$ = Mid$(pucksString$, puckStringIndex, 1)

		If Not GTgetPuckIndex(OnepuckChar$, ByRef puckIndex) Then
			g_RunResult$ = "Illegal PUCK Name in g_RunArgs$:" + OnepuckChar$
            UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf
		
		GTResetPuck(cassette_position, puckIndex)
		GTprobeAllPortsInPuck(cassette_position, puckIndex)
	Next

	'' Return Magnet To Cradle And Go to Home Position
	If Not GTReturnMagnetAndGoHome Then
		g_RunResult$ = "GTReturnMagnetAndGoHome failed"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	g_RunResult$ = "success GTProbePucks"
	Print "GTProbePucks finished at ", Date$, " ", Time$
Fend

Function GTProbeColumns
	Print "GTProbeColumns entered at ", Date$, " ", Time$
	''init result
    g_RunResult$ = ""
    
	String GTProbeColumnsTokens$(0)
	Integer GTProbeColumnsArgC
    ParseStr g_RunArgs$, GTProbeColumnsTokens$(), " "
    ''check argument
    GTProbeColumnsArgC = UBound(GTProbeColumnsTokens$) + 1
    If GTProbeColumnsArgC <> 2 Then
        g_RunResult$ = "Bad columns argument in g_RunArgs$"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf

	If Not GTInitialize Then
		g_RunResult$ = "GTInitialize failed"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	g_RunResult$ = "progress GTJumpHomeToCoolingPointAndWait"
	If Not GTJumpHomeToCoolingPointAndWait Then
		g_RunResult$ = "GTJumpHomeToCoolingPointAndWait failed"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf

	If Not GTCheckAndPickMagnet Then
		g_RunResult$ = "GTCheckAndPickMagnet failed"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf

    String cassettesString$
    Integer NumCassettesToProbe
    cassettesString$ = LTrim$(GTProbeColumnsTokens$(0))
    cassettesString$ = RTrim$(cassettesString$)
    NumCassettesToProbe = Len(cassettesString$)

    If (NumCassettesToProbe <> 1) Then
        g_RunResult$ = "Bad cassette argument in g_RunArgs$"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf

	String OneCassetteChar$
	Integer cassette_position
	OneCassetteChar$ = cassettesString$
	If GTgetCassettePosition(OneCassetteChar$, ByRef cassette_position) Then
		If g_CassetteType(cassette_position) <> CALIBRATION_CASSETTE And g_CassetteType(cassette_position) <> NORMAL_CASSETTE Then
			g_RunResult$ = "There is no calibration or normal cassette at cassette position given in g_RunArgs$:" + OneCassetteChar$
            UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf
	Else
		g_RunResult$ = "Illegal Cassette Position in g_RunArgs$:" + OneCassetteChar$
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf

    String columnsString$
    Integer NumColumnsToProbe
    columnsString$ = LTrim$(GTProbeColumnsTokens$(1))
    columnsString$ = RTrim$(columnsString$)
    NumColumnsToProbe = Len(columnsString$)

    If (NumColumnsToProbe < 1) Or (NumColumnsToProbe > NUM_COLUMNS) Then
        g_RunResult$ = "Bad num columns to probe in g_RunArgs$"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf

	Integer columnStringIndex
	String OneColumnChar$
	Integer columnIndex
	For columnStringIndex = 1 To NumColumnsToProbe
		OneColumnChar$ = Mid$(columnsString$, columnStringIndex, 1)

		If Not GTgetColumnIndex(OneColumnChar$, ByRef columnIndex) Then
			g_RunResult$ = "Illegal column name in g_RunArgs$:" + OneColumnChar$
            UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf
		
		GTResetColumn(cassette_position, columnIndex)
		GTprobeAllPortsInColumn(cassette_position, columnIndex)
	Next

	'' Return Magnet To Cradle And Go to Home Position
	g_RunResult$ = "progress GTReturnMagnetAndGoHome"
	If Not GTReturnMagnetAndGoHome Then
		g_RunResult$ = "GTReturnMagnetAndGoHome: Putting magnet back to cradle and going home failed"
        UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	g_RunResult$ = "success GTProbeColumns"
	Print "GTProbeColumns finished at ", Date$, " ", Time$
Fend

