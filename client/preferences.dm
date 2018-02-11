

//------------------------------------------------------------------------------

//------------------------------------------------
relay/user
	var
		colorName
		colorText


//------------------------------------------------
client
	var
		list/code_messages = new()
	code_message
		parent_type = /datum
		var
			id
			code
			sender
		New(relay/msg/_msg)
			id = rand(1,9999)
			code = _msg.body
			sender = _msg.sender
			spawn(3000)
				del src

//------------------------------------------------
client
	proc

		echo(relay/msg/msg)
			var/tab_channel
			var/relay/user/target = relay.getUser(msg.target)
			if(!target) return
			var/hash_pos = findtextEx(msg.target, "#")
			if(hash_pos)
				tab_channel = "#[copytext(msg.target, hash_pos+1)]"
			else
				tab_channel = target.fullName
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
					var/client/code_message/cm = new(msg)
					code_messages += cm
					formatted_text = formatUsercode(user, cm, msg.time)
					roomFlash(tab_channel)
			src << output(formatted_text, "[tab_channel].output")

		receive(var/relay/msg/msg)
			. = TRUE
			var/tab_channel
			var/relay/user/sender = relay.getUser(msg.sender)
			if(!sender) return
			var/hash_pos = findtextEx(msg.target, "#")
			if(hash_pos)
				tab_channel = "#[copytext(msg.target, hash_pos+1)]"
			else
				tab_channel = sender.fullName
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
					var/client/code_message/cm = new(msg)
					code_messages += cm
					formatted_text = formatUsercode(sender, cm, msg.time)
					roomFlash(tab_channel)
			src << output(formatted_text, "[tab_channel].output")

	//------------------------------------------------
	proc
		formatSystem(body, time)
			body = html_encode(body)
			return {"<span class="system">[body]</span>"}

		handleTraffic(tab_channel, relay/msg/msg)
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
					var/relay/user/U = relay.getUser(user_name)
					if(!U) return
					var/old_nick = copytext(value, colon_pos+1)
					if(old_nick){ info = {" ([old_nick])"}}
					var/full_span = "&lt;[U.fullName]&gt;"
					var/new_nick = U.nickname? html_encode(U.nickname) : full_span
					info = {"[full_span][info] is now known as [new_nick]"}
					updateWhogrid(tab_channel)
				if("join")
					var/relay/user/U = relay.getUser(value)
					if(!U){ return}
					if(preferences.view_nicks && U.nickname)
						info = {"[html_encode(U.nickname)] "}
					info = {"[info]&lt;[U.fullName]&gt; has connected."}
					updateWhogrid(tab_channel)
				if("leave")
					var/relay/user/U = relay.getUser(value)
					if(!U) return
					if(preferences.view_nicks && U.nickname)
						info = {"[html_encode(U.nickname)] "}
					info = {"[info]&lt;[U.fullName]&gt; has disconnected."}
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
					var/relay/user/U = relay.getUser(user_name)
					if(!U) return
					var/_tier = text2num(copytext(value, colon_pos+1))
					if(!isnum(_tier)) return
					var/tiers = list("Blocked", "Muted", "Normal", "Voiced", "Operator", "Owner")
					var/permission_tier = tiers[_tier+1]
					if(preferences.view_nicks && U.nickname)
						info = {"[html_encode(U.nickname)] "}
					info = {"[info]&lt;[U.fullName]&gt; permission has been set to: [permission_tier]"}
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

		/*format_channel(body, time){
			body = html_encode(body)
			var/time_stamp = {""}
			var/body_span = {"<span class="traffic">[body]</span>"}
			if(preferences.time_stamps){
				time_stamp = time2stamp(time, preferences.time_zone + preferences.daylight)
				time_stamp = {"<span class="time_stamp"><span class="traffic">[time_stamp]</span></span>"}
				}
			return {"[time_stamp] [body_span]"}
			}*/

		formatEmote(var/relay/user/sender, body, time)
			body = html_encode(body)
			var/using_nick = (sender.nickname && preferences.view_nicks)
			var/sender_span
			if(using_nick) sender_span = html_encode(sender.nickname)
			else sender_span = sender.simpleName
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

		formatUser(var/relay/user/sender, body, time)
			body = html_encode(body)
			var/using_nick = (sender.nickname && preferences.view_nicks)
			var/sender_span
			if(using_nick){ sender_span = html_encode(sender.nickname)}
			else{ sender_span = sender.simpleName}
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

		formatUsercode(var/relay/user/sender, var/client/code_message/cm, time)
			var/using_nick = (sender.nickname && preferences.view_nicks)
			var/sender_span
			if(using_nick) sender_span = html_encode(sender.nickname)
			else sender_span = sender.simpleName
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


//------------------------------------------------------------------------------

client
	var
		client/preferences/preferences

	preferences
		parent_type = /datum
		var
			version = 1
			client/preferences/skin/skin = "ceres"
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
			client/client

		New(var/client/_client)
			.=..()
			client = _client
			nickname = client.key

		proc
			skinLoad(var/XML/Element/template)
				skin = new()
				if(template)
					skin.imprint(template)
				skinApply(skin)

			skinApply(var/client/preferences/skin/which)
				which.apply(client)

			imprint(var/XML/Element/template)
				version = text2num(template.Attribute("version"))
				var/XML/Element/child
				if(version >= 2)
					child = template.FirstChildElement("nickname")
					nickname = child.Attribute("value")
				child = template.FirstChildElement("home_channel")
				home_channel = child.Attribute("name")
				child = template.FirstChildElement("show_time_stamps")
				time_stamps = text2num(child.Attribute("value"))
				child = template.FirstChildElement("show_traffic")
				traffic = text2num(child.Attribute("value"))
				child = template.FirstChildElement("show_colors")
				show_colors = text2num(child.Attribute("value"))
				child = template.FirstChildElement("time")
				time_zone = text2num(child.Attribute("offset"))
				daylight = text2num(child.Attribute("daylight"))
				child = template.FirstChildElement("colors")
				colorName = child.Attribute("name")
				colorText = child.Attribute("text")
				child = template.FirstChildElement("skin")
				skinLoad(child)

			to_xml()
				var/XML/Element/template = xmlRootFromString({"<preferences version="2" />"})
				template.AddChild(xmlRootFromString({"<nickname value="[nickname]" />"}))
				template.AddChild(xmlRootFromString({"<home_channel name="[home_channel]" />"}))
				template.AddChild(xmlRootFromString({"<show_time_stamps value="[time_stamps? 1 : 0]" />"}))
				template.AddChild(xmlRootFromString({"<show_traffic value="[traffic? 1 : 0]" />"}))
				template.AddChild(xmlRootFromString({"<show_colors value="[show_colors? 1 : 0]" />"}))
				template.AddChild(xmlRootFromString({"<time offset="[time_zone]" daylight="[daylight? 1 : 0]" />"}))
				template.AddChild(xmlRootFromString({"<colors name="[colorName]" text="[colorText]" />"}))
				template.AddChild(skin.to_xml())
				return template

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
				to_xml()
					var/XML/Element/template = xmlRootFromString({"<skin version="2" />"})
					template.AddChild(xmlRootFromString({"<chat_font family="[chat_font]" size="[font_size]" />"}))
					template.AddChild(xmlRootFromString({"<background color="[background]" />"}))
					template.AddChild(xmlRootFromString({"<user_message color="[user_message]" />"}))
					template.AddChild(xmlRootFromString({"<user_name color="[user]" />"}))
					template.AddChild(xmlRootFromString({"<channel_traffic color="[traffic]" />"}))
					template.AddChild(xmlRootFromString({"<system color="[system]" />"}))
					template.AddChild(xmlRootFromString({"<time_stamp color="[time_stamp]" />"}))
					return template

				imprint(var/XML/Element/template)
					version = text2num(template.Attribute("version"))
					var/XML/Element/child
					child = template.FirstChildElement("chat_font")
					chat_font = child.Attribute("family")
					if(version >= 2)
						font_size = child.Attribute("size")

					child = template.FirstChildElement("background")
					background = child.Attribute("color")
					child = template.FirstChildElement("user_message")
					user_message = child.Attribute("color")
					child = template.FirstChildElement("user_name")
					user = child.Attribute("color")
					child = template.FirstChildElement("channel_traffic")
					traffic = child.Attribute("color")
					child = template.FirstChildElement("system")
					system = child.Attribute("color")
					child = template.FirstChildElement("time_stamp")
					time_stamp = child.Attribute("color")

				apply(var/client/who, chan_name)
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

				style()
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
client
	proc
		nicknameSend()
			relay.route(new /relay/msg(user.fullName, SYSTEM, ACTION_NICKNAME, preferences.nickname))

		preferencesLoad()
			preferences = new(src)
			var/file_path = "data/preferences/[ckey].xml"
			if(!fexists(file_path))
				preferences.skinLoad()
				nicknameSend()
				return
			var/F = file(file_path)
			F = file2text(F)
			var/XML/Element/E = xmlRootFromString(F)
			preferences.imprint(E)
			// Set Colors on User & Relay Nickname
			user.colorName = preferences.colorName
			user.colorText = preferences.colorText
			nicknameSend()

		preferencesSave()
			// Set Colors on User & Relay Nickname
			user.colorName = preferences.colorName
			user.colorText = preferences.colorText
			nicknameSend()
			// Save Preferences to File
			var/XML/Element/E = preferences.to_xml()
			var/file_path = "data/preferences/[ckey].xml"
			if(fexists(file_path))
				fdel(file_path)
			var/F = file(file_path)
			F << E.XML(TRUE)
