

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
#define MAX_HANDLE_LENGTH 12
	// The max length of a relay (server) name
#define CHANNEL_DEFAULT "Artemis"

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

#define RESULT_NOTARTEMIS 1
#define RESULT_SUCCESS 2
#define RESULT_FAILURE 3
#define ACTION_MALFORMED 4
#define ACTION_COLLISION 5
#define RESULT_NONEXIST 6
#define ACTION_UNREACHABLE 7
//#define ACTION_DEATH 8

#define ACTION_PING 10
#define ACTION_REGSERVER 11
#define ACTION_DISCONNECT 12
#define ACTION_REGUSER 13
#define ACTION_BADUSER 14
#define ACTION_CONFLICT 15
#define ACTION_CHANSYNC 16

#define ACTION_DENIED 33
// Message Types I'm sure the user can send:
#define ACTION_MESSAGE 30
#define ACTION_JOIN 31
#define ACTION_LEAVE 32
#define ACTION_OPERATE 34
#define ACTION_NICKNAME 35
#define ACTION_TRAFFIC 36
#define ACTION_EMOTE 37
#define ACTION_CODE 38

//-- Useful diagnostic functions -----------------

#define LINE world << {"<span style="color:#800">[__FILE__]:[__LINE__]</span>"};

#define DIAG(X) world << {"<span style="color:red">[__FILE__]:[__LINE__]:: [X]</span>"};;

#define ALERT(X) for(var/client/C){ alert(C,X)}