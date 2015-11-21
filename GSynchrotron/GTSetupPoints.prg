#include "mxrobotdefs.inc"
#include "GTCassettedefs.inc"

Function GTCheckPoint(pointNum As Integer, ByRef StatusStringToAppend$ As String) As Boolean
	If (Not PDef(P(pointNum))) Then
		StatusStringToAppend$ = StatusStringToAppend$ + "GTCheckPoint: P" + Str$(pointNum) + " is not defined yet!"
		GTCheckPoint = False
	ElseIf CX(P(pointNum)) = 0 Or CY(P(pointNum)) = 0 Then
		StatusStringToAppend$ = StatusStringToAppend$ + "GTCheckPoint: P" + Str$(pointNum) + " has X or Y coordinate set to 0(zero)!"
		GTCheckPoint = False
	Else
		GTCheckPoint = True
	EndIf
Fend

Function GTCheckTool(toolNum As Integer, ByRef StatusStringToAppend$ As String) As Boolean
	P51 = TLSet(toolNum)
	If CX(P51) = 0 Or CY(P51) = 0 Or CU(P51) = 0 Then
		StatusStringToAppend$ = StatusStringToAppend$ + "GTCheckTool: Tool(" + Str$(toolNum) + ") is not defined yet!"
		GTCheckTool = False
	Else
		GTCheckTool = True
	EndIf
Fend

Function GTInitBasicPoints(ByRef StatusStringToAppend$ As String) As Boolean
 	String GTCheckPointStatus$
 	'' Check Points P0, P1 and P18
	If GTCheckPoint(0, ByRef GTCheckPointStatus$) And GTCheckPoint(1, ByRef GTCheckPointStatus$) And GTCheckPoint(18, ByRef GTCheckPointStatus$) Then
		GTInitBasicPoints = True
	Else
		StatusStringToAppend$ = "GTInitBasicPoints->" + GTCheckPointStatus$
		GTInitBasicPoints = False
	EndIf
Fend

Function GTInitMagnetPoints(ByRef StatusStringToAppend$ As String) As Boolean
	String GTCheckPointStatus$
 	'' Check Points P6, P16 and P26
	If Not (GTCheckPoint(6, ByRef GTCheckPointStatus$) Or GTCheckPoint(16, ByRef GTCheckPointStatus$) Or GTCheckPoint(26, ByRef GTCheckPointStatus$)) Then
    	StatusStringToAppend$ = "GTInitMagnetPoints->" + GTCheckPointStatus$
		GTInitMagnetPoints = False
		Exit Function
	EndIf
	
	'' Check Points P10, P11 and P12
	If Not (GTCheckPoint(10, ByRef GTCheckPointStatus$) Or GTCheckPoint(11, ByRef GTCheckPointStatus$) Or GTCheckPoint(12, ByRef GTCheckPointStatus$)) Then
		StatusStringToAppend$ = "GTInitMagnetPoints->" + GTCheckPointStatus$
		GTInitMagnetPoints = False
		Exit Function
	EndIf
	
	String GTCheckToolStatus$
	'' Check Tool 1 (pickerTool) and Tool 2 (placerTool)
	If Not (GTCheckTool(1, ByRef GTCheckToolStatus$) Or GTCheckTool(2, ByRef GTCheckToolStatus$)) Then
		StatusStringToAppend$ = "GTInitMagnetPoints->" + GTCheckToolStatus$
		GTInitMagnetPoints = False
		Exit Function
	EndIf
	
	
	'' Above required Points and Tools are defined. Start deriving magnet points
	'' dumbbell Orientation in World Coordinates when dumbbell is on cradle
	g_dumbbell_Perfect_Angle = GTAngleToPerfectOrientationAngle(CU(P6))
	g_dumbbell_Perfect_cosValue = Cos(DegToRad(g_dumbbell_Perfect_Angle))
	g_dumbbell_Perfect_sinValue = Sin(DegToRad(g_dumbbell_Perfect_Angle))
	
	'' Cooling Point: 20mm in the perpendicular direction from center of dumbbell
	P3 = P6 +X(20.0 * -g_dumbbell_Perfect_sinValue) +Y(20.0 * g_dumbbell_Perfect_cosValue)

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
	
	GTInitMagnetPoints = True
Fend

Function GTInitCassettePoints(ByRef StatusStringToAppend$ As String) As Boolean
	String GTCheckPointStatus$
	
 	'' Check Point P6: dumbbell cradle needed to decided cassette orientation
	If Not GTCheckPoint(6, ByRef GTCheckPointStatus$) Then
		StatusStringToAppend$ = "GTInitCassettePoints->" + GTCheckPointStatus$
		GTInitCassettePoints = False
		Exit Function
	EndIf
	
	'' Check Left Cassette Points P34, P41 and P44
	If Not (GTCheckPoint(34, ByRef GTCheckPointStatus$) Or GTCheckPoint(41, ByRef GTCheckPointStatus$) Or GTCheckPoint(44, ByRef GTCheckPointStatus$)) Then
		StatusStringToAppend$ = "GTInitCassettePoints->" + GTCheckPointStatus$
		GTInitCassettePoints = False
		Exit Function
	EndIf
	
	'' Check Middle Cassette Points P35, P42 and P45
	If Not (GTCheckPoint(35, ByRef GTCheckPointStatus$) Or GTCheckPoint(42, ByRef GTCheckPointStatus$) Or GTCheckPoint(45, ByRef GTCheckPointStatus$)) Then
		StatusStringToAppend$ = "GTInitCassettePoints->" + GTCheckPointStatus$
		GTInitCassettePoints = False
		Exit Function
	EndIf
	
	'' Check Right Cassette Points P36, P43 and P46
	If Not (GTCheckPoint(36, ByRef GTCheckPointStatus$) Or GTCheckPoint(43, ByRef GTCheckPointStatus$) Or GTCheckPoint(46, ByRef GTCheckPointStatus$)) Then
		StatusStringToAppend$ = "GTInitCassettePoints->" + GTCheckPointStatus$
		GTInitCassettePoints = False
		Exit Function
	EndIf

	'' Setup location and required angles for each cassette
	String SetupCassetteStatus$
	If Not (GTSetupCassetteAllProperties(LEFT_CASSETTE, ByRef SetupCassetteStatus$) Or GTSetupCassetteAllProperties(MIDDLE_CASSETTE, ByRef SetupCassetteStatus$) Or GTSetupCassetteAllProperties(RIGHT_CASSETTE, ByRef SetupCassetteStatus$)) Then
		StatusStringToAppend$ = "GTInitCassettePoints->" + SetupCassetteStatus$
		GTInitCassettePoints = False
		Exit Function
	EndIf
	
	GTInitCassettePoints = True
Fend

Function GTInitAllPoints() As Boolean
	String GTInitBasicPointsStatus$
	If Not GTInitBasicPoints(ByRef GTInitBasicPointsStatus$) Then
		g_RunResult$ = "Error GTInitAllPoints->" + GTInitBasicPointsStatus$
		GTInitAllPoints = False
		Exit Function
	EndIf
	
	String GTInitMagnetPointsStatus$
	If Not GTInitMagnetPoints(ByRef GTInitMagnetPointsStatus$) Then
		g_RunResult$ = "Error GTInitAllPoints->" + GTInitMagnetPointsStatus$
		GTInitAllPoints = False
		Exit Function
	EndIf
	
	String GTInitCassettePointsStatus$
	If Not GTInitCassettePoints(ByRef GTInitCassettePointsStatus$) Then
		g_RunResult$ = "Error GTInitAllPoints->" + GTInitCassettePointsStatus$
		GTInitAllPoints = False
		Exit Function
	EndIf
	
	g_RunResult$ = "Success GTInitAllPoints executed successfully."
	GTInitAllPoints = True
Fend

