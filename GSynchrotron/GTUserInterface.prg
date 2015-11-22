#include "GTGenericdefs.inc"

Function GTtestCassetteScan()
	''init result
    g_RunResult$ = ""
    
	String GTCassettesProbeTokens$(0)
	Integer GTCassettesProbeArgC
    ParseStr g_RunArgs$, GTCassettesProbeTokens$(), " "
    ''check argument
    GTCassettesProbeArgC = UBound(GTCassettesProbeTokens$) + 1
    If GTCassettesProbeArgC <> 1 Then
        g_RunResult$ = "bad format of argument in g_RunArgs$. should be lmr, l, m or r"
        Exit Function
    EndIf
    
    String cassettesString$
    Integer NumCassettesToProbe
    cassettesString$ = LTrim$(GTCassettesProbeTokens$(0))
    cassettesString$ = RTrim$(cassettesString$)
    NumCassettesToProbe = Len(cassettesString$)

    If (NumCassettesToProbe < 1) Or (NumCassettesToProbe > 3) Then
        g_RunResult$ = "Bad argument in g_RunArgs$, string length is not [1-3]"
        ''SPELCom_Return 1
        Exit Function
    EndIf

	''Remove after defining Gonio point
	P21 = XY(0, 0, 0, 0)
	
	If Not GTInitialize Then
		Exit Function
	EndIf
	
	Integer cassetteStringIndex
	String OneCassette$
	Integer cassette_position
	For cassetteStringIndex = 1 To NumCassettesToProbe
		OneCassette$ = Mid$(cassettesString$, cassetteStringIndex, 1)
		Select OneCassette$
			Case "l"
				cassette_position = LEFT_CASSETTE
				
			Case "m"
				cassette_position = MIDDLE_CASSETTE
				
			Case "r"
				cassette_position = RIGHT_CASSETTE

			Default
	    		''Error in arguments
    		    g_RunResult$ = "Bad argument in g_RunArgs$, g_RunArgs$ can only contain l,m and r"
				Exit Function
		Send
			
		
		If Not GTProbeOneCassette(cassette_position) Then
			Exit Function
		EndIf
		
		GTProbeAllPorts(cassette_position)
		
	Next
Fend

