#include "GTReporterdefs.inc"
#include "networkdefs.inc"

'' Filter Masks
Global Byte g_ReportMask
Global Byte g_ReportingFunctionMask
Global Boolean g_PrintReports

'' Wrapper around UpdateClient to filter network messages based on g_ReportingLevel
'' Function level filtering only applies to INFO_LEVEL and DEBUG_LEVEL Reports
Function GTUpdateClient(report_type As Byte, function_level As Byte, msg$ As String)
	g_ReportMask = 255 ''Should be set from EPICS
	g_ReportingFunctionMask = 255
	g_PrintReports = True



	If report_type And TASK_ENTERED_REPORT Then
		If g_PrintReports Then
			Print "entered " + msg$
		EndIf
		UpdateClient EVTNO_CAL_MSG, "entered " + msg$
	EndIf

	If report_type And TASK_PROGRESS_REPORT Then
		If g_PrintReports Then
			Print "progress " + msg$
		EndIf
		UpdateClient EVTNO_CAL_STEP, "progress " + msg$
	EndIf

	If report_type And TASK_DONE_REPORT Then
		If g_PrintReports Then
			Print "success " + msg$
		EndIf
		UpdateClient EVTNO_FOREGROUND_DONE, "success " + msg$
	EndIf

	If report_type And TASK_WARNING_REPORT Then
		If g_PrintReports Then
			Print "warning " + msg$
		EndIf
		UpdateClient EVTNO_WARNING, "warning " + msg$
	EndIf

	If report_type And TASK_FAILURE_REPORT Then
		If g_PrintReports Then
			Print "error " + msg$
		EndIf
		UpdateClient EVTNO_FOREGROUND_ERR, "error " + msg$
	EndIf
	
	If report_type And TASK_MESSAGE_REPORT Then
		If g_PrintReports Then
			Print "message " + msg$
		EndIf
		UpdateClient EVTNO_CAL_MSG, "message " + msg$
	EndIf

Fend

