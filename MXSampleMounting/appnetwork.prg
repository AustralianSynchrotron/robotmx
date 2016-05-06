'' Copyright (c) 2012  Australian Synchrotron
''
'' This library is free software; you can redistribute it and/or
'' modify it under the terms of the GNU Lesser General Public
'' Licence as published by the Free Software Foundation; either
'' version 2.1 of the Licence, or (at your option) any later version.
''
'' This library is distributed in the hope that it will be useful,
'' but WITHOUT ANY WARRANTY; without even the implied warranty of
'' MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
'' Lesser General Public Licence for more details.
''
'' You should have received a copy of the GNU Lesser General Public
'' Licence along with this library; if not, write to the Free Software
'' Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
''
'' Contact details:
'' mark.clift@synchrotron.org.au
'' 800 Blackburn Road, Clayton, Victoria 3168, Australia.
''
'' Modification Log
'' 04/12/12 Initial Release

''Put application specific background SPEL tasks here
''Normally used to provide application data to network clients in a fast efficient way

#include "networkdefs.inc"
#include "genericdefs.inc"
#include "mxrobotdefs.inc"
#include "cassettedefs.inc"

''Returns false if request is not application specific background task
''Returns true if request is application specific background task
Function IsAppCmdBackground(cmd$ As String) As Boolean
	''General counter
	Integer i
	''number of tokens in received command
	Integer numtokens
	''the tokens after received command split
	String toks$(0)
	
	''setup error handler to catch errors
	OnErr GoTo errHandler
	''set default return value
	IsAppCmdBackground = True
	
	''split received message into tokens
	numtokens = ParseStr(cmd$, toks$(), " =,")
	
	''Call application specific task
	Select toks$(0)
		Case "JSONDataRequest"
			Xqt JSONDataRequest
		Case "ResetRobotStatus"
			Xqt ResetRobotStatus
		Case "MyQuickTest"
			Xqt MyQuickTest
		Default
			''Command was not found
			IsAppCmdBackground = False
	Send
	Exit Function
	
errHandler:
		Print "IsCmdAppBackground: !!Error " + Str$(Err) + " " + ErrMsg$(Err) + " " + "Line:" + Str$(Erl)
		EResume Next
Fend
Function MyQuickTest
	Integer i, j, k
	String data$(3)
	For i = 1 To NUM_CASSETTES Step 1
		For j = 1 To NUM_ROWS Step 1
			For k = 1 To NUM_COLUMNS Step 1
				data$(i) = data$(i) + Str$(g_CASSampleDistanceError(i, j, k)) + " "
			Next
		Next
	Next
Fend
Function ResetRobotStatus
	''Clear any errors
	If ErrorOn Then
		Reset Error
	EndIf
	''If robot at home, and not at home reason set in RobotStatus then clear it
	If AtHome And ((g_RobotStatus And FLAG_REASON_NOT_HOME) = FLAG_REASON_NOT_HOME) Then
		g_RobotStatus = g_RobotStatus - FLAG_REASON_NOT_HOME
	EndIf
	''If estop not on, yet estop reason set in RobotStatus then clear it
	If Not EStopOn And ((g_RobotStatus And FLAG_REASON_ESTOP) = FLAG_REASON_ESTOP) Then
		g_RobotStatus = g_RobotStatus - FLAG_REASON_ESTOP
	EndIf
	''If SafetyOn not on, yet estop reason set in RobotStatus then clear it	
	If Not SafetyOn And ((g_RobotStatus And FLAG_REASON_SAFEGUARD) = FLAG_REASON_SAFEGUARD) Then
		g_RobotStatus = g_RobotStatus - FLAG_REASON_SAFEGUARD
	EndIf
	''Force dumbbell status blindly to be in cradle
	g_DumbbellStatus = DUMBBELL_IN_CRADLE
	''Force clear all status
	g_RobotStatus = 0
Fend

