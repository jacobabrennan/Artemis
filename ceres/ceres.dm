

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


//-- View Code Messages --------------------------------------------------------

ceres/preferences/skin
	proc
		codeStyle()
			return {"
			<style type="text/css">
				body{
					background:[background];
					}
				pre.code{
					color:[user_message];
					background:[background];
					margin:0.5em;
					}
				.comment{color:[traffic];}
				.preproc{color:[system];}
				.number{color:[user_message];}
				.ident{color:[user_message];}
				.keyword{color:[user];}
				.string{color:[time_stamp];}
			</style>
			"}

ceres
	Topic(href, list/hrefList, hsrc)
		.=..()
		//
		var action = hrefList["action"]
		switch(action)
		// Show Channel Stats
			if("stats")
				var/_channel = hrefList["channel"]
				if(!_channel) return
				if(!fexists("data/stats/[_channel].html")) return
				src << run(file("data/stats/[_channel].html"))
		// Show Code Messages
			if("viewcode")
				// Retrieve code message from \ref number
				var refNum = hrefList["code"]
				var /ceres/codeMessage/cm = locate(refNum)
				// Cancel out if not located or expired
				if(!cm)
					info("This code message has expired.")
					return
				var/_id = text2num(hrefList["id"])
				if(_id != cm.id)
					info("This code message has expired.")
					return
				// Display Code in the browser
				var/bodyText = "[cm.code]"
				bodyText = highlighter.HighlightCode(bodyText)
				var codeStyle = preferences.skin.codeStyle()
				bodyText = "<html><title>Code Viewer</title><head>[codeStyle]</head><body>[bodyText]</body></html>"
				src << browse(bodyText, "window=browser_code_viewer")