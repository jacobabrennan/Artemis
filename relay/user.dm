

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
		msg(_target, _action, _body, _time)
			var /artemis/msg/newMsg = new(nameFull, _target, _action, _body, _time)
			return artemis.route(newMsg)

		receive(artemis/msg/msg)
			if(nameHost)
				CRASH("Attempt to route Remote User locally: [msg.target],[msg.sender],[msg.action]")
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
			// NOT called by the artemis when a user drops.
			msg(SYSTEM, ACTION_DROPUSER)
			del src

		setName(newLocalName, newHostName)
			nameSimple = artemis.validId(newLocalName)
			nameHost = newHostName
			if(newHostName)
				ASSERT(newHostName != artemis.handle)
				nameFull = "[nameSimple].[nameHost]"
			else
				nameFull = nameSimple
			return nameFull

		channelAdd(chanName)
			channels.Add(chanName)

		channelRemove(chanName)
			channels.Remove(chanName)

