relay/channel
	dd_SortValue() // For the /list command
		return -(activeUsers.len)


//------------------------------------------------------------------------------

relay/channel
	parent_type = /datum
	var
		name
		topic
		list/activeUsers = new() // list of full_names currently in channel
		list/localUsers = new() // subset of activeUsers on local server
		list/userPermissions = new // full_names associated with permission tiers (5 to 0)
		status = 0 // see status bit flags in defines.dm

	proc
		add(userName)
			var/relay/user/U = relay.getUser(userName)
			if(!U) return
			if(!activeUsers.len)
				userPermissions[userName] = PERMISSION_OWNER
			activeUsers += userName
			U.channelAdd(name)
			relay.route(new /relay/msg(SYSTEM, "[userName]#[name]", ACTION_TRAFFIC, "topic=[url_encode(topic)];"))
			if(!findtextEx(userName, "."))
				localUsers += userName
			for(var/localUser in localUsers)
				relay.route(new /relay/msg(SYSTEM, "[localUser]#[name]", ACTION_TRAFFIC, "join=[userName];"))

		remove(userName)
			activeUsers -= userName
			localUsers -= userName
			var /relay/user/U = relay.getUser(userName)
			if(U)
				U.channelRemove(name)
			if(!activeUsers.len)
				spawn()
					relay.channels.Remove(name)
					del src
			for(var/localUser in localUsers)
				relay.route(new /relay/msg(SYSTEM, "[localUser]#[name]", ACTION_TRAFFIC, "leave=[userName];"))
	proc
		receive(relay/msg/msg)
			var resultCode = ACTION_SUCCESS // Important! Will not route to other servers without this value returned
			switch(msg.action)
				if(ACTION_MESSAGE, ACTION_EMOTE, ACTION_CODE)
					resultCode = actionMessage(msg)
				if(ACTION_JOIN)
					resultCode = actionJoin(msg)
				if(ACTION_LEAVE)
					resultCode = actionLeave(msg)
				if(ACTION_OPERATE)
					resultCode = actionOperate(msg)
			return resultCode

		actionMessage(relay/msg/msg)
			if(!canSpeak(msg.sender))
				spawn()
					relay.route(new /relay/msg(SYSTEM, "[msg.sender]#[name]", ACTION_DENIED, "You do not have permission to send messages to this channel."))
				return ACTION_DENIED
			for(var/userName in localUsers)
				relay.route(new /relay/msg(msg.sender, "[userName]#[name]", msg.action, msg.body, msg.time))

		actionJoin(relay/msg/msg)
			if(msg.sender in activeUsers)
				return ACTION_FAILURE
			if(permissionLevel(msg.sender) <= PERMISSION_BLOCKED)
				spawn()
					relay.route(new /relay/msg(SYSTEM, "[msg.sender]#[name]", ACTION_DENIED, "You do not have permission to join this channel."))
				return ACTION_DENIED
			add(msg.sender)
			return ACTION_SUCCESS

		actionLeave(relay/msg/msg)
			if(!(msg.sender in activeUsers))
				return ACTION_MALFORMED
			remove(msg.sender)
			return ACTION_SUCCESS

		actionOperate(relay/msg/msg)
			// Cancel out if the msg sender doesn't have appropriate permissions
			if(!canOperate(msg.sender))
				spawn()
					relay.route(new /relay/msg(SYSTEM, "[msg.sender]#[name]", ACTION_DENIED, "You do not have permission to operate this channel."))
				return ACTION_DENIED
			//
			var/list/params = params2list(lowertext(msg.body))
			for(var/index in params)
				switch(index) // closed, hidden, locked
					if("status")
						var/value = text2num(params[index])
						value &= (STATUS_CLOSED | STATUS_LOCKED | STATUS_HIDDEN)
						status = value
						for(var/user_name in activeUsers)
							relay.route(new /relay/msg(SYSTEM, "[user_name]#[name]", ACTION_TRAFFIC, "status=[status];"))
					if("topic")
						topic = url_decode(params[index])
						for(var/user_name in localUsers)
							relay.route(new /relay/msg(SYSTEM, "[user_name]#[name]", ACTION_TRAFFIC, "topic=[url_encode(topic)];"))
					if("user")
						var usersList = params[index]
						var newList = {""}
						var /list/senderPath = relay.text2list(msg.sender, ".")
						var remoteHandle = (senderPath.len > 1)? senderPath[senderPath.len] : null
						for(var/section in relay.text2list(usersList, " "))
							var equalPos = findtextEx(section, ":")
							if(!equalPos) continue
							var userName = copytext(section, 1, equalPos)
							if(remoteHandle)
								if(senderPath == 1)
									userName += ".[remoteHandle]"
								else
									var/list/userPath = relay.text2list(userName, ".")
									var/_proxy = userPath[userPath.len]
									if(_proxy == relay.rootServer.handle)
										userPath.Cut(userPath.len)
										userName = relay.list2text(userPath, ".")
									else
										userName += ".[remoteHandle]"
							var newPermission = text2num(copytext(section, equalPos+1))
							newPermission &= ~PERMISSION_ACTIVEFLAG
							newPermission = min(newPermission, permissionLevel(msg.sender))
							if(!(userName in activeUsers) && newPermission == PERMISSION_NORMAL)
								userPermissions -= userName
							else
								userPermissions[userName] = newPermission
							if(length(newList)) newList += " "
							newList += "[userName]:[newPermission]"
							newPermission = max(0, min(PERMISSION_OWNER, newPermission))
							for(var/_name in localUsers)
								relay.route(new /relay/msg(SYSTEM, "[_name]#[name]", ACTION_TRAFFIC, "user=[userName]:[newPermission]"))
							if((newPermission <= PERMISSION_BLOCKED) && (userName in activeUsers))
								remove(userName)
						params[index] = newList
						msg.body = list2params(params)
					//if("server")
						// TODO: Blocking servers


//------------------------------------------------------------------------------

relay/channel
	proc
		chan2string()
			if(!length(topic))
				topic = "[name] -- Artemis Chat"
			var/string = {"!name=[name];!status=[status];!topic=[url_encode(topic)]"}
			for(var/userName in userPermissions)
				var/tier = userPermissions[userName]
				if(userName in activeUsers)
					tier |= PERMISSION_ACTIVEFLAG
				string += ";[userName]=[tier]"
			for(var/userName in activeUsers)
				if(userName in userPermissions) continue
				string += ";[userName]=[PERMISSION_ACTIVEFLAG]"
			return string
		/*status(){
			var/statlist = {"!name=[name];status=[status];!topic=[url_encode(topic)]"}
			for(var/user_name in activeUsers){
				var/tier = permission_level(user_name)
				statlist += ";[user_name]=[tier]"
				}
			}*/


//------------------------------------------------------------------------------

relay/channel
	proc
		permissionLevel(userName)
			userName = lowertext(userName)
			if(!(userName in userPermissions))
				return PERMISSION_NORMAL
			return userPermissions[userName]

		isOwner(userName)
			if(permissionLevel(userName) >= PERMISSION_OWNER) return TRUE

		canOperate(userName)
			if(!(userName in activeUsers)) return FALSE
			if(permissionLevel(userName) >= PERMISSION_OPERATOR) return TRUE

		canSpeak(userName)
			if(!(userName in activeUsers)) return FALSE
			var/tier = permissionLevel(userName)
			if(tier >= PERMISSION_VOICED) return TRUE
			if(status & STATUS_LOCKED) return FALSE
			if(tier <= PERMISSION_MUTED) return FALSE
			return TRUE

		canJoin(userName)
			var/tier = permissionLevel(userName)
			if(tier >= PERMISSION_VOICED) return TRUE
			if(status & STATUS_CLOSED) return FALSE
			if(tier <= PERMISSION_BLOCKED) return FALSE
			return TRUE