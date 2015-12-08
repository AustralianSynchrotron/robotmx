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

''User tasks are operated in foreground
#define USER_TASKS_START 10
''Network client default timeout is 1 sec minus response time of .2
#define NETCLIENT_TIMEOUT .8

''Used to indicate if caller is FOREGROUND or BACKGROUND task
''Used for IsUseEval
#define FOREGROUND True
#define BACKGROUND False

''Epson locks used to protect access to string variables
''foreground done msg lock
#define FDONE_MSG_LOCK 1
''Task msg lock
#define TASK_MSG_LOCK 2
''StateChangeWatcher msg lock
#define STATE_MSG_LOCK 3
''StateChangeWatcher err msg lock
#define SERR_MSG_LOCK 4
''Fore error mesg lock
#define FORE_EMSG_LOCK 5
''Epson locks used to serialize access to SendMessage from user tasks
#define SEND_MSG_LOCK 6

''Epson signals used
#define FDONE_MSG_SENT 1
#define TASK_MSG_SENT 2
#define STATE_MSG_SENT 3
#define SERR_MSG_SENT 4
#define FORE_EMSG_SENT 5
#define FOREGROUND_JOB 6

''Epson timers used
#define BACK_TIMER 0

''Epson network connections
#define SYNCHRONOUS 201
#define ASYNCHRONOUS 202

''Timeout for obtaining locks, and receiving signals.
#define SIG_LOCK_TIMEOUT .5

''Epson Events to Vb guide JobSolver
#define RUN_SINGLETOKEN_SPEL 1001
''Must be a native Epson SPEL command
#define RUN_MULTITOKEN_SPEL 1002

''Monitor deadbands
#define ENCODER_NOISE_RAW 2
#define ENCODER_NOISE_EGU 0.002
#define FORCE_NOISE_EGU .06

''Use unsolicited messaging of state changes
#define NUM_STATES 200

''UpdateClient Event numbers
''Used by application to update network and vb guide clients via network server
#define EVTNO_LID_OPEN 2002
#define EVTNO_UPDATE 2003
#define EVTNO_INPUT 2004
#define EVTNO_OUTPUT 2005
#define EVTNO_CAL_STEP 2101
#define EVTNO_CAL_MSG 2102
#define EVTNO_WARNING 2105
#define EVTNO_LOG_NOTE 2110
#define EVTNO_LOG_WARNING 2111
#define EVTNO_LOG_ERROR 2112
#define EVTNO_LOG_SEVERE 2113
#define EVTNO_HARDWARE_LOG_WARNING 2114
#define EVTNO_HARDWARE_LOG_ERROR 2115
#define EVTNO_HARDWARE_LOG_SEVERE 2116

''define added to support tcp ip server
#define EVTNO_PRINT_EVENT 6

''Defines to support UpdateClient wrapper function
''Events used soley by tcp server to update network clients only
#define EVTNO_FOREGROUND_DONE 1
#define EVTNO_FOREGROUND_ERR 2
#define EVTNO_STATE_ERR 3

''Memory bit map
''Bit 0, 1 (+/-) JogX
''Bit 2, 3 (+/-) JogY
''Bit 4, 5 (+/-) JogZ
''Bit 6, 7 (+/-) JogU
''Bit 8, 9 (+/-) JogV
''Bit 10, 11 (+/-) JogW

#define NUM_JOG_BITS 11


