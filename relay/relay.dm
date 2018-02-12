

//-- World Configuration - world/Topic() must be handled by the artemis ----------

world/Topic(T, Addr, Master, Key)
	. = ..()
	if(artemis)
		var result = artemis.import(T, Addr)
		if(result == RESULT_NOTARTEMIS)
			return .
		return result


//-- Artemis artemis -------------------------------------------------------------

var /artemis/artemis
artemis
	New(newHandle, channelDefault)
		. = ..()
		artemis = src
		defaultChannel = channelDefault || CHANNEL_DEFAULT
		var result = configure(newHandle)
		if(!result) del src

	var
		handle
		defaultChannel
		list/localUsers = new()
		list/namedServers = new() // Remote Servers: Server Handle => Server Instance
		list/addressedHandles = new() // Handles of remote servers: IP_Address => Server Handle
		list/namedChannels = new() // All Channels: Channel Name => Channel Instance
		list/namedUsers = new() // All users on all servers: name.handle => User Instance
		list/nicknamedUsers = new() // All nicknames, in lowertext: Nickname => Full Name

	//-- Access Functions ----------------------------
	proc

		getServer(serverHandle)
			return namedServers[serverHandle]

		getUser(userName)
			userName = lowertext(userName)
			var /artemis/user/theUser = namedUsers[userName]
			if(istype(theUser))
				return theUser

		getChannel(channelName)
			channelName = validId(channelName)
			var/artemis/channel/theChannel = namedChannels[channelName]
			if(istype(theChannel))
				return theChannel

		addUser(userName, intelligence)
			userName = validId(userName)
			var result = registerUser(userName, null, intelligence)
			if(result == RESULT_SUCCESS)
				return getUser(userName)
			return result

		removeUser(artemis/user/oldUser)
			if(istext(oldUser))
				oldUser = getUser(oldUser)
			if(oldUser in localUsers)
				oldUser.drop()
				return TRUE
			return FALSE

	//-- User Creation -------------------------------
	proc
		validId(rawId)
			var /list/namePath = text2list(rawId, ".")
			var first = namePath[1]
			first = alphanumeric(lowertext(first))
			if(length(first) > MAX_NAME_LENGTH)
				first = copytext(rawId, 1, MAX_NAME_LENGTH+1)
			namePath[1] = first
			rawId = list2text(namePath, ".")
			return rawId

		registerUser(simpleName, serverHandle, datum/intelligence)
			// Sanitize user name
			simpleName = validId(simpleName)
			// Get user from remote server if user is remote
			var /artemis/user/newUser
			if(serverHandle && (serverHandle != handle))
				var /artemis/server/proxy = getServer(serverHandle)
				var nameFull = "[simpleName].[serverHandle]"
				if(nameFull in namedUsers)
					DIAG("Conflict: [nameFull]")
					return RESULT_CONFLICT
				if(!proxy)
					DIAG("No Proxy: [simpleName].[serverHandle]")
					return RESULT_BADUSER
				newUser = proxy.addUser(simpleName)
			// Otherwise, create user locally
			else
				if(simpleName in namedUsers) return RESULT_CONFLICT
				newUser = new()
				newUser.setName(simpleName, null)
				localUsers.Add(newUser)
			// Connect intelligence and add to users list
			newUser.intelligence = intelligence
			namedUsers[newUser.nameFull] = newUser
			//
			return RESULT_SUCCESS

	//-- Message Routing -----------------------------
	proc

		msg(_sender, _target, _action, _body, _time)
			return route(new /artemis/msg(_sender, _target, _action, _body, _time))

		route(artemis/msg/msg)
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
			// Ensure sender is valid on this artemis
			if(!(msg.sender in namedUsers))
				DIAG("Bad User: [msg.sender]")
				return RESULT_BADUSER
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
				var /artemis/server/targetServer = getServer(targetHandle)
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
				var/artemis/user/targetUser = namedUsers[targetnameFull]
				targetUser.receive(msg)

		_routeChannel(artemis/msg/msg, targetnameFull, targetHandle, channelName)
			if(!(msg.sender in namedUsers))
				DIAG("BAD USER: '[msg.sender]'")
				for(var/nameKey in namedUsers)
					DIAG("Not Equal: [nameKey]/[msg.sender]")
				return RESULT_BADUSER
			if(targetHandle)
				DIAG("MALFORMED: [msg.sender], [msg.target], [msg.action], [msg.body]")
				CRASH("Attempt to route to remote user locally")
				return ACTION_MALFORMED
			// Send channel message directly to use
			if(length(targetnameFull))
				var /artemis/user/targetUser = namedUsers[targetnameFull]
				if(!targetUser)
					DIAG("NO USER TARGET")
					return RESULT_NONEXIST
				targetUser.receive(msg)
				return RESULT_SUCCESS
			// Ensure target channel exists
			var /artemis/channel/targetChannel = namedChannels[channelName]
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
				var /artemis/server/broadcastServer = namedServers[loopHandle]
				if(loopHandle == senderHandle) continue
				export(new /artemis/msg(msg.sender, "[msg.target].[loopHandle]", msg.action, msg.body, msg.time), broadcastServer.address)
				// ".[loopHandle]" section will be stripped off in import(), making this target valid.
			return RESULT_SUCCESS


//-- System Message Handling ---------------------------------------------------

artemis
	proc
		receive(artemis/msg/msg)
		// Start system message, such as server updates, connections, and disconnects
			. = -1 // What is this -1? Make sure to return it, things break!
			var resultCode
			switch(msg.action)
				if(ACTION_CONNECT)
					resultCode = actionConnectServer(msg.sender, msg.target, msg.body)
				if(ACTION_DISCONNECT)
					resultCode = actionDisconnectServer(msg.sender, msg.target, msg.body)
				if(ACTION_REGUSER)
					resultCode = actionRegisterUser(msg.sender, msg.target, msg.body)
				if(ACTION_DROPUSER)
					resultCode = actionRemoveUser(msg.sender, msg.target, msg.body)
				if(ACTION_CHANSYNC)
					resultCode = actionChannelSync(msg.sender, msg.target, msg.body)
				if(ACTION_NICKNAME)
					resultCode = actionNickname(msg.sender, msg.target, msg.body)
			if(resultCode)
				return resultCode
			return .

		actionConnectServer(sender, target, body)
			DIAG("attempting connection")
			// Ensure that this message has been sent by a SYSTEM user
			if(sender != SYSTEM)
				DIAG("Wrong User: [sender]")
				return
			// Parse arguments from message body. Ensure message was formatted correctly
			var /list/argList = params2list(body)
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
					export(new /artemis/msg(SYSTEM, "[SYSTEM].[remoteHandle]", ACTION_COLLISION, remoteHandle), remoteAddress)
				DIAG("Collision")
				return ACTION_COLLISION
			// Create the newly connected Server & SYSTEM user
			var /artemis/server/connectingServer = new(remoteHandle)
			connectingServer.address = remoteAddress
			namedServers[remoteHandle] = connectingServer
			addressedHandles[remoteAddress] = remoteHandle
			registerUser(SYSTEM, remoteHandle)
			// Respond with a Register Server action from this Artemis instance
			if(_response)
				DIAG("Response Success")
				return RESULT_SUCCESS
			msg(SYSTEM, "[SYSTEM].[remoteHandle]", ACTION_CONNECT, "response=true;handle=[handle];")
			// Generate information about all users on this server (except SYSTEM user)
			var /list/usersList = list()
			var /list/prefsList = new()
			for(var/artemis/user/localUser in localUsers)
				if(localUser.nameSimple == SYSTEM) continue
				usersList.Add(localUser.nameSimple)
				if(localUser.nickname)
					prefsList.Add(new /artemis/msg(localUser.nameSimple, "[SYSTEM].[remoteHandle]", ACTION_NICKNAME, localUser.nickname))
			// Send users list, channels list, and user nicknames
			spawn(1)
				msg(SYSTEM, "[SYSTEM].[remoteHandle]", ACTION_REGUSER, list2text(usersList, " "))
				sleep(1)
				for(var/channelName in namedChannels)
					var/artemis/channel/theChannel = namedChannels[channelName]
					msg(SYSTEM, "[SYSTEM].[remoteHandle]", ACTION_CHANSYNC, theChannel.chan2string())
				sleep(1)
				for(var/artemis/msg/indexedMessage in prefsList)
					sleep(0)
					route(indexedMessage)
			// Return success
			DIAG("Connection Success")
			return RESULT_SUCCESS

		actionDisconnectServer(sender, target, body)
			// Retrieve remote SYSTEM User
			var /artemis/user/oldSYSTEM = getUser(sender)
			DIAG("Dropping [sender]")
			if(!oldSYSTEM || oldSYSTEM.nameSimple != SYSTEM) return
			// Remove server connection (to prevent messages flowing back during removal)
			var /artemis/server/oldServer = getServer(oldSYSTEM.nameHost)
			var oldAddress = oldServer.address
			addressedHandles.Remove(oldAddress)
			oldServer.address = null
			// Drop all users from the remote server
			for(var/artemis/user/oldUser in oldServer.users)
				oldUser.drop()
			// Cleanup references on artemis and Delete Server
			namedServers.Remove(oldServer.handle)
			del oldServer

		actionRegisterUser(sender, target, body)
			// Retrieve remote SYSTEM User
			var /artemis/user/oldSYSTEM = getUser(sender)
			if(!oldSYSTEM || oldSYSTEM.nameSimple != SYSTEM) return
			// Register all user names in body
			var /list/newNames = text2list(lowertext(body), " ")
			for(var/userName in newNames)
				if(oldSYSTEM.nameHost)
					registerUser(userName, oldSYSTEM.nameHost)
				else
					registerUser(userName)

		actionRemoveUser(sender, target, body)
			// Retrieve User
			var /artemis/user/oldUser = getUser(sender)
			if(!oldUser) return
			// Leave all currently joined channels
			for(var/channelName in oldUser.channels)
				oldUser.msg("#[channelName]", ACTION_LEAVE)
			// Remove from associated remote server
			var /artemis/server/remoteHost = getServer(oldUser.nameHost)
			if(remoteHost)
				remoteHost.users.Remove(oldUser)
			// Inform remote servers (if the user was local)
			else
				for(var/loopHandle in namedServers)
					oldUser.msg("[SYSTEM].[loopHandle]", ACTION_DROPUSER)
			// Cleanup references on artemis and Delete User
			var nickedName = nicknamedUsers[lowertext(oldUser.nickname)]
			if(nickedName == oldUser.nameFull)
				nicknamedUsers.Remove(oldUser.nameFull)
			namedUsers.Remove(oldUser.nameFull)
			del oldUser

		actionChannelSync(sender, target, body) // Un-refactored
			// Retrieve User
			var /artemis/user/sendingUser = getUser(sender)
			if(!sendingUser) return
			var remoteHandle = sendingUser.nameHost
			if(remoteHandle && sendingUser.nameSimple != SYSTEM) return
			// Parse Body
			var /list/params = params2list(lowertext(body))
			var chanName = params["!name"]
			var newStatus = text2num(params["!status"])
			var _response = params["!response"]
			var newTopic = params["!topic"]
			var /artemis/msg/syncMessage
			// Respond with local channel info (if this is not already a response)
			if(!_response)
				var/artemis/channel/C = namedChannels[chanName]
				if(C)
					var msgBody = "!response=1;" + C.chan2string()
					syncMessage = new(SYSTEM, sender, ACTION_CHANSYNC, msgBody)
			// Configure channel (remote SYSTEM user hope into channel and attempts to opperate)
			if(!isnum(newStatus)) newStatus = STATUS_NORMAL
			msg(sender, "#[chanName]", ACTION_JOIN)
			msg(sender, "#[chanName]", ACTION_OPERATE, "status=[newStatus];topic=[newTopic]")
			params.Remove("!name","!status","!response","!topic")
			// Configure user permissions
			for(var/userName in params)
				if(!userName in namedUsers) continue
				var userPermission = text2num(params[userName])
				if(userPermission & PERMISSION_ACTIVEFLAG)
					msg("[userName].[remoteHandle]", "#[chanName]", ACTION_JOIN)
					userPermission &= ~PERMISSION_ACTIVEFLAG
				if(userPermission)
					msg(sender, "#[chanName]", ACTION_OPERATE, "user=[userName].[remoteHandle]:[userPermission];")
			msg(sender, "#[chanName]", ACTION_LEAVE)
			// Send previously crafted response
			if(syncMessage)
				route(syncMessage)

		actionNickname(sender, target, body)
			// Cancel out if specified user doesn't exist
			var /artemis/user/sendingUser = namedUsers[sender]
			if(!sendingUser) return
			// Sanitize Nickname
			var oldNick = sendingUser.nickname
			var newNickname = body ///list/params = params2list(body)
			if(length(newNickname) > 20)
				newNickname = copytext(newNickname, 1, 21)
			// Clear the nickname if: No nick supplied; nick starts with " "; there's a collision
			var clear = FALSE
			if(!newNickname) clear = TRUE
			else if(copytext(newNickname, 1, 2) == " ") clear = TRUE
			else if((lowertext(newNickname) in nicknamedUsers) && (nicknamedUsers[lowertext(newNickname)] != sendingUser.nameFull))
				clear = TRUE
			if(clear)
				nicknamedUsers.Remove(lowertext(sendingUser.nickname))
				sendingUser.nickname = null
				newNickname = null
			// Set the New Nickname, and store in nicknames list
			else
				nicknamedUsers.Remove(lowertext(sendingUser.nickname))
				sendingUser.nickname = newNickname
				nicknamedUsers[lowertext(sendingUser.nickname)] = sendingUser.nameFull
			// If nickname was changed, generate traffic in joined channels
			if(oldNick != sendingUser.nickname)
				var t_body = "nick=[sendingUser.nameFull]:[url_encode(oldNick)];"
				for(var/channelName in sendingUser.channels)
					var/artemis/channel/joinedChannel = artemis.getChannel(channelName)
					if(!istype(joinedChannel)) continue
					for(var/channelUser in joinedChannel.localUsers)
						msg(SYSTEM, "[channelUser]#[joinedChannel.name]", ACTION_TRAFFIC, t_body)
			// artemis msg to all dependent servers (except the origin of the message)
			var /list/senderPath = text2list(lowertext(sender), ".")
			var originHandle
			if(senderPath.len > 1)
				originHandle = senderPath[senderPath.len]
			for(var/loopHandle in namedServers)
				if(originHandle == loopHandle) continue
				msg(sender, "[SYSTEM].[loopHandle]", ACTION_NICKNAME, newNickname)


//-- Inter Artemis Communication -----------------------------------------------

artemis
	proc
		configure(newHandle)
			if(handle) return handle
			if(!newHandle) newHandle = "A[rand(1000,9999)]"
			if(length(newHandle) > MAX_HANDLE_LENGTH) return
			handle = lowertext(newHandle)
			registerUser(SYSTEM, handle, src)
			return handle

		connect(_address, _port)
			// Attempt to Connect. Cancel if the remote server does not respond with
			// the the proper handshake and compatible version information.
			if(_port) _address = "[_address]:[_port]"
			var remoteReply = world.Export("[_address]?artemis=ping;")
			// This reply should be: "Artemis [VERSION]: [artemis.handle]"
			if(copytext(remoteReply, 1, 8) != "Artemis")
				DIAG("Not ARTEMIS")
				return RESULT_FAILURE
			var spacePosition = findtextEx(remoteReply, " ")
			var colonPosition = findtextEx(remoteReply, ":")
			var remoteVersion = copytext(remoteReply, spacePosition+1, colonPosition)
			var /list/params = params2list(copytext(remoteReply, colonPosition+1))
			var remoteHandle = params["handle"]
			for(var/word in params)
				DIAG("Word: [word]")
			if(remoteVersion != "[PROTOCOL_VERSION]") return RESULT_FAILURE
			if(!remoteHandle)
				DIAG("Malformed: [remoteHandle], [copytext(remoteReply, colonPosition+1)]")
				return RESULT_FAILURE
			// Register local server handle with remote server
			var /artemis/msg/message = new(
				SYSTEM,
				"[SYSTEM].[remoteHandle]",
				ACTION_CONNECT,
				"handle=[handle];"
			)
			export(message, _address)
			// Register all users on the remote server (except SYSTEM user)
			var /list/userNames = list()
			for(var/artemis/user/localUser in localUsers)
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

		disconnect(remoteHandle) // leave _handle null to disconnect all, like when world exits
			if(!remoteHandle)
				for(var/loopHandle in namedServers)
					msg(SYSTEM, "[SYSTEM].[loopHandle]", ACTION_DISCONNECT)
					msg("[SYSTEM].[loopHandle]", SYSTEM, ACTION_DISCONNECT)
			else
				var/artemis/server/remoteServer = getServer(remoteHandle)
				if(!remoteServer) return
				msg(SYSTEM, "[SYSTEM].[remoteHandle]", ACTION_DISCONNECT)
				msg("[SYSTEM].[remoteHandle]", SYSTEM, ACTION_DISCONNECT)

	//-- Export/Import - Convert Topics to Messages --
	proc
		export(var/artemis/msg/msg, address)
			//world << {"<span style="color:#080;">Exporting:: [msg.action]: [msg.sender], [msg.target] : [msg.body]</span>"}
			// Convert message to text
			var/topic = msg2topic(msg)
			// Return immediately. Don't wait for network delays.
			spawn()
				// Send the message to the remote Artemis Instance
				var result = world.Export("[address]?[topic]", null, 1)
				// If we DO NOT get back an Artemis reply, drop the remote server
				var drop = TRUE
				if(copytext(result, 1, 8) == "Artemis") drop = FALSE
				// Drop the remote server if it does not recognize this connection.
				if(msg.action != ACTION_CONNECT)
					var colonPos = findtextEx(result, ":", 8)
					var /list/params = params2list(copytext(result, colonPos+1))
					var ownHandle = params["connection"]
					if(ownHandle != artemis.handle) drop = TRUE
				//
				if(drop)
					var remoteHandle = addressedHandles[address]
					var /artemis/server/remoteServer = getServer(remoteHandle)
					remoteServer.drop()

		import(string, remoteAddress)
			//world << {"<span style="color:#080;">Importing:: [url_decode(string)]</span>"}
			// Check if this is an Artemis message
			var decoded = url_decode(string)
			var action = copytext(decoded,1,9)
			if(action != "artemis=") return RESULT_NOTARTEMIS
			// Respond with correct handshake information
			. = "Artemis [PROTOCOL_VERSION]:handle=[handle];"
			// If the remoteAddress is known, indicate so in response.
			var remoteHandle = addressedHandles[remoteAddress]
			if(remoteHandle)
				. += "connection=[remoteHandle];"
			// Determine Artemis Action. Cancel if malformed.
			var semicolon_pos = findtextEx(decoded, ";", 9)
			if(!semicolon_pos) return
			action = lowertext(copytext(decoded, 9, semicolon_pos))
			if(!length(action)) return
			// Ping actions are handled via the default handshake message
			// All other Artemis communication is handled via routed messages
			if(action != "message") return
			// Ensure the message was properly formatted
			var/artemis/msg/msg = topic2msg(string)
			if(!istype(msg)) return
			// Remove own handle from msg target
			var /list/targetPath = text2list(lowertext(msg.target), ".")
			if(!targetPath.len) return
			if(lowertext(targetPath[targetPath.len]) != handle) return
			targetPath.Cut(targetPath.len)
			msg.target = list2text(targetPath, ".")
			// Handle server registration requests (send directly to SYSTEM without routing)
			if(msg.action == ACTION_CONNECT)
				msg.body += "address=[remoteAddress];"
				artemis.receive(msg)
				return
			// Add remote server handle to sender
			if(!remoteHandle) return
			var /artemis/server/remoteServer = getServer(remoteHandle)
			if(!remoteServer) return
			msg.sender = "[msg.sender].[remoteHandle]"
			// artemis the message
			spawn()
				artemis.route(msg)
			return

		msg2topic(artemis/msg/msg)
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
			var /artemis/msg/msg = new(
				msgArgs[1],
				msgArgs[2],
				text2num(msgArgs[3]),
				msgBody,
				text2num(msgArgs[4]),
			)
			return msg
