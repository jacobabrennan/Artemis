

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
				relay.users.Remove(nameFull)
				if(relay.nicknames[lowertext(nickname)] == nameFull)
					relay.nicknames.Remove(lowertext(nickname))
		. = ..()

	proc
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
				relay.route(new /relay/msg(nameFull, "#[chanName]", ACTION_LEAVE))
			relay.users -= nameFull
			if(relay.nicknames[lowertext(nickname)] == nameFull)
				relay.nicknames -= lowertext(nickname)
			del src

		channelAdd(chan_name)
			channels.Add(chan_name)

		channelRemove(chan_name)
			channels.Remove(chan_name)
