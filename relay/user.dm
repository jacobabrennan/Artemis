

//------------------------------------------------------------------------------

relay/user
	parent_type = /datum

	var
		fullName
		simpleName
		nickname
		datum/intelligence
		list/channels = new()

	Del()
		if(fullName)
			var/relay/user/U = relay.getUser(fullName)
			if(U == src)
				relay.users.Remove(fullName)
				if(relay.nicknames[lowertext(nickname)] == fullName)
					relay.nicknames.Remove(lowertext(nickname))
		. = ..()

	proc
		setName(newFullName)
			fullName = relay.validId(newFullName)
			var/list/namePath = relay.text2list(fullName, ".")
			if(namePath.len > 1)
				simpleName = "[namePath[1]].[namePath[2]]"
			else
				simpleName = fullName
			return fullName

		receive(relay/msg/msg)
			var result
			if(intelligence)
				if(hascall(intelligence,"receive"))
					result = call(intelligence,"receive")(msg)
			if(!result)
				drop()

		drop()
			for(var/chanName in channels)
				relay.route(new /relay/msg(fullName, "#[chanName]", ACTION_LEAVE))
			relay.users -= fullName
			if(relay.nicknames[lowertext(nickname)] == fullName)
				relay.nicknames -= lowertext(nickname)
			del src

		channelAdd(chan_name)
			channels.Add(chan_name)

		channelRemove(chan_name)
			channels.Remove(chan_name)
