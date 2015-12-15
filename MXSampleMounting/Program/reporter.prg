#include "reporterdefs.inc"
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


