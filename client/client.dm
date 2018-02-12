
/*
mob/Logout()
		drop the user, and stuff
*/


//------------------------------------------------------------------------------

#define CLONER_CHANNEL "channel"
#define CLONER_PRIVATE "private"
#define CHAR_LIMIT 400

client
	var
		relay/user/user
		utOffset = -5

	New()
		set waitfor = FALSE
		.=..()
		sleep(10)
		var userName = relay.validId(ckey)
		var result = relay.registerUser(userName)
		if(result != RESULT_SUCCESS)
			alert(src, {"The server has denied registration for the user "[userName]". Error [result]"})
			//winset(src, null, "command=.quit")
			//del src
		user = relay.getUser(userName)
		if(!user)
			alert(src, {"There has been a registration error with your username "[userName]"."})
			//winset(src, null, "command=.quit")
			//del src
		user.intelligence = src
		preferencesLoad()
		sleep(5)
		//var/pref_body = {"nickname=[key]"}
		//if(user.color_name){ pref_body += {"color_name=[user.color_name]"}}
		//if(user.color_text){ pref_body += {"color_text=[user.color_text]"}}
		//user.msg(SYSTEM, ACTION_PREFERENCES, pref_body)
		if(preferences.home_channel)
			join(preferences.home_channel)
		else
			join(CHANNEL_DEFAULT)

client/proc

	time2stamp(_stamp, _offset)
		_stamp += (_offset-utOffset)*36000
		var/tpd = 864000
		while(_stamp > tpd){ _stamp -= tpd}
		while(_stamp < 0  ){ _stamp += tpd}
		return time2text(_stamp, "\[hh:mm\]")

	text2bool(string)
		if(isnum(string)) return string
		string = lowertext(string)
		switch(string)
			if("true" ,"1") return TRUE
			if("false","0") return FALSE
			else            return TRUE

	bool2text(number)
		if(istext(number)) return number
		if(number) return "true"
		else       return "false"