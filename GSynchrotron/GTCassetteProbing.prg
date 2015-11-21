#include "GTCassettedefs.inc"
#include "GTReporterdefs.inc"

Function GTtestCassetteScan()
	Integer standbyPointNum
	Real scanZdistance, cassetteHeight
	
	g_RunResult$ = "Progress GTtestCassetteScan->GTInitAllPoints"
	GTInitAllPoints
	
	standbyPointNum = 52
	
	Tool 1
	
	g_RunResult$ = "Progress GTtestCassetteScan->GTSetScanCassetteTopStandbyPoint"
	GTSetScanCassetteTopStandbyPoint(LEFT_CASSETTE, standbyPointNum, ByRef scanZdistance)
	
	g_RunResult$ = "Progress GTtestCassetteScan->GTScanCassetteTop"
	If GTScanCassetteTop(standbyPointNum, scanZdistance, ByRef cassetteHeight) Then
		GTUpdateClient(TASK_DONE_REPORT, HIGH_LEVEL_FUNCTION, "GTtestCassetteScan successfully completed. Detected Cassette Height = " + Str$(cassetteHeight))
		g_RunResult$ = "Success GTScanCassetteTop"
	Else
		GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTtestCassetteScan failed: error in GTScanCassetteTop!")
		g_RunResult$ = "Error GTtestCassetteScan"
	EndIf
Fend

