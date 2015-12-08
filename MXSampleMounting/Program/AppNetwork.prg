''Put application specific background SPEL tasks here
''Normally used to provide application data to network clients in a fast efficient way

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
	
	Select toks$(0)
		Case "MyQuickTest"
			Print "Running MyQuickTest"
			Xqt MyQuickTest
		Default
			IsAppCmdBackground = False
	Send
	Exit Function
	
errHandler:
		Print "IsCmdAppBackground: !!Error " + Str$(Err) + " " + ErrMsg$(Err) + " " + "Line:" + Str$(Erl)
		EResume Next
Fend
