#include "GTReporterdefs.inc"
#include "networkdefs.inc"

'' Filter Masks
Global Byte g_ReportMask
Global Byte g_ReportingFunctionMask
Global Boolean g_PrintReports

Function initGTReporter()
	''This function is only for testing, all the variables below should be set from python layers
	g_ReportMask = TASK_ENTERED_REPORT + TASK_PROGRESS_REPORT + TASK_DONE_REPORT + TASK_WARNING_REPORT + TASK_FAILURE_REPORT + TASK_MESSAGE_REPORT
	g_ReportingFunctionMask = LOW_LEVEL_FUNCTION + MID_LEVEL_FUNCTION + HIGH_LEVEL_FUNCTION
	g_PrintReports = True
Fend

'' Wrapper around UpdateClient to filter network messages based on g_ReportingLevel
'' Function level filtering only applies to INFO_LEVEL and DEBUG_LEVEL Reports
Function GTUpdateClient(report_type As Byte, function_level As Byte, msg$ As String)
	''>0 because And operation gives values above 0 if g_ReportMask allows the report_type
	If ((report_type And g_ReportMask) > 0) Then
		If ((function_level And g_ReportingFunctionMask) > 0) Then
			If report_type = TASK_ENTERED_REPORT Then
				If g_PrintReports Then
					Print "entered " + msg$
				EndIf
				UpdateClient EVTNO_CAL_MSG, "entered " + msg$
			EndIf
		
			If report_type = TASK_PROGRESS_REPORT Then
				If g_PrintReports Then
					Print "progress " + msg$
				EndIf
				UpdateClient EVTNO_CAL_STEP, "progress " + msg$
			EndIf
		
			If report_type = TASK_DONE_REPORT Then
				If g_PrintReports Then
					Print "success " + msg$
				EndIf
				UpdateClient EVTNO_FOREGROUND_DONE, "success " + msg$
			EndIf
			
			If report_type = TASK_MESSAGE_REPORT Then
				If g_PrintReports Then
					Print "message " + msg$
				EndIf
				UpdateClient EVTNO_CAL_MSG, "message " + msg$
			EndIf
			
			If report_type = TASK_WARNING_REPORT Then
				If g_PrintReports Then
					Print "warning " + msg$
				EndIf
				UpdateClient EVTNO_WARNING, "warning " + msg$
			EndIf
		EndIf
		
		'' The following messages are not filtered by function level		
			If report_type = TASK_FAILURE_REPORT Then
				If g_PrintReports Then
					Print "error " + msg$
				EndIf
				UpdateClient EVTNO_FOREGROUND_ERR, "error " + msg$
			EndIf
	EndIf
Fend

