

//-- Artemis artemis Users -------------------------------------------------------

artemis/user
	parent_type = /datum

	var
		nameFull
		nameSimple
		nameHost
		nickname
		datum/intelligence
		list/channels = new()

	Del()
		if(nameFull)
			var/artemis/user/U = artemis.getUser(nameFull)
			if(U == src)
				artemis.namedUsers.Remove(nameFull)
				if(artemis.nicknamedUsers[lowertext(nickname)] == nameFull)
					artemis.nicknamedUsers.Remove(lowertext(nickname))
		. = ..()

	//-- Message Handling ----------------------------
	proc
		msg(_target, _action, _channel, _body, _time)
			var /artemis/msg/newMsg = new(src, _target, _action, _channel, _body, _time)
			return artemis.route(newMsg)

		receive(artemis/msg/msg)
			if(nameHost)
				CRASH("Attempt to route Remote User locally: [msg.target.nameFull],[msg.sender.nameFull],[msg.action]")
				return
			var result
			if(intelligence)
				if(hascall(intelligence,"receive"))
					result = call(intelligence,"receive")(msg, src)
			if(!result)
				drop()

	//------------------------------------------------
	proc
		drop()
			// Call to manually drop a user.
			// NOT called by artemis when a user drops.
			msg(artemis.SYSTEM, ARTEMIS_ACTION_DROPUSER)
			del src

		channelAdd(artemis/channel/channel)
			channels.Add(channel)

		channelRemove(artemis/channel/channel)
			channels.Remove(channel)


		setName(newLocalName, newHostName)
			nameSimple = artemis.validId(newLocalName)
			nameHost = newHostName
			if(newHostName)
				ASSERT(newHostName != artemis.handle)
				nameFull = "[nameSimple].[nameHost]"
			else
				nameFull = nameSimple
			return nameFull

		setNick(newNick)
			// Sanitize Nickname
			var oldNick = nickname
			var newNickname = newNick
			if(length(newNickname) > ARTEMIS_MAX_NICKNAME_LENGTH)
				newNickname = copytext(newNickname, 1, ARTEMIS_MAX_NICKNAME_LENGTH+1)
				DIAG("Smaller: [newNickname]")
			var/global/regex/noLines = regex(@"\n", "g")
			newNickname = noLines.Replace(newNickname, "")
			// Clear the nickname if no nick supplied or there's a collision
			var clear = FALSE
			if(!newNickname || newNickname == "clear")
				DIAG("1")
				clear = TRUE
			else if((lowertext(newNickname) in artemis.nicknamedUsers) && (artemis.nicknamedUsers[lowertext(newNickname)] != nameFull))
				DIAG("2")
				clear = TRUE
			if(clear)
				artemis.nicknamedUsers.Remove(lowertext(nickname))
				nickname = null
				newNickname = null
				DIAG("Clearing: [nickname]")
			// Set the New Nickname, and store in nicknames list
			else
				artemis.nicknamedUsers.Remove(lowertext(nickname))
				nickname = newNickname
				artemis.nicknamedUsers[lowertext(nickname)] = nameFull
				DIAG("SUCCESS: [nickname]")
			// If nickname was changed, generate traffic in joined channels
			if(oldNick != nickname)
				var t_body = "nick=[nameFull]:[url_encode(oldNick)];"
				for(var/artemis/channel/joinedChannel in channels)
					if(!istype(joinedChannel)) continue
					for(var/artemis/user/channelUser in joinedChannel.localUsers)
						artemis.msg(artemis.SYSTEM, channelUser, ARTEMIS_ACTION_TRAFFIC, joinedChannel, t_body)
			// broadcast msg to all dependent servers (but don't broadcast nonlocal actions)
			if(nameHost)
				return
			for(var/loopHandle in artemis.namedServers)
				var /artemis/server/remoteServer = artemis.getServer(loopHandle)
				var /artemis/user/remoteSystem = remoteServer.SYSTEM
				msg(remoteSystem, ARTEMIS_ACTION_NICKNAME, null, newNickname)
