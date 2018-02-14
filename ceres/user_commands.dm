

//------------------------------------------------------------------------------

ceres
	var
		list/commands

	verb
		mainParse(what as text|null)
			set name = "mainparse"
			if(!what) return
			if(copytext(what,1,2) == "/")
				var/word_split = findtextEx(what, " ")
				var/first_word = copytext(what, 2, word_split)
				first_word = lowertext(first_word)
				var/arg_text
				if(word_split)
					arg_text = copytext(what, word_split+1)
				user_command(src, first_word, arg_text)
			else
				if(length(what) > CHAR_LIMIT)
					what = copytext(what,1,CHAR_LIMIT+1)
				chat(what)

	//-- Input Sanitization --------------------------
	var
		regex/sanitizer = new("\n", "g")
	proc
		sanitizeChat(chat)
			return sanitizer.Replace(chat, " ")
			// Also Needed: flood guards


	//-- Command Setup & Handling --------------------
	New()
		.=..()
		initialize_commands()

	proc
		info(what)
			currentRoom.hear({"<span class="system">[what]</span>"})

		initialize_commands()
			commands = new()
			for(var/c_type in typesof(/ceres/command))
				var/ceres/command/C = new c_type()
				if(!C.aliases)
					del C
					continue
				if(istext(C.aliases))
					commands[C.aliases] = C
				else
					for(var/_alias in C.aliases)
						commands[_alias] = C

		user_command(var/client/who, which, arg_text)
			var/ceres/command/command = commands[which]
			if(!command)
				info("Unrecognized or invalid command: [which]")
				return
			var/result = command.execute(who, arg_text)
			return result

	//------------------------------------------------
	verb
		chat(what as text) // Talking into a Ceres Room
			set name = ".chat"
			what = sanitizeChat(what)
			// Ensure a valid target
			if(!(currentRoom && currentRoom.target)) return
			var /artemis/channel/currentTarget = currentRoom.target
			// Route to channel
			if(istype(currentTarget))
				user.msg(null, ARTEMIS_ACTION_MESSAGE, currentTarget, what)
			// Route to user
			else if(istype(currentTarget, /artemis/user))
				var/artemis/msg/M = new(user, currentTarget, ARTEMIS_ACTION_MESSAGE, null, what)
				artemis.route(M)
				echo(M)

		msg(who as text, what as text) // Private Message
			set name = ".msg"
			what = sanitizeChat(what)
			var/artemis/user/target = artemis.getUser(who)
			if(!target)
				info({"The user "[who]" does not exist. You may be using a nickname instead of a network name."})
				return
			var/artemis/msg/M = new(user, target, ARTEMIS_ACTION_MESSAGE, null, what)
			artemis.route(M)
			echo(M)

		emote(what as text)
			set name = ".emote"
			what = sanitizeChat(what)
			// Ensure a valid target
			if(!(currentRoom && currentRoom.target)) return
			var /artemis/channel/currentTarget = currentRoom.target
			// Route to channel
			if(istype(currentTarget))
				user.msg(null, ARTEMIS_ACTION_EMOTE, currentTarget, what)
			// Route to user
			else if(istype(currentTarget, /artemis/user))
				var/artemis/msg/M = new(user, currentTarget, ARTEMIS_ACTION_EMOTE, null, what)
				artemis.route(M)
				echo(M)

		open_code_editor()
			set name = ".open_code_editor"
			winshow(src, "code_editor")

		whois(who as text)
			set name = ".whois"
			var/_full = artemis.nicknamedUsers[lowertext(who)]
			if(!_full)
				info({"There is no user "[who]""})
				return
			info({"The nickname "[who]" is registered to &lt;[artemis.nicknamedUsers[lowertext(who)]]&gt;"})

		chanlist()
			set name = ".list"
			var/chan_text = {"Visible Channels:"}
			var/list/sorted_channels = new()
			for(var/chan_name in artemis.namedChannels)
				sorted_channels += artemis.namedChannels[chan_name]
			quickSort(sorted_channels)
			for(var/artemis/channel/C in sorted_channels)
				var/status = {""}
				if(C.status & ARTEMIS_STATUS_HIDDEN) continue
				if(C.status & ARTEMIS_STATUS_CLOSED) status += " (CLOSED)"
				if(C.status & ARTEMIS_STATUS_LOCKED) status += " (LOCKED)"
				chan_text += "\n    \[[C.activeUsers.len]\][C.name] [status]: [C.topic]"
			info(chan_text)

		channel_status()
			set name = ".status"
			var/artemis/channel/C = currentRoom.target
			if(!istype(C)){ return}
			info({"Channel Status: [C.name]
    Closed: [bool2text(C.status & ARTEMIS_STATUS_CLOSED)]
    Locked: [bool2text(C.status & ARTEMIS_STATUS_LOCKED)]
    Hidden: [bool2text(C.status & ARTEMIS_STATUS_HIDDEN)]"})

		changeNick(newNick as text)
			set name = ".change_nick"
			var/global/regex/noSpaces = regex(@"\n|\s", "g")
			newNick = noSpaces.Replace(newNick, "")
			newNick = copytext(newNick, 1, CERES_MAX_NICKNAME_LENGTH+1)
			preferences.nickname = newNick
			nicknameSend()

		join(channelName as text)
			set name = ".join"
			var/artemis/channel/C = artemis.getChannel(channelName)
			if(C)
				user.msg(null, ARTEMIS_ACTION_JOIN, C)
			else
				user.msg(null, ARTEMIS_ACTION_JOIN, channelName)
				C = artemis.getChannel(channelName)
			if(!C)
				return
			switchChannel(C.name)

		leave(channel as text|null)
			set name = ".leave"
			var/artemis/channel/C
			// Handle Removing Current Room
			if(!channel)
				C = currentRoom.target
				roomRemove(C)
				if(istype(C))
					user.msg(null, ARTEMIS_ACTION_LEAVE, C.name)
				return
			// Handle Removing Specified Channel
			C = artemis.getChannel(channel)
			if(istype(C))
				roomRemove(C)
				user.msg(null, ARTEMIS_ACTION_LEAVE, C.name)

		close()
			set name = ".close"
			var/channel = winget(src, "channels", "current-tab")
			roomRemove("#[channel]")
			leave(channel)

		/*disconnect()
			user.disconnect()*/

		switchChannel(roomName as text)
			set name = ".switch"
			var /ceres/room/namedRoom = namedRooms[roomName]
			if(!namedRoom) return
			currentRoom = namedRoom
			winset(src, "channels", "current-tab=[roomName]")
			var title = winget(src, namedRoom.name, "title")
			if(copytext(title,1,2) == "*")
				title = copytext(title,2)
				winset(src, namedRoom.name, "title='[title]'")

		operate(action as text, username as text, value as num)
			set name = ".operate"
			var /artemis/channel/C = currentRoom.target
			if(!istype(C)) return
			var /artemis/user/U = artemis.getUser(username)
			var status = C.status
			var p_level = C.permissionLevel(U)
			if(U) username = U.nameFull
			var errorMessage
			switch(lowertext(action))
				if("topic")
					user.msg(null, ARTEMIS_ACTION_OPERATE, C, "topic=[url_encode(value)];")
				if("block")
					var newp = value? ARTEMIS_PERMISSION_BLOCKED : ARTEMIS_PERMISSION_NORMAL
					user.msg(null, ARTEMIS_ACTION_OPERATE, C, "user=[username]:[newp];")
				if("mute")
					if(p_level == ARTEMIS_PERMISSION_BLOCKED)
						errorMessage = "You cannot mute [username], the user is already blocked."
					else
						var newp = value? ARTEMIS_PERMISSION_MUTED : ARTEMIS_PERMISSION_NORMAL
						user.msg(null, ARTEMIS_ACTION_OPERATE, C, "user=[username]:[newp];")
				if("voice")
					if(p_level > ARTEMIS_PERMISSION_VOICED)
						errorMessage = "You cannot voice [username], the user already has a higher permission level."
					else
						var newp = value? ARTEMIS_PERMISSION_VOICED : ARTEMIS_PERMISSION_NORMAL
						user.msg(null, ARTEMIS_ACTION_OPERATE, C, "user=[username]:[newp];")
				if("operator")
					if(p_level > ARTEMIS_PERMISSION_OPERATOR)
						errorMessage = "You cannot make [username] an operator, the user already has a higher permission level."
					else
						var newp = value? ARTEMIS_PERMISSION_OPERATOR : ARTEMIS_PERMISSION_NORMAL
						user.msg(null, ARTEMIS_ACTION_OPERATE, C, "user=[username]:[newp];")
				if("owner")
					if(p_level == ARTEMIS_PERMISSION_OWNER && username != user.nameFull)
						errorMessage = "You cannot change [username]'s permission level, the user is a channel owner."
					else
						var newp = value? ARTEMIS_PERMISSION_OWNER : ARTEMIS_PERMISSION_NORMAL
						user.msg(null, ARTEMIS_ACTION_OPERATE, C, "user=[username]:[newp];")
				if("locked")
					var new_s
					if(value){ new_s = status |  ARTEMIS_STATUS_LOCKED}
					else{      new_s = status & ~ARTEMIS_STATUS_LOCKED}
					user.msg(null, ARTEMIS_ACTION_OPERATE, C, "status=[new_s];")
				if("closed")
					var new_s
					if(value) new_s = status |  ARTEMIS_STATUS_CLOSED
					else      new_s = status & ~ARTEMIS_STATUS_CLOSED
					user.msg(null, ARTEMIS_ACTION_OPERATE, C, "status=[new_s];")
				if("hidden")
					var new_s
					if(value){ new_s = status |  ARTEMIS_STATUS_HIDDEN}
					else{      new_s = status & ~ARTEMIS_STATUS_HIDDEN}
					user.msg(null, ARTEMIS_ACTION_OPERATE, C, "status=[new_s];")
			if(errorMessage)
				artemis.msg(artemis.SYSTEM, U, ARTEMIS_ACTION_DENIED, errorMessage)


//------------------------------------------------------------------------------

	command
		parent_type = /datum
		var
			list/aliases
		proc
			execute(var/user/who, arg_text)
			help()

		whois
			aliases = "whois"
			execute(var/ceres/who, arg_text)
				who.whois(arg_text)
			help()
				return {"
Used to determine a user's network name. A private message must be sent to a network name, not a nickname.
Usage: /whois nickname
					"}

		list
			aliases = "list"
			execute(var/ceres/who, arg_text)
				who.chanlist()
			help()
				return {"
Used to query the server for a list of visible channels.
Usage: /list
					"}

		nick
			aliases = "nick"
			execute(var/ceres/who, argText)
				who.changeNick(argText)
			help()
				return {"
Used to change your nickname.
Usage: /nick newnick
  newnick: The new nickname you wish to use. Use "clear" or leave blank to clear your nickname.
  					"}

		join
			aliases = "join"
			execute(var/ceres/who, arg_text)
				var/list/_args = artemis.text2list(arg_text, " ")
				if(!_args.len){ return}
				var/chan = _args[1]
				who.join(chan)
			help()
				return {"
Used to join channels. If the channel does not exist, it will be created for you.
Usage: /join channel
  channel: The name of the channel you wish to join
  					"}

		emote
			aliases = list("me","emote")
			execute(var/ceres/who, arg_text)
				who.emote(arg_text)
			help()
				return {"
Used to emote. This sends a message to the channel describing an action you are performing.
Usage: /me action
  action: The message you would like to send, such as "eats rice".
  					"}

		code
			aliases = "code"
			execute(var/ceres/who, arg_text)
				who.open_code_editor()
			help()
				return {"
(Functional, But Incomplete) Used to open the code editor window to send code messages.
Usage: /code
					"}

		channel_status
			aliases = list("status")
			execute(var/ceres/who, arg_text)
				who.channel_status()
			help()
				return {"
(Temporary). Used to view a channel's status
Usage: /status"}

		leave
			aliases = "leave"
			execute(var/ceres/who, argText)
				var /list/words = artemis.text2list(argText, " ")
				if(!words.len) return
				var channelName = words[1]
				who.leave(channelName)
			help()
				return {"
Used to leave channels.
Usage: /leave channel
  channel: The channel you wish to leave. The default is the current channel"}

		private
			aliases = list("pm","msg")
			execute(var/ceres/who, arg_text)
				var/list/_args = artemis.text2list(arg_text, " ")
				if(!_args.len) return
				var/user_name = _args[1]
				_args.Cut(1,2)
				var/body = artemis.list2text(_args, " ")
				who.msg(user_name, body)
			help()
				return {"
Used to send a private message to another user.
Usage: /msg netname message
  netname: The Network Name of the user you wish to message
  message: The body of your message"}

		topic
			aliases = "topic"
			execute(var/ceres/who, arg_text)
				if(!arg_text){ return}
				who.operate("topic", null, arg_text)
			help()
				return {"
You must be a channel operator to use this command. Used to change the channel topic.
Usage: /topic newtopic
  newtopic: The new topic for this channel"}

		lock
			aliases = list("lock","l")
			execute(var/ceres/who, arg_text)
				var/list/_args = artemis.text2list(arg_text, " ")
				var/_value = (_args.len >= 1)? who.text2bool(_args[1]) : TRUE
				who.operate("locked", null, _value)
			help()
				return {"
You must be a channel operator to use this command. Used to lock a channel. Users without voice cannot chat while the channel is locked.
Usage: /lock status
  status: 0 or false to unlock the channel, 1, true, or default to lock"}

		open
			aliases = list("close")
			execute(var/ceres/who, arg_text)
				var/list/_args = artemis.text2list(arg_text, " ")
				var/_value = (_args.len >= 1)? who.text2bool(_args[1]) : TRUE
				who.operate("closed", null, _value)
			help()
				return {"
You must be a channel operator to use this command. Used to close or open a channel to new connections. Users without voice cannot join a channel which is closed.
Usage: /close status
  status: 1, true, or default to close a channel, 0 or false to open it."}

		hide
			aliases = list("hide")
			execute(var/ceres/who, arg_text)
				var/list/_args = artemis.text2list(arg_text, " ")
				var/_value = (_args.len >= 1)? who.text2bool(_args[1]) : TRUE
				who.operate("hidden", null, _value)
			help()
				return {"
You must be a channel operator to use this command. Used to change the visibility of a channel. Hidden channels will not be advertised by the server.
Usage: /hide status
  status: 1, true, or default to hide a channel, 0 or false to make it visible."}

		block
			aliases = list("block")
			execute(var/ceres/who, arg_text)
				var/list/_args = artemis.text2list(arg_text, " ")
				if(!_args.len){ return}
				var/user = _args[1]
				var/_value = (_args.len > 1)? who.text2bool(_args[2]) : TRUE
				who.operate("block", user, _value)
			help() // TODO: Block at the server or IP level.
				return {"
You must be a channel operator to use this command. Used to block and remove a user front a channel.
Usage: /block user_name status
  netname: The Network Name of the user you wish to block and remove
  status: 0 or false to unblock the user, 1, true, or default to block"}

		mute
			aliases = list("mute")
			execute(var/ceres/who, arg_text)
				var/list/_args = artemis.text2list(arg_text, " ")
				if(!_args.len){ return}
				var/user = _args[1]
				var/_value = (_args.len > 1)? who.text2bool(_args[2]) : TRUE
				who.operate("mute", user, _value)
			help()
				return {"
You must be a channel operator to use this command. Used to mute a user in a channel.
Usage: /mute user_name status
  netname: The Network Name of the user you wish to mute
  status: 0 or false to unmute the user, 1, true, or default to mute"}

		voice
			aliases = list("voice")
			execute(var/ceres/who, arg_text)
				var/list/_args = artemis.text2list(arg_text, " ")
				if(!_args.len){ return}
				var/user = _args[1]
				var/_value = (_args.len > 1)? who.text2bool(_args[2]) : TRUE
				who.operate("voice", user, _value)
			help()
				return {"
You must be a channel operator to use this command. Used to grant or revoke voice status. A voiced user may speak while a channel is locked.
Usage: /voice user_name status
  netname: The Network Name of the user you wish to modify
  status: 0 or false to remove voice, 1, true, or default to grant"}

		operator
			aliases = list("operator")
			execute(var/ceres/who, arg_text)
				var/list/_args = artemis.text2list(arg_text, " ")
				if(!_args.len){ return}
				var/user = _args[1]
				var/_value = (_args.len > 1)? who.text2bool(_args[2]) : TRUE
				who.operate("operator", user, _value)
			help()
				return {"
You must be a channel owner to use this command. Used to grant or revoke operator status.
Usage: /operator user_name status
  netname: The Network Name of the user you wish to modify
  status: 0 or false to revoke operator status, 1, true, or default to grant"}

		owner
			aliases = list("owner")
			execute(var/ceres/who, arg_text)
				var/list/_args = artemis.text2list(arg_text, " ")
				if(!_args.len){ return}
				var/user = _args[1]
				who.operate("owner", user, TRUE)
			help()
				return {"
You must be a channel owner to use this command. Used to transer ownership of a channel.
Usage: /operator user_name status
  netname: The Network Name of the user you wish to grant ownership"}

		help
			aliases = "help"
			execute(var/ceres/who, arg_text)
				var/list/_args = artemis.text2list(arg_text, " ")
				if(!_args.len) return
				var/command = _args[1]
				if(!command)
					var/command_text = {""}
					for(var/_alias in who.commands)
						command_text += "\n    [_alias]"
					who.info({"To chat, simply enter text into the input and hit enter. \
					All commands are used by entering them in the main chat, preceded by a slash / character. For instance, \
					you can access this command by entering "/help". Some commands take parameters which can be added after the command, \
					such as "/help join", which will display info explaining how to use the "join" command. The following commands are available:[command_text]"})
				else
					var/ceres/command/C = who.commands[lowertext(command)]
					if(!C)
						who.info("The specified command does not exist: [command]")
					who.info(C.help())
			help()
				return {"
Used to view command usage documents.
Usage: /help command
  command: The command you need help with. If left out, a list of all avaliable commands will be displayed."}
