'' Cassette Position
#define LEFT_CASSETTE 0
#define MIDDLE_CASSETTE 1
#define RIGHT_CASSETTE 2
#define NUM_CASSETTES 3

'' Cassette Type
#define UNKNOWN_CASSETTE 0	'' Unknown cassette, Cassette Absent, Cassette Problem
#define CALIBRATION_CASSETTE 1
#define NORMAL_CASSETTE 2
#define SUPERPUCK_CASSETTE 3

'' Toolset Names
#define UNIVERSAL_TOOL 0
#define PICKER_TOOL 1
#define PLACER_TOOL 2

'' PORT Properties
#define SAMPLE_ABSENT False
#define SAMPLE_PRESENT True

'' Could be CASSETTE_SHRINK_IN_LN2
#define CASSETTE_SHRINK_FACTOR 1.0

#define PROBE_STANDBY_DISTANCE 5.0
'' Acceptable error in cassette height in mm
#define ACCPT_ERROR_IN_CASSETTE_HEIGHT 0.4
'' Retry Threshold for height in mm
#define MAX_ERR_FOR_SCAN_CAS_TYPE_RTRY 1.4
