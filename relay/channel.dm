

//-- Artemis artemis Channels ----------------------------------------------------

artemis/channel
	parent_type = /datum
	var
		name
		topic
		list/activeUsers = new() // list of user instances currently in channel
		list/localUsers = new() // subset of activeUsers on local server
		list/userPermissions = new // user associated with permission tiers (5 to 0)
		status = 0 // see status bit flags in defines.dm

	New(newName)
		. = ..()
		name = artemis.validId(newName)
		topic = name
		artemis.namedChannels[name] = src

	//-- User Management -----------------------------
	proc
		addUser(artemis/user/joinUser)
			if(!activeUsers.len)
				userPermissions[joinUser] = ARTEMIS_PERMISSION_OWNER
			activeUsers.Add(joinUser)
			joinUser.channelAdd(src)
			artemis.msg(artemis.SYSTEM, joinUser, ARTEMIS_ACTION_TRAFFIC, src, "topic=[url_encode(topic)];")
			if(!joinUser.nameHost)
				localUsers.Add(joinUser)
			for(var/artemis/user/localUser in localUsers)
				artemis.msg(artemis.SYSTEM, localUser, ARTEMIS_ACTION_TRAFFIC, src, "join=[joinUser.nameFull];")

		removeUser(artemis/user/removeUser)
			activeUsers.Remove(removeUser)
			localUsers.Remove(removeUser)
			if(removeUser)
				removeUser.channelRemove(src)
			if(!activeUsers.len)
				spawn()
					artemis.namedChannels.Remove(name)
					del src
			for(var/localUser in localUsers)
				artemis.msg(artemis.SYSTEM, localUser, ARTEMIS_ACTION_TRAFFIC, src, "leave=[removeUser.nameFull];")

	//-- Message Handling ----------------------------
	proc
		receive(artemis/msg/msg)
			. = ARTEMIS_RESULT_SUCCESS // Important! Will not route to other servers without this value returned
			var resultCode
			switch(msg.action)
				if(ARTEMIS_ACTION_MESSAGE, ARTEMIS_ACTION_EMOTE, ARTEMIS_ACTION_CODE)
					resultCode = actionMessage(msg)
				if(ARTEMIS_ACTION_JOIN)
					resultCode = actionJoin(msg)
				if(ARTEMIS_ACTION_LEAVE)
					resultCode = actionLeave(msg)
				if(ARTEMIS_ACTION_OPERATE)
					resultCode = actionOperate(msg)
			if(resultCode)
				return resultCode

		actionMessage(artemis/msg/msg)
			if(!canSpeak(msg.sender))
				return ARTEMIS_ACTION_DENIED
			for(var/artemis/user/localUser in localUsers)
				artemis.msg(msg.sender, localUser, msg.action, src, msg.body, msg.time)

		actionJoin(artemis/msg/msg)
			if(msg.sender in activeUsers)
				return ARTEMIS_RESULT_FAILURE
			if(permissionLevel(msg.sender) <= ARTEMIS_PERMISSION_BLOCKED)
				return ARTEMIS_ACTION_DENIED
			addUser(msg.sender)
			return ARTEMIS_RESULT_SUCCESS

		actionLeave(artemis/msg/msg)
			if(!(msg.sender in activeUsers))
				return ARTEMIS_RESULT_MALFORMED
			removeUser(msg.sender)
			return ARTEMIS_RESULT_SUCCESS

		actionOperate(artemis/msg/msg)
			// Cancel out if the msg sender doesn't have appropriate permissions
			if(!canOperate(msg.sender))
				return ARTEMIS_ACTION_DENIED
			//
			var/list/params = params2list(lowertext(msg.body))
			for(var/index in params)
				switch(index) // closed, hidden, locked
					if("status")
						var/value = text2num(params[index])
						value &= (ARTEMIS_STATUS_CLOSED | ARTEMIS_STATUS_LOCKED | ARTEMIS_STATUS_HIDDEN)
						status = value
						for(var/artemis/user/localUser in localUsers)
							artemis.msg(artemis.SYSTEM, localUser, ARTEMIS_ACTION_TRAFFIC, src, "status=[status];")
					if("topic")
						topic = url_decode(params[index])
						for(var/artemis/user/localUser in localUsers)
							artemis.msg(artemis.SYSTEM, localUser, ARTEMIS_ACTION_TRAFFIC, src, "topic=[url_encode(topic)];")
					//if("user") // This is a mess
						/*
						var usersList = params[index]
						var newList = {""}
						var /list/senderPath = artemis.text2list(msg.sender, ".")
						var remoteHandle = (senderPath.len > 1)? senderPath[senderPath.len] : null
						for(var/section in artemis.text2list(usersList, " "))
							var equalPos = findtextEx(section, ":")
							if(!equalPos) continue
							var userName = copytext(section, 1, equalPos)
							if(remoteHandle)
								if(senderPath == 1)
									userName += ".[remoteHandle]"
								else
									var/list/userPath = artemis.text2list(userName, ".")
									var/_proxy = userPath[userPath.len]
									if(_proxy == artemis.handle)
										userPath.Cut(userPath.len)
										userName = artemis.list2text(userPath, ".")
									else
										userName += ".[remoteHandle]"
							var newPermission = text2num(copytext(section, equalPos+1))
							newPermission &= ~ARTEMIS_PERMISSION_ACTIVEFLAG
							newPermission = min(newPermission, permissionLevel(msg.sender))
							if(!(userName in activeUsers) && newPermission == ARTEMIS_PERMISSION_NORMAL)
								userPermissions -= userName
							else
								userPermissions[userName] = newPermission
							if(length(newList)) newList += " "
							newList += "[userName]:[newPermission]"
							newPermission = max(0, min(ARTEMIS_PERMISSION_OWNER, newPermission))
							for(var/_name in localUsers)
								artemis.msg(SYSTEM, "[_name]#[name]", ARTEMIS_ACTION_TRAFFIC, "user=[userName]:[newPermission]")
							if((newPermission <= ARTEMIS_PERMISSION_BLOCKED) && (userName in activeUsers))
								removeUser(userName)
						params[index] = newList
						msg.body = list2params(params)
						*/
					//if("server")
						// TODO: Blocking servers


//-- Utilities -----------------------------------------------------------------

//-- Text Utilities ------------------------------
artemis/channel
	proc
		toJSON()
			if(!length(topic))
				topic = "[name]"
			var /list/objectData = list()
			objectData["name"] = name
			objectData["status"] = status
			objectData["topic"] = topic
			var /list/permissions = list()
			for(var/artemis/user/permissionUser in userPermissions)
				if(permissionUser.nameHost) continue
				var tier = userPermissions[permissionUser]
				if(permissionUser in activeUsers)
					tier |= ARTEMIS_PERMISSION_ACTIVEFLAG
				permissions[permissionUser.nameFull] = tier
			for(var/artemis/user/permissionUser in activeUsers)
				if(permissionUser in userPermissions) continue
				if(permissionUser.nameHost) continue
				permissions[permissionUser.nameFull] = ARTEMIS_PERMISSION_ACTIVEFLAG
			objectData["users"] = permissions
			return objectData

//-- Permission Access Utilities -----------------
artemis/channel
	proc
		permissionLevel(artemis/user/user)
			user.nameFull = lowertext(user.nameFull)
			if(!(user.nameFull in userPermissions))
				return ARTEMIS_PERMISSION_NORMAL
			return userPermissions[user]

		isOwner(artemis/user/user)
			if(permissionLevel(user) >= ARTEMIS_PERMISSION_OWNER) return TRUE

		canOperate(artemis/user/user)
			if(!(user in activeUsers)) return FALSE
			if(permissionLevel(user) >= ARTEMIS_PERMISSION_OPERATOR) return TRUE

		canSpeak(artemis/user/user)
			if(!(user in activeUsers)) return FALSE
			var/tier = permissionLevel(user)
			if(tier >= ARTEMIS_PERMISSION_VOICED) return TRUE
			if(status & ARTEMIS_STATUS_LOCKED) return FALSE
			if(tier <= ARTEMIS_PERMISSION_MUTED) return FALSE
			return TRUE

		canJoin(artemis/user/user)
			var/tier = permissionLevel(user)
			if(tier >= ARTEMIS_PERMISSION_VOICED) return TRUE
			if(status & ARTEMIS_STATUS_CLOSED) return FALSE
			if(tier <= ARTEMIS_PERMISSION_BLOCKED) return FALSE
			return TRUE