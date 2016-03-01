#include "networkdefs.inc"
#include "mxrobotdefs.inc"
#include "genericdefs.inc"
#include "cassettedefs.inc"

'' Note: All angle values in GT domain are in degrees
Global Real g_dumbbell_Perfect_Angle
Global Real g_dumbbell_Perfect_cosValue
Global Real g_dumbbell_Perfect_sinValue

Global Real g_goniometer_Angle
Global Real g_goniometer_cosValue
Global Real g_goniometer_sinValue


Function GTCheckPoint(pointNum As Integer) As Boolean
	String msg$
	
	''msg$ = "GTCheckPoint(P" + Str$(pointNum) + ")"
	''UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
	If (Not PDef(P(pointNum))) Then
		msg$ = "GTCheckPoint: P" + Str$(pointNum) + " is not defined yet!"
		UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
		GTCheckPoint = False
	ElseIf CX(P(pointNum)) = 0 Or CY(P(pointNum)) = 0 Then
		msg$ = "GTCheckPoint: P" + Str$(pointNum) + " has X or Y coordinate set to 0(zero)!"
		UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
		GTCheckPoint = False
	Else
		''msg$ = "GTCheckPoint: P" + Str$(pointNum) + " is Valid."
		''UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
		GTCheckPoint = True
	EndIf
Fend
Function GTCheckTool(toolNum As Integer) As Boolean
	''Messaging variable
	String msg$
	''Default return value
	GTCheckTool = False
	''Setup error handler
    OnErr GoTo ToolSetError
	
	''Check specified tool
	P51 = TLSet(toolNum)
	If CX(P51) = 0 Or CY(P51) = 0 Or CU(P51) = 0 Then
		msg$ = "GTCheckTool: Tool(" + Str$(toolNum) + ") is not defined yet!"
		UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
	Else
		msg$ = "GTCheckTool: Tool(" + Str$(toolNum) + ") is Valid."
		UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
		GTCheckTool = True
	EndIf
	Exit Function

''Error handler
ToolSetError:
	''inform the client
	msg$ = "GTCheckTool: Tool(" + Str$(toolNum) + ") is not defined yet!"
	UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
	''Clear the error
	OnErr GoTo 0
	''Exit function
	Exit Function
Fend

Function GTInitBasicPoints() As Boolean
 	'' Check Points P0, P1 and P18
	If GTCheckPoint(0) And GTCheckPoint(1) And GTCheckPoint(18) Then
		UpdateClient(TASK_MSG, "GTInitBasicPoints completed.", INFO_LEVEL)
		GTInitBasicPoints = True
	Else
		UpdateClient(TASK_MSG, "GTInitBasicPoints: error in GTCheckPoint!", ERROR_LEVEL)
		GTInitBasicPoints = False
	EndIf
Fend

Function GTInitMagnetPoints() As Boolean
	
 	'' Check Points P6, P16 and P26
	If Not (GTCheckPoint(6) Or GTCheckPoint(16) Or GTCheckPoint(26)) Then
		UpdateClient(TASK_MSG, "GTInitMagnetPoints: error in GTCheckPoint!", ERROR_LEVEL)
		GTInitMagnetPoints = False
		Exit Function
	EndIf
	
	'' Check Points P10, P11 and P12
	If Not (GTCheckPoint(10) Or GTCheckPoint(11) Or GTCheckPoint(12)) Then
		UpdateClient(TASK_MSG, "GTInitMagnetPoints: error in GTCheckPoint!", ERROR_LEVEL)
		GTInitMagnetPoints = False
		Exit Function
	EndIf
	
	'' Check Tool 1 (pickerTool) and Tool 2 (placerTool)
	If Not (GTCheckTool(PICKER_TOOL) Or GTCheckTool(PLACER_TOOL)) Then
		UpdateClient(TASK_MSG, "GTInitMagnetPoints: error in GTCheckTool!", ERROR_LEVEL)
		GTInitMagnetPoints = False
		Exit Function
	EndIf
		
	'' Above required Points and Tools are defined. Start deriving magnet points
	'' dumbbell Orientation in World Coordinates when dumbbell is on cradle
	g_dumbbell_Perfect_Angle = GTAngleToPerfectOrientationAngle(CU(P6))
	g_dumbbell_Perfect_cosValue = Cos(DegToRad(g_dumbbell_Perfect_Angle))
	g_dumbbell_Perfect_sinValue = Sin(DegToRad(g_dumbbell_Perfect_Angle))
	
	'' Cooling Point: DISTANCE_P3_TO_P6=20.0mm in the perpendicular direction from center of dumbbell
	P3 = P6 +X(DISTANCE_P3_TO_P6 * -g_dumbbell_Perfect_sinValue) +Y(DISTANCE_P3_TO_P6 * g_dumbbell_Perfect_cosValue)

	'' High Above CoolPoint, get the tong out of LN2
	P2 = P3 :Z(-2)
		
	'' Above Center of dumbbell, middle of cassette height
	P4 = P6 +Z(30.0)
	
	'' Picker Ready Position: 10mm in front of picker
	P17 = P16 +X(10.0 * g_dumbbell_Perfect_cosValue) +Y(10.0 * g_dumbbell_Perfect_sinValue)
	'' Placer Ready Position: 10mm in front of placer
	P27 = P26 -X(10.0 * g_dumbbell_Perfect_cosValue) -Y(10.0 * g_dumbbell_Perfect_sinValue)
	
	'' 35mm in the perpendicular direction from center of picker magnet when dumbbell on cradle
	P93 = P16 +X(35.0 * -g_dumbbell_Perfect_sinValue) +Y(35.0 * g_dumbbell_Perfect_cosValue)
	'' 35mm in the perpendicular direction from center of placer magnet when dumbbell on cradle
	P94 = P26 +X(35.0 * -g_dumbbell_Perfect_sinValue) +Y(35.0 * g_dumbbell_Perfect_cosValue)
	
	Real dumbbell_cos_plus_sin, dumbbell_cos_minus_sin
	dumbbell_cos_plus_sin = g_dumbbell_Perfect_cosValue + g_dumbbell_Perfect_sinValue
	dumbbell_cos_minus_sin = g_dumbbell_Perfect_cosValue - g_dumbbell_Perfect_sinValue
	'' Middle point of Arc from cooling point to picker magnet
	P15 = P16 +X(17.5 * dumbbell_cos_minus_sin) +Y(17.5 * dumbbell_cos_plus_sin)
	'' Middle point of Arc from cooling point to placer magnet
	P25 = P26 +X(17.5 * -dumbbell_cos_plus_sin) +Y(17.5 * dumbbell_cos_minus_sin)
	
	
	'' To avoid Tong touching dumbbell head (with 0.5 as additional buffer offset)
	Real tong_dumbbell_gap
	tong_dumbbell_gap = MAGNET_HEAD_RADIUS + CAVITY_RADIUS + 0.5
	P5 = P16 +X(tong_dumbbell_gap * -g_dumbbell_Perfect_sinValue) +Y(tong_dumbbell_gap * g_dumbbell_Perfect_cosValue)
	
	UpdateClient(TASK_MSG, "GTInitMagnetPoints completed.", INFO_LEVEL)
	GTInitMagnetPoints = True
Fend

Function GTInitCassettePoints() As Boolean
	''Set initial value on entry
	GTInitCassettePoints = False
	
 	'' Check Point P6: dumbbell cradle needed to decided cassette orientation
	If Not GTCheckPoint(6) Then
		UpdateClient(TASK_MSG, "GTInitCassettePoints: P6 is not valid!", ERROR_LEVEL)
		Exit Function
	EndIf
	
	'' Check Left Cassette Points P34, P41 and P44
	If Not (GTCheckPoint(34) Or GTCheckPoint(41) Or GTCheckPoint(44)) Then
		UpdateClient(TASK_MSG, "GTInitCassettePoints: left cassette points are not valid!", ERROR_LEVEL)
		Exit Function
	EndIf
	
	'' Check Middle Cassette Points P35, P42 and P45
	If Not (GTCheckPoint(35) Or GTCheckPoint(42) Or GTCheckPoint(45)) Then
		UpdateClient(TASK_MSG, "GTInitCassettePoints: middle cassette points are not valid!", ERROR_LEVEL)
		Exit Function
	EndIf
	
	'' Check Right Cassette Points P36, P43 and P46
	If Not (GTCheckPoint(36) Or GTCheckPoint(43) Or GTCheckPoint(46)) Then
		UpdateClient(TASK_MSG, "GTInitCassettePoints: right cassette points are not valid!", ERROR_LEVEL)
		Exit Function
	EndIf

	'' Setup location and required angles for each cassette
	If Not (GTSetupCassetteAllProperties(LEFT_CASSETTE) Or GTSetupCassetteAllProperties(MIDDLE_CASSETTE) Or GTSetupCassetteAllProperties(RIGHT_CASSETTE)) Then
		UpdateClient(TASK_MSG, "GTInitCassettePoints: error in GTSetupCassetteAllProperties!", ERROR_LEVEL)
		Exit Function
	EndIf
	
	GTInitCassettePoints = True
Fend

Function GTInitGoniometerPoints() As Boolean
 	'' Check Point P20
	If GTCheckPoint(20) Then
		'' P20 is pointing towards Gonio, so Gonio orientation is 180 degrees from CU(P20)
		g_goniometer_Angle = CU(P20) + 180
		g_goniometer_cosValue = Cos(DegToRad(g_goniometer_Angle))
		g_goniometer_sinValue = Sin(DegToRad(g_goniometer_Angle))
		
		UpdateClient(TASK_MSG, "GTInitGoniometerPoints completed.", INFO_LEVEL)
		GTInitGoniometerPoints = True
	Else
		UpdateClient(TASK_MSG, "GTInitGoniometerPoints: error in GTCheckPoint!", ERROR_LEVEL)
		GTInitGoniometerPoints = False
	EndIf
Fend

Function GTInitAllPoints() As Boolean

	If Not GTInitBasicPoints() Then
		g_RunResult$ = "GTInitAllPoints: error in GTInitBasicPoints!"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		GTInitAllPoints = False
		Exit Function
	EndIf
	
	If Not GTInitMagnetPoints() Then
		g_RunResult$ = "GTInitAllPoints: error in GTInitMagnetPoints!"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		GTInitAllPoints = False
		Exit Function
	EndIf
	
	If Not GTInitCassettePoints() Then
		g_RunResult$ = "GTInitAllPoints: error in GTInitCassettePoints!"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		GTInitAllPoints = False
		Exit Function
	EndIf
	
	If Not GTInitGoniometerPoints() Then
		g_RunResult$ = "GTInitAllPoints: error in GTInitGoniometerPoints!"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		GTInitAllPoints = False
		Exit Function
	EndIf
	
	SavePoints "robot1.pts"
	g_RunResult$ = "Success GTInitAllPoints"
	UpdateClient(TASK_MSG, g_RunResult$, INFO_LEVEL)
	GTInitAllPoints = True
Fend

