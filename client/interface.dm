

//------------------------------------------------------------------------------

client
	proc

		updateWhogrid(channel)
			var/list/_markers = who_markers[channel]
			if(_markers)
				for(var/obj/_marker in _markers)
					del _marker
			var/relay/channel/C = relay.getChannel(channel)
			if(!C) return
			_markers = list()
			for(var/user_name in C.activeUsers)
				var/client/whoMarker/_marker = new()
				_marker.setup(src, user_name, C.permissionLevel(user_name))
				_markers += _marker
			_markers = dd_sortedObjectList(_markers)
			who_markers[channel] = _markers
			updateGrid(channel)

		updateGrid(channel_name)
			var/list/_markers = who_markers[channel_name]
			if(!_markers) _markers = list()
			winset(src, "[channel_name].who", "cells=[1],[_markers.len]")
			for(var/I = 1 to _markers.len)
				var/client/whoMarker/M = _markers[I]
				src << output(M,"[channel_name].who:[1],[I]")

	proc
		centerWindow(window_name)
			var/list/params = winget(src, "main", "pos;size")
			params = params2list(params)
			var/pos = params["pos"]
			var/comma = findtextEx(pos,",")
			var/_x = text2num(copytext(pos,1,comma))
			var/_y = text2num(copytext(pos,comma+1))
			var/size = params["size"]
			var/commx = findtextEx(size,"x")
			var/main_w = text2num(copytext(size,1,commx))
			var/main_h = text2num(copytext(size,commx+1))
			size = winget(src, window_name, "size")
			commx = findtextEx(size,"x")
			var/targ_w = text2num(copytext(size,1,commx))
			var/targ_h = text2num(copytext(size,commx+1))
			var/center_x = ((main_w - targ_w)/2) + _x
			var/center_y = ((main_h - targ_h)/2) + _y
			winset(src, window_name, "pos='[center_x],[center_y]'")

	verb

		tabchanged()
			set name = ".tabchanged"
			set hidden = TRUE
			var/channel_name = winget(src, "channels", "current-tab")
			switch_chan(channel_name)

		about(toggle as num)
			set name = ".about"
			set hidden = TRUE
			centerWindow("about")
			winshow(src, "about", toggle)

		showPreferences()
			set name = ".preferences"
			centerWindow("preferences")
			winshow(src, "preferences")
			var/client/preferences/skin/S = preferences.skin
			/* Naming preferences */
			winset(src, "pref_naming.name_netname"  , "text='Network Name: [user.fullName]'")
			winset(src, "pref_naming.name_error"    , "is-visible='false'")
			winset(src, "pref_naming.name_nickname" , "text='[user.nickname]'")
			winset(src, "pref_naming.name_viewnicks", "is-checked='[bool2text(preferences.view_nicks)]'")
			/* General preferences */
			winset(src, "pref_general.g_home"   , "text='[preferences.home_channel]'")
			winset(src, "pref_general.g_traffic", "is-checked='[bool2text(preferences.traffic)]'")
			winset(src, "pref_general.g_font", "text='[preferences.skin.chat_font]'")
			winset(src, "pref_general.g_fontsize", "text='[preferences.skin.font_size]'")
			/* Time preferences */
			winset(src, "pref_time.ut_viewstamps", "is-checked='[bool2text(preferences.time_stamps)]'")
			winset(src, "pref_time.ut_bar"      , "value='[(100*preferences.time_zone/24)+50]'")
			var/_offset = preferences.time_zone + preferences.daylight
			winset(src, "pref_time.ut_num"      , "text='UT[(_offset >= 0)? "+[_offset]":_offset]'")
			winset(src, "pref_time.ut_zone"     , "text='[offset2zone(preferences.time_zone)]'")
			winset(src, "pref_time.ut_daylight" , "is-checked='[bool2text(preferences.daylight)]'")
			/* Color Settings */
			winset(src, "pref_color.cb_viewcolors", "is-checked='[bool2text(preferences.show_colors)]'")
			winset(src, "pref_color.cb_time"      , "background-color='[S.time_stamp  ]'")
			winset(src, "pref_color.cb_message"   , "background-color='[S.user_message]'")
			winset(src, "pref_color.cb_user"      , "background-color='[S.user        ]'")
			winset(src, "pref_color.cb_system"    , "background-color='[S.system      ]'")
			winset(src, "pref_color.cb_traffic"   , "background-color='[S.traffic     ]'")
			winset(src, "pref_color.cb_background", "background-color='[S.background  ]'")
			winset(src, "pref_color.color_test"   , "background-color='[S.background  ]'")
			winset(src, "pref_color.cb_pname"     , "background-color='[preferences.colorName]'")
			winset(src, "pref_color.cb_ptext"     , "background-color='[preferences.colorText]'")
			winset(src, "pref_color.color_test"   , "style='[S.style()]'")
			var/ipsum
			var/test_colon = {"<span class="time_stamp">:</span>"}
			var/test_time_stamp = {""}
			var/test_nick = (user.nickname && preferences.view_nicks)? user.nickname : user.simpleName
			var/test_using_nick = (test_nick != user.simpleName)
			if(preferences.time_stamps)
				test_time_stamp = {"<span class="time_stamp">\[23:59\]</span>"}
			if(preferences.show_colors)
				ipsum = {"\
[test_time_stamp]\
[preferences.view_nicks? {"<span class="user" style="color:#f00">Ipsum</span>"} : {"<span class="time_stamp">&lt;<span class="user" style="color:#f00">ipsum</span>&gt;</span>"}]\
[test_colon] \
<span class="user_message" style="color:#0d0">Ut adipiscing feugiat!</span>\
					"}
			else
				ipsum = {"\
[test_time_stamp]\
[preferences.view_nicks? {"<span class="user">Ipsum</span>"} : {"<span class="time_stamp">&lt;<span class="user">ipsum</span>&gt;</span>"}]\
[test_colon] \
<span class="user_message">Ut adipiscing feugiat!</span>\
					"}
			var/test_chat = {"\
<span class="system">System Message</span>
[test_time_stamp]\
[test_using_nick? "" : {"<span class="time_stamp">&lt;</span>"}]\
<span style="color:[preferences.colorName? preferences.colorName : preferences.skin.user]">[test_nick]</span>\
[test_using_nick? "[test_colon] " : {"<span class="time_stamp">&gt;</span>"}]\
<span style="color:[preferences.colorText? preferences.colorText : preferences.skin.user_message]">Lorem ipsum.</span>
<i class="traffic">[preferences.view_nicks? "Lorem &lt;dolorem12&gt;" : "&lt;dolorem12&gt;"] has connected.</i>
[test_time_stamp]\
[preferences.view_nicks? {"<span class="user">Lorem</span>"} : {"<span class="time_stamp">&lt;<span class="user">dolorem12</span>&gt;</span>"}]\
[test_colon] \
<span class="user_message">consectetur adipiscing?</span>
[ipsum]"}
			src << output({"<span style="font-family:[preferences.skin.chat_font];font-size:[preferences.skin.font_size]pt;">[test_chat]</span>"}, "pref_color.color_test")

		updateGeneral(var/which as text)
			set name = ".update_general"
			switch(which)
				if("current")
					winset(src, "pref_general.g_home", "text='[copytext(current_room,2)]'")
				if("traffic")
					var/view_traffic = winget(src, "pref_general.g_traffic", "is-checked")
					view_traffic = text2bool(view_traffic)
					preferences.traffic = view_traffic
			var/home_chan = winget(src, "pref_general.g_home", "text")
			if(relay.alphanumeric(home_chan) != home_chan)
				winset(src, "pref_general.home_error", "is-visible='true'")
				winset(src, "preferences.pref_tabs", "current-tab='pref_general'")
				return
			preferences.home_channel = home_chan
			preferences.skin.chat_font = winget(src, "pref_general.g_font", "text")
			var/new_font_size = round(text2num(winget(src, "pref_general.g_fontsize", "text")))
			preferences.skin.font_size = (isnum(new_font_size) && new_font_size >= 0)? new_font_size : preferences.skin.font_size
			return TRUE

		updateNaming(var/which as text)
			set name = ".update_naming"
			switch(which)
				if("usekey") // TODO
					/*var/keynick = key
					if(length(keynick) > 20){ keynick = copytext(keynick, 1, 21)}
					winset(src, "pref_naming.name_nickname", "text='[keynick]'")*/
				if("viewnicks")
					var/old_val = preferences.view_nicks
					var/view_nicks = winget(src, "pref_naming.name_viewnicks", "is-checked")
					view_nicks = text2bool(view_nicks)
					preferences.view_nicks = view_nicks
					if(old_val != view_nicks)
						for(var/channel_name in user.channels)
							updateWhogrid("#[channel_name]")
			var/new_nick = winget(src, "pref_naming.name_nickname", "text")
			if(copytext(new_nick, 1, 2) == " ")
				winset(src, "pref_naming.name_error", "is-visible='true';text='This nickname is invalid';")
				winset(src, "preferences.pref_tabs", "current-tab='pref_naming'")
				return
			else if(lowertext(new_nick) in relay.nicknames && relay.nicknames[lowertext(new_nick)] != user.fullName)
				winset(src, "pref_naming.name_error", "is-visible='true';text='This nickname is taken';")
				winset(src, "preferences.pref_tabs", "current-tab='pref_naming'")
				return
			else
				preferences.nickname = new_nick
			return TRUE

		//------------------------------------------------
		slideTime()
			set name = ".slide_time"
			var/value = text2num(winget(src, "pref_time.ut_bar", "value"))
			var/time = (value/100)*24
			var/hours = round(time)
			var/partial_hour = time - hours
			if(partial_hour > 1/2)
				hours += 1
			var/_daylight = text2bool(winget(src , "pref_time.ut_daylight", "is-checked"))
			preferences.daylight = _daylight
			hours -= 12
			preferences.time_zone = hours
			var/day_hours = hours + _daylight
			winset(src, "pref_time.ut_bar"      , "value='[(100*hours/24)+50]'")
			winset(src, "pref_time.ut_num"      , "text='UT[(day_hours >= 0)? "+[day_hours]" : day_hours]'")
			winset(src, "pref_time.ut_zone"     , "text='[offset2zone(hours)]'")

		offset2zone(utOffset as num)
			// Should be a proc, not verb. Got placed here while refactoring
			if(!utOffset) utOffset = 0
			utOffset += 13
			var /list/zones = list(
				"Baker Island, Howland Island",
				"Apia, Pago Pago",
				"US: Hawaii-Aleutian, Papeete",
				"US: Alaska",
				"US: Pacific, Vancouver",
				"US: Mountain, Calgary",
				"US: Central, Mexico City",
				"US: Eastern, Toronto, Havana, Lima",
				"Halifax, Asunción, Santiago",
				"São Paulo, Buenos Aires, Montevideo",
				"Fernando de Noronha, South Georgia",
				"Azores, Cape Verde",
				"Dakar, Dublin, London, Lisbon",
				"Algiers, Berlin, Paris, Madrid",
				"Athens, Cairo, Cape Town, Helsinki",
				"Addis Ababa, Baghdad, Moscow",
				"Baku, Mauritius, Samara, Tbilisi",
				"Karachi, Maldives, Tashkent",
				"Almaty, Dhaka, Omsk",
				"Bangkok, Jakarta, Krasnoyarsk",
				"Beijing, Irkutsk, Manila, Perth",
				"Pyongyang, Seoul, Tokyo, Yakutsk",
				"Melbourne, Sydney, Vladivostok",
				"Magadan, Nouméa",
				"Auckland, Petropavlovsk, Suva",
				)
			return zones[utOffset]

		//------------------------------------------------
		changeColor(which as text)
			set name = ".change_color"
			switch(which)
				if("time")
					var color = input(src, null, "Time Stamp", preferences.skin.time_stamp) as color
					preferences.skin.time_stamp = color
					winset(src, "pref_color.cb_[which]", "background-color='[color]'")
				if("message")
					var color = input(src, null, "User Message", preferences.skin.user_message) as color
					preferences.skin.user_message = color
					winset(src, "pref_color.cb_[which]", "background-color='[color]'")
				if("user")
					var color = input(src, null, "User Names", preferences.skin.user) as color
					preferences.skin.user = color
					winset(src, "pref_color.cb_[which]", "background-color='[color]'")
				if("system")
					var color = input(src, null, "System Message", preferences.skin.system) as color
					preferences.skin.system = color
					winset(src, "pref_color.cb_[which]", "background-color='[color]'")
				if("traffic")
					var color = input(src, null, "Channel Traffic", preferences.skin.traffic) as color
					preferences.skin.traffic = color
					winset(src, "pref_color.cb_[which]", "background-color='[color]'")
				if("background")
					var color = input(src, null, "Chat Background", preferences.skin.background) as color
					preferences.skin.background = color
					winset(src, "pref_color.cb_[which]", "background-color='[color]'")
					winset(src, "pref_color.color_test", "background-color='[color]'")
				if("pname")
					var color = input(src, null, "Personal Name", preferences.colorName) as color
					preferences.colorName = color
					winset(src, "pref_color.cb_[which]", "background-color='[color]'")
				if("ptext")
					var color = input(src, null, "Personal Text", preferences.colorText) as color
					preferences.colorText = color
					winset(src, "pref_color.cb_[which]", "background-color='[color]'")
				if("viewcolors")
					var is_checked = winget(src, "pref_color.cb_viewcolors", "is-checked")
					is_checked = text2bool(is_checked == "true")
					preferences.show_colors = is_checked
			winset(src, "pref_color.color_test", "style='[preferences.skin.style()]'")
			var ipsum
			var test_colon = {"<span class="time_stamp">:</span>"}
			var test_time_stamp = {""}
			var test_nick = (user.nickname && preferences.view_nicks)? user.nickname : user.simpleName
			var test_using_nick = (test_nick != user.simpleName)
			if(preferences.time_stamps)
				test_time_stamp = {"<span class="time_stamp">\[23:59\]</span>"}
			if(preferences.show_colors)
				ipsum = {"\
[test_time_stamp]\
[preferences.view_nicks? {"<span class="user" style="color:#f00">Ipsum</span>"} : {"<span class="time_stamp">&lt;<span class="user" style="color:#f00">ipsum</span>&gt;</span>"}]\
[test_colon] \
<span class="user_message" style="color:#0d0">Ut adipiscing feugiat!</span>\
					"}
			else
				ipsum = {"\
[test_time_stamp]\
[preferences.view_nicks? {"<span class="user">Ipsum</span>"} : {"<span class="time_stamp">&lt;<span class="user">ipsum</span>&gt;</span>"}]\
[test_colon] \
<span class="user_message">Ut adipiscing feugiat!</span>\
					"}
			var test_chat = {"\
<span class="system">System Message</span>
[test_time_stamp]\
[test_using_nick? "" : {"<span class="time_stamp">&lt;</span>"}]\
<span style="color:[preferences.colorName? preferences.colorName : preferences.skin.user]">[test_nick]</span>\
[test_using_nick? "[test_colon] " : {"<span class="time_stamp">&gt;</span>"}]\
<span style="color:[preferences.colorText? preferences.colorText : preferences.skin.user_message]">Lorem ipsum.</span>
<i class="traffic">[preferences.view_nicks? "Lorem &lt;dolorem12&gt;" : "&lt;dolorem12&gt;"] has connected.</i>
[test_time_stamp]\
[preferences.view_nicks? {"<span class="user">Lorem</span>"} : {"<span class="time_stamp">&lt;<span class="user">dolorem12</span>&gt;</span>"}]\
[test_colon] \
<span class="user_message">consectetur adipiscing?</span>
[ipsum]"}
			src << output({"<span style="font-family:[preferences.skin.chat_font];font-size:[preferences.skin.font_size]pt;">[test_chat]</span>"}, "pref_color.color_test")

		applyPrefChanges(close as num)
			set name = ".apply_pref_changes"
			var success = updateGeneral(FALSE)
			if(success)
				success = updateNaming(FALSE)
			if(!success && close)
				return
			winset(src, "pref_general.home_error", "is-visible='false'")
			winset(src, "pref_naming.name_error", "is-visible='false'")
			preferences.time_stamps = text2bool(winget(src, "pref_time.ut_viewstamps", "is-checked"))
			preferences.skin.apply(src)
			if(close)
				winshow(src, "preferences", 0)
			// Set Colors on User & Relay Nickname
			user.colorName = preferences.colorName
			user.colorText = preferences.colorText
			nicknameSend()

	//------------------------------------------------
	show_popup_menus = FALSE
	whoMarker
		parent_type = /obj
		var
			user
			tier
		dd_SortValue()
			return -tier
		proc

			setup(var/client/who, user_name, _tier)
				user = user_name
				var/relay/user/U = relay.getUser(user_name)
				tier = _tier
				var/using_nick = (who.preferences.view_nicks && U.nickname)
				if(using_nick)
					name = {"[prefix(tier)][U.nickname]"}
				else
					name = {"[prefix(tier)]<[user_name]>"}

			prefix(_tier)
				if(!_tier) _tier = tier
				switch(_tier)
					if(PERMISSION_OWNER   ) return "#"
					if(PERMISSION_OPERATOR) return "@"
					if(PERMISSION_VOICED  ) return "+"
					if(PERMISSION_NORMAL  ) return "*"
					if(PERMISSION_MUTED   ) return "-"
					if(PERMISSION_BLOCKED ) return "!"
					else return "*"

			clicked(var/client/who)
				if(ckey(who.user.fullName) == ckey(user)) return
				who.roomAdd(user, TRUE)

			right_clicked(var/client/who)
				var/relay/user/U = relay.getUser(user)
				if(!istype(U) || !U.nickname) return
				who.whois(U.nickname)

		Click(location,control,params)
			if(!istype(usr) || !usr.client) return
			var/client/C = usr.client
			if("right" in params2list(params))
				right_clicked(C)
			else
				clicked(C)

client
	verb
		submitCode()
			set name = ".submit_code"
			var/_code = winget(src, "code_editor.code_input", "text")
			var/relay/msg/M = new(user.fullName, current_room, ACTION_CODE, _code)
			winshow(src, "code_editor", FALSE)
			winset(src, "code_editor.code_input", "text='';")
			if(copytext(current_room, 1, 2) != "#")
				echo(M)
			relay.route(M)


//------------------------------------------------------------------------------

client
	var
		list/who_markers = new()
		list/rooms = new()
	New()
		.=..()
		spawn(10)
			winset(src, "channels", "on-tab='.tabchanged'")
			winset(src, "about.version", "text='Client Version: 0.8'")
	proc
		roomAdd(channel_name, auto_show)
			rooms.Add(channel_name)
			var/relay/channel/C = relay.getChannel(channel_name)
			var/relay/user/U
			var/title
			if(C)
				title = C.name
				winclone(src, CLONER_CHANNEL, channel_name)
			else
				U = relay.getUser(channel_name)
				title = "PM:[U.fullName]"
				winclone(src, CLONER_PRIVATE, channel_name)
			preferences.skin.apply(src, channel_name)
			winset(src, channel_name, "title='[title]'")
			winset(src, "channels", "tabs='+[channel_name]'")
			if(auto_show)
				switch_chan(channel_name)

		roomRemove(channel_name)
			rooms.Remove(channel_name)
			winset(src, "channels", "tabs='-[channel_name]'")

		roomFlash(channel_name)
			if(ckey(channel_name) == ckey(current_room))
				return
			var/relay/channel/C = relay.getChannel(channel_name)
			var/relay/user/U
			var/title
			if(C)
				title = C.name
			else
				U = relay.getUser(channel_name)
				title = U.fullName
			if(copytext(channel_name,1,2) != "#"){ title = "PM:[title]"}
			winset(src, channel_name, "title='*[title]';")
