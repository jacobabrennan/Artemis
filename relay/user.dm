

//------------------------------------------------------------------------------

relay/user
	parent_type = /datum

	var
		nameFull
		nameSimple
		nameHost
		nickname
		datum/intelligence
		list/channels = new()
		isRemote

	Del()
		DIAG("Deleting User: [nameFull]")
		CRASH()
		if(nameFull)
			var/relay/user/U = relay.getUser(nameFull)
			if(U == src)
				relay.namedUsers.Remove(nameFull)
				if(relay.nicknamedUsers[lowertext(nickname)] == nameFull)
					relay.nicknamedUsers.Remove(lowertext(nickname))
		. = ..()

	proc

		msg(_target, _action, _body, _time)
			var /relay/msg/newMsg = new(nameFull, _target, _action, _body, _time)
			return relay.route(newMsg)

		setName(newLocalName, newHostName)
			nameSimple = relay.validId(newLocalName)
			nameHost = newHostName
			if(newHostName)
				nameFull = "[nameSimple].[nameHost]"
			else
				nameFull = nameSimple
			return nameFull

		receive(relay/msg/msg)
			if(isRemote)
				CRASH("Attempt to route Remote User locally: [msg.target],[msg.sender],[msg.action]")
				return
			var result
			if(intelligence)
				if(hascall(intelligence,"receive"))
					result = call(intelligence,"receive")(msg)
			if(!result)
				drop()

		drop()
			for(var/chanName in channels)
				msg("#[chanName]", ACTION_LEAVE)
			relay.namedUsers -= nameFull
			if(relay.nicknamedUsers[lowertext(nickname)] == nameFull)
				relay.nicknamedUsers -= lowertext(nickname)
			del src

		channelAdd(chan_name)
			channels.Add(chan_name)

		channelRemove(chan_name)
			channels.Remove(chan_name)
