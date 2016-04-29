#include "mxrobotdefs.inc"
#include "genericdefs.inc"
#include "robotspeed.inc"

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

Function SetSuperSlowSpeed
	Accel SUPERSLOW_GO_ACCEL, SUPERSLOW_GO_DEACCEL
    Speed SUPERSLOW_GO_SPEED
    
    AccelS SUPERSLOW_MOVE_ACCEL, SUPERSLOW_MOVE_DEACCEL
    SpeedS SUPERSLOW_MOVE_SPEED
Fend

Function SetProbeSpeed
	Accel PROBE_GO_ACCEL, PROBE_GO_DEACCEL
    Speed PROBE_GO_SPEED
    
    AccelS PROBE_MOVE_ACCEL, PROBE_MOVE_DEACCEL
    SpeedS PROBE_MOVE_SPEED
Fend

Function SetSampleOnTongSpeed
	Accel SAMPLE_ON_TONG_GO_ACCEL, SAMPLE_ON_TONG_GO_DEACCEL
    Speed SAMPLE_ON_TONG_GO_SPEED
    
    AccelS SAMPLE_ON_TONG_MOVE_ACCEL, SAMPLE_ON_TONG_MOVE_DEACCEL
    SpeedS SAMPLE_ON_TONG_MOVE_SPEED
Fend

Function SetInsideLN2Speed
	Accel Inside_Ln2_GO_ACCEL, INSIDE_LN2_GO_DEACCEL
    Speed INSIDE_LN2_GO_SPEED
    
    AccelS INSIDE_LN2_MOVE_ACCEL, INSIDE_LN2_MOVE_DEACCEL
    SpeedS INSIDE_LN2_MOVE_SPEED
Fend

Function SetOutsideLN2Speed
	Accel OUTSIDE_Ln2_GO_ACCEL, OUTSIDE_LN2_GO_DEACCEL
    Speed OUTSIDE_LN2_GO_SPEED
    
    AccelS OUTSIDE_LN2_MOVE_ACCEL, OUTSIDE_LN2_MOVE_DEACCEL
    SpeedS OUTSIDE_LN2_MOVE_SPEED
Fend

Function SetRobotDanceSpeed
	Accel ROBOT_DANCE_GO_ACCEL, ROBOT_DANCE_GO_DEACCEL
    Speed ROBOT_DANCE_GO_SPEED
    
    AccelS ROBOT_DANCE_MOVE_ACCEL, ROBOT_DANCE_MOVE_DEACCEL
    SpeedS ROBOT_DANCE_MOVE_SPEED
Fend

Function GTsetRobotSpeedMode(speed_mode As Byte)
	GTSaveCurrentRobotSpeedMode
	
	Select speed_mode
		Case PROBE_SPEED
			SetProbeSpeed
			
		Case SAMPLE_ON_TONG_SPEED
			SetSampleOnTongSpeed ''Inside LN2 only
			
		Case INSIDE_LN2_SPEED
			SetInsideLN2Speed
			
		Case OUTSIDE_LN2_SPEED
			SetOutsideLN2Speed
			
		Case SUPERSLOW_SPEED
			SetSuperSlowSpeed
			
		Case DANCE_SPEED
			SetRobotDanceSpeed
	Send
Fend

Function GTLoadPreviousRobotSpeedMode
	Accel m_previous_Go_Acceleration, m_previous_Go_Deceleration
	Speed m_previous_Go_SpeedSetting
	
	AccelS m_previous_Move_Acceleration, m_previous_Move_Deceleration
	SpeedS m_previous_Move_SpeedSetting
Fend

