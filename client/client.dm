
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
		artemis/user/user
		utOffset = -5

	New()
		set waitfor = FALSE
		.=..()
		sleep(10)
		user = artemis.addUser(ckey, src)
		if(!user)
			alert(src, {"There has been a registration error with your username "[ckey]"."})
			//winset(src, null, "command=.quit")
			del src
		preferencesLoad()
		if(preferences.home_channel)
			join(preferences.home_channel)
		else
			join(artemis.defaultChannel)
	Del()
		if(user)
			artemis.removeUser(user)
		. = ..()

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