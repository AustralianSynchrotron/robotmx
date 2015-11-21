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
	
	If g_ReportingLevel < ERROR_LEVEL Then
		Exit Function
	EndIf
	
		If report_type = TASK_FAILURE_REPORT Then
			If g_PrintReports Then
				Print "error " + msg$
			EndIf
			UpdateClient EVTNO_FOREGROUND_ERR, "error " + msg$
		EndIf
	
	If g_ReportingLevel < WARNING_LEVEL Then
		Exit Function
	EndIf
	
		If report_type = TASK_WARNING_REPORT Then
			If g_PrintReports Then
				Print "warning " + msg$
			EndIf
			UpdateClient EVTNO_WARNING, "warning " + msg$
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
			If g_PrintReports Then
				Print "entered " + msg$
			EndIf
			UpdateClient EVTNO_CAL_MSG, "entered " + msg$
		ElseIf report_type = TASK_MESSAGE_REPORT Then
			If g_PrintReports Then
				Print "message " + msg$
			EndIf
			UpdateClient EVTNO_CAL_MSG, "message " + msg$
		EndIf
				
	If g_ReportingLevel < DEBUG_LEVEL Then
		Exit Function
	EndIf
	
		If report_type = TASK_PROGRESS_REPORT Then
			If g_PrintReports Then
				Print "progress " + msg$
			EndIf
			UpdateClient EVTNO_CAL_STEP, "progress " + msg$
		ElseIf report_type = TASK_DONE_REPORT Then
			If g_PrintReports Then
				Print "success " + msg$
			EndIf
			UpdateClient EVTNO_FOREGROUND_DONE, "success " + msg$
		EndIf
Fend

