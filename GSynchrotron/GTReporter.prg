#include "GTReporterdefs.inc"
#include "networkdefs.inc"

Global Integer g_ReportingLevel
Global Integer g_ReportingFunctionLevel
Global Boolean g_PrintReports

'' Wrapper around UpdateClient to filter network messages based on g_ReportingLevel
'' Function level filtering only applies to INFO_LEVEL and DEBUG_LEVEL Reports
Function GTUpdateClient(report_type As Integer, function_level As Integer, msg$ As String)
	g_ReportingLevel = DEBUG_LEVEL ''Should be set from EPICS
	g_ReportingFunctionLevel = LOW_LEVEL_FUNCTION
	g_PrintReports = True
	
	'' We might have to put the Print msg$ inside the filters
	If g_PrintReports Then
		Print msg$
	EndIf
	
	If g_ReportingLevel < ERROR_LEVEL Then
		Exit Function
	EndIf
	
		If report_type = TASK_FAILURE_REPORT Then
			UpdateClient EVTNO_FOREGROUND_ERR, msg$
		EndIf
	
	If g_ReportingLevel < WARNING_LEVEL Then
		Exit Function
	EndIf
	
			If report_type = TASK_WARNING_REPORT Then
				UpdateClient EVTNO_WARNING, msg$
			EndIf
	
	'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
	'' Function level filtering only applies to INFO_LEVEL and DEBUG_LEVEL Reports
	If function_level < g_ReportingFunctionLevel Then
		Exit Function
	EndIf
	'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
	If g_ReportingLevel < INFO_LEVEL Then
		Exit Function
	EndIf
	
			If report_type = TASK_ENTERED_REPORT Then
				UpdateClient EVTNO_CAL_MSG, msg$
			EndIf
				
	If g_ReportingLevel < DEBUG_LEVEL Then
		Exit Function
	EndIf
	
		If report_type = TASK_PROGRESS_REPORT Then
			UpdateClient EVTNO_CAL_STEP, msg$
		ElseIf report_type = TASK_DONE_REPORT Then
			UpdateClient EVTNO_FOREGROUND_DONE, msg$
		EndIf
Fend

