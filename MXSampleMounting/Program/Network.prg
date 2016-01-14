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

#include "networkdefs.inc"
#include "forcedefs.inc"

''Reply from JobSolver Vb guide app
Global Preserve String g_JobSolverReply$
''Global flag indicating JobSolver busy status
Global Preserve Boolean g_JobSolverBusy
''command string received from host, reply from SPEL board to be sent back to host
''and error string to be sent back to host
String backcmd$, backreply$, backerr$
String forecmd$, foreerr$, foredone$
''task message status string to be sent back to host
String taskmesg$
''return value of the foreground command path including JobSolver (thus global)
Global Preserve Integer g_foreretval
''return value of the background command path
Integer backretval
''error value of the StateChangeWatcher background task
Integer stateretval
''busy status of foreground processing path
Boolean foredonestatus
''flag to indicate tcp connection status
Boolean tcpconnected
''for communication with external clients
Global Preserve String g_RunArgs$ ''Parameters to called function
Global Preserve String g_RunResult$ ''Return results from function
''Abort process flag for use by external clients
Global Preserve Boolean g_FlagAbort
''set by script, read by SPELCOM (C++)
Global Preserve Long g_RobotStatus
''point coordinates
Global Integer g_point
Global Integer g_teachpoint
''The string holding the state change info
String statechange_msg$(NUM_STATES)
''Any error that occurs in statechangewatcher
String stateerr$
''Number of messages queued by statechangewatcher in current loop
Integer num_statechange_msg
''Flag for mandatory sending of states.  Otherwise states sent on change
Boolean SendStates
''the states we check for changes
''flag to indicate foreground done status
Boolean stored_WindowsStatus
Boolean stored_Motor
Integer stored_SysErr
String stored_SysErrStr$
Boolean stored_SafetyOn
Boolean stored_EStopOn
Long stored_OutW
Long stored_InW
''Current coordinates
Real stored_RealPosCX
Real stored_RealPosCY
Real stored_RealPosCZ
Real stored_RealPosCU
Real stored_RealPosCV
Real stored_RealPosCW
Real stored_pointCX
Real stored_pointCY
Real stored_pointCZ
Real stored_pointCU
Real stored_pointCV
Real stored_pointCW
Boolean stored_Power
String stored_RobotModel$
Integer stored_RobotType
String stored_RobotName$
Integer stored_Robot
Global String g_TaskStatusName$
Integer stored_TaskStatus
Integer stored_Speed
Integer stored_SpeedR
Integer stored_SpeedS
Boolean stored_PauseOn
Long stored_Pls(NUM_JOINTS)
Real stored_LimZ
Integer stored_Tool
Integer stored_foreretval
Integer stored_backretval
Integer stored_stateretval
Boolean stored_InPos
Boolean stored_TeachOn
Boolean stored_SFree(NUM_JOINTS)
Boolean stored_Brake(NUM_JOINTS)
Double stored_Force(NUM_FORCES)
Boolean stored_ErrorOn
Boolean stored_AtHome
Integer stored_closestPoint
Long stored_RobotStatus
String stored_Time$
''Run statuses
String stored_RunResult$
String stored_RunArgs$

''Print level
Global Byte g_PrintLevel

''Signals
''See network.inc

''Locks
''See network.inc

''Timers
''See network.inc

''Network connections
''see network.inc

''Foreground task list
''1 is Main task
''2 is JobDispatcher task
''3-8 is JogJ1 to JogJ6 tasks
''9 is JobWorker task

''Background Task List
''65 is BGMain
''66 is ForceMeasureLoop
''67 is ReceiveSendLoop
''68 is StateChangeWatcher
''69 is Continue Or QuitAllUserTasks

''Task start order
''BGMain starts ForceMeasureLoop, ReceiveSendLoop, and Main.  
''ReceiveSendLoop starts/stops StateChangeWatcher based on connection status.
''Main starts JobDispatcher, and jog tasks
''JobDispatcher is given jobs by ReceiveSendLoop, and JobDispatcher runs JobWorker to complete the jobs

''Send message from user task to ReceiveSendLoop variables, and wait for transmission complete signal
''Call UpdateClient instead to send messages from tasks 
Function SendMessageWait(msg$ As String, prefix$ As String, ByRef netmsg$ As String, lock As Integer, sig As Integer, mutex As Boolean)
	''Use serialization mutex only when requested
	If mutex Then
		''only 1 thread allowed in here at a time
		SyncLock SEND_MSG_LOCK
	EndIf
	''get lock required to access specified variable
	SyncLock lock, SIG_LOCK_TIMEOUT
	''only access the variable if we get the lock
	If TW = False Then
		''Set the new mesg
		netmsg$ = prefix$ + msg$
		SyncUnlock lock
		''If not connected or there is no valid msg, dont bother waiting for transmission
		If tcpconnected And netmsg$ <> "" Then
			''wait until transmission done in ReceiveSendLoop
			WaitSig sig, SIG_LOCK_TIMEOUT
			If TW = True Then
				Print "SendMessageWait: Did not receive transmission complete signal ", sig
			EndIf
		EndIf
	Else
		Print "SendMessageWait: Cannot get lock ", lock
	EndIf
	''Use serialization mutex only when requested
	If mutex Then
		''This thread is finished, release the lock
		SyncUnlock SEND_MSG_LOCK
	EndIf
Fend
''Called by ReceiveSendLoop to do the message transmission to host
''Call UpdateClient instead to send messages from user tasks to host
Function SendMessage(ByRef netmsg$ As String, lock As Integer, sig As Integer, connection As Integer)
	''only send if good connection, and valid mesg
	If tcpconnected And netmsg$ <> "" Then
		''Attempt to get exclusive access to the netmsg$ variable
	    SyncLock lock, SIG_LOCK_TIMEOUT
	    ''Only use the variable if we get the lock
	    If TW = False Then
	    	''Send the message to correct connection
			Print #connection, netmsg$
			''netmsg string sent, now clear the buffer
			netmsg$ = ""
			SyncUnlock lock
		Else
			Print "SendMessage: Could not get lock", lock
		EndIf
		''Tell waiting task that transmission complete
		Signal sig
	EndIf
Fend
Function GTInitPrintLevel()
	''This function is only for testing
	''The g_PrintLevel variable should be set from python layers
    g_PrintLevel = INFO_LEVEL + WARNING_LEVEL + ERROR_LEVEL ''DEBUG_LEVEL + 
Fend
''Send message from user task to client
''This function is a wrapper for SendMessageWait, and SPELCOM_Event
''Do not call from ReceiveSendLoop, it must be separate thread
Function UpdateClient(receiver As Integer, msg$ As String, level As Integer)
	''Print message locally if within specified g_PrintLevel
	If ((g_PrintLevel And level > 0)) Then
		Print msg$
	EndIf
	If receiver = TASK_MSG Then
		Select level
			Case DEBUG_LEVEL
				msg$ = "DEBUG " + msg$
			Case INFO_LEVEL
				msg$ = "INFO " + msg$
			Case WARNING_LEVEL
				msg$ = "WARNING " + msg$
			Case ERROR_LEVEL
				msg$ = "ERROR " + msg$
	    Send
    EndIf
	''send message to network client only if connected
	''which means that ReceiveSendLoop is looping and can actually send the message
	If tcpconnected Then
		Select receiver
			Case TASK_MSG
				''send task general message via TCPIP_SERVER to EPICS host
				SendMessageWait(msg$, "Task Msg:", ByRef taskmesg$, TASK_MSG_LOCK, TASK_MSG_SENT, True)
			Case CLIENT_UPDATE
				''send client update message via TCPIP_SERVER to EPICS host
				SendMessageWait(msg$, "Client Update:", ByRef taskmesg$, TASK_MSG_LOCK, TASK_MSG_SENT, True)
			Case CLIENT_RESP
				''send client response message via TCPIP_SERVER to EPICS host
				SendMessageWait(msg$, "Client Resp:", ByRef taskmesg$, TASK_MSG_LOCK, TASK_MSG_SENT, True)
			Case TASK_PROG
				''send task progress message via TCPIP_SERVER to EPICS host
                SendMessageWait(msg$, "Task Prog:", ByRef taskmesg$, TASK_MSG_LOCK, TASK_MSG_SENT, True)
			Case FOREGROUND_DONE
				''Send foreground done message via TCPIP_SERVER to EPICS host
				SendMessageWait(msg$, "FDone:", ByRef foredone$, FDONE_MSG_LOCK, FDONE_MSG_SENT, False)
			Case FOREGROUND_ERR
				''send the foreground error message
				SendMessageWait(msg$, "Fore:", ByRef foreerr$, FORE_EMSG_LOCK, FORE_EMSG_SENT, False)
			Case STATE_ERR
				''send the StateChangeWatcher stateerr$ error message
				SendMessageWait(msg$, "State:", ByRef stateerr$, SERR_MSG_LOCK, SERR_MSG_SENT, False)
		Send
	EndIf
Fend
''some tasks are not suited to using Eval
''Called by JobWorker, and IsCmdBackground
Function IsUseEval(mode As Boolean, cmd$ As String) As Boolean
	''the tokens after received command split
	String toks$(0)
	Integer numtokens
			
	''split received message into tokens
	numtokens = ParseStr(cmd$, toks$(), " =,")
	
	''Use eval when more than 1 token
	''When calling SPEL tasks only 1 token used
	If numtokens > 1 Then
		IsUseEval = True
	Else
		IsUseEval = False
	EndIf
	
	OnErr GoTo errHandler
	
	''Dont use Eval in BACKGROUND for certain slow epson commands
	''This will force this tcp server to execute these cmds in foreground
	If toks$(0) = "SFree" Or toks$(0) = "SLock" Then
		If mode = BACKGROUND Then
			IsUseEval = False
		Else
			IsUseEval = True
		EndIf
	EndIf

''if fail, just accept it and move on
SkipTask:
	Exit Function
	
errHandler:
	UpdateClient(FOREGROUND_ERR, "IsUseEval !!Error:" + " " + Str$(Err) + " " + ErrMsg$(Err) + " " + "Line: " + Str$(Erl), ERROR_LEVEL)
	EResume SkipTask
Fend
''Called by JobWorker, and IsCmdBackground
Function GetReturnType(ByRef cmd$ As String) As Integer
	''default is no reply at all
	GetReturnType = 0
	''look for return type specifier in received line
	If InStr(cmd$, "ret:") > 0 Then
		''return specification found
		GetReturnType = Val(Mid$(cmd$, InStr(cmd$, "ret:") + 4))
		''remove return type specification from received line prior to eval received line
		cmd$ = Left$(cmd$, InStr(cmd$, "ret:") - 2)
	EndIf
Fend
''Called by JobWorker
Function IsNumeric(msg$ As String) As Boolean
	Integer i
	Integer asciival
	IsNumeric = True
	''check msg to see if numeric
	For i = 1 To Len(msg$) Step 1
    	asciival = Asc(Mid$(msg$, i, 1))
    	If (asciival < 48 Or asciival > 57) And asciival <> 46 And asciival <> 43 And asciival <> 45 And asciival <> 32 Then
    		IsNumeric = False
    	EndIf
	Next
Fend
''ensure reply matches specified datatype and timeout rules
''Called by JobWorker
Function ParseReturnType$(msg$ As String, return_type As Integer, timer As Integer) As String
	ParseReturnType$ = ""
	''parse return type
	Select return_type
		Case 0
			''no reply specified, ensure we dont return a reply
			msg$ = ""
		Case 1
			''float reply specified, ensure reply is a number
			''if timeout then null the response
			If Not IsNumeric(msg$) Then
				If Tmr(timer) < NETCLIENT_TIMEOUT Then
					msg$ = "0"
				Else
					''receiver record would have timed out by now
					msg$ = ""
				EndIf
			EndIf
		Case 2
			''string reply specified, ensure reply is a string
			''if timeout then null the response
			If msg$ = "" Then
				If Tmr(timer) < NETCLIENT_TIMEOUT Then
					msg$ = "Forced"
				Else
					''receiver record would have timed out by now
					msg$ = ""
				EndIf
			EndIf
	Send
	ParseReturnType$ = msg$
Fend
''JobWorker is a foreground task
''JobDispatcher starts JobWorker
Function JobWorker
	''Error mesg string
	String err$
	''Return type specified in msg
	Integer return_type
	''if no error, force OK string to be sent back to host as default
	err$ = "OK"
	''inspect specified return type, and remove the specifier leaving correct syntax
	return_type = GetReturnType(ByRef forecmd$)
	''setup error handler to catch errors
	OnErr GoTo errHandler
	
	''If we dont know how to service the request, we must use eval
	If IsUseEval(FOREGROUND, forecmd$) Then
		''User trying to call SPEL task
		''Set JobSolverBusy flag true
		g_JobSolverBusy = True
		''Pass job up to VB guide JobSolver
        SPELCom_Event RUN_MULTITOKEN_SPEL, forecmd$
        ''Wait for JobSolver to complete
        Do While g_JobSolverBusy
        	Wait 0.001
        Loop
		''check for errors generated by JobSolver and shown by g_JobSolverReply$
		''Other errors are handled by errHandler, or Reset mechanism (if JobWorker is halted)
		If g_JobSolverReply$ <> "" Then
			''Construct the error mesg
			err$ = "JobWorker " + g_JobSolverReply$
			''g_JobSolverReply$ has been used to contruct error string
			''now clear g_JobSolverReply$
			g_JobSolverReply$ = ""
			''Send error message to client
			UpdateClient(FOREGROUND_ERR, err$, INFO_LEVEL)
		EndIf
	Else
		''User trying to call SPEL task
		''Set JobSolverBusy flag true
		g_JobSolverBusy = True
		''Set default return value before running SPEL task so tasks dont have to do this
		g_foreretval = 0
		''Pass job up to VB guide JobSolver
        SPELCom_Event RUN_SINGLETOKEN_SPEL, forecmd$
        ''Wait for JobSolver to complete
        Do While g_JobSolverBusy
        	Wait 0.001
        Loop
	EndIf
	Exit Function
	
''Error handler for epson system
errHandler:
	err$ = "JobWorker !!Error: " + Str$(Err) + " " + ErrMsg$(Err) + "Line:" + Str$(Erl)
	''Send message to client
	UpdateClient(FOREGROUND_ERR, err$, INFO_LEVEL)
	''try instruction after the one that caused error
	EResume Next
Fend
''JobDispatcher is a foreground task
''Main starts JobDispatcher
Function JobDispatcher
	Do While 1
		''Wait for job 
		WaitSig FOREGROUND_JOB
		
		''Job is assumed to be slow, start JobWorker to handle it
		If Not PauseOn And Not SafetyOn And Not ErrorOn Then
			''Inform client that foreground now busy
			UpdateClient(FOREGROUND_DONE, "0", INFO_LEVEL)
			foredonestatus = False
			Xqt 9, JobWorker, NoPause
			TaskWait JobWorker
			''Inform client that foreground now available
			foredonestatus = True
			UpdateClient(FOREGROUND_DONE, "1", INFO_LEVEL)
		EndIf
	Loop
Fend
''Foreground jog task for a single joint
''Main starts jog
Function Jog(RobotJoint As Integer, BitPos As Integer, BitNeg As Integer)
	Integer myInt
	Integer savSpeed
	''error string
	String err$
	''loop index
	Integer i
	''Joint encoder pulse storage used for joint jog tasks
	Long pulses(NUM_JOINTS)
	OnErr GoTo errHandler
	''always monitor for a jog
	Do While 1
		''Wait for user to press a jog button thus setting memory IO on RC620
		Wait MemSw(BitPos) = On Or MemSw(BitNeg) = On
		
		''save current position for all joints
		For i = 1 To 6 Step 1
          pulses(i) = Pls(i)
		Next
			
		''calculate required tweak
		If MemSw(BitPos) = On Then
			''+ve tweak full range for joint
			pulses(RobotJoint) = JRange(RobotJoint, 2)
		Else
			''-ve tweak full range for joint
			pulses(RobotJoint) = JRange(RobotJoint, 1)
		EndIf
		
		''set till condition so motion stops when user releases jog button
       	Till MemSw(BitPos) = Off And MemSw(BitNeg) = Off
    
       	''do the move
		Go Pulse(pulses(1), pulses(2), pulses(3), pulses(4), pulses(5), pulses(6)) Till
		
		''Restore speed
		Speed savSpeed
	Loop
	Exit Function
	
''Error handler for epson system
errHandler:
	''construct the message
	err$ = "Jog " + Str$(RobotJoint) + " !!Error " + Str$(Err) + " " + ErrMsg$(Err) + "Line:" + Str$(Erl)
	''Send message to client
	UpdateClient(FOREGROUND_ERR, err$, ERROR_LEVEL)
	''try instruction after the one that caused error
	EResume Next
Fend
''continue in separate thread so ReceiveSendLoop can still process cmds during continue
''putting this in ReceiveSendLoop caused problems as cont seems to disrupt the thread its running in
''Started by ReceiveSendLoop thread
Function Continue
	''if in paused state and safety off then
	If PauseOn And Not SafetyOn Then
		''take us out of pause state
		Cont
	EndIf
	Exit Function
Fend
''Started by ReceiveSendLoop thread
''kills from foreground tasks from num start upto 32 
Function QuitAllTasks(start As Integer)
	''quits foreground tasks.
	Integer i
    For i = start To 32 Step 1
		If TaskState(i) <> 0 Then
			Quit i
		EndIf
	Next
	Exit Function
Fend
''Called by BGMain thread
Function TasksRunning As Boolean
	TasksRunning = False
	''test if any foreground tasks running
	Integer i
	For i = 1 To 32 Step 1
		If TaskState(i) <> 0 Then
			''found a task running
			TasksRunning = True
			Exit For
		EndIf
	Next
	Exit Function
Fend
''Execute command in background ReceiveSendLoop thread if possible
''Other threads should not call this function
Function IsCmdBackground As Boolean
	Boolean UseEval
	Boolean error_on_special
	''Temporary copy of command received
	String cmd$
	''General counter
	Integer i
	''number of tokens in received command
	Integer numtokens
	''the tokens after received command split
	String toks$(0)
	''The return type specified in the received command
	Integer return_type
	''setup error handler to catch errors
	OnErr GoTo errHandler
		
	''split received message into tokens
	numtokens = ParseStr(backcmd$, toks$(), " =,")
	
	''assume we find the command
	IsCmdBackground = True
	''assume no error
	backretval = 0
	''Default for print erroron special command
	error_on_special = False
	
	''First, lets attempt to process recv cmd using case statement
	''Only cmds in case statement generate background path errors by using errHandler
	''First token is the cmd
	Select toks$(0)
		Case "PDel"
			''so we can delete points in background with SafetyOn
			''pdel button pressed on gui
			If numtokens = 1 Then
				PDel g_teachpoint
			EndIf
		Case "Teach"
			P(g_teachpoint) = RealPos
		Case "Quit"
			''search for requested taskname. if found, then task is running
			For i = USER_TASKS_START To 32 Step 1
				If toks$(1) = TaskInfo$(i, 0) Then
					''task found at index i, lets quit it
					Quit i
					Exit For
				EndIf
			Next
		Case "QuitAllUserTasks"
			If TaskState(QuitAllTasks) = 0 Then
				If TaskState(Main) And TaskState(JobWorker) Then
					''Foreground up, and JobWorker is running a task
					Xqt QuitAllTasks(USER_TASKS_START), NoPause
				ElseIf TaskState(Main) And Not TaskState(JobWorker) Then
   					''Foreground up, and JobWorker is not running a task
					Xqt QuitAllTasks(USER_TASKS_START - 1), NoPause
				Else
					''When foreground is not part of ip server (eg. FindMagnet ran from RC+ directly)
					Xqt QuitAllTasks(1), NoPause
				EndIf
			EndIf
		Case "Cont"
			If TaskState(Continue) = 0 And Not ErrorOn And Not SafetyOn Then
				Xqt Continue, NoPause
			EndIf
		Case "Pause"
			''Pause cannot use background eval, but can be executed in background
			Pause
		Case "AbortMotion"
			AbortMotion Robot
		Case "SavePoints"
			String fname$, bfname$
			''construct filenames based on robot number
			fname$ = "robot" + Str$(Robot) + ".pts"
			bfname$ = "robot" + Str$(Robot) + "_bak.pts"
			''check if backup already exists
			If FileExists(bfname$) Then
				''del the old backup file, if it exists already
				Del bfname$
			EndIf
			''create backup before saving
			Copy fname$, bfname$
			''save new points file
			SavePoints fname$
		Case "print"
			error_on_special = True
		Case "Print"
			error_on_special = True
		Default
			''did not find the command
			IsCmdBackground = False
	Send
	
	''Special for returning ErrorOn to EPICS in polled style
	''Done so streamDevice gets periodic traffic on at least 1 record
	''This enables streamDevice to autoconnect if connection breaks
	If error_on_special And toks$(1) = "ErrorOn" Then
		backreply$ = Str$(ErrorOn)
	Else
		''did not find the command, other print commands will use background eval to solve
		IsCmdBackground = False
	EndIf
	
	''Application specific background tasks
	If IsCmdBackground = False Then
		IsCmdBackground = IsAppCmdBackground(backcmd$)
	EndIf
	
	''case could not process recv cmd, try using eval instead
	If Not IsCmdBackground Then
		''make temporary copy of received cmd
		cmd$ = backcmd$
		''inspect specified return type, and remove the specifier leaving correct syntax
		return_type = GetReturnType(ByRef cmd$)
		''guard against user trying to run SPEL tasks using Eval
		UseEval = IsUseEval(BACKGROUND, cmd$)
		If UseEval Then
			''lets keep an eye on how long this command takes.
			''Reset the timer
			TmReset BACK_TIMER
			''Try to process recv cmd using Eval 
			backretval = EVal(cmd$, backreply$)
			If backretval = 0 Then
				''cmd success
				IsCmdBackground = True
			Else
				''we dont want to inform client about errors here as this is an attempt to process only
				''if it fails we try foreground
				backretval = 0
			EndIf
			''parse return type
			backreply$ = ParseReturnType$(backreply$, return_type, BACK_TIMER)
		EndIf
	EndIf
	
	''default return value when no error, and cmd was background
	If backerr$ = "" And IsCmdBackground Then
		backerr$ = "Back:OK"
	EndIf
	
	Exit Function
	
errHandler:
	''construct error string to send back to host
	backerr$ = "Back:" + "IsCmdBackground !!Error " + Str$(Err) + " " + ErrMsg$(Err) + " " + "Line:" + Str$(Erl)
	backretval = Err
	''try instruction after the one that caused error
    EResume Next
Fend
Function IsForegroundAvailable As Boolean
	''default is foreground is available
	IsForegroundAvailable = True
	''errors we generate ourselves
	If Not foredonestatus And WindowsStatus = 3 Then
		foreerr$ = "Fore:ReceiveSendLoop " + "!!Error: Cannot use foreground exe path while it is still busy with a previous job"
		IsForegroundAvailable = False
	EndIf
	If Not foredonestatus And WindowsStatus <> 3 Then
		foreerr$ = "Fore:ReceiveSendLoop " + "!!Error: Cannot use foreground exe path while RC+ is down"
		IsForegroundAvailable = False
	EndIf
	If PauseOn Then
		foreerr$ = "Fore:ReceiveSendLoop " + "!!Error: Cannot use foreground exe path while paused"
		IsForegroundAvailable = False
	EndIf
	If SafetyOn Then
		foreerr$ = "Fore:ReceiveSendLoop " + "!!Error: Cannot use foreground exe path while safetyOn"
		IsForegroundAvailable = False
	EndIf
	If ErrorOn Then
		foreerr$ = "Fore:ReceiveSendLoop " + "!!Error: Cannot use foreground exe path while RC620 in error state. Use Reset"
		IsForegroundAvailable = False
	EndIf
Fend

''This bg task is started when tcp is connected, and halted when tcp not connected
''Check several robot states, if they have changed then inform the client about the change of state
''Here we contruct the message, and ReceiveSendLoop does the sending.
Function StateChangeWatcher
	''tmp working variables
	Integer i
	Real pos
	Real diff
	String msg$
	Boolean WindowsStatus_bool
	''flag to indicate if we must get the STATE_MSG_LOCK again before proceeding
	''This happens when we give up the lock to process an error
	Boolean need_lock
	
	''Have we sent the StateChangeWatcher error status mesg since it last changed 
	Boolean StatusSent
	StatusSent = False
	
	need_lock = False
	
	''StateChangeWatcher error status string
	String err$
	''old/stored StateChangeWatcher error status string
	String stored_err$
	
	OnErr GoTo errHandler
	
	''Main loop for state change checks
	Do While TaskState(ReceiveSendLoop) <> 0

		''lets keep track of number of states we wish to send
		num_statechange_msg = 0
		
		''flag no error at loop start
		stateretval = 0
		
		''get sole access to state variables 
		SyncLock STATE_MSG_LOCK, SIG_LOCK_TIMEOUT
		
		''do states only if we have the lock
		If TW = False Then

			''Check motor change of state
			stored_Motor = check_boolean_state(Motor, stored_Motor, "Motor:")
			
			''Check SysErr change of state
	 	    stored_SysErr = check_integer_state(SysErr, stored_SysErr, "SysErr:")
	 	    
	 	    ''Check SysErrStr$ change of state			
	 	    If stored_SysErr <> 0 Then
	 	    	msg$ = "SysErr !!Error:" + " " + Str$(stored_SysErr) + " " + ErrMsg$(stored_SysErr)
				stored_SysErrStr$ = check_string_state$(msg$, stored_SysErrStr$, "ErrMsg$:")
			Else
				stored_SysErrStr$ = check_string_state$("OK", stored_SysErrStr$, "ErrMsg$:")
			EndIf
			
			''Check SafetyOn change of state
			stored_SafetyOn = check_boolean_state(SafetyOn, stored_SafetyOn, "SafetyOn:")
			
			''Check EStopOn change of state
			stored_EStopOn = check_boolean_state(EStopOn, stored_EStopOn, "EStopOn:")
			
			''Check OutW change of state
			stored_OutW = check_long_state(OutW(0), stored_OutW, "OutW(0):", 0)
			
			''Check InW change of state
			stored_InW = check_long_state(InW(0), stored_InW, "InW(0):", 0)
			
			''Check power change of state
			stored_Power = check_boolean_state(Power, stored_Power, "Power:")
			
			stored_closestPoint = check_integer_state(GetClosestPoint(ByRef diff), stored_closestPoint, "ClosestPoint:")
			
			''Check present position CX change of state
		    stored_RealPosCX = check_real_state(CX(RealPos), stored_RealPosCX, "CX(RealPos):", ENCODER_NOISE_EGU)
				
			''Check present position CY change of state
			stored_RealPosCY = check_real_state(CY(RealPos), stored_RealPosCY, "CY(RealPos):", ENCODER_NOISE_EGU)
			
			''Check present position CZ change of state
		    stored_RealPosCZ = check_real_state(CZ(RealPos), stored_RealPosCZ, "CZ(RealPos):", ENCODER_NOISE_EGU)
			
			''Check present position CU change of state
	        stored_RealPosCU = check_real_state(CU(RealPos), stored_RealPosCU, "CU(RealPos):", ENCODER_NOISE_EGU)
			
			''Check present position CV change of state
			stored_RealPosCV = check_real_state(CV(RealPos), stored_RealPosCV, "CV(RealPos):", ENCODER_NOISE_EGU)
			
			''Check present position CW change of state
			stored_RealPosCW = check_real_state(CW(RealPos), stored_RealPosCW, "CW(RealPos):", ENCODER_NOISE_EGU)
			
			''Check point CX change of state
		    stored_pointCX = check_real_state(CX(P(g_point)), stored_pointCX, "CX(g_point):", ENCODER_NOISE_EGU)
				
			''Check point CY change of state
			stored_pointCY = check_real_state(CY(P(g_point)), stored_pointCY, "CY(g_point):", ENCODER_NOISE_EGU)
				
			''Check point CZ change of state
			stored_pointCZ = check_real_state(CZ(P(g_point)), stored_pointCZ, "CZ(g_point):", ENCODER_NOISE_EGU)
			
			''Check point CU change of state
			stored_pointCU = check_real_state(CU(P(g_point)), stored_pointCU, "CU(g_point):", ENCODER_NOISE_EGU)
				
			''Check point CV change of state
			stored_pointCV = check_real_state(CV(P(g_point)), stored_pointCV, "CV(g_point):", ENCODER_NOISE_EGU)
				
			''Check point CW change of state
			stored_pointCW = check_real_state(CW(P(g_point)), stored_pointCW, "CW(g_point):", ENCODER_NOISE_EGU)
			
SkipPoint:
			''check the lock before proceeding
            If need_lock Then
            	''reset the need_lock flag
            	need_lock = False
				''get sole access to state variables 
				SyncLock STATE_MSG_LOCK, SIG_LOCK_TIMEOUT
				
				''do states only if we have the lock
				If TW = True Then
					Print "StateChangeWatcher: Cannot get STATE_MSG_LOCK"
					GoTo SkipStates
				EndIf
            EndIf
            
			''check RobotModel$ change of state
			stored_RobotModel$ = check_string_state$(RobotModel$, stored_RobotModel$, "RobotModel$:")
			
			''check Time$ change of state
			stored_Time$ = check_string_state$(Time$, stored_Time$, "Time$:")
			
			''Check RobotType change of state
		    stored_RobotType = check_integer_state(RobotType, stored_RobotType, "RobotType:")
				
			''check RobotName$ change of state
		    stored_RobotName$ = check_string_state$(RobotName$, stored_RobotName$, "RobotName$:")
			
			''Check Robot change of state
		    stored_Robot = check_integer_state(Robot, stored_Robot, "Robot:")
			
			''Check TaskStatus change of state
			If g_TaskStatusName$ <> "" Then
				''default is not running
				pos = 0
				''search for requested taskname.
				For i = USER_TASKS_START To 32 Step 1
					If g_TaskStatusName$ = TaskInfo$(i, 0) Then
						''store task number of requested task
						pos = i
						''break out of the loop
						Exit For
					EndIf
				Next
				''retrieve task status using task number
				If pos >= USER_TASKS_START Then
					pos = TaskState(pos)
				EndIf
				''prepare message if status is changed from that stored
				stored_TaskStatus = check_integer_state(pos, stored_TaskStatus, "TaskStatus:")
			EndIf
			
SkipTaskState:
			''check the lock before proceeding
            If need_lock Then
            	''reset the need_lock flag
            	need_lock = False
				''get sole access to state variables 
				SyncLock STATE_MSG_LOCK, SIG_LOCK_TIMEOUT
				
				''do states only if we have the lock
				If TW = True Then
					Print "StateChangeWatcher: Cannot get STATE_MSG_LOCK"
					GoTo SkipStates
				EndIf
            EndIf
			
			''Check Speed change of state
	        stored_Speed = check_integer_state(Speed, stored_Speed, "Speed:")
			
			''Check SpeedR change of state
			stored_SpeedR = check_integer_state(SpeedR, stored_SpeedR, "SpeedR:")
			
			''Check SpeedS change of state
			stored_SpeedS = check_integer_state(SpeedS, stored_SpeedS, "SpeedS:")
			
			''Check Pls change of state		
			For i = 1 To NUM_JOINTS Step 1
				stored_Pls(i) = check_long_state(Pls(i), stored_Pls(i), "Pls(" + Str$(i) + "):", ENCODER_NOISE_RAW)
			Next
			
			''Check LimZ change of state
		    stored_LimZ = check_real_state(LimZ, stored_LimZ, "LimZ:", 0)
			
			''Check Tool change of state
			stored_Tool = check_integer_state(Tool, stored_Tool, "Tool:")
			
			''Check foreground task error change of state
		    stored_foreretval = check_integer_state(g_foreretval, stored_foreretval, "foreretval:")
			
			''Check background task error change of state
			stored_backretval = check_integer_state(backretval, stored_backretval, "backretval:")
			
			''Check StateChangeWatcher task error change of state
			stored_stateretval = check_integer_state(stateretval, stored_stateretval, "stateretval:")
			
			''Check InPos change of state
		    stored_InPos = check_boolean_state(InPos, stored_InPos, "InPos:")
			
			''Check TeachOn change of state
			stored_TeachOn = check_boolean_state(TeachOn, stored_TeachOn, "TeachOn:")
			
			''Check SFree change of state
			For i = 1 To NUM_JOINTS Step 1
				If Motor And Not ErrorOn Then
					''Test if joint free only if motors are on
					stored_SFree(i) = check_boolean_state(SFree(i), stored_SFree(i), "SFree(" + Str$(i) + "):")
				Else
					''When motors are off, the joint is free
					stored_SFree(i) = check_boolean_state(True, stored_SFree(i), "SFree(" + Str$(i) + "):")
				EndIf
			Next
			
			''Check Brake change of state
			For i = 1 To NUM_JOINTS Step 1
	            stored_Brake(i) = check_boolean_state(Brake(i), stored_Brake(i), "Brake(" + Str$(i) + "):")
			Next
			
			''Check for ErrorOn change of state
			stored_ErrorOn = check_boolean_state(ErrorOn, stored_ErrorOn, "ErrorOn:")
			
			''Check for AtHome change of state
			stored_AtHome = check_boolean_state(AtHome, stored_AtHome, "AtHome:")
			
			''Check PauseOn change of state
			stored_PauseOn = check_boolean_state(PauseOn, stored_PauseOn, "PauseOn:")
			
			''reduce WindowsStatus to boolean 
			If WindowsStatus = 3 Then
				WindowsStatus_bool = True
			Else
				WindowsStatus_bool = False
			EndIf
			
			''Check WindowsStatus change of state
			stored_WindowsStatus = check_boolean_state(WindowsStatus_bool, stored_WindowsStatus, "WindowsStatus:")
			
			''Check for g_RobotStatus change of state
			stored_RobotStatus = check_long_state(g_RobotStatus, stored_RobotStatus, "g_RobotStatus:", 0)
	   
			''Check for g_RunResult$ change of state
		    stored_RunResult$ = check_string_state$(g_RunResult$, stored_RunResult$, "g_RunResult$:")
	
			''Check for g_RunArgs$ change of state	
			stored_RunArgs$ = check_string_state$(g_RunArgs$, stored_RunArgs$, "g_RunArgs$:")
	
	        ''Check Forces change of state
			For i = 1 To NUM_FORCES Step 1
				stored_Force(i) = check_double_state(g_FSForces(i), stored_Force(i), "Force_GetForce(" + Str$(i) + "):", FORCE_NOISE_EGU)
			Next
					
			''allow other threads to access state variables
			SyncUnlock STATE_MSG_LOCK
SkipStates:
	
			''send the state mesgs
			If tcpconnected And num_statechange_msg <> 0 Then
				''wait for ReceiveSendLoop to transmit the data
				WaitSig STATE_MSG_SENT, SIG_LOCK_TIMEOUT
				If TW = True Then
					Print "StateChangeWatcher: Did not receive signal STATE_MSG_SENT"
				EndIf
			EndIf
			
			''If no error construct statechangewatcher error status string then send if required
			''errHandler contructs mesg when errors occur
			If stateretval = 0 Then
				err$ = "OK"
				''determine if client requires update mesg
				If stored_err$ <> err$ Then
					stored_err$ = err$
					''wait for transmission of error string
					UpdateClient(STATE_ERR, err$, ERROR_LEVEL)
				EndIf
			EndIf
			
			''We have looped once since SendStates was set to true at StateChangeWatcher startup
			SendStates = False
		Else
			Print "StateChangeWatcher: Cannot get STATE_MSG_LOCK"
		EndIf
		
	Loop
	Print "StateChangeWatcher exiting.."
	Exit Function
	
''Error handler for epson system
errHandler:
    ''allow other threads to access state variables, as we want to transmit an stateerr mesg instead now
	SyncUnlock STATE_MSG_LOCK
	''construct the error string
	err$ = "StateChangeWatcher !!Error:" + " " + Str$(Err) + " " + ErrMsg$(Err) + " " + "Line: " + Str$(Erl)
	stateretval = Err
	''determine if client requires update mesg
	If stored_err$ <> err$ Then
		stored_err$ = err$
		''wait for transmission of error string
		UpdateClient(STATE_ERR, err$, ERROR_LEVEL)
	EndIf
	''force over threshold error
	If Err = 7955 Then
		''skip forces, they are they last state checked anyhow
		EResume SkipStates
	''Task num out of available range.  Happens when calling Taskinfo just as another task is starting.
	ElseIf Err = 2260 Then
		need_lock = True
		EResume SkipTaskState
	''point not defined error
	ElseIf Err = 7006 Or Err = 7007 Then
		need_lock = True
		EResume SkipPoint
	Else
		''All other errors, just try again
		EResume SkipStates
	EndIf
Fend
''Return point number closest to robot current position
Function GetClosestPoint(ByRef mindiff As Real) As Integer
	Integer i
	Real diff
	Real diffx, diffy, diffz, diffu
	''Default min to large number
	mindiff = 999999
	''Cycle through all points
	For i = 0 To 100 Step 1
		''If the point is defined
		If PDef(P(i)) Then
			''Calculate position difference between point i, and current position
			diffx = Abs(CX(RealPos) - CX(P(i)))
			diffy = Abs(CY(RealPos) - CY(P(i)))
			diffz = Abs(CZ(RealPos) - CZ(P(i)))
			diffu = Abs(CU(RealPos) - CU(P(i)))
            diff = Sqr((diffx * diffx) + (diffy * diffy) + (diffz * diffz) + (diffu * diffu))
		    If (diff < (mindiff - 0.001)) Then
		    	''Store minimum difference, and point
		    	mindiff = diff
		    	GetClosestPoint = i
		    	If mindiff = 0 Then
		    		''right on this point.  It does not get any closer than this
		    		Exit Function
		    	EndIf
		    EndIf
		EndIf
	Next
Fend
Function check_string_state$(current$ As String, stored$ As String, prefix$ As String) As String
	check_string_state$ = stored$
	''Check for string change of state
	If (current$ <> stored$ Or SendStates) Then
		check_string_state$ = current$
		statechange_msg$(num_statechange_msg) = prefix$ + check_string_state$
		''increment num state mesg counter
		num_statechange_msg = num_statechange_msg + 1
	EndIf
Fend
Function check_boolean_state(current As Boolean, stored As Boolean, prefix$ As String) As Boolean
	check_boolean_state = stored
	''Check for boolean change of state
	If (current <> stored Or SendStates) Then
		check_boolean_state = current
		statechange_msg$(num_statechange_msg) = prefix$ + Str$(check_boolean_state)
		''increment num state mesg counter
		num_statechange_msg = num_statechange_msg + 1
	EndIf
Fend
Function check_integer_state(current As Integer, stored As Integer, prefix$ As String) As Integer
	check_integer_state = stored
	''Check for integer change of state
	If (current <> stored Or SendStates) Then
		check_integer_state = current
		statechange_msg$(num_statechange_msg) = prefix$ + Str$(check_integer_state)
		''increment num state mesg counter
		num_statechange_msg = num_statechange_msg + 1
	EndIf
Fend
Function check_long_state(current As Long, stored As Long, prefix$ As String, hystersis As Long) As Long
	check_long_state = stored
	''Check for long change of state
	If (current < stored - hystersis Or current > stored + hystersis Or SendStates) Then
		check_long_state = current
		statechange_msg$(num_statechange_msg) = prefix$ + Str$(check_long_state)
		''increment num state mesg counter
		num_statechange_msg = num_statechange_msg + 1
	EndIf
Fend
Function check_real_state(current As Real, stored As Real, prefix$ As String, hystersis As Real) As Real
	check_real_state = stored
	''Check for Real change of state
	If (current < stored - hystersis Or current > stored + hystersis Or SendStates) Then
		check_real_state = current
		statechange_msg$(num_statechange_msg) = prefix$ + Str$(check_real_state)
		''increment num state mesg counter
		num_statechange_msg = num_statechange_msg + 1
	EndIf
Fend
Function check_double_state(current As Double, stored As Double, prefix$ As String, hystersis As Real) As Double
	check_double_state = stored
	''Check for Real change of state
	If (current < stored - hystersis Or current > stored + hystersis Or SendStates) Then
		check_double_state = current
		statechange_msg$(num_statechange_msg) = prefix$ + Str$(check_double_state)
		''increment num state mesg counter
		num_statechange_msg = num_statechange_msg + 1
	EndIf
Fend
''Send all unsolicited message to client
''This Function called by ReceiveSendLoop thread
Function SendAllMessages
	Integer i
	Boolean state_msg_was_sent
	
	''cmd was processed in background and reply is ready to be sent to host
	If backreply$ <> "" Then
		Print #SYNCHRONOUS, backreply$
		''reply string sent, now clear the buffer, and flags
		backreply$ = ""
	EndIf
				
	''cmd was processed in background and error status is ready to be sent to host
	If backerr$ <> "" Then
		Print #ASYNCHRONOUS, backerr$
		''error string sent, now clear the buffer, and flags
		backerr$ = ""
	EndIf
		
	''foreground cmd error is ready to be sent to host
	''foreground cmd error may not occur on same cycle as received request
	''JobWorker must be either i) not running ii) Halted iii) Waiting
	OnErr GoTo foreerr_error
	If (TaskState(JobWorker) = 0 Or TaskState(JobWorker) = 3 Or TaskState(JobWorker) = 2) Then
		SendMessage(ByRef foreerr$, FORE_EMSG_LOCK, FORE_EMSG_SENT, ASYNCHRONOUS)
	EndIf
		
	''Foreground job done msg is ready to be sent to host
	OnErr GoTo foredone_error
	SendMessage(ByRef foredone$, FDONE_MSG_LOCK, FDONE_MSG_SENT, ASYNCHRONOUS)
	
	''Send state change messages
	state_msg_was_sent = False
	OnErr GoTo statemsg_error
	If num_statechange_msg <> 0 Then
		''Attempt to get exclusive access to the variable statechange_msg$()
		SyncLock STATE_MSG_LOCK, SIG_LOCK_TIMEOUT
		''Only use the variable if we get the lock
		If TW = False Then
			For i = 0 To num_statechange_msg - 1 Step 1
				If statechange_msg$(i) <> "" Then
				    ''send the data
					Print #ASYNCHRONOUS, statechange_msg$(i)
					''clear the buffer
					statechange_msg$(i) = ""
					state_msg_was_sent = True
				EndIf
			Next
			''reset state mesg count
			num_statechange_msg = 0
			''allow other threads access to state variables
			SyncUnlock STATE_MSG_LOCK
		Else
			Print "SendAllMessages: Could not get lock STATE_MSG_LOCK"
		EndIf
		If state_msg_was_sent Then
			''Tell StateChangeWatcher that state change messages have been sent
			Signal STATE_MSG_SENT
		EndIf
	EndIf
	
	''Error mesgs from StateChangeWatcher
	OnErr GoTo stateerr_error
	SendMessage(ByRef stateerr$, SERR_MSG_LOCK, SERR_MSG_SENT, ASYNCHRONOUS)
		
	''Task general message ready to be sent to host
	OnErr GoTo taskmesg_error
	SendMessage(ByRef taskmesg$, TASK_MSG_LOCK, TASK_MSG_SENT, ASYNCHRONOUS)
	
	''No error when we use this exit
	Exit Function
	
	''Exit if we get failed to read from port during sending of data
BadConnection:
    Exit Function
    
''Error handing	
''Ensure we unlock the correct lock   
foreerr_error:
	''bad tcp connection
    If Err = 2902 Then
		SyncUnlock FORE_EMSG_LOCK
	EndIf
	EResume BadConnection
	
foredone_error:
	''bad tcp connection
    If Err = 2902 Then
		SyncUnlock FDONE_MSG_LOCK
	EndIf
	EResume BadConnection
	
statemsg_error:
	''bad tcp connection
    If Err = 2902 Then
		SyncUnlock STATE_MSG_LOCK
	EndIf
	EResume BadConnection
	
stateerr_error:
	''bad tcp connection
    If Err = 2902 Then
		SyncUnlock SERR_MSG_LOCK
	EndIf
	EResume BadConnection
	
taskmesg_error:
	''bad tcp connection
    If Err = 2902 Then
		SyncUnlock TASK_MSG_LOCK
	EndIf
	EResume BadConnection
	
Fend
Function InitNetworkVariables
	Integer i
	''command string received from host, reply from SPEL board to be sent back to host
	''and error string to be sent back to host
	backcmd$ = ""; backerr$ = ""
	forecmd$ = ""; foreerr$ = ""
	stateerr$ = ""
	''Default foreground return value
	g_foreretval = 0;
	''task message status string to be sent back to host
	taskmesg$ = ""
	''return value of the background command path
    backretval = 0
	''point number to query
	g_point = 0
	''point number to teach/delete
	g_teachpoint = 999
	''Messaging of state changes
	For i = 0 To NUM_STATES Step 1
		statechange_msg$(i) = ""
	Next
	''flag to indicate tcp connection status
	tcpconnected = False
Fend
Function Connect
	''setup error handler to catch errors
	OnErr GoTo errHandler
StartOver:
	''ensure StateChangeWatcher not running until connected
    If TaskState(StateChangeWatcher) Then
        Quit StateChangeWatcher
    EndIf
	''initialize memory IO to all 0 for no jog
	MemOutW 0, 0
	''Two connections used as streamDevice used at EPICS end does not
	''like mixed sync and asyn records on the same link
	''because it corrupts the data stream on the ethernet wire according to wireshark
	Do While ChkNet(SYNCHRONOUS) <> -1 And ChkNet(ASYNCHRONOUS) <> -1
		''Wait .1
		''Ensure ethernet connections are closed
		CloseNet #SYNCHRONOUS
		CloseNet #ASYNCHRONOUS
		''Connect to IP associated with #SYNCHRONOUS for periodic or poll/response records
		OpenNet #SYNCHRONOUS As Server
		''Connect to IP associated with #ASYNCHRONOUS for I/O intr records
		OpenNet #ASYNCHRONOUS As Server
		''let things settle before testing if its ok
		''Wait .2
	Loop
	''init variables related to this tcp server
	InitNetworkVariables
	''Wait for connection to be ready
	Print ""
	Print "Waiting for connection " + Time$ + " " + Date$ + ".."
	WaitNet #SYNCHRONOUS
	WaitNet #ASYNCHRONOUS
	Print "Connection established " + Time$ + " " + Date$ + ".."
    ''flag as connected
	tcpconnected = True
	''Ensure system states sent via unsolicited message at connect
	SendStates = True
	''Determine FDone status to send to client at connect
	If TaskState(Main) And foredonestatus = True Then
		foredone$ = "FDone:1"
	Else
		foredone$ = "FDone:0"
	EndIf
	''let connection settle for a moment
	Wait .5
	''Start StateChangeWatcher as background task
	Xqt StateChangeWatcher, NoPause
	Exit Function
errHandler:
	''construct error string
	Print "Connect !!Error " + Str$(Err) + " " + ErrMsg$(Err) + " ", Erl(Ert)
	''Slow frequency of print commands
	Wait 1
	EResume StartOver
Fend
''Called by ReceiveSendLoop
''Quits all tasks when safety is on
Function IsSafetyOn(ByRef QuitAllForeTasksDone As Boolean)
	
	''Reset QuitAllUserTasks flag when the safety is not on
	If Not SafetyOn And QuitAllForeTasksDone Then
		QuitAllForeTasksDone = False
	EndIf
	
	''Quit All Foreground Tasks running when safetyOn
	''This includes foreground tasks used by ip server
	''done to prevent position recovery after safety gate close
	''position recovery only occurs when fore NoPause tasks are running whilst safetyon
	If SafetyOn Then
		If TaskState(QuitAllTasks) = 0 And QuitAllForeTasksDone = False Then
			''Quit all tasks running in foreground
			Xqt QuitAllTasks(1), NoPause
			QuitAllForeTasksDone = True
			''tell client that all foreground has been quit because of safetyOn
			backerr$ = "Back:IsSafetyOn " + "Quit All Foreground Tasks due to SafetyOn"
			''flag foreground as not available
			''foreground becomes available after another Startmain main, managed by BGmain task.
			foredonestatus = False
			''tell client foreground busy whilst safetyOn
			If tcpconnected Then
				UpdateClient(FOREGROUND_DONE, "0", INFO_LEVEL)
			EndIf
		EndIf
	EndIf
	
Fend
''Called by ReceiveSendLoop
''Check if user requesting jog, while it is not available.  If yes, give them a mesg
Function IsJogAvailable(ByRef JogMesgDone As Boolean)
	Boolean jog_requested
	Integer i
	''default is no jog being requested by user
	jog_requested = False
	''default is jog is available
	IsJogAvailable = True
	''check if a jog is being requested by user
	For i = 0 To NUM_JOG_BITS Step 1
		If MemSw(i) = On Then
			jog_requested = True
		EndIf
	Next
	''prepare any neccessary mesg to user
	If Not JogMesgDone And jog_requested Then
		If WindowsStatus <> 3 Then
			foreerr$ = "Fore:ReceiveSendLoop " + "!!Error: Cannot use jog while RC+ is down"
			IsJogAvailable = False
			JogMesgDone = True
		EndIf
		If PauseOn Then
			foreerr$ = "Fore:ReceiveSendLoop " + "!!Error: Cannot use jog while paused"
			IsJogAvailable = False
			JogMesgDone = True
		EndIf
		If SafetyOn Then
			foreerr$ = "Fore:ReceiveSendLoop " + "!!Error: Cannot use jog while safetyOn"
			IsJogAvailable = False
			JogMesgDone = True
		EndIf
		If ErrorOn Then
			foreerr$ = "Fore:ReceiveSendLoop " + "!!Error: Cannot use jog while RC620 in error state. Use Reset"
			IsJogAvailable = False
			JogMesgDone = True
		EndIf
	EndIf
	''reset JogMesgDone flag, as no jog is being requested
	If Not jog_requested Then
		JogMesgDone = False
	EndIf
Fend
Function ReceiveSendLoop
	''general variable for loops
	Integer i
	''Number of characters in receive buffer for #SYNCHRONOUS
	Integer numchars1
	''Number of characters in receive buffer for #ASYNCHRONOUS
	Integer numchars2
	''flag to indicate if we can execute received command in background task
	Boolean cmdbackground
	''Have we quit all tasks due to safetyOn
	Boolean QuitAllForeTasksDone
	QuitAllForeTasksDone = False
	
	''Have we sent jog task message
	Boolean JogMesgDone
	JogMesgDone = False

	''setup error handler to catch errors
	OnErr GoTo errHandler
	
	''ReceiveSendLoop
	Do While 1
		''react to Jog command when in pause or error
		IsJogAvailable(ByRef JogMesgDone)

		''Look at how many chars in receive buffer for #SYNCHRONOUS
		numchars1 = ChkNet(SYNCHRONOUS)
		''Look at how many chars in receive buffer for #ASYNCHRONOUS
		numchars2 = ChkNet(ASYNCHRONOUS)
		''If more than 0 chars, then read a line
		If numchars1 > 0 And numchars2 >= 0 Then

			''read the input request
			Line Input #SYNCHRONOUS, backcmd$

			''Attempt to process recv cmd in background
			If Not IsCmdBackground Then
				''IsCmdBackground is False.  Pass cmd to foreground JobDispatcher task
				''check error statuses before passing to foreground
				If IsForegroundAvailable Then
					''copy command so we can continue to service background commands sent from client
					''whilst also processing this foreground command
					forecmd$ = backcmd$
					''Signal Foreground JobDispatcher to wake up
					Signal FOREGROUND_JOB
				EndIf
			EndIf
			
		ElseIf numchars1 < 0 Or numchars2 < 0 Then
			''lost connection so enter Connect algorithm
			Connect
		EndIf
		
		''send all messages
		SendAllMessages
	Loop
	Exit Function

errHandler:
	Print "ReceiveSendLoop !!Error " + Str$(Err) + " " + ErrMsg$(Err) + " ", Erl(Ert)
	''Just try again.  Most likely is network fault so no point sending error mesg to host
    EResume Next
Fend
Function Main
	''See BGMain below for entry point
	
	''start the JobDispatcher task
	Xqt 2, JobDispatcher, NoPause
	''start the jog monitoring tasks
	Xqt 3, Jog(1, 0, 1), NoPause
	Xqt 4, Jog(2, 2, 3), NoPause
	Xqt 5, Jog(3, 4, 5), NoPause
	Xqt 6, Jog(4, 6, 7), NoPause
	Xqt 7, Jog(5, 8, 9), NoPause
	Xqt 8, Jog(6, 10, 11), NoPause
	
	''flag foreground as available
	foredonestatus = True
	''System configuration option for SPEL controller
	''clear globals on mainXX start must be set to off
	If tcpconnected Then
		UpdateClient(FOREGROUND_DONE, "1", INFO_LEVEL)
	EndIf
	
	''Wait for ReceiveSendLoop termination before exit
	''to ensure user tasks start at predictable number
	''TaskWait did strange things here
	Do While TaskState(ReceiveSendLoop) <> 0
		Wait 1
	Loop
Fend
''Foreground Test task.  Testing tcp server ability to call SPEL functions
''Started by JobWorker
Function task1
	String error$
   	Do While 1
		Wait 1
		UpdateClient(TASK_PROG, "Step 1 of 10", INFO_LEVEL)
		UpdateClient(TASK_MSG, "Doing bit of this", INFO_LEVEL)
		UpdateClient(TASK_MSG, "log i am doing this", INFO_LEVEL)
		Wait 1
		UpdateClient(TASK_PROG, "Step 2 of 10", INFO_LEVEL)
		UpdateClient(TASK_MSG, "Doing bit of that", INFO_LEVEL)
		UpdateClient(TASK_MSG, "log i am doing that", INFO_LEVEL)
		Wait 1
		UpdateClient(TASK_PROG, "Step 3 of 10", INFO_LEVEL)
		UpdateClient(TASK_MSG, "Doing bit of this", INFO_LEVEL)
		UpdateClient(TASK_MSG, "log i am doing this", INFO_LEVEL)
		Wait 1
		UpdateClient(TASK_PROG, "Step 4 of 10", INFO_LEVEL)
		UpdateClient(TASK_MSG, "Doing bit of that", INFO_LEVEL)
		UpdateClient(TASK_MSG, "log i am doing that", INFO_LEVEL)
		Wait 1
		UpdateClient(TASK_PROG, "Step 5 of 10", INFO_LEVEL)
		UpdateClient(TASK_MSG, "Doing bit of this", INFO_LEVEL)
		UpdateClient(TASK_MSG, "log i am doing this", INFO_LEVEL)
		Wait 1
		UpdateClient(TASK_PROG, "Step 6 of 10", INFO_LEVEL)
		UpdateClient(TASK_MSG, "Doing bit of that", INFO_LEVEL)
		UpdateClient(TASK_MSG, "log i am doing that", INFO_LEVEL)
		Wait 1
		UpdateClient(TASK_PROG, "Step 7 of 10", INFO_LEVEL)
		UpdateClient(TASK_MSG, "Doing bit of this", INFO_LEVEL)
		UpdateClient(TASK_MSG, "log i am doing this", INFO_LEVEL)
		Wait 1
		UpdateClient(TASK_PROG, "Step 8 of 10", INFO_LEVEL)
		UpdateClient(TASK_MSG, "Doing bit of that", INFO_LEVEL)
		UpdateClient(TASK_MSG, "log i am doing that", INFO_LEVEL)
		Wait 1
		UpdateClient(TASK_PROG, "Step 9 of 10", INFO_LEVEL)
		UpdateClient(TASK_MSG, "Doing bit of this", INFO_LEVEL)
		UpdateClient(TASK_MSG, "log i am doing this", INFO_LEVEL)
		Wait 1
		UpdateClient(TASK_PROG, "Step 10 of 10", INFO_LEVEL)
		UpdateClient(TASK_MSG, "Doing bit of that", INFO_LEVEL)
		UpdateClient(TASK_MSG, "log i am doing that", INFO_LEVEL)
	Loop
Fend

''Test performance of force system
Function ForcesTest()
	Double fvalues(NUM_FORCES)
	Integer i
	Print Time$
	For i = 0 To 1000 Step 1
		ReadForces(ByRef fvalues())
		Print Str$(fvalues(1)) + " " + Str$(fvalues(2)) + " " + Str$(fvalues(3))
	Next
	Print Time$
Fend
Function EpsonForceTest()
	Real fvalue(1000)
	Real minf, maxf, diff
	Integer i
	minf = 99999
	maxf = 0.000
	Print Time$
	For i = 0 To 1000 Step 1
		fvalue(i) = Force_GetForce(3)
		If (fvalue(i) > maxf) Then
			maxf = fvalue(i)
		EndIf
		If (fvalue(i) < minf) Then
			minf = fvalue(i)
		EndIf

	Next
	Print Time$
	diff = maxf - minf
	Print "Min force = ", Str$(minf)
	Print "Max force = ", Str$(maxf)
	Print "P-P Force = ", Str$(diff)
	
Fend
''This is the entry point
Function BGMain
	Integer last_WindowsState
	Integer i
	''Have we quit all tasks due to safetyOn
	Boolean QuitAllForeTasksDone
	QuitAllForeTasksDone = False
	''initialize last WindowsState
	last_WindowsState = 0
		
	''Initialize message print level
	GTInitPrintLevel
	
	''Initialize Australian Synchrotron force sensing
	ForceInit
	''Exit if force sensing init failed
	If g_FSInitOK = False Then
		Exit Function
	EndIf
		
	''Reset errors at startup
	If ErrorOn Then
		Reset Error
	EndIf
		
	''Initialize the network variables
	InitNetworkVariables
	
	''Start ForceMeasureLoop as background task so we can call ReadForce and ReadForces
	Xqt ForceMeasureLoop, NoPause
	
	''Calibrate the force sensor and check its readback health
	If Not ForceCalibrateAndCheck(HIGH_SENSITIVITY, HIGH_SENSITIVITY) Then
		UpdateClient(TASK_MSG, "Force sensor calibration and check failed, stopping all tasks..", ERROR_LEVEL)
		''problem with force sensor so exit
		Exit Function
	EndIf
	
	''Start ReceiveSendLoop as background task
	Xqt ReceiveSendLoop, NoPause
	
	''Start the EPS loop as background task
	''Xqt EPSLoop, NoPause
	
	''Wait for ReceiveSendLoop termination before exit
	Do While TaskState(ReceiveSendLoop) <> 0
		''manage the startup of main
		''if rc+ is up, and main is dead, and no error, no pauseon, no safetyon, and no foreground task running then restart main
		If WindowsStatus = 3 And TaskState(Main) = 0 And Not ErrorOn And Not PauseOn And Not SafetyOn And Not TasksRunning Then
			''rc+ is now up
			''update last_WindowsStatus
			last_WindowsState = WindowsStatus
			''allow time for operation mode to be set by JinHu vb guide service before starting main
			Wait 1
			''StartMain if no other tasks running in foreground
			If Not TasksRunning Then
				StartMain Main
			EndIf
		EndIf
		If WindowsStatus = 1 And last_WindowsState <> WindowsStatus Then
			''rc+ is not up
			''update last_WindowsStatus
			last_WindowsState = WindowsStatus
			''flag foreground as not available
			foredonestatus = False
			''tell client foreground busy whilst rc+ down
			If tcpconnected Then
				UpdateClient(FOREGROUND_DONE, "0", INFO_LEVEL)
			EndIf
		EndIf
		''react to safety on
		IsSafetyOn(ByRef QuitAllForeTasksDone)
		''reduce loop cycle frequency to 10 Hz max
		Wait .1
	Loop
Fend

