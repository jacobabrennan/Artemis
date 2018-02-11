

//-- Global Defines - Macros, Configuration, and Values ------------------------

//-- Useful headers, 50 & 80 characters long -----

//------------------------------------------------

//------------------------------------------------------------------------------

//       1         2         3         4         5         6         7         8
//345678901234567890123456789012345678901234567890123456789012345678901234567890

//------------------------------------------------------------------------------

//-- Relay Configuration & Metrics ---------------

#define SYSTEM "system"
#define PROTOCOL_VERSION "0.3"
#define MAX_HANDLE_LENGTH 8
	// The max length of a relay (server) name

//-- Channel Status Flags ------------------------

#define STATUS_NORMAL 0
#define STATUS_CLOSED 1
#define STATUS_HIDDEN 2
#define STATUS_LOCKED 4

//-- User Permission levels with Channels --------

#define PERMISSION_OWNER 5
#define PERMISSION_OPERATOR 4
#define PERMISSION_VOICED 3
#define PERMISSION_NORMAL 2
#define PERMISSION_MUTED 1
#define PERMISSION_BLOCKED 0
#define PERMISSION_ACTIVEFLAG 16

//-- Message Types and Return Codes---------------
// Needs refactoring to clarify the two

#define ACTION_SUCCESS 1
#define ACTION_FAILURE 2
#define ACTION_MALFORMED 3
#define ACTION_COLLISION 4
#define ACTION_NONEXIST 5
#define ACTION_UNREACHABLE 6
//#define ACTION_DEATH 8

#define ACTION_PING 10
#define ACTION_REGSERVER 11
#define ACTION_SERVERUPDATE 12
#define ACTION_DISCONNECT 13
#define ACTION_REGUSER 14
#define ACTION_BADUSER 15
#define ACTION_CONFLICT 16
#define ACTION_CHANSYNC 17

#define ACTION_DENIED 33
// Message Types I'm sure the user can send:
#define ACTION_MESSAGE 30
#define ACTION_JOIN 31
#define ACTION_LEAVE 32
#define ACTION_OPERATE 34
#define ACTION_NICKNAME 35
#define ACTION_PREFERENCES 35
#define ACTION_TRAFFIC 36
#define ACTION_EMOTE 37
#define ACTION_CODE 38

//-- Useful diagnostic functions -----------------

#define LINE world << {"<span style="color:#800">[__FILE__]:[__LINE__]</span>"};

#define DIAG(X) world << {"<span style="color:red">[__FILE__]:[__LINE__]:: [X]</span>"};;
