

//------------------------------------------------------------------------------

client
	var
		list/commands
		current_room

	verb
		mainParse(what as text|null)
			set name = "mainparse"
			d(what)
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

	New()
		.=..()
		initialize_commands()

	//------------------------------------------------
	proc
		info(what)
			src << output({"<span class="system">[what]</span>"}, "[current_room].output")

		initialize_commands()
			commands = new()
			for(var/c_type in typesof(/client/command))
				var/client/command/C = new c_type()
				if(!C.aliases)
					del C
					continue
				if(istext(C.aliases))
					commands[C.aliases] = C
				else
					for(var/_alias in C.aliases)
						commands[_alias] = C

		user_command(var/client/who, which, arg_text)
			var/client/command/command = commands[which]
			if(!command)
				info("Unrecognized or invalid command: [which]")
				return
			var/result = command.execute(who, arg_text)
			return result

	verb
		chat(what as text)
			set name = ".chat"
			if(current_room)
				if(copytext(current_room, 1, 2) == "#")
					relay.route(new /relay/msg(user.nameFull, current_room, ACTION_MESSAGE, what))
				else
					msg(current_room, what)

		msg(who as text, what as text)
			set name = ".msg"
			var/relay/user/target = relay.getUser(who)
			if(!target)
				info({"The user "[who]" does not exist. You may be using a nickname instead of a network name."})
				return
			var/relay/msg/M = new(user.nameFull, target.nameFull, ACTION_MESSAGE, what)
			relay.route(M)
			echo(M)

		emote(what as text)
			set name = ".emote"
			if(!current_room) return
			var/relay/msg/M = new(user.nameFull, current_room, ACTION_EMOTE, what)
			relay.route(M)
			if(copytext(current_room, 1, 2) != "#")
				echo(M)

		open_code_editor()
			set name = ".open_code_editor"
			winshow(src, "code_editor")

		whois(who as text)
			set name = ".whois"
			var/_full = relay.nicknamedUsers[lowertext(who)]
			if(!_full)
				info({"There is no user "[who]""})
				return
			info({"The nickname "[who]" is registered to &lt;[relay.nicknamedUsers[lowertext(who)]]&gt;"})

		chanlist()
			set name = ".list"
			var/chan_text = {"Visible Channels:"}
			var/list/sorted_channels = new()
			for(var/chan_name in relay.namedChannels)
				sorted_channels += relay.namedChannels[chan_name]
			sorted_channels = dd_sortedObjectList(sorted_channels)
			for(var/relay/channel/C in sorted_channels)
				var/status = {""}
				if(C.status & STATUS_HIDDEN) continue
				if(C.status & STATUS_CLOSED) status += " (CLOSED)"
				if(C.status & STATUS_LOCKED) status += " (LOCKED)"
				chan_text += "\n    \[[C.activeUsers.len]\][C.name] [status]: [C.topic]"
			info(chan_text)

		channel_status()
			set name = ".status"
			var/relay/channel/C = relay.getChannel(current_room)
			if(!C){ return}
			info({"Channel Status: [C.name]
    Closed: [bool2text(C.status & STATUS_CLOSED)]
    Locked: [bool2text(C.status & STATUS_LOCKED)]
    Hidden: [bool2text(C.status & STATUS_HIDDEN)]"})

		change_nick(new_nick as text)
			set name = ".change_nick"
			preferences.nickname = new_nick
			nicknameSend()

		join(channel as text)
			set name = ".join"
			var/relay/channel/C = relay.getChannel(channel)
			if(C) channel = C.name
			relay.route(new /relay/msg(user.nameFull, "#[channel]", ACTION_JOIN))
			if(!C) C = relay.getChannel(channel)
			if(!C) return
			//add_room(C.name, TRUE)
			switch_chan("#[C.name]")

		leave(channel as text|null)
			set name = ".leave"
			if(!channel)
				channel = current_room
			var/relay/channel/C = relay.getChannel(channel)
			if(C)
				relay.route(new /relay/msg(user.nameFull, "#[C.name]", ACTION_LEAVE))
				roomRemove("#[C.name]")
			else
				roomRemove(channel)

		close()
			set name = ".close"
			var/channel = winget(src, "channels", "current-tab")
			roomRemove("#[channel]")
			leave(channel)

		/*disconnect()
			user.disconnect()*/

		switch_chan(channel as text)
			set name = ".switch"
			current_room = channel
			winset(src, "channels", "current-tab=[channel]")
			var/title = winget(src, channel, "title")
			if(copytext(title,1,2) == "*")
				title = copytext(title,2)
				winset(src, channel, "title='[title]'")

		operate(action as text, username as text, value as num)
			set name = ".operate"
			var/channel = current_room
			var/relay/channel/C = relay.getChannel(copytext(channel,2))
			var/relay/user/U = relay.getUser(username)
			if(!C) return
			var/status = C.status
			var/p_level = C.permissionLevel(username)
			if(U) username = U.nameFull
			switch(lowertext(action))
				if("topic")
					relay.route(new /relay/msg(user.nameFull, channel, ACTION_OPERATE, "topic=[url_encode(value)];"))
				if("block")
					var/newp = value? PERMISSION_BLOCKED : PERMISSION_NORMAL
					relay.route(new /relay/msg(user.nameFull, channel, ACTION_OPERATE, "user=[username]:[newp];"))
				if("mute")
					if(p_level == PERMISSION_BLOCKED)
						relay.route(new /relay/msg(SYSTEM, "[user.nameFull][channel]", ACTION_DENIED, "You cannot mute [username], the user is already blocked."))
						return
					var/newp = value? PERMISSION_MUTED : PERMISSION_NORMAL
					relay.route(new /relay/msg(user.nameFull, channel, ACTION_OPERATE, "user=[username]:[newp];"))
				if("voice")
					if(p_level > PERMISSION_VOICED)
						relay.route(new /relay/msg(SYSTEM, "[user.nameFull][channel]", ACTION_DENIED, "You cannot voice [username], the user already has a higher permission level."))
						return
					var/newp = value? PERMISSION_VOICED : PERMISSION_NORMAL
					relay.route(new /relay/msg(user.nameFull, channel, ACTION_OPERATE, "user=[username]:[newp];"))
				if("operator")
					if(p_level > PERMISSION_OPERATOR)
						relay.route(new /relay/msg(SYSTEM, "[user.nameFull][channel]", ACTION_DENIED, "You cannot make [username] an operator, the user already has a higher permission level."))
						return
					var/newp = value? PERMISSION_OPERATOR : PERMISSION_NORMAL
					relay.route(new /relay/msg(user.nameFull, channel, ACTION_OPERATE, "user=[username]:[newp];"))
				if("owner")
					if(p_level == PERMISSION_OWNER && username != user.nameFull)
						relay.route(new /relay/msg(SYSTEM, "[user.nameFull][channel]", ACTION_DENIED, "You cannot [username]'s permission level, the user is a channel owner."))
						return
					var/newp = value? PERMISSION_OWNER : PERMISSION_NORMAL
					relay.route(new /relay/msg(user.nameFull, channel, ACTION_OPERATE, "user=[username]:[newp];"))
				if("locked")
					var/new_s
					if(value){ new_s = status |  STATUS_LOCKED}
					else{      new_s = status & ~STATUS_LOCKED}
					relay.route(new /relay/msg(user.nameFull, channel, ACTION_OPERATE, "status=[new_s];"))
				if("closed")
					var/new_s
					if(value) new_s = status |  STATUS_CLOSED
					else      new_s = status & ~STATUS_CLOSED
					relay.route(new /relay/msg(user.nameFull, channel, ACTION_OPERATE, "status=[new_s];"))
				if("hidden")
					var/new_s
					if(value){ new_s = status |  STATUS_HIDDEN}
					else{      new_s = status & ~STATUS_HIDDEN}
					relay.route(new /relay/msg(user.nameFull, channel, ACTION_OPERATE, "status=[new_s];"))


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
			execute(var/client/who, arg_text)
				who.whois(arg_text)
			help()
				return {"
Used to determine a user's network name. A private message must be sent to a network name, not a nickname.
Usage: /whois nickname
					"}

		list
			aliases = "list"
			execute(var/client/who, arg_text)
				who.chanlist()
			help()
				return {"
Used to query the server for a list of visible channels.
Usage: /list
					"}

		nick
			aliases = "nick"
			execute(var/client/who, arg_text)
				if(!arg_text){ return}
				who.change_nick(arg_text)
			help()
				return {"
Used to change your nickname.
Usage: /nick newnick
  newnick: The new nickname you wish to use
  					"}

		join
			aliases = "join"
			execute(var/client/who, arg_text)
				var/list/_args = relay.text2list(arg_text, " ")
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
			execute(var/client/who, arg_text)
				who.emote(arg_text)
			help()
				return {"
Used to emote. This sends a message to the channel describing an action you are performing.
Usage: /me action
  action: The message you would like to send, such as "eats rice".
  					"}

		code
			aliases = "code"
			execute(var/client/who, arg_text)
				who.open_code_editor()
			help()
				return {"
(Functional, But Incomplete) Used to open the code editor window to send code messages.
Usage: /code
					"}

		channel_status
			aliases = list("status")
			execute(var/client/who, arg_text)
				who.channel_status()
			help()
				return {"
(Temporary). Used to view a channel's status
Usage: /status"}

		leave
			aliases = "leave"
			execute(var/client/who, arg_text)
				var/list/_args = relay.text2list(arg_text, " ")
				if(!_args.len) return
				var/chan = _args[1]
				if(!chan) chan = who.current_room
				who.leave(chan)
			help()
				return {"
Used to leave channels.
Usage: /leave channel
  channel: The channel you wish to leave. The default is the current channel"}

		private
			aliases = list("pm","msg")
			execute(var/client/who, arg_text)
				var/list/_args = relay.text2list(arg_text, " ")
				if(!_args.len) return
				var/user_name = _args[1]
				_args.Cut(1,2)
				var/body = dd_list2text(_args, " ")
				who.msg(user_name, body)
			help()
				return {"
Used to send a private message to another user.
Usage: /msg netname message
  netname: The Network Name of the user you wish to message
  message: The body of your message"}

		topic
			aliases = "topic"
			execute(var/client/who, arg_text)
				if(!arg_text){ return}
				who.operate("topic", null, arg_text)
			help()
				return {"
You must be a channel operator to use this command. Used to change the channel topic.
Usage: /topic newtopic
  newtopic: The new topic for this channel"}

		lock
			aliases = list("lock","l")
			execute(var/client/who, arg_text)
				var/list/_args = relay.text2list(arg_text, " ")
				var/_value = (_args.len >= 1)? who.text2bool(_args[1]) : TRUE
				who.operate("locked", null, _value)
			help()
				return {"
You must be a channel operator to use this command. Used to lock a channel. Users without voice cannot chat while the channel is locked.
Usage: /lock status
  status: 0 or false to unlock the channel, 1, true, or default to lock"}

		open
			aliases = list("close")
			execute(var/client/who, arg_text)
				var/list/_args = relay.text2list(arg_text, " ")
				var/_value = (_args.len >= 1)? who.text2bool(_args[1]) : TRUE
				who.operate("closed", null, _value)
			help()
				return {"
You must be a channel operator to use this command. Used to close or open a channel to new connections. Users without voice cannot join a channel which is closed.
Usage: /close status
  status: 1, true, or default to close a channel, 0 or false to open it."}

		hide
			aliases = list("hide")
			execute(var/client/who, arg_text)
				var/list/_args = relay.text2list(arg_text, " ")
				var/_value = (_args.len >= 1)? who.text2bool(_args[1]) : TRUE
				who.operate("hidden", null, _value)
			help()
				return {"
You must be a channel operator to use this command. Used to change the visibility of a channel. Hidden channels will not be advertised by the server.
Usage: /hide status
  status: 1, true, or default to hide a channel, 0 or false to make it visible."}

		block
			aliases = list("block")
			execute(var/client/who, arg_text)
				var/list/_args = relay.text2list(arg_text, " ")
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
			execute(var/client/who, arg_text)
				var/list/_args = relay.text2list(arg_text, " ")
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
			execute(var/client/who, arg_text)
				var/list/_args = relay.text2list(arg_text, " ")
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
			execute(var/client/who, arg_text)
				var/list/_args = relay.text2list(arg_text, " ")
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
			execute(var/client/who, arg_text)
				var/list/_args = relay.text2list(arg_text, " ")
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
			execute(var/client/who, arg_text)
				var/list/_args = relay.text2list(arg_text, " ")
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
					var/client/command/C = who.commands[lowertext(command)]
					if(!C)
						who.info("The specified command does not exist: [command]")
					who.info(C.help())
			help()
				return {"
Used to view command usage documents.
Usage: /help command
  command: The command you need help with. If left out, a list of all avaliable commands will be displayed."}
