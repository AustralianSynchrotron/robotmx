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

''Defines to support UpdateClient wrapper function
''UpdateClient message types
#define FOREGROUND_DONE 1
#define FOREGROUND_ERR 2
#define STATE_ERR 3
#define TASK_MSG 4
#define TASK_PROG 5
#define CLIENT_UPDATE 6
#define CLIENT_RESP 7

''Message levels
#define DEBUG_LEVEL &b000001
#define INFO_LEVEL &b000010
#define WARNING_LEVEL &b000100
#define ERROR_LEVEL &b001000

''Memory bit map
''Bit 0, 1 (+/-) JogX
''Bit 2, 3 (+/-) JogY
''Bit 4, 5 (+/-) JogZ
''Bit 6, 7 (+/-) JogU
''Bit 8, 9 (+/-) JogV
''Bit 10, 11 (+/-) JogW

#define NUM_JOG_BITS 11


