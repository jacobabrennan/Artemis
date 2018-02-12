

//-- World Configuration - world/Topic() must be handled by the relay ----------

world/Topic(T, Addr, Master, Key)
	. = ..()
	if(relay)
		var result = relay.import(T, Addr)
		if(result == RESULT_NOTARTEMIS)
			return .
		return result


//-- Artemis Relay -------------------------------------------------------------

var /relay/relay
relay
	New(newHandle)
		. = ..()
		relay = src
		var result = configure(newHandle)
		if(!result) del src

	var
		handle
		list/localUsers = new()
		list/namedServers = new() // Remote Servers: Server Handle => Server Instance
		list/addressedHandles = new() // Handles of remote servers: IP_Address => Server Handle
		list/namedChannels = new() // All Channels: Channel Name => Channel Instance
		list/namedUsers = new() // All users on all servers: name.handle => User Instance
		list/nicknamedUsers = new() // All nicknames, in lowertext: Nickname => Full Name

	//------------------------------------------------
	proc

		getServer(serverHandle)
			return namedServers[serverHandle]

		getUser(userName)
			userName = lowertext(userName)
			var /relay/user/U = namedUsers[userName]
			if(istype(U))
				return U
		getChannel(chanName)
			chanName = validId(chanName)
			var/relay/channel/C = namedChannels[chanName]
			if(istype(C))
				return C

		validId(rawId)
			var /list/namePath = text2list(rawId, ".")
			var first = namePath[1]
			first = alphanumeric(lowertext(first))
			if(length(first) > 16)
				first = copytext(rawId, 1, 17)
			namePath[1] = first
			rawId = list2text(namePath, ".")
			return rawId

		registerUser(simpleName, serverHandle, datum/intelligence)
			// Sanitize user name
			simpleName = validId(simpleName)
			// Get user from appropriate server
			var /relay/user/newUser
			if((!serverHandle) || (serverHandle == handle))
				if(simpleName in namedUsers) return ACTION_CONFLICT
				newUser = new()
				newUser.setName(simpleName, null)
				localUsers.Add(newUser)
			else
				var /relay/server/proxy = getServer(serverHandle)
				var nameFull = "[simpleName].[serverHandle]"
				if(nameFull in namedUsers)
					DIAG("Conflict: [nameFull]")
					return ACTION_CONFLICT
				if(!proxy)
					DIAG("No Proxy: [simpleName], [serverHandle]. ([serverHandle] != [handle])")
				newUser = proxy.addUser(simpleName)
			//
			if(!istype(newUser))
				return ACTION_BADUSER
			// Connect intelligence and add to users list
			newUser.intelligence = intelligence
			namedUsers[newUser.nameFull] = newUser
			//
			return RESULT_SUCCESS


	//------------------------------------------------
	proc
		receive(relay/msg/msg)
		// Start system message, such as server updates, connections, and disconnects
			. = -1 // What is this -1?
			var resultCode
			switch(msg.action)
				if(ACTION_DISCONNECT)
					resultCode = actionDisconnect(msg)
				if(ACTION_REGSERVER)
					resultCode = actionRegisterServer(msg)
				if(ACTION_REGUSER)
					resultCode = actionRegisterUser(msg)
				if(ACTION_CHANSYNC)
					resultCode = actionChannelSync(msg)
				if(ACTION_NICKNAME)
					resultCode = actionNickname(msg)
			if(resultCode)
				return resultCode
			return .

		actionDisconnect(relay/msg/msg)
			var /list/senderPath = text2list(lowertext(msg.sender), ".")
			if((senderPath.len < 2) || (senderPath[1] != SYSTEM)) return
			var remoteHandle = senderPath[2]
			var /relay/server/oldServer = getServer(remoteHandle)
			if(!oldServer) return
			namedServers[oldServer.handle] = null
			namedServers.Remove(oldServer.handle)
			oldServer.drop()

		actionRegisterServer(relay/msg/msg)
			DIAG("attempting connection")
			// Ensure that this message has been sent by a SYSTEM user
			if(msg.sender != SYSTEM)
				DIAG("Wrong User: [msg.sender]")
				return
			// Parse arguments from message body. Ensure message was formatted correctly
			var /list/argList = params2list(msg.body)
			var remoteHandle   = argList["handle"]
			var remoteAddress  = argList["address" ]
			var _response = argList["response"]
			if(!(remoteHandle && remoteAddress))
				DIAG("Malformed: [remoteHandle], [remoteAddress]")
				return ACTION_MALFORMED
			if(length(remoteHandle) > MAX_HANDLE_LENGTH)
				DIAG("Too Long: [remoteHandle] > [MAX_HANDLE_LENGTH]")
				return // malformed
			// Check for Artemis handle collisions (instance with that handle already connected)
			if(getServer(remoteHandle))
				spawn()
					export(new /relay/msg(SYSTEM, "[SYSTEM].[remoteHandle]", ACTION_COLLISION, remoteHandle), remoteAddress)
				DIAG("Collision")
				return ACTION_COLLISION
			// Create the newly connected Server & SYSTEM user
			var /relay/server/connectingServer = new(remoteHandle)
			connectingServer.address = remoteAddress
			namedServers[remoteHandle] = connectingServer
			addressedHandles[remoteAddress] = remoteHandle
			registerUser(SYSTEM, remoteHandle)
			// Respond with a Register Server action from this Artemis instance
			if(_response)
				DIAG("Response Success")
				return RESULT_SUCCESS
			msg(SYSTEM, "[SYSTEM].[remoteHandle]", ACTION_REGSERVER, "response=true;handle=[handle];")
			// Generate information about all users on this server (except SYSTEM user)
			var /list/usersList = list()
			var /list/prefsList = new()
			for(var/relay/user/localUser in localUsers)
				if(localUser.nameSimple == SYSTEM) continue
				usersList.Add(localUser.nameSimple)
				if(localUser.nickname)
					prefsList.Add(new /relay/msg(localUser.nameSimple, "[SYSTEM].[remoteHandle]", ACTION_NICKNAME, localUser.nickname))
			// Send users list, channels list, and user nicknames
			spawn(1)
				msg(SYSTEM, "[SYSTEM].[remoteHandle]", ACTION_REGUSER, list2text(usersList, " "))
				spawn(1)
					for(var/channelName in namedChannels)
						var/relay/channel/theChannel = namedChannels[channelName]
						msg(SYSTEM, "[SYSTEM].[remoteHandle]", ACTION_CHANSYNC, theChannel.chan2string())
					spawn(1)
						for(var/relay/msg/indexedMessage in prefsList)
							sleep(0)
							route(indexedMessage)
			// Return success
			DIAG("Connection Success")
			return RESULT_SUCCESS

		actionRegisterUser(relay/msg/msg) // Un-refactored
			var /list/sender_path = text2list(lowertext(msg.sender), ".")
			var simpleName = sender_path[1]
			if(simpleName != SYSTEM)
				return
			var string = lowertext(msg.body)
			var remote_handle
			//var/list/sender_path = text2list(msg.sender, ".")
			if(sender_path.len > 1)
				remote_handle = sender_path[sender_path.len]
			var /list/user_names = text2list(string, " ")
			var /list/successes = new()
			var /list/bad_users = new()
			var /list/conflicts = new()
			for(var/user_name in user_names)
				var result
				if(remote_handle)
					result = registerUser(user_name, remote_handle)
				else
					result = registerUser(user_name)
				switch(result)
					if(RESULT_SUCCESS ) successes += user_name
					if(ACTION_BADUSER ) bad_users += user_name
					if(ACTION_CONFLICT) conflicts += user_name
			if(conflicts.len)
				spawn()
					msg(SYSTEM, "[SYSTEM].[remote_handle]", ACTION_CONFLICT, list2text(conflicts, " "))
			if(bad_users.len)
				spawn()
					msg(SYSTEM, "[SYSTEM].[remote_handle]", ACTION_BADUSER, list2text(bad_users, " "))

		actionChannelSync(relay/msg/msg)
			var /list/sender_path = text2list(lowertext(msg.sender), ".")
			if((sender_path.len < 2) || (sender_path[1] != SYSTEM)) return
			var remote_handle = sender_path[2]
			var /list/params = params2list(lowertext(msg.body))
			var chan_name = params["!name"]
			var new_status = text2num(params["!status"])
			var _response = params["!response"]
			var _topic = params["!topic"]
			var remote_sysuser = msg.sender
			var /relay/msg/sync_message
			if(!_response)
				var/relay/channel/C = namedChannels[chan_name]
				if(C)
					var/msg_body = "!response=1;" + C.chan2string()
					sync_message = new(SYSTEM, remote_sysuser, ACTION_CHANSYNC, msg_body)
			if(!isnum(new_status)) new_status = STATUS_NORMAL
			msg(remote_sysuser, "#[chan_name]", ACTION_JOIN)
			msg(remote_sysuser, "#[chan_name]", ACTION_OPERATE, "status=[new_status];topic=[_topic]")
			params.Remove("!name","!status","!response","!topic")
			for(var/user_name in params)
				if(!user_name in namedUsers) continue
				var user_permission = text2num(params[user_name])
				if(user_permission & PERMISSION_ACTIVEFLAG)
					msg("[user_name].[remote_handle]", "#[chan_name]", ACTION_JOIN)
					user_permission &= ~PERMISSION_ACTIVEFLAG
				if(user_permission)
					msg(remote_sysuser, "#[chan_name]", ACTION_OPERATE, "user=[user_name].[remote_handle]:[user_permission];")
			msg(remote_sysuser, "#[chan_name]", ACTION_LEAVE)
			if(sync_message)
				route(sync_message)

		actionNickname(relay/msg/msg)
			return
			// Cancel out if specified user doesn't exist
			var /relay/user/U = namedUsers[msg.sender]
			if(!U) return
			// Sanitize Nickname
			var oldNick = U.nickname
			var newNickname = msg.body ///list/params = params2list(msg.body)
			if(length(newNickname) > 20)
				newNickname = copytext(newNickname, 1, 21)
			// Clear the nickname if: No nick supplied; nick starts with " "; there's a collision
			var clear = FALSE
			if(!newNickname) clear = TRUE
			else if(copytext(newNickname, 1, 2) == " ") clear = TRUE
			else if((lowertext(newNickname) in nicknamedUsers) && (nicknamedUsers[lowertext(newNickname)] != U.nameFull))
				clear = TRUE
			if(clear)
				nicknamedUsers.Remove(lowertext(U.nickname))
				U.nickname = null
				newNickname = null
			// Set the New Nickname, and store in nicknames list
			else
				nicknamedUsers.Remove(lowertext(U.nickname))
				U.nickname = newNickname
				nicknamedUsers[lowertext(U.nickname)] = U.nameFull
			// If nickname was changed, generate traffic in joined channels
			if(oldNick != U.nickname)
				var t_body = "nick=[U.nameFull]:[url_encode(oldNick)];"
				for(var/channelName in U.channels)
					var/relay/channel/joinedChannel = relay.getChannel(channelName)
					if(!istype(joinedChannel)) continue
					for(var/channelUser in joinedChannel.localUsers)
						msg(SYSTEM, "[channelUser]#[joinedChannel.name]", ACTION_TRAFFIC, t_body)
			// Relay msg to all dependent servers (except the origin of the message)
			var /list/senderPath = text2list(lowertext(msg.sender), ".")
			var originHandle
			if(senderPath.len > 1)
				originHandle = senderPath[senderPath.len]
			for(var/loopHandle in namedServers)
				if(loopHandle == handle || originHandle == loopHandle) continue
				msg(msg.sender, "[SYSTEM].[loopHandle]", ACTION_NICKNAME, newNickname)

	//------------------------------------------------
	proc

		msg(_sender, _target, _action, _body, _time)
			return route(new /relay/msg(_sender, _target, _action, _body, _time))

		route(relay/msg/msg)
			if(!handle) return
			// Output some diagnostic information
			#ifdef DEBUG
			if(msg.sender == SYSTEM)
				world << {"<span style="color:#00f;">Routing:: [msg.action]: [msg.sender], [msg.target] : [msg.body]</span>"}
			else
				world << {"<span style="color:#000;">Routing:: [msg.action]: [msg.sender], [msg.target] : [msg.body]</span>"}
			if(!istype(msg))
				DIAG("BAD MESAAGE")
				return ACTION_MALFORMED
			#endif
			// Ensure sender is valid on this relay
			if(!(msg.sender in namedUsers))
				DIAG("Bad User: [msg.sender]")
				return ACTION_BADUSER
			// Parse Target
			//var targetSimpleName
			var targetnameFull
			var targetHandle
			var channelName
			var hashPos = findtextEx(msg.target, "#")
			if(hashPos)
				channelName = copytext(msg.target, hashPos+1)
				channelName = validId(channelName)
			targetnameFull = copytext(msg.target, 1, hashPos)
			var periodPos = findtextEx(msg.target, ".", 1, hashPos)
			if(periodPos)
				targetHandle = copytext(msg.target, periodPos+1, hashPos)
			//	targetSimpleName = copytext(msg.target, 1, periodPos)
			//else
			//	targetSimpleName = copytext(msg.target, 1, hashPos)
			// Start message to be routed to another server (such as an intermediary on a private message)
			if(targetHandle)
				var /relay/server/targetServer = getServer(targetHandle)
				if(!istype(targetServer))
					DIAG("No Remote Server: [targetHandle]")
					return RESULT_NONEXIST
				export(msg, targetServer.address)
				return
			// Start Message to a channel, or to a user filtered by channel
			if(channelName && !targetHandle)
				return _routeChannel(msg, targetnameFull, targetHandle, channelName)
			// start route message directly to user
			if(targetnameFull in namedUsers)
				var/relay/user/targetUser = namedUsers[targetnameFull]
				targetUser.receive(msg)

		_routeChannel(relay/msg/msg, targetnameFull, targetHandle, channelName)
			if(!(msg.sender in namedUsers))
				DIAG("BAD USER: '[msg.sender]'")
				for(var/nameKey in namedUsers)
					DIAG("Not Equal: [nameKey]/[msg.sender]")
				return ACTION_BADUSER
			if(targetHandle)
				DIAG("MALFORMED: [msg.sender], [msg.target], [msg.action], [msg.body]")
				CRASH("Attempt to route to remote user locally")
				return ACTION_MALFORMED
			// Send channel message directly to use
			if(length(targetnameFull))
				var /relay/user/targetUser = namedUsers[targetnameFull]
				if(!targetUser)
					DIAG("NO USER TARGET")
					return RESULT_NONEXIST
				targetUser.receive(msg)
				return RESULT_SUCCESS
			// Ensure target channel exists
			var /relay/channel/targetChannel = namedChannels[channelName]
			if(!targetChannel)
				if(msg.action != ACTION_JOIN)
					return RESULT_NONEXIST
			// Handle channel creation actions
				targetChannel = new()
				targetChannel.name = channelName
				targetChannel.topic = "[targetChannel.name] -- Artemis Chat"
				namedChannels[targetChannel.name] = targetChannel
			// Send the message to the channel
			var result = targetChannel.receive(msg)
			// Handle failure notification from channel
			if(result != RESULT_SUCCESS)
				return RESULT_FAILURE
			// Broadcast to all other servers
			var /list/senderPath = text2list(msg.sender, ".")
			var senderHandle = (senderPath.len > 1)? senderPath[senderPath.len] : handle
			for(var/loopHandle in namedServers)
				var /relay/server/broadcastServer = namedServers[loopHandle]
				if(loopHandle == senderHandle) continue
				export(new /relay/msg(msg.sender, "[msg.target].[loopHandle]", msg.action, msg.body, msg.time), broadcastServer.address)
				// ".[loopHandle]" section will be stripped off in import(), making this target valid.
			return RESULT_SUCCESS


//-- Inter Artemis Communication -----------------------------------------------

relay
	proc
		configure(newHandle)
			if(handle) return handle
			if(!newHandle) newHandle = "A[rand(1000,9999)]"
			if(length(newHandle) > MAX_HANDLE_LENGTH) return
			handle = lowertext(newHandle)
			registerUser(SYSTEM, handle, src)
			return handle

		connect(_address)
			// Attempt to Connect. Cancel if the remote server does not respond with
			// the the proper handshake and compatible version information.
			var remoteReply = world.Export("[_address]?artemis=ping;")
			// This reply should be: "Artemis [VERSION]: [relay.handle]"
			if(copytext(remoteReply, 1, 8) != "Artemis") return RESULT_FAILURE
			var spacePosition = findtextEx(remoteReply, " ")
			var colonPosition = findtextEx(remoteReply, ":")
			var remoteVersion = copytext(remoteReply, spacePosition+1, colonPosition)
			var remoteHandle  = copytext(remoteReply, colonPosition+2)
			if(remoteVersion != "[PROTOCOL_VERSION]") return RESULT_FAILURE
			if(!remoteHandle) return RESULT_FAILURE
			// Register local server handle with remote server
			var /relay/msg/message = new(
				SYSTEM,
				"[SYSTEM].[remoteHandle]",
				ACTION_REGSERVER,
				"handle=[handle];"
			)
			export(message, _address)
			// Register all users on the remote server (except SYSTEM user)
			var /list/userNames = list()
			for(var/relay/user/localUser in localUsers)
				if(localUser.nameSimple == SYSTEM) continue
				userNames.Add(localUser.nameSimple)
			if(userNames.len)
				spawn(1)
					message = new(
						SYSTEM,
						"[SYSTEM].[remoteHandle]",
						ACTION_REGUSER,
						list2text(userNames, " ")
					)
					export(message, _address)


		disconnect(_handle) // leave _handle null to disconnect all, like when world exits
			if(!_handle)
				for(var/loopHandle in namedServers)
					if(loopHandle == handle) continue
					msg(SYSTEM, "[SYSTEM].[loopHandle]", ACTION_DISCONNECT)
					msg("[SYSTEM].[loopHandle]", SYSTEM, ACTION_DISCONNECT)
			else
				var/relay/server/S = getServer(_handle)
				if(S)
					msg(SYSTEM, "[SYSTEM].[_handle]", ACTION_DISCONNECT)
					msg("[SYSTEM].[_handle]", SYSTEM, ACTION_DISCONNECT)

	//-- Export/Import - Convert Topics to Messages --
	proc
		export(var/relay/msg/msg, address)
			//world << {"<span style="color:#080;">Exporting:: [msg.action]: [msg.sender], [msg.target] : [msg.body]</span>"}
			// Convert message to text
			var/topic = msg2topic(msg)
			// Return immediately. Don't wait for network delays.
			spawn()
				// Send the message to the remote Artemis Instance
				var result = world.Export("[address]?[topic]", null, 1)
				// If we get back a proper Artemis reply, we're done.
				if(copytext(result, 1, 8) == "Artemis") return
				// If we DO NOT get back an Artemis reply, disconnect the remote server
				for(var/loopHandle in namedServers)
					var /relay/server/remoteServer = namedServers[loopHandle]
					if(remoteServer.address != address) continue
					var /relay/msg/dropMessage = new(
						SYSTEM,
						"[SYSTEM].[remoteServer.handle]",
						ACTION_DISCONNECT
					)
					remoteServer.drop()
					world.Export("[address]?[msg2topic(dropMessage)]", null, 1)
					return

		import(string, remoteAddress)
			//world << {"<span style="color:#080;">Importing:: [url_decode(string)]</span>"}
			// Check if this is an Artemis message
			var decoded = url_decode(string)
			var action = copytext(decoded,1,9)
			if(action != "artemis=") return RESULT_NOTARTEMIS
			// Respond with correct handshake information
			. = "Artemis [PROTOCOL_VERSION]: [handle]"
			// Determine Artemis Action. Cancel if malformed.
			var semicolon_pos = findtextEx(decoded, ";", 9)
			if(!semicolon_pos) return
			action = lowertext(copytext(decoded, 9, semicolon_pos))
			if(!length(action)) return
			// Ping actions are handled via the default handshake message
			// All other Artemis communication is handled via routed messages
			if(action != "message") return
			// Ensure the message was properly formatted
			var/relay/msg/msg = topic2msg(string)
			if(!istype(msg)) return
			// Remove own handle from msg target
			var /list/targetPath = text2list(lowertext(msg.target), ".")
			if(!targetPath.len) return
			if(lowertext(targetPath[targetPath.len]) != handle) return
			targetPath.Cut(targetPath.len)
			msg.target = list2text(targetPath, ".")
			// Handle server registration requests (send directly to SYSTEM without routing)
			if(msg.action == ACTION_REGSERVER)
				msg.body += "address=[remoteAddress];"
				relay.receive(msg)
				return
			// Add remote server handle to sender
			var remoteHandle = addressedHandles[remoteAddress]
			if(!remoteHandle) return
			var /relay/server/remoteServer = getServer(remoteHandle)
			if(!remoteServer) return
			msg.sender = "[msg.sender].[remoteHandle]"
			// Relay the message
			spawn()
				relay.route(msg)
			return

		msg2topic(relay/msg/msg)
			var string = "artemis=message;"
			string += "[msg.sender],[msg.target],[msg.action],[msg.time]:[msg.body]"
			return url_encode(string)

		topic2msg(string)
			string = url_decode(string)
			var actionMessage = copytext(string,1,17)
			if(lowertext(actionMessage) != "artemis=message;") return
			string = copytext(string,17)
			var colonPos = findtextEx(string,":")
			if(!colonPos) return
			var msgContext = copytext(string,1,colonPos)
			var msgBody    = copytext(string,colonPos+1)
			var /list/msgArgs = text2list(msgContext, ",")
			if(!msgArgs || msgArgs.len < 4) return
			var /relay/msg/msg = new(
				msgArgs[1],
				msgArgs[2],
				text2num(msgArgs[3]),
				msgBody,
				text2num(msgArgs[4]),
			)
			return msg
