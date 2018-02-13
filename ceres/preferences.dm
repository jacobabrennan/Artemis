

//-- Preprocessor - See end of file for namespace cleanup ----------------------

#define CERES_PREFERENCES_VERSION 3

#define CERES_PATH_PREFERENCES "data/preferences"

#define CERES_LOAD_KEY(theKey) theKey = objectData[#theKey]
#define CERES_SAVE_KEY(theKey) objectData[#theKey] = theKey


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
				var artemis/channel/chanA = A
				return chanA.activeUsers.len - B.activeUsers.len


//------------------------------------------------------------------------------


//-- Message Handling ----------------------------------------------------------

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

//------------------------------------------------
ceres
	proc
		echo(artemis/msg/msg) // Unrefactored
			var/tab_channel
			var/artemis/user/target = artemis.getUser(msg.target)
			if(!target) return
			var/hash_pos = findtextEx(msg.target, "#")
			if(hash_pos)
				tab_channel = "#[copytext(msg.target, hash_pos+1)]"
			else
				tab_channel = target.nameFull
			if(!(tab_channel in rooms))
				roomAdd(tab_channel, FALSE)
			var/formatted_text
			switch(msg.action)
				if(ACTION_MESSAGE)
					if(!msg.body) return
					formatted_text = formatUser(user, msg.body, msg.time)
					roomFlash(tab_channel)
				if(ACTION_EMOTE)
					if(!msg.body) return
					formatted_text = formatEmote(user, msg.body, msg.time)
					roomFlash(tab_channel)
				if(ACTION_CODE)
					if(!msg.body) return
					var /ceres/codeMessage/cm = new(msg)
					codeMessages += cm
					formatted_text = formatUsercode(user, cm, msg.time)
					roomFlash(tab_channel)
			src << output(formatted_text, "[tab_channel].output")

		receive(var/artemis/msg/msg) // Unrefactored
			. = TRUE
			var/tab_channel
			var/artemis/user/sender = artemis.getUser(msg.sender)
			if(!sender) return
			var/hash_pos = findtextEx(msg.target, "#")
			if(hash_pos)
				tab_channel = "#[copytext(msg.target, hash_pos+1)]"
			else
				tab_channel = sender.nameFull
			if(!(tab_channel in rooms))
				roomAdd(tab_channel, FALSE)
			var/formatted_text
			switch(msg.action)
				if(ACTION_TRAFFIC)
					formatted_text = handleTraffic(tab_channel, msg)
					if(!preferences.traffic) return
					if(!formatted_text) return
				if(ACTION_MESSAGE)
					if(!msg.body) return
					formatted_text = formatUser(sender, msg.body, msg.time)
					roomFlash(tab_channel)
				if(ACTION_EMOTE)
					if(!msg.body) return
					formatted_text = formatEmote(sender, msg.body, msg.time)
					roomFlash(tab_channel)
				if(ACTION_DENIED)
					if(!msg.body) return
					formatted_text = formatSystem(msg.body, msg.time)
					roomFlash(tab_channel)
				if(ACTION_CODE)
					if(!msg.body) return
					var /ceres/codeMessage/cm = new(msg)
					codeMessages += cm
					formatted_text = formatUsercode(sender, cm, msg.time)
					roomFlash(tab_channel)
			src << output(formatted_text, "[tab_channel].output")

		handleTraffic(tab_channel, artemis/msg/msg) // Unrefactored
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
					updateWhogrid(tab_channel)
				if("join")
					var/artemis/user/U = artemis.getUser(value)
					if(!U){ return}
					if(preferences.view_nicks && U.nickname)
						info = {"[html_encode(U.nickname)] "}
					info = {"[info]&lt;[U.nameFull]&gt; has connected."}
					updateWhogrid(tab_channel)
				if("leave")
					var/artemis/user/U = artemis.getUser(value)
					if(!U) return
					if(preferences.view_nicks && U.nickname)
						info = {"[html_encode(U.nickname)] "}
					info = {"[info]&lt;[U.nameFull]&gt; has disconnected."}
					updateWhogrid(tab_channel)
				if("topic")
					var/capitol = uppertext(copytext(value,1,2)) // HACK
					var/rest = copytext(value, 2) // HACK
					winset(src, "[tab_channel].topic", "text=' [capitol][rest]';")
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
					updateWhogrid(tab_channel)
				if("status")
					info = {"Channel status has been set to:"}
					var/new_status = text2num(value)
					var/normal = TRUE
					if(new_status & STATUS_CLOSED){ info += " CLOSED"; normal = FALSE}
					if(new_status & STATUS_LOCKED){ info += " LOCKED"; normal = FALSE}
					if(new_status & STATUS_HIDDEN){ info += " HIDDEN"; normal = FALSE}
					if(normal)
						info += " NORMAL"
			if(!info) return
			var/time_stamp = {""}
			var/body_span = {"<span class="traffic">[info]</span>"}
			if(preferences.time_stamps)
				time_stamp = time2stamp(msg.time, preferences.time_zone + preferences.daylight)
				time_stamp = {"<span class="time_stamp"><span class="traffic">[time_stamp]</span></span>"}
			return {"[time_stamp] [body_span]"}


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
			var/message_span = {"<a href="?action=viewcode;code=\ref[cm];id=[cm.id];">Click to view Code</a>"}
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
				apply(var/ceres/who, chan_name) // Unrefactored
					if(!who) return
					var/style = style()
					var/list/_channels
					if(chan_name) _channels = list(chan_name)
					else _channels = who.rooms
					winset(who, "input", "background-color='[user_message]';text-color='[background]';font-family='[chat_font], fixedsys';font-size='[font_size]';")
					winset(who, "close", "background-color='[user_message]';text-color='[background]';font-family='[chat_font], fixedsys';font-size='[font_size]';")
					winset(who, "join", "background-color='[user_message]';text-color='[background]';font-family='[chat_font], fixedsys';font-size='[font_size]';")
					for(var/channel_name in _channels)
						if(copytext(channel_name, 1, 2) == "#")
							winset(who, "[channel_name].topic", "background-color='[background]';text-color='[user_message]'; font-family='[chat_font]';")
							winset(who, "[channel_name].who", "background-color='[background]';text-color='[user_message]';")
							winset(who, "[channel_name].who", "")
							who.updateGrid(channel_name)
						winset(who, "[channel_name].output", "background-color='[background]';style='[style]';")

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
			user.msg(SYSTEM, ACTION_NICKNAME, preferences.nickname)



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
				nicknameSend()
				return
			var savedPreferences = file2text(filePath)
			savedPreferences = json_decode(savedPreferences)
			preferences.fromJSON(savedPreferences)
			// Set Colors on User & artemis Nickname
			user.colorName = preferences.colorName
			user.colorText = preferences.colorText
			nicknameSend()

		preferencesSave()
			// Set Colors on User & artemis Nickname
			user.colorName = preferences.colorName
			user.colorText = preferences.colorText
			nicknameSend()
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


//-- Preprocessor Namespace Cleanup --------------------------------------------

// Refactored. None needed at this time.