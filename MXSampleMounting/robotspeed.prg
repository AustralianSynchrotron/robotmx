#include "mxrobotdefs.inc"
#include "genericdefs.inc"

Integer m_previousAcceleration, m_previousDeceleration
Real m_previousStraightAcceleration, m_previousStraightDeceleration
Integer m_previousSpeedSetting
Real m_previousStraightSpeedSetting

Function GTSaveCurrentRobotSpeedMode
	m_previousAcceleration = Accel(1)
	m_previousDeceleration = Accel(2)
	m_previousSpeedSetting = Speed(1)

	m_previousStraightAcceleration = AccelS(1)
	m_previousStraightDeceleration = AccelS(2)
	m_previousStraightSpeedSetting = SpeedS(1)
Fend

Function GTsetRobotSpeedMode(speed_mode As Byte)
	GTSaveCurrentRobotSpeedMode
	
	Select speed_mode
		Case ULTRA_SLOW_SPEED
			SetUltraSlowSpeed
			
		Case VERY_SLOW_SPEED
			SetVerySlowSpeed
			
		Case FAST_SPEED
			SetFastSpeed
	Send
Fend

Function GTLoadPreviousRobotSpeedMode
	Accel m_previousAcceleration, m_previousDeceleration
	Speed m_previousSpeedSetting
	
	AccelS m_previousStraightAcceleration, m_previousStraightDeceleration
	SpeedS m_previousStraightSpeedSetting
Fend


