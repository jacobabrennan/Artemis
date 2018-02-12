

//-- Global Defines - Macros, Configuration, and Values ------------------------


//-- Useful headers, 50 & 80 characters long -----------------------------------
//       1         2         3         4         5         6         7         8
//345678901234567890123456789012345678901234567890123456789012345678901234567890

//------------------------------------------------

//------------------------------------------------------------------------------




//-- artemis & Metrics - NONCONFIGURABLE -----------------------------------------
#define SYSTEM "system"
#define PROTOCOL_VERSION "0.3"
#define MAX_HANDLE_LENGTH 12
	// The maximum length of a artemis (server) name
#define MAX_NAME_LENGTH 20
	// The maximum length of an unqualified user name


//-- This Belongs in a File somewhere ------------------------------------------

#define CHANNEL_DEFAULT "Artemis"


//-- Channel Status Flags ------------------------------------------------------

#define STATUS_NORMAL 0
// User can join and speak in the channel
#define STATUS_CLOSED 1
// Unvoiced users can't join the channel
#define STATUS_HIDDEN 2
// Channel doesn't appear in public lists
#define STATUS_LOCKED 4
// Unvoiced users can't speak in the channel


//-- User Permission levels with Channels --------------------------------------

#define PERMISSION_OWNER 5
// Can edit other users' permissions. Can assign Operator and Owner.
#define PERMISSION_OPERATOR 4
// Can edit other lower tier users' permissions
#define PERMISSION_VOICED 3
// Can speak when the channel is muted
#define PERMISSION_NORMAL 2
// Can speak except when the channel is muted
#define PERMISSION_MUTED 1
// Cannot speak in channel
#define PERMISSION_BLOCKED 0
// Cannot join channel
#define PERMISSION_ACTIVEFLAG 16
// User isn't AFK in this channel. (Unknown if current functional)




//-- Message Types and Return Codes---------------------------------------------
// Needs refactoring to clarify the two


//-- Return Codes (mostly) -----------------------------------------------------

#define RESULT_NOTARTEMIS 1
#define RESULT_SUCCESS 2
#define RESULT_FAILURE 3
#define RESULT_NONEXIST 4
//#define RESULT_UNREACHABLE 5
//#define RESULT_DEATH 6
#define RESULT_BADUSER 5
#define RESULT_CONFLICT 6
#define ACTION_MALFORMED 7
#define ACTION_COLLISION 8


//-- SYSTEM Commands -----------------------------------------------------------

#define ACTION_PING 10
// To ping a server
#define ACTION_CONNECT 11
// To connect to a remote server
#define ACTION_DISCONNECT 12
// To disconnect a remote server
#define ACTION_REGUSER 13
// To register a user
#define ACTION_DROPUSER 14
// To disconnect a user
#define ACTION_CHANSYNC 15
// To syncronize a channel's state on with a remote server


//-- End User facing Action ----------------------------------------------------

#define ACTION_MESSAGE 30
// A normal chat message
#define ACTION_JOIN 31
// A request to join a channel
#define ACTION_LEAVE 32
// A request to leave a channel
#define ACTION_DENIED 33
// Unknown
#define ACTION_OPERATE 34
// A request to operate on a channel
#define ACTION_NICKNAME 35
// A notification of change in user nickname
#define ACTION_TRAFFIC 36
// Info about changes to a channel
#define ACTION_EMOTE 37
// A request to show an "emote" message
#define ACTION_CODE 38
// A request to show a "code" message




//-- Useful diagnostic functions -----------------------------------------------

#define LINE world << {"<span style="color:#800">[__FILE__]:[__LINE__]</span>"};

#define DIAG(X) world << {"<span style="color:red">[__FILE__]:[__LINE__]:: [X]</span>"};;

#define ALERT(X) for(var/client/C){ alert(C,X)}