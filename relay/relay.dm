

//-- World Configuration - world/Topic() must be handled by the artemis ----------

world/Topic(T, Addr, Master, Key)
	. = ..()
	if(artemis)
		var result = artemis.import(T, Addr)
		if(result == ARTEMIS_RESULT_NOTARTEMIS)
			return .
		return result


//-- Artemis artemis -------------------------------------------------------------

var /artemis/artemis
artemis
	New(newHandle)
		. = ..()
		// Ensure a valid handle
		if(!newHandle)
			del src
		if(length(newHandle) > ARTEMIS_MAX_HANDLE_LENGTH)
			del src
		handle = alphanumeric(newHandle)
		//
		artemis = src
		SYSTEM = addUser(ARTEMIS_SYSTEM_NAME, src)
		loadConfiguration(newHandle)

	proc/loadConfiguration(newHandle, channelDefault)
		// Get configuration data from file
		var filePath = "[ARTEMIS_PATH_DATA]/config_[handle].json"
		var /list/configData = json_decode(file2text(filePath))
		//
		defaultChannel = configData["defaultChannel"]

	proc/saveConfiguration()
		// Compile configuration data
		var /list/configData = list()
		configData["defaultChannel"] = defaultChannel
		// Save to file
		var filePath = "[ARTEMIS_PATH_DATA]/config_[handle].json"
		if(fexists(filePath))
			fdel(filePath)
		text2file(json_encode(configData), filePath)

	proc/setDefaultChannel(newDefaultChannel)
		defaultChannel = validId(newDefaultChannel)
		saveConfiguration()

	var
		artemis/user/SYSTEM
		handle
		defaultChannel = ARTEMIS_CHANNEL_DEFAULT
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
			if(result == ARTEMIS_RESULT_SUCCESS)
				return getUser(userName)
			return result

		removeUser(artemis/user/oldUser)
			if(istext(oldUser))
				oldUser = getUser(oldUser)
			if(!oldUser.nameHost)
				oldUser.drop()
				return TRUE
			return FALSE

	//-- User Creation -------------------------------
	proc
		validId(rawId)
			var /list/namePath = text2list(rawId, ".")
			var first = namePath[1]
			first = alphanumeric(lowertext(first))
			if(length(first) > ARTEMIS_MAX_NAME_LENGTH)
				first = copytext(rawId, 1, ARTEMIS_MAX_NAME_LENGTH+1)
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
					return ARTEMIS_RESULT_CONFLICT
				if(!proxy)
					DIAG("No Proxy: [simpleName].[serverHandle]")
					return ARTEMIS_RESULT_BADUSER
				newUser = proxy.createUser(simpleName)
			// Otherwise, create user locally
			else
				if(simpleName in namedUsers) return ARTEMIS_RESULT_CONFLICT
				newUser = new()
				newUser.setName(simpleName, null)
				localUsers.Add(newUser)
			// Connect intelligence and add to users list
			newUser.intelligence = intelligence
			namedUsers[newUser.nameFull] = newUser
			//
			return ARTEMIS_RESULT_SUCCESS

	//-- Message Routing -----------------------------
	proc

		msg(_sender, _target, _action, _channel, _body, _time)
			return route(new /artemis/msg(_sender, _target, _action, _channel, _body, _time))

		route(artemis/msg/msg)
			if(!msg.sender)
				CRASH("[msg.sender],[msg.target],[msg.action],[msg.channel],[msg.body]")
			// Output some diagnostic information
			#ifdef DEBUG
			var targetName
			if(msg.target) targetName = msg.target.nameFull
			else if(istype(msg.channel)) targetName = "([msg.channel.name])"
			else if(msg.channel) targetName = "([msg.channel])"
			else targetName = "NO TARGET"
			if(msg.sender != SYSTEM)
				world << {"<span style="color:#00f;">Routing:: [msg.action]: [msg.sender.nameFull], [targetName] : [msg.body]</span>"}
			else
				world << {"<span style="color:#000;">Routing:: [msg.action]: [msg.sender.nameFull], [targetName] : [msg.body]</span>"}
			#endif
			// Ensure sender is valid on this artemis
			if(!(msg.sender.nameFull in namedUsers))
				DIAG("Bad User: [msg.sender.nameFull]")
				return ARTEMIS_RESULT_BADUSER
			// Start message to be routed to another server (such as an intermediary on a private message)
			if(msg.target && msg.target.nameHost)
				var /artemis/server/targetServer = getServer(msg.target.nameHost)
				if(!istype(targetServer))
					DIAG("No Remote Server: [msg.target.nameHost]")
					return ARTEMIS_RESULT_NONEXIST
				export(null, targetServer.address, msg)
				return
			// Start Message to a channel, or to a user filtered by channel
			if(msg.channel && (!msg.target || !msg.target.nameHost))
				return _routeChannel(msg)
			// start route message directly to user
			if(msg.target && msg.target.nameFull in namedUsers)
				msg.target.receive(msg)

		_routeChannel(artemis/msg/msg)
			//
			if(!(msg.sender.nameFull in namedUsers))
				DIAG("BAD USER: '[msg.sender.nameFull]'")
				return ARTEMIS_RESULT_BADUSER
			/*if(msg.sender.nameHost)
				DIAG("MALFORMED: [msg.sender.nameFull], [msg.target.nameFull], [msg.action], [msg.body]")
				CRASH("Attempt to route to remote user locally")
				return ARTEMIS_ACTION_MALFORMED*/
			// Send channel message directly to user
			if(msg.target)
				msg.target.receive(msg)
				return ARTEMIS_RESULT_SUCCESS
			// Ensure target channel exists & Handle channel creation actions
			var /artemis/channel/targetChannel = msg.channel
			if(!istype(targetChannel))
				targetChannel = getChannel(msg.channel)
				if(!istype(targetChannel) && msg.action == ARTEMIS_ACTION_JOIN)
					targetChannel = new(msg.channel)
			if(!istype(targetChannel))
				return ARTEMIS_RESULT_NONEXIST
			// Send the message to the channel
			var result = targetChannel.receive(msg)
			// Handle failure notification from channel
			if(result != ARTEMIS_RESULT_SUCCESS)
				return ARTEMIS_RESULT_FAILURE
			// Broadcast to all other servers (but only local actions)
			// Check for non locals
			if(msg.sender.nameHost)
				return ARTEMIS_RESULT_SUCCESS
			// Broadcast
			for(var/loopHandle in namedServers)
				var /artemis/server/broadcastServer = namedServers[loopHandle]
				export(null, broadcastServer.address, new /artemis/msg(msg.sender, msg.target, msg.action, targetChannel, msg.body, msg.time))


//-- System Message Handling ---------------------------------------------------

artemis
	proc
		receive(artemis/msg/msg)
		// Start system message, such as server updates, connections, and disconnects
			. = -1 // What is this -1? Make sure to return it, things break!
			var resultCode
			switch(msg.action)
				if(ARTEMIS_ACTION_DISCONNECT)
					resultCode = actionDisconnectServer(msg.sender, msg.target, msg.body)
				if(ARTEMIS_ACTION_REGUSER)
					resultCode = actionRegisterUser(msg.sender, msg.target, msg.body)
				if(ARTEMIS_ACTION_DROPUSER)
					resultCode = actionRemoveUser(msg.sender, msg.target, msg.body)
				if(ARTEMIS_ACTION_CHANSYNC)
					resultCode = actionChannelSync(msg.sender, msg.target, msg.body)
				if(ARTEMIS_ACTION_NICKNAME)
					resultCode = actionNickname(msg.sender, msg.target, msg.body)
			if(resultCode)
				return resultCode
			return .

		actionDisconnectServer(artemis/user/sender, artemis/user/target, body)
			// Retrieve remote SYSTEM User
			if(!sender || sender.nameSimple != ARTEMIS_SYSTEM_NAME) return
			// Remove server connection (to prevent messages flowing back during removal)
			var /artemis/server/oldServer = getServer(sender.nameHost)
			var oldAddress = oldServer.address
			addressedHandles.Remove(oldAddress)
			oldServer.address = null
			// Drop all users from the remote server
			for(var/artemis/user/oldUser in oldServer.users)
				oldUser.drop()
			// Cleanup references on artemis and Delete Server
			namedServers.Remove(oldServer.handle)
			del oldServer

		actionRegisterUser(artemis/user/sender, artemis/user/target, body)
			// Retrieve remote SYSTEM User
			if(!sender || sender.nameSimple != ARTEMIS_SYSTEM_NAME) return
			// Register all user names in body
			var /list/newNames = text2list(lowertext(body), " ")
			for(var/userName in newNames)
				if(sender.nameHost)
					registerUser(userName, sender.nameHost)
				else
					registerUser(userName)

		actionRemoveUser(artemis/user/sender, artemis/user/target, body)
			// Leave all currently joined channels
			for(var/artemis/channel/leaveChannel in sender.channels)
				sender.msg(null, ARTEMIS_ACTION_LEAVE, leaveChannel)
			// Remove from associated remote server
			var /artemis/server/remoteHost = getServer(sender.nameHost)
			if(remoteHost)
				remoteHost.users.Remove(sender)
			// Inform remote servers (if the user was local)
			else
				for(var/loopHandle in namedServers)
					var /artemis/user/remoteSystem = getUser("[ARTEMIS_SYSTEM_NAME].[loopHandle]")
					sender.msg(remoteSystem, ARTEMIS_ACTION_DROPUSER)
			// Cleanup references on artemis and Delete User
			var nickedName = nicknamedUsers[lowertext(sender.nickname)]
			if(nickedName == sender.nameFull)
				nicknamedUsers.Remove(sender.nameFull)
			namedUsers.Remove(sender.nameFull)
			del sender

		actionChannelSync(artemis/user/sender, artemis/user/target, body)
			// Retrieve User
			if(!sender) return
			var remoteHandle = sender.nameHost
			var /artemis/server/remoteHost = getServer(remoteHandle)
			if(remoteHandle && sender != remoteHost.SYSTEM) return
			// Parse Body
			var /artemis/channel/channel = getChannel(body["name"])
			var newStatus = body["status"]
			//var response = body["response"]
			var newTopic = body["topic"]
			var /list/permissions = body["users"]
			//var /artemis/msg/syncMessage
			// Respond with local channel info (if this is not already a response)
			/*if(!response)
				var/artemis/channel/C = namedChannels[chanName]
				if(C)
					var msgBody = "!response=1;" + C.chan2string()
					syncMessage = new(SYSTEM, sender, ARTEMIS_ACTION_CHANSYNC, null, msgBody)
			*/
			// Configure channel (remote SYSTEM user hops into channel and attempts to opperate)
			if(!isnum(newStatus)) newStatus = ARTEMIS_STATUS_NORMAL
			msg(sender, null, ARTEMIS_ACTION_JOIN, channel)
			msg(sender, null, ARTEMIS_ACTION_OPERATE, channel, "status=[newStatus];topic=[newTopic]")
			// Configure user permissions
			for(var/simpleName in permissions)
				var fullName = "[simpleName].[remoteHandle]"
				if(!fullName in namedUsers)
					continue
				var userPermission = permissions[simpleName]
				if(userPermission & ARTEMIS_PERMISSION_ACTIVEFLAG)
					var /artemis/user/remoteUser = getUser(fullName)
					if(remoteUser)
						msg(remoteUser, null, ARTEMIS_ACTION_JOIN, channel)
						userPermission &= ~ARTEMIS_PERMISSION_ACTIVEFLAG
				if(userPermission)
					msg(sender, null, ARTEMIS_ACTION_OPERATE, channel, "user=[fullName]:[userPermission];")
			msg(sender, null, ARTEMIS_ACTION_LEAVE, channel)
			// Send previously crafted response
			/*if(syncMessage)
				route(syncMessage)
			*/

		actionNickname(artemis/user/sender, artemis/user/target, body)
			DIAG("Nick: [body]")
			return sender.setNick(body)
