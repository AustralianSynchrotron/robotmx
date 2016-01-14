#include "mxrobotdefs.inc"
#include "genericdefs.inc"

Integer m_previous_Go_Acceleration, m_previous_Go_Deceleration
Real m_previous_Move_Acceleration, m_previous_Move_Deceleration
Integer m_previous_Go_SpeedSetting
Real m_previous_Move_SpeedSetting

Function GTSaveCurrentRobotSpeedMode
	m_previous_Go_Acceleration = Accel(1); ''Print "go_acc=" + Str$(m_previous_Go_Acceleration);
	m_previous_Go_Deceleration = Accel(2); ''Print "go_dec=" + Str$(m_previous_Go_Deceleration);
	m_previous_Go_SpeedSetting = Speed(1); ''Print "go_speed=" + Str$(m_previous_Go_SpeedSetting);

	m_previous_Move_Acceleration = AccelS(1); ''Print "move_acc=" + Str$(m_previous_Move_Acceleration);
	m_previous_Move_Deceleration = AccelS(2); ''Print "move_dec=" + Str$(m_previous_Move_Deceleration);
	m_previous_Move_SpeedSetting = SpeedS(1); ''Print "move_speed=" + Str$(m_previous_Move_SpeedSetting);
Fend

Function GTsetRobotSpeedMode(speed_mode As Byte)
	GTSaveCurrentRobotSpeedMode
	
	Select speed_mode
		Case PROBE_SPEED
			SetProbeSpeed
			
		Case INSIDE_LN2_SPEED
			SetInsideLN2Speed
			
		Case OUTSIDE_LN2_SPEED
			SetOutsideLN2Speed
	Send
Fend

Function GTLoadPreviousRobotSpeedMode
	Accel m_previous_Go_Acceleration, m_previous_Go_Deceleration
	Speed m_previous_Go_SpeedSetting
	
	AccelS m_previous_Move_Acceleration, m_previous_Move_Deceleration
	SpeedS m_previous_Move_SpeedSetting
Fend

Function SetProbeSpeed
	Accel PROBE_GO_ACCEL, PROBE_GO_DEACCEL
    Speed PROBE_GO_SPEED
    
    AccelS PROBE_MOVE_ACCEL, PROBE_MOVE_DEACCEL
    SpeedS PROBE_MOVE_SPEED
Fend

Function SetInsideLN2Speed
	Accel Inside_Ln2_GO_ACCEL, INSIDE_LN2_GO_DEACCEL
    Speed INSIDE_LN2_GO_SPEED
    
    AccelS INSIDE_LN2_MOVE_ACCEL, INSIDE_LN2_MOVE_DEACCEL
    SpeedS INSIDE_LN2_MOVE_SPEED
Fend

Function SetOutsideLN2Speed
	Accel outside_Ln2_GO_ACCEL, outside_LN2_GO_DEACCEL
    Speed outside_LN2_GO_SPEED
    
    AccelS outside_LN2_MOVE_ACCEL, outside_LN2_MOVE_DEACCEL
    SpeedS outside_LN2_MOVE_SPEED
Fend

