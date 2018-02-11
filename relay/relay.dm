

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
		relay/server/rootServer
		list/passwords = new()
		list/users = new() // All users on all servers, associated by full_name
		list/channels = new()
		list/nicknames = new() // All nicknames, in lowertext, and associated with full_names

	//------------------------------------------------
	proc
		getUser(userName)
			userName = lowertext(userName)
			var /relay/user/U = users[userName]
			if(istype(U))
				return U
		getChannel(chanName)
			chanName = validId(chanName)
			var/relay/channel/C = channels[chanName]
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

		registerUser(userName, datum/intelligence)
			userName = validId(userName)
			if(userName in users) return ACTION_CONFLICT
			var /list/userPath = text2list(userName, ".")
			var /relay/user/result = rootServer.addUser(userPath.Copy(), userName)
			if(!istype(result))
				return ACTION_BADUSER
			result.intelligence = intelligence
			users[result.fullName] = result
			var /relay/server/proxy
			if(userPath.len > 1)
				proxy = rootServer.getServer(userPath[userPath.len], TRUE)
			for(var/relay/server/dependentServer in (rootServer.dependents - proxy))
				route(new /relay/msg(SYSTEM, "[SYSTEM].[dependentServer.handle]", ACTION_REGUSER, userName))
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
				if(ACTION_SERVERUPDATE)
					resultCode = actionServerUpdate(msg)
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
			var /relay/server/oldServer = rootServer.getServer(remoteHandle)
			if(!oldServer) return
			relay.rootServer.dependents.Remove(oldServer)
			/*for(var/relay/server/S in relay.rootServer.dependents){
				world << "Dis: [route(new /relay/msg(msg.sender, "[SYSTEM].[S.handle]", ACTION_DISCONNECT))]"
				}*/
			oldServer.drop()

		actionServerUpdate(relay/msg/msg)
			var /list/senderPath = text2list(lowertext(msg.sender), ".")
			var remoteHandle = senderPath[senderPath.len]
			if(senderPath.len != 2 || senderPath[1] != SYSTEM)
				goto bail
			var/list/newServers = text2list(lowertext(msg.body), " ")
			for(var/serverHandle in newServers)
				serverHandle += ".[remoteHandle]"
				var /list/newServerPath = text2list(serverHandle, ".")
				var newHandle = newServerPath[1]
				if(length(newHandle) > MAX_HANDLE_LENGTH)
					goto bail
				if(rootServer.getServer(newHandle))
					goto bail
				var/relay/server/result = rootServer.addServer(newServerPath)
				if(!istype(result))
					goto bail
			return
			bail
				route(new /relay/msg(SYSTEM, "[SYSTEM].[remoteHandle]", ACTION_DISCONNECT))
				route(new /relay/msg("[SYSTEM].[remoteHandle]", SYSTEM, ACTION_DISCONNECT))
				return

		actionRegisterServer(relay/msg/msg)
			DIAG("attempting connection")
			// Ensure that this message has been sent by a SYSTEM user
			var /list/senderPath = text2list(lowertext(msg.sender), ".")
			if(senderPath.len != 2 || senderPath[1] != SYSTEM)
				DIAG("Wrong User")
				return
			// Parse arguments from message body. Ensure message was formatted correctly
			var /list/argList = params2list(msg.body)
			var remoteHandle = senderPath[2]
			var remotePassword = argList["password"]
			var remoteAddress  = argList["address" ]
			var _response = argList["response"]
			if(!(remotePassword && remoteAddress))
				DIAG("Malformed")
				return ACTION_MALFORMED
			if(length(remoteHandle) > MAX_HANDLE_LENGTH)
				DIAG("Too Long: [remoteHandle] > [MAX_HANDLE_LENGTH]")
				return // malformed
			// Check for Artemis handle collisions (instance with that handle already connected)
			if(rootServer.getServer(remoteHandle))
				spawn()
					export(new /relay/msg(SYSTEM, "[SYSTEM].[remoteHandle]", ACTION_COLLISION, remoteHandle), remoteAddress)
				DIAG("Collision")
				return ACTION_COLLISION
			// Create the newly connected Server
			var /relay/server/connectingServer = new(remoteHandle)
			connectingServer.password = remotePassword
			connectingServer.address = remoteAddress
			rootServer.dependents.Add(connectingServer)
			// Respond with a Register Server action from this Artemis instance
			if(_response)
				DIAG("Response Success")
				return RESULT_SUCCESS
			var outgoingPass = md5("[rootServer.handle][rand(1,65535)]")
			passwords[connectingServer.handle] = outgoingPass
			route(new /relay/msg(SYSTEM, "[SYSTEM].[remoteHandle]", ACTION_REGSERVER, "response=true;password=[outgoingPass];"))
			// Generate information about all users on this server
			var usersList = list2text(users, " ")
			var /list/prefs_list = new()
			for(var/userName in users)
				var /relay/user/_u = users[userName]
				if(_u.nickname)
					prefs_list.Add(new /relay/msg(userName, "[SYSTEM].[remoteHandle]", ACTION_NICKNAME, _u.nickname))
			// Send users list, channels list, and user nicknames
			spawn(1)
				route(new /relay/msg(SYSTEM, "[SYSTEM].[remoteHandle]", ACTION_REGUSER, usersList))
				spawn(1)
					for(var/chan_name in channels)
						var/relay/channel/C = channels[chan_name]
						route(new /relay/msg(SYSTEM, "[SYSTEM].[remoteHandle]", ACTION_CHANSYNC, C.chan2string()))
					spawn(1)
						for(var/relay/msg/M in prefs_list)
							sleep(0)
							route(M)
			// Return success
			DIAG("Connection Success")
			return RESULT_SUCCESS

		actionRegisterUser(relay/msg/msg)
			var /list/sender_path = text2list(lowertext(msg.sender), ".")
			if(sender_path[1] != SYSTEM)
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
					result = registerUser("[user_name].[remote_handle]")
				else
					result = registerUser("[user_name]")
				switch(result)
					if(RESULT_SUCCESS ) successes += user_name
					if(ACTION_BADUSER ) bad_users += user_name
					if(ACTION_CONFLICT) conflicts += user_name
			if(conflicts.len)
				spawn()
					route(new /relay/msg(SYSTEM, "[SYSTEM].[remote_handle]", ACTION_CONFLICT, list2text(conflicts, " ")))
			if(bad_users.len)
				spawn()
					route(new /relay/msg(SYSTEM, "[SYSTEM].[remote_handle]", ACTION_BADUSER, list2text(bad_users, " ")))

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
				var/relay/channel/C = channels[chan_name]
				if(C)
					var/msg_body = "!response=1;" + C.chan2string()
					sync_message = new(SYSTEM, remote_sysuser, ACTION_CHANSYNC, msg_body)
			if(!isnum(new_status)) new_status = STATUS_NORMAL
			route(new /relay/msg(remote_sysuser, "#[chan_name]", ACTION_JOIN))
			route(new /relay/msg(remote_sysuser, "#[chan_name]", ACTION_OPERATE, "status=[new_status];topic=[_topic]"))
			params.Remove("!name","!status","!response","!topic")
			for(var/user_name in params)
				if(!user_name in users) continue
				var user_permission = text2num(params[user_name])
				if(user_permission & PERMISSION_ACTIVEFLAG)
					route(new /relay/msg("[user_name].[remote_handle]", "#[chan_name]", ACTION_JOIN))
					user_permission &= ~PERMISSION_ACTIVEFLAG
				if(user_permission)
					route(new /relay/msg(remote_sysuser, "#[chan_name]", ACTION_OPERATE, "user=[user_name].[remote_handle]:[user_permission];"))
			route(new /relay/msg(remote_sysuser, "#[chan_name]", ACTION_LEAVE))
			if(sync_message)
				route(sync_message)

		actionNickname(relay/msg/msg)
			// Cancel out if specified user doesn't exist
			var /relay/user/U = users[msg.sender]
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
			else if((lowertext(newNickname) in nicknames) && (nicknames[lowertext(newNickname)] != U.fullName))
				clear = TRUE
			if(clear)
				nicknames.Remove(lowertext(U.nickname))
				U.nickname = null
				newNickname = null
			// Set the New Nickname, and store in nicknames list
			else
				nicknames.Remove(lowertext(U.nickname))
				U.nickname = newNickname
				nicknames[lowertext(U.nickname)] = U.fullName
			// If nickname was changed, generate traffic in joined channels
			if(oldNick != U.nickname)
				var t_body = "nick=[U.fullName]:[url_encode(oldNick)];"
				for(var/channelName in U.channels)
					var/relay/channel/joinedChannel = relay.getChannel(channelName)
					if(!istype(joinedChannel)) continue
					for(var/channelUser in joinedChannel.localUsers)
						route(new /relay/msg(SYSTEM, "[channelUser]#[joinedChannel.name]", ACTION_TRAFFIC, t_body))
			// Relay msg to all dependent servers (except the origin of the message)
			var /list/senderPath = text2list(lowertext(msg.sender), ".")
			var originHandle
			if(senderPath.len > 1)
				originHandle = senderPath[senderPath.len]
			for(var/relay/server/dependentServer in rootServer.dependents)
				if(originHandle == dependentServer.handle) continue
				route(new /relay/msg(msg.sender, "[SYSTEM].[dependentServer.handle]", ACTION_NICKNAME, newNickname))

		route(relay/msg/msg)
			if(!rootServer) return
			if(msg.sender == SYSTEM)
				world << {"<span style="color:#00f;">Routing:: [msg.action]: [msg.sender], [msg.target] : [msg.body]</span>"}
			else
				world << {"<span style="color:#000;">Routing:: [msg.action]: [msg.sender], [msg.target] : [msg.body]</span>"}
			if(!istype(msg)) return ACTION_MALFORMED
			var /list/serverPath = text2list(msg.target, ".")
			var targetUser = serverPath[1]
			// Start Message to a channel, or to a user filtered by channel
			var hashPos = findtextEx(msg.target, "#")
			if(hashPos)
				if(!(msg.sender in users)) return ACTION_BADUSER
				if(serverPath.len > 1)
					return ACTION_MALFORMED
				var chanName = copytext(msg.target, hashPos+1)
				chanName = validId(chanName)
				if(hashPos != 1)
					targetUser = copytext(msg.target, 1, hashPos)
					var /relay/user/_user = users[targetUser]
					if(!_user)
						return ACTION_NONEXIST
					_user.receive(msg)
					return RESULT_SUCCESS
				else
					var /relay/channel/C = channels[chanName]
					if(!C)
						if(msg.action != ACTION_JOIN)
							return ACTION_NONEXIST
						C = new()
						C.name = chanName
						C.topic = "[C.name] -- Artemis Chat"
						channels[C.name] = C
					var result = C.receive(msg)
					if(result == RESULT_SUCCESS)
						var /list/senderPath = text2list(msg.sender, ".")
						var senderHandle = (senderPath.len > 1)? senderPath[senderPath.len] : rootServer.handle
						for(var/relay/server/S in rootServer.dependents)
							if(S.handle == senderHandle) continue
							export(new /relay/msg(msg.sender, "[msg.target].[S.handle]", msg.action, msg.body, msg.time), S.address)
							// ".[server]" section will be stripped off in import(), making this target valid.
						return RESULT_SUCCESS
					return RESULT_FAILURE
			// Start message to be routed to another server (such as an intermediary on a private message)
			else if(serverPath.len > 1)
				if(!(msg.sender in users))
					return ACTION_BADUSER
				var _proxy = serverPath[serverPath.len]
				var /relay/server/S = rootServer.getServer(_proxy)
				if(!istype(S))
					return ACTION_NONEXIST
				export(msg, S.address)
				return
			// start route message directly to user
			else
				if(!(msg.sender in users))
					if(msg.target != SYSTEM)
						return ACTION_BADUSER
				if(targetUser in users)
					var/relay/user/_user = users[targetUser]
					_user.receive(msg)


//-- Inter Artemis Communication -----------------------------------------------

relay
	proc
		configure(newHandle)
			if(rootServer) return rootServer.handle
			if(!newHandle) newHandle = "A[rand(1000,9999)]"
			if(length(newHandle) > MAX_HANDLE_LENGTH) return
			newHandle = lowertext(newHandle)
			rootServer = new()
			rootServer.handle = newHandle
			registerUser(SYSTEM, src)
			return rootServer.handle

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
			var password = md5("[rootServer.handle][rand(1,65535)]")
			passwords[remoteHandle] = password
			var /relay/msg/message = new(
				SYSTEM,
				"[SYSTEM].[remoteHandle]",
				ACTION_REGSERVER,
				"password=[password];"
			)
			export(message, _address)
			// Register all users on the remote server
			if(users.len)
				spawn(1)
					message = new(
						SYSTEM,
						"[SYSTEM].[remoteHandle]",
						ACTION_REGUSER,
						list2text(users, " ")
					)
					export(message, _address)

		disconnect(_handle) // leave _handle null to disconnect all, like when world exits
			if(!_handle)
				for(var/relay/server/S in rootServer.dependents)
					route(new /relay/msg(SYSTEM, "[SYSTEM].[S.handle]", ACTION_DISCONNECT))
					route(new /relay/msg("[SYSTEM].[S.handle]", SYSTEM, ACTION_DISCONNECT))
			else
				var/relay/server/S = rootServer.getServer(_handle)
				if(S)
					route(new /relay/msg(SYSTEM, "[SYSTEM].[S.handle]", ACTION_DISCONNECT))
					route(new /relay/msg("[SYSTEM].[S.handle]", SYSTEM, ACTION_DISCONNECT))

	//-- Export/Import - Convert Topics to Messages --
	proc
		export(var/relay/msg/msg, address)
			// Append own handle to message sender, and convert message to text
			msg.sender = "[msg.sender].[rootServer.handle]"
			var/topic = msg2topic(msg)
			// Return immediately. Don't wait for network delays.
			spawn()
				// Send the message to the remote Artemis Instance
				var result = world.Export("[address]?[topic]", null, 1)
				// If we get back a proper Artemis reply, we're done.
				if(copytext(result, 1, 8) == "Artemis") return
				// If we DO NOT get back an Artemis reply, disconnect the remote server
				for(var/relay/server/S in rootServer.dependents)
					if(S.address != address) continue
					var /relay/msg/M = new(
						"[SYSTEM].[rootServer.handle]",
						"[SYSTEM].[S.handle]",
						ACTION_DISCONNECT
					)
					S.drop()
					world.Export("[address]?[msg2topic(M)]", null, 1)
					return

		import(string, address)
			// Check if this is an Artemis message
			var decoded = url_decode(string)
			var action = copytext(decoded,1,9)
			if(action != "artemis=") return RESULT_NOTARTEMIS
			// Respond with correct handshake information
			. = "Artemis [PROTOCOL_VERSION]: [relay.rootServer.handle]"
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
			// If this is a new server, record the incomming address
			if(msg.action == ACTION_REGSERVER)
				msg.body += "address=[address];"
			else
			// Authentication : Is this the address we have on file for this server?
				var /list/senderPath = text2list(lowertext(msg.sender), ".")
				if(senderPath.len < 2) return
				var remoteHandle = senderPath[senderPath.len]
				var /relay/server/remoteServer = rootServer.getServer(remoteHandle, TRUE)
				if(!remoteServer || remoteServer.address != address) return
			// Remove own handle from msg target
			var /list/targetPath = text2list(lowertext(msg.target), ".")
			if(!targetPath.len) return
			if(lowertext(targetPath[targetPath.len]) != rootServer.handle) return
			targetPath.Cut(targetPath.len)
			msg.target = list2text(targetPath, ".")
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
