

//-- Global Defines - Macros, Configuration, and Values ------------------------


//-- Useful headers, 50 & 80 characters long -----------------------------------
//       1         2         3         4         5         6         7         8
//345678901234567890123456789012345678901234567890123456789012345678901234567890

//------------------------------------------------

//------------------------------------------------------------------------------




//-- artemis & Metrics - NONCONFIGURABLE ---------------------------------------
#define ARTEMIS_SYSTEM_NAME "system"
#define ARTEMIS_PROTOCOL_VERSION "0.4"
#define ARTEMIS_MAX_HANDLE_LENGTH 16
	// The maximum length of a artemis (server) name
#define ARTEMIS_MAX_NAME_LENGTH 32
	// The maximum length of an unqualified user name
#define ARTEMIS_MAX_NICKNAME_LENGTH 64
	// The maximum length of a user nickname
#define ARTEMIS_CHANNEL_DEFAULT "Artemis"
	// The default Channel Name if none is set
#define ARTEMIS_PATH_DATA "artemis_data"
	// Where Artemis configuration files are stored


//-- This Belongs in a File somewhere ------------------------------------------



//-- Channel Status Flags ------------------------------------------------------

#define ARTEMIS_STATUS_NORMAL 0
// User can join and speak in the channel
#define ARTEMIS_STATUS_CLOSED 1
// Unvoiced users can't join the channel
#define ARTEMIS_STATUS_HIDDEN 2
// Channel doesn't appear in public lists
#define ARTEMIS_STATUS_LOCKED 4
// Unvoiced users can't speak in the channel


//-- User Permission levels with Channels --------------------------------------

#define ARTEMIS_PERMISSION_OWNER 5
// Can edit other users' permissions. Can assign Operator and Owner.
#define ARTEMIS_PERMISSION_OPERATOR 4
// Can edit other lower tier users' permissions
#define ARTEMIS_PERMISSION_VOICED 3
// Can speak when the channel is muted
#define ARTEMIS_PERMISSION_NORMAL 2
// Can speak except when the channel is muted
#define ARTEMIS_PERMISSION_MUTED 1
// Cannot speak in channel
#define ARTEMIS_PERMISSION_BLOCKED 0
// Cannot join channel
#define ARTEMIS_PERMISSION_ACTIVEFLAG 16
// User is currently in channel




//-- Message Types and Return Codes---------------------------------------------


//-- Return Codes --------------------------------------------------------------

#define ARTEMIS_RESULT_NOTARTEMIS 1
#define ARTEMIS_RESULT_SUCCESS 2
#define ARTEMIS_RESULT_FAILURE 3
#define ARTEMIS_RESULT_NONEXIST 4
//#define ARTEMIS_RESULT_UNREACHABLE 5
//#define ARTEMIS_RESULT_DEATH 6
#define ARTEMIS_RESULT_BADUSER 5
#define ARTEMIS_RESULT_CONFLICT 6
#define ARTEMIS_RESULT_MALFORMED 7
#define ARTEMIS_RESULT_COLLISION 8


//-- SYSTEM Commands -----------------------------------------------------------

#define ARTEMIS_ACTION_PING 10
// To ping a server
#define ARTEMIS_ACTION_DISCONNECT 12
// To disconnect a remote server
#define ARTEMIS_ACTION_REGUSER 13
// To register a user
#define ARTEMIS_ACTION_DROPUSER 14
// To disconnect a user
#define ARTEMIS_ACTION_CHANSYNC 15
// To syncronize a channel's state on with a remote server


//-- End User facing Action ----------------------------------------------------

#define ARTEMIS_ACTION_MESSAGE 30
// A normal chat message
#define ARTEMIS_ACTION_JOIN 31
// A request to join a channel
#define ARTEMIS_ACTION_LEAVE 32
// A request to leave a channel
#define ARTEMIS_ACTION_DENIED 33
// Unknown
#define ARTEMIS_ACTION_OPERATE 34
// A request to operate on a channel
#define ARTEMIS_ACTION_NICKNAME 35
// A notification of change in user nickname
#define ARTEMIS_ACTION_TRAFFIC 36
// Info about changes to a channel
#define ARTEMIS_ACTION_EMOTE 37
// A request to show an "emote" message
#define ARTEMIS_ACTION_CODE 38
// A request to show a "code" message




//-- Useful diagnostic functions -----------------------------------------------

#define LINE world << {"<span style="color:#800">[__FILE__]:[__LINE__]</span>"};

#define DIAG(X) world << {"<span style="color:red">[__FILE__]:[__LINE__]:: [X]</span>"};;

#define ALERT(X) for(var/client/C){ alert(C,X)}