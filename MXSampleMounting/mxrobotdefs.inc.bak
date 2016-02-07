''#define DEBUG
#define AUTO_SAVE_POINT True
''#define FINE_TUNE_PICKER
''#define FINE_TUNE_PLACER
#define BINARY_CROSS

''#define PUSH_MAGNET_ASIDE

''keep the same as C++
''this is for g_RobotStatus
#define FLAG_NEED_CLEAR &H00000001
#define FLAG_NEED_RESET &H00000002
#define FLAG_NEED_CAL_MAGNET &H00000004
#define FLAG_NEED_CAL_CASSETTE &H00000008
#define FLAG_NEED_CAL_GONIO &H00000010

#define FLAG_REASON_LID_JAM &H00001000
#define FLAG_REASON_GRIPPER_JAM &H00002000
#define FLAG_REASON_TOLERANCE &H00020000
#define FLAG_REASON_HEATER_FAIL &H00080000
#define FLAG_REASON_ABORT &H02000000

''for IOMinitor to send event to VB if lid is opened
#define OUT_GRIP 1
#define OUT_LID 3
#define OUT_DRY_AIR 13
#define OUT_HEATER 14
#define IN_GRIP_OPEN 8
#define IN_GRIP_CLOSE 9
#define IN_LID_CLOSE 11
#define IN_LID_OPEN 12
#define IN_HEATERHOT 13

''Ultra slow used for force moves in z
#define ULTRA_SLOW_GO_SPEED 2
#define ULTRA_SLOW_MOVE_SPEED 2

''slow used for force moves x and y
#define VERY_SLOW_GO_ACCEL 5
#define VERY_SLOW_GO_DEACCEL 5
''#define VERY_SLOW_GO_SPEED 1
#define VERY_SLOW_GO_SPEED 5
#define VERY_SLOW_MOVE_ACCEL 5
#define VERY_SLOW_MOVE_DEACCEL 5
''#define VERY_SLOW_MOVE_SPEED 1
#define VERY_SLOW_MOVE_SPEED 5

#define FAST_GO_ACCEL 20
#define FAST_GO_DEACCEL 20
#define FAST_GO_SPEED 10
#define FAST_MOVE_ACCEL 20
#define FAST_MOVE_DEACCEL 20
#define FAST_MOVE_SPEED 20

#define TIME_WAIT_BEFORE_RESET 2

#define LOG_FILE_NO 31
#define POINT_FILE_NO 41

'angle of force sensor axises from magnet (strong end)'
''we require Y =0, X= 90
''do not change even they are more than 10 degrees off,
''because the moving direction is depended on these
#define FS_XAXIS_ANGLE 90
#define FS_YAXIS_ANGLE 0
''moving direction definition:
''change relation between magnet and force sensor, also need
''change following constants

#ifdef FORCE_TORQUE_WRONG_DIRECTION
	#define DIRECTION_CAVITY_HEAD -FORCE_XTORQUE
	#define DIRECTION_CAVITY_TAIL FORCE_XTORQUE
	#define DIRECTION_MAGNET_TO_CAVITY FORCE_YTORQUE
	#define DIRECTION_CAVITY_TO_MAGNET -FORCE_YTORQUE
#else
	#define DIRECTION_CAVITY_HEAD FORCE_XTORQUE
	#define DIRECTION_CAVITY_TAIL -FORCE_XTORQUE
	#define DIRECTION_MAGNET_TO_CAVITY -FORCE_YTORQUE
	#define DIRECTION_CAVITY_TO_MAGNET FORCE_YTORQUE
#endif

#define DISTANCE_FROM_SEAT 10
#define H_DISTANCE_CAVITY_TO_GRIPPER 15.75
#define V_DISTANCE_CAVITY_TO_GRIPPER 0.29

''we really rely on following distance
#define HALF_OF_SEAT_THICKNESS 5
#define CAVITY_RADIUS 7.06
#define MAGNET_HEAD_RADIUS 4.72
#define MAGNET_LENGTH 35.6
#define MAGNET_HEAD_THICKNESS 3.55
#define FINGER_THICKNESS 2.5

''twist off center
#define SAMPLE_PIN_DEPTH 2.0

''if we did not fine tune X,Y, then we also depend on
#define PICKER_OVER_MAGNET_HEAD 3.0
#define PLACER_OVER_MAGNET_HEAD 3.0
#define GONIO_OVER_MAGNET_HEAD 3.0

#define SAFE_BUFFER_FOR_U_TURN 20
#define SAFE_BUFFER_FOR_RESET_FORCE 10
#define SAFE_BUFFER_FOR_DETACH 5
#define SAFE_BUFFER_FOR_GONIO_DETACH 1.3
#define SAFE_BUFFER_FOR_Z_TOUCH 5
''how much in Y direction the cavity overlap with magnet head
'' should be 2-3.55,
#define OVER_LAP_FOR_Z_TOUCH 3

''for positon after picker/placer calibration
#define STANDBY_DISTANCE 10

#define DISTANCE_BETWEEN_TWO_TOUCH 20

''more than detach+3.55+1, this is a value from experiment
''from touch magnet head in Y direction to touch holder arm in X direction
#define DISTANCE_TOUCH_ARM 8

#define DISTANCE_PLACER_FROM_MAGNET 40
''must greater than 32.75(seat length)+7.1(2*3.55(length of magnet head)

#define CRADLE_WIDTH 32.75
#define GRIPPER_WIDTH 17.25
''14.9-3.21  
''14.9 is 40(Prong) - 20(Seat:50-30) - 5(top of prong to center of ...) - 0.1(center of magnet to center of ...)
''(3.21 is bottom of gripper to magnet center)
#define Z_FROM_CRADLE_TO_MAGNET 11.69
#define Y_FROM_CRADLE_TO_MAGNET 2

''this is used to touch horizontal edges of cradle
''5(center of wall)+3.73(center of gripper)
#define OVERLAP_GRAPPER_CRADLE 8.75

#define MAX_POST_CAL_STEP 12

''requires that gripper is forced agaist the cradle holder.
''This function will rototate U to reduce the force "DIRECTION_CAVITY_TO_MAGNET"
''we have no clue that which way we should try, so we have to try both way at the
''beginning
''first stepsize will be 1 degree, then 0.1 degree, that is it.
#define PGC_MAX_SCAN_U 8
#define PGC_INIT_STEPSIZE 1
#define PGC_FINAL_STEPSIZE 0.1

#define POZ_MAX_STEPS 35
#define POZ_STEPSIZE 1

#define FIND_MAGNET_Z_DOWN 15

#define CASSETTE_STANDBY_DISTANCE 45
#define CASSETTE_RADIUS 32
#define CASSETTE_CAL_HEIGHT 135
#define CASSETTE_HEIGHT 130
#define CASSETTE_A1_HEIGHT 117
#define CASSETTE_EDGE_HEIGHT 8.5
#define CASSETTE_EDGE_DISTANCE 23.5
#define CASSETTE_SHRINK_IN_LN2 0.9961126827

''replaced by preserve global so they can be configured.
''ALS
''#define JUMP_LIMIT_IN_LN2 -80
''#define JUMP_LIMIT_FOR_MAGNET -80
''SSRL, APS
''#define JUMP_LIMIT_IN_LN2 -100
''#define JUMP_LIMIT_FOR_MAGNET -200

''this value is from BL9-1 to get max table high without collision
#define GONIO_X_SAFE_BUFFER 21
#define GONIO_X_SIDE 15

'''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' Accept Threshold
'''''''''''''''''''''''''''''''''''''''''''''''''''''''
''Z difference (unit:mm) between two heads of magnet holding by tong
#define ACCPT_THRHLD_MAGNET_LEVEL 0.4
''Z difference (unit:mm) between two heads of magnet in cradle
#define ACCPT_THRHLD_POST_LEVEL 0.5
''freedom for dumbbell in cradle
#define ACCPT_THRHLD_MAGNET_FREE_Y 0.6

''cassette tilt (unit:degree)
#define ACCPT_THRHLD_CASSETTE_TILT 1.0

''freedom between tong cavity and goniometer head
#define ACCPT_THRHLD_GONIO_FREEDOM 3.0

'''''''''''''''''''''''''''''''''''''''''''''''''''''
'' Strip dumbbell position from P6
'''''''''''''''''''''''''''''''''''''''''''''''''''''
#define STRIP_PLACER_X_OFFSET 1.0
#define STRIP_PLACER_Y_OFFSET 4.0
#define STRIP_PLACER_Z_OFFSET 61.5

''strip dumbbell Z offset for X touch out
#define STRIP_PLACER_LIFT_Z 5.0
#define STRIP_PULL_OUT_Z_RANGE 2.0
#define STRIP_PULL_OUT_Z_STEP 20

''#define NO_DEWAR_LID
''#define MIXED_ARM_ORIENTATION
''#define MIDDLE_CASSETTE_NOT_EXIST


