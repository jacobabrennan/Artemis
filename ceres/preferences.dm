

//-- QuickSort - Attributed to AbyssDragon -------
ceres
	proc
		quickSort(list/unsortedList, low = 1, high = -1)
			if(high == -1)
				high = unsortedList.len
			if(low >= high)
				return
			// Find Pivot (folded helper function into main function)
			var X = unsortedList[high]
			var I = low -1
			for(var/J = low to high -1)
				if(Compare(unsortedList[J], X) > 0)
					I++
					unsortedList.Swap(I, J)
			unsortedList.Swap(I+1, high)
			var pivot = I + 1
			//
			quickSort(unsortedList, low, pivot-1)
			quickSort(unsortedList, pivot+1, high)
			//
			return unsortedList


		Compare(ceres/whoMarker/A, artemis/channel/B)
			if(istype(A))
				var /ceres/whoMarker/markB = B
				return (A.tier - markB.tier)
			if(istype(B))
				var /artemis/channel/chanA = A
				return chanA.activeUsers.len - B.activeUsers.len


//------------------------------------------------------------------------------

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
				if(!fexists("[CERES_PATH_STATS]/[_channel].html")) return
				src << run(file("[CERES_PATH_STATS]/[_channel].html"))
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


//-- Output Formatting ---------------------------------------------------------

ceres
	proc
		/*format_channel(body, time) // Unrefactored
			body = html_encode(body)
			var/time_stamp = {""}
			var/body_span = {"<span class="traffic">[body]</span>"}
			if(preferences.time_stamps)
				time_stamp = time2stamp(time, preferences.time_zone + preferences.daylight)
				time_stamp = {"<span class="time_stamp"><span class="traffic">[time_stamp]</span></span>"}
			return {"[time_stamp] [body_span]"}*/

		formatSystem(body, time) // Unrefactored
			body = html_encode(body)
			return {"<span class="system">[body]</span>"}

		formatEmote(artemis/user/sender, body, time) // Unrefactored
			body = html_encode(body)
			var/using_nick = (sender.nickname && preferences.view_nicks)
			var/sender_span
			if(using_nick) sender_span = html_encode(sender.nickname)
			else sender_span = sender.nameFull
			var/message_span = linker.linkParse(body)
			if(preferences.show_colors || sender == user)
				sender_span  = {"<span style="color:[sender.colorName]">[sender_span ]</span>"}
				message_span = {"<span style="color:[sender.colorName]">[message_span]</span>"}
			if(using_nick)
				sender_span = {"<span class="user">[sender_span]</span>"}
			else
				sender_span = {"<span class="time_stamp">&lt;</span><span class="user">[sender_span]</span><span class="time_stamp">&gt;</span>"}
			message_span = {"<span class="emote">[message_span]</span>"}
			var/time_stamp = {""}
			if(preferences.time_stamps)
				time_stamp = time2stamp(time, preferences.time_zone + preferences.daylight)
				time_stamp = {"<span class="time_stamp">[time_stamp]</span>"}
			var/full_message = {"[time_stamp]<span class="emote"> *** [sender_span] [message_span]</emote>"}
			return full_message

		formatUser(artemis/user/sender, body, time) // Unrefactored
			body = html_encode(body)
			var/using_nick = (sender.nickname && preferences.view_nicks)
			var/sender_span
			if(using_nick){ sender_span = html_encode(sender.nickname)}
			else{ sender_span = sender.nameFull}
			var/message_span = linker.linkParse(body)
			if(preferences.show_colors || sender == user)
				sender_span  = {"<span style="color:[sender.colorName]">[sender_span ]</span>"}
				message_span = {"<span style="color:[sender.colorText]">[message_span]</span>"}
			var/separator = " "
			if(using_nick)
				sender_span = {"<span class="user"> [sender_span]</span>"}
				separator = {"<span class="time_stamp">: </span>"}
			else
				sender_span = {"<span class="time_stamp">&lt;</span><span class="user">[sender_span]</span><span class="time_stamp">&gt;</span>"}
			message_span = {"<span class="user_message">[message_span]</span>"}
			var/time_stamp = {""}
			if(preferences.time_stamps)
				time_stamp = time2stamp(time, preferences.time_zone + preferences.daylight)
				time_stamp = {"<span class="time_stamp">[time_stamp]</span>"}
			var/full_message = {"[time_stamp][sender_span][separator][message_span]"}
			return full_message

		formatUsercode(artemis/user/sender, ceres/codeMessage/cm, time) // Unrefactored
			var/using_nick = (sender.nickname && preferences.view_nicks)
			var/sender_span
			if(using_nick) sender_span = html_encode(sender.nickname)
			else sender_span = sender.nameFull
			var/message_span = {"<a href="?src=\ref[src];action=viewcode;code=\ref[cm];id=[cm.id];">Click to view Code</a>"}
			if(preferences.show_colors || sender == user)
				sender_span  = {"<span style="color:[sender.colorName]">[sender_span ]</span>"}
			var/separator = " "
			if(using_nick)
				sender_span = {"<span class="user"> [sender_span]</span>"}
				separator = {"<span class="time_stamp">: </span>"}
			else
				sender_span = {"<span class="time_stamp">&lt;</span><span class="user">[sender_span]</span><span class="time_stamp">&gt;</span>"}
			message_span = {"<span class="user_message">[message_span]</span>"}
			var/time_stamp = {""}
			if(preferences.time_stamps)
				time_stamp = time2stamp(time, preferences.time_zone + preferences.daylight)
				time_stamp = {"<span class="time_stamp">[time_stamp]</span>"}
			var/full_message = {"[time_stamp][sender_span][separator][message_span]"}
			return full_message


//-- Preferences ---------------------------------------------------------------

artemis/user
	var
		colorName
		colorText

ceres
	var
		ceres/preferences/preferences

	preferences
		parent_type = /datum
		var
			version = 1
			ceres/preferences/skin/skin
			// Nonconfigurable
			nickname
			home_channel
			colorName
			colorText
			view_nicks = TRUE
			time_stamps = TRUE
			traffic = TRUE
			show_colors = TRUE
			time_zone = -5
			daylight = FALSE
			// Internals
			ceres/ceres

		New(var/ceres/_client)
			.=..()
			ceres = _client
			nickname = ceres.client.key
			skin = new()

		//------------------------------------------------
		skin
			parent_type = /datum
			var
				version = 1
				name = "ceres"
				chat_font = "Fixedsys" //"Georgia"
				font_size = 12
				background = "#000"
				user_message = "#ffcb16" // class="user_message"
				user = "#fff" // class="user"
				traffic = "#396" // class="traffic"
				system = "#ccc" // class="system"
				time_stamp = "#999980" // class="time_stamp"

			proc
				apply(var/ceres/who, ceres/room/specificRoom)
					if(!who) return
					var/style = style()
					var/list/rooms
					if(specificRoom) rooms = list(specificRoom)
					else rooms = who.namedRooms
					winset(who, "input", "background-color='[user_message]';text-color='[background]';font-family='[chat_font], fixedsys';font-size='[font_size]';")
					winset(who, "close", "background-color='[user_message]';text-color='[background]';font-family='[chat_font], fixedsys';font-size='[font_size]';")
					winset(who, "join", "background-color='[user_message]';text-color='[background]';font-family='[chat_font], fixedsys';font-size='[font_size]';")
					for(var/ceres/room/styleRoom in rooms)
						if(istype(specificRoom.target, /artemis/channel))
							winset(who, "[styleRoom.name].topic", "background-color='[background]';text-color='[user_message]'; font-family='[chat_font]';")
							winset(who, "[styleRoom.name].who", "background-color='[background]';text-color='[user_message]';")
							winset(who, "[styleRoom.name].who", "")
							who.updateGrid(styleRoom)
						winset(who, "[styleRoom.name].output", "background-color='[background]';style='[style]';")

				style() // Unrefactored
					var/style = {"
						.system{
							color: [system];
							font-family: "[chat_font]", "Fixedsys";
							font-size: [font_size]pt;
							}
						.user_message{
							color: [user_message];
							font-family: "[chat_font]", "Fixedsys";
							font-size: [font_size]pt;
							}
						.user{
							color: [user];
							font-family: "[chat_font]", "Fixedsys";
							font-size: [font_size]pt;
							}
						.traffic{
							color: [traffic];
							font-family: "[chat_font]", "Fixedsys";
							font-size: [font_size]pt;
							font-style: italic;
							}
						.emote{
							color: [user];
							font-family: "[chat_font]", "Fixedsys";
							font-size: [font_size]pt;
							font-style: italic;
							}
						.time_stamp{
							color: [time_stamp];
							font-family: "[chat_font]", "Fixedsys";
							font-size: [font_size]pt;
							}
						"}
					return style

//------------------------------------------------
ceres
	proc
		nicknameSend()
			user.msg(artemis.SYSTEM, ARTEMIS_ACTION_NICKNAME, null, preferences.nickname)


//-- Preferences Saving & Loading ----------------------------------------------

//-- File Access ---------------------------------
ceres
	proc
		preferencesLoad()
			// Load preferences from File
			preferences = new(src)
			var filePath = "[CERES_PATH_PREFERENCES]/[ckey].json"
			if(!fexists(filePath))
				preferences.skin.apply(src)
				changeNick(preferences.nickname)
				return
			var savedPreferences = file2text(filePath)
			savedPreferences = json_decode(savedPreferences)
			preferences.fromJSON(savedPreferences)
			// Set Colors on User & artemis Nickname
			user.colorName = preferences.colorName
			user.colorText = preferences.colorText
			changeNick(preferences.nickname)

		preferencesSave()
			// Set Colors on User & artemis Nickname
			user.colorName = preferences.colorName
			user.colorText = preferences.colorText
			changeNick(preferences.nickname)
			// Save Preferences to File
			var /list/objectData = preferences.toJSON()
			var filePath = "[CERES_PATH_PREFERENCES]/[ckey].json"
			if(fexists(filePath))
				fdel(filePath)
			text2file(json_encode(objectData), filePath)

//-- JSON - encoding / decoding ------------------

ceres/preferences
	proc
		fromJSON(list/objectData)
			if(objectData["version"] > CERES_PREFERENCES_VERSION)
				return
			CERES_LOAD_KEY(nickname)
			CERES_LOAD_KEY(home_channel)
			CERES_LOAD_KEY(time_stamps)
			CERES_LOAD_KEY(traffic)
			CERES_LOAD_KEY(show_colors)
			CERES_LOAD_KEY(time_zone)
			CERES_LOAD_KEY(daylight)
			CERES_LOAD_KEY(colorName)
			CERES_LOAD_KEY(colorText)
			skin.fromJSON(objectData["skin"])
			skin.apply(ceres)

		toJSON()
			var /list/objectData = new()
			objectData["version"] = CERES_PREFERENCES_VERSION
			CERES_SAVE_KEY(nickname)
			CERES_SAVE_KEY(home_channel)
			CERES_SAVE_KEY(time_stamps)
			CERES_SAVE_KEY(traffic)
			CERES_SAVE_KEY(show_colors)
			CERES_SAVE_KEY(time_zone)
			CERES_SAVE_KEY(daylight)
			CERES_SAVE_KEY(colorName)
			CERES_SAVE_KEY(colorText)
			objectData["skin"] = skin.toJSON()
			return objectData

ceres/preferences/skin
	proc
		toJSON()
			var /list/objectData = new()
			objectData["version"] = CERES_PREFERENCES_VERSION
			CERES_SAVE_KEY(chat_font)
			CERES_SAVE_KEY(font_size)
			CERES_SAVE_KEY(background)
			CERES_SAVE_KEY(user_message)
			CERES_SAVE_KEY(user)
			CERES_SAVE_KEY(traffic)
			CERES_SAVE_KEY(system)
			CERES_SAVE_KEY(time_stamp)
			return objectData

		fromJSON(list/objectData)
			if(objectData["version"] > CERES_PREFERENCES_VERSION)
				return
			CERES_LOAD_KEY(chat_font)
			CERES_LOAD_KEY(font_size)
			CERES_LOAD_KEY(background)
			CERES_LOAD_KEY(user_message)
			CERES_LOAD_KEY(user)
			CERES_LOAD_KEY(traffic)
			CERES_LOAD_KEY(system)
			CERES_LOAD_KEY(time_stamp)
