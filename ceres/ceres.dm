

//------------------------------------------------------------------------------

#define CLONER_CHANNEL "channel"
#define CLONER_PRIVATE "private"
#define CHAR_LIMIT 400

world/mob = /ceres

ceres
	Login()
		. = ..()
		client.show_popup_menus = FALSE
	Logout()
		. = ..()
		del src
	Del()
		if(user)
			user.drop()
		. = ..()

ceres
	parent_type = /mob
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
			winset(src, null, "command=.quit")
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

ceres/proc

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


//-- Message Handling ----------------------------------------------------------

ceres
	proc

		receive(artemis/msg/msg) // Unrefactored
			. = TRUE
			//
			var tabName
			var tabTarget
			if(msg.channel)
				tabName = msg.channel.name
				tabTarget = msg.channel
			else
				tabName = "pm_[msg.sender.nameFull]"
				tabTarget = msg.sender
			if(!(tabName in namedRooms))
				roomAdd(tabTarget, FALSE)
			//
			var formattedText
			switch(msg.action)
				if(ARTEMIS_ACTION_TRAFFIC)
					formattedText = handleTraffic(msg.channel, msg)
					if(!preferences.traffic) return
					if(!formattedText) return
				if(ARTEMIS_ACTION_MESSAGE)
					if(!msg.body) return
					formattedText = formatUser(msg.sender, msg.body, msg.time)
					roomFlash(tabName)
				if(ARTEMIS_ACTION_EMOTE)
					if(!msg.body) return
					formattedText = formatEmote(msg.sender, msg.body, msg.time)
					roomFlash(tabName)
				if(ARTEMIS_ACTION_DENIED)
					if(!msg.body) return
					formattedText = formatSystem(msg.body, msg.time)
					roomFlash(tabName)
				if(ARTEMIS_ACTION_CODE)
					if(!msg.body) return
					var /ceres/codeMessage/cm = new(msg)
					codeMessages += cm
					formattedText = formatUsercode(msg.sender, cm, msg.time)
					roomFlash(tabName)
			//
			var /ceres/room/hearRoom = getRoomByName(tabName)
			hearRoom.hear(formattedText)

		echo(artemis/msg/msg)
			//
			var tabName
			var tabTarget
			if(msg.channel)
				tabName = msg.channel.name
				tabTarget = msg.channel
			else
				tabName = "pm_[msg.target.nameFull]"
				tabTarget = msg.target
			if(!(tabName in namedRooms))
				roomAdd(tabTarget, FALSE)
			//
			var formattedText
			switch(msg.action)
				if(ARTEMIS_ACTION_MESSAGE)
					if(!msg.body) return
					formattedText = formatUser(user, msg.body, msg.time)
					roomFlash(tabName)
				if(ARTEMIS_ACTION_EMOTE)
					if(!msg.body) return
					formattedText = formatEmote(user, msg.body, msg.time)
					roomFlash(tabName)
				if(ARTEMIS_ACTION_CODE)
					if(!msg.body) return
					var /ceres/codeMessage/cm = new(msg)
					codeMessages += cm
					formattedText = formatUsercode(user, cm, msg.time)
					roomFlash(tabName)
			//
			var /ceres/room/hearRoom = getRoomByName(tabName)
			hearRoom.hear(formattedText)

		handleTraffic(artemis/channel/trafficChannel, artemis/msg/msg) // Unrefactored
			var/list/params = params2list(msg.body)
			var/info
			var/index = params[1]
			var/value = params[index]
			switch(index)
				if("nick")
					if(!preferences.view_nicks) return
					var/colon_pos = findtextEx(value, ":")
					if(!colon_pos || colon_pos == 1) return
					var/user_name = copytext(value, 1, colon_pos)
					var/artemis/user/U = artemis.getUser(user_name)
					if(!U) return
					var/old_nick = copytext(value, colon_pos+1)
					if(old_nick){ info = {" ([old_nick])"}}
					var/full_span = "&lt;[U.nameFull]&gt;"
					var/new_nick = U.nickname? html_encode(U.nickname) : full_span
					info = {"[full_span][info] is now known as [new_nick]"}
					updateWhogrid(trafficChannel)
				if("join")
					var/artemis/user/U = artemis.getUser(value)
					if(!U){ return}
					if(preferences.view_nicks && U.nickname)
						info = {"[html_encode(U.nickname)] "}
					info = {"[info]&lt;[U.nameFull]&gt; has connected."}
					updateWhogrid(trafficChannel)
				if("leave")
					var/artemis/user/U = artemis.getUser(value)
					if(!U) return
					if(preferences.view_nicks && U.nickname)
						info = {"[html_encode(U.nickname)] "}
					info = {"[info]&lt;[U.nameFull]&gt; has disconnected."}
					updateWhogrid(trafficChannel)
				if("topic")
					var/capitol = uppertext(copytext(value,1,2)) // HACK
					var/rest = copytext(value, 2) // HACK
					winset(src, "[trafficChannel.name].topic", "text=' [capitol][rest]';")
					return
				if("user")
					var/colon_pos = findtextEx(value, ":")
					if(!colon_pos || colon_pos == 1) return
					var/user_name = copytext(value, 1, colon_pos)
					var/artemis/user/U = artemis.getUser(user_name)
					if(!U) return
					var/_tier = text2num(copytext(value, colon_pos+1))
					if(!isnum(_tier)) return
					var/tiers = list("Blocked", "Muted", "Normal", "Voiced", "Operator", "Owner")
					var/permission_tier = tiers[_tier+1]
					if(preferences.view_nicks && U.nickname)
						info = {"[html_encode(U.nickname)] "}
					info = {"[info]&lt;[U.nameFull]&gt; permission has been set to: [permission_tier]"}
					updateWhogrid(trafficChannel)
				if("status")
					info = {"Channel status has been set to:"}
					var/new_status = text2num(value)
					var/normal = TRUE
					if(new_status & ARTEMIS_STATUS_CLOSED){ info += " CLOSED"; normal = FALSE}
					if(new_status & ARTEMIS_STATUS_LOCKED){ info += " LOCKED"; normal = FALSE}
					if(new_status & ARTEMIS_STATUS_HIDDEN){ info += " HIDDEN"; normal = FALSE}
					if(normal)
						info += " NORMAL"
			if(!info) return
			var/time_stamp = {""}
			var/body_span = {"<span class="traffic">[info]</span>"}
			if(preferences.time_stamps)
				time_stamp = time2stamp(msg.time, preferences.time_zone + preferences.daylight)
				time_stamp = {"<span class="time_stamp"><span class="traffic">[time_stamp]</span></span>"}
			return {"[time_stamp] [body_span]"}

//-- Utility Class -------------------------------
ceres
	var
		list/codeMessages = new()
	codeMessage
		parent_type = /datum
		var
			id
			code
			sender
		New(artemis/msg/_msg)
			id = rand(1,9999)
			code = _msg.body
			sender = _msg.sender
			spawn(3000)
				del src
