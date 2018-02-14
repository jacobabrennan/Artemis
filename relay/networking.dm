// Add server discovery to serverData()


//-- Inter Artemis Communication -----------------------------------------------

artemis
	proc
		connect(_address, _port)
			DIAG("Requesting Connection")
			// Attempt to Connect. Cancel if the remote server does not respond with
			// the the proper handshake and compatible version information.
			if(_port) _address = "[_address]:[_port]"
			var remoteReply = world.Export({"[_address]?artemis={"ping":1}"})
			// This reply should be: "Artemis [VERSION]: [artemis.handle]"
			if(copytext(remoteReply, 1, 8) != "Artemis")
				DIAG("Not ARTEMIS")
				return ARTEMIS_RESULT_FAILURE
			var spacePosition = findtextEx(remoteReply, " ")
			var colonPosition = findtextEx(remoteReply, ":")
			var remoteVersion = copytext(remoteReply, spacePosition+1, colonPosition)
			var /list/params = params2list(copytext(remoteReply, colonPosition+1))
			var remoteHandle = params["handle"]
			addressedHandles[_address] = remoteHandle
			for(var/word in params)
			if(remoteVersion != "[ARTEMIS_PROTOCOL_VERSION]")
				DIAG("Wrong Version")
				return ARTEMIS_RESULT_FAILURE
			if(!remoteHandle)
				DIAG("Malformed: [remoteHandle], [copytext(remoteReply, colonPosition+1)]")
				return ARTEMIS_RESULT_FAILURE
			// Register local server handle with remote server
			var /list/exportData = list(
				"connect" = serverData()
			)
			export(exportData, _address)

		disconnect(remoteHandle) // leave _handle null to disconnect all, like when world exits
			if(!remoteHandle)
				for(var/loopHandle in namedServers)
					var /artemis/server/namedServer = namedServers[loopHandle]
					msg(SYSTEM, namedServer.SYSTEM, ARTEMIS_ACTION_DISCONNECT)
					msg(namedServer.SYSTEM, SYSTEM, ARTEMIS_ACTION_DISCONNECT)
			else
				var/artemis/server/remoteServer = getServer(remoteHandle)
				if(!remoteServer) return
				msg(SYSTEM, remoteServer.SYSTEM, ARTEMIS_ACTION_DISCONNECT)
				msg(remoteServer.SYSTEM, SYSTEM, ARTEMIS_ACTION_DISCONNECT)

		connectionRequest(remoteAddress, connectionData)
			DIAG("Received Connection Request")
			// Cancel is handle is invalid
			var remoteHandle = connectionData["handle"]
			if(length(remoteHandle) > ARTEMIS_MAX_HANDLE_LENGTH)
				DIAG("Too Long: [remoteHandle] > [ARTEMIS_MAX_HANDLE_LENGTH]")
				return ARTEMIS_RESULT_MALFORMED
			// Check for Artemis handle collisions (instance with that handle already connected)
			if(remoteHandle == handle)
				DIAG("Collision")
				return ARTEMIS_RESULT_COLLISION
			var /artemis/server/remoteServer = getServer(remoteHandle)
			if(remoteServer && remoteServer.address != remoteAddress)
				DIAG("Collision")
				return ARTEMIS_RESULT_COLLISION
			// Asymmetric Reconnection
			if(remoteServer)
				remoteServer.drop()
			// Create the newly connected Server & SYSTEM user
			remoteServer = new(remoteHandle, remoteAddress)
			//new /artemis/server(remoteHandle, remoteAddress)
			// Register Users
			var /list/userData = connectionData["users"]
			for(var/userName in userData)
				registerUser(userName, remoteHandle)
			// Sync Channels
			var /list/channelData = connectionData["channels"]
			for(var/channelName in channelData)
				msg(remoteServer.SYSTEM, SYSTEM, ARTEMIS_ACTION_CHANSYNC, null, channelData[channelName])
				//var /artemis/channel/connectChannel = getChannel(channelName)
				//if(!connectChannel) connectChannel = new(channelName)
			// Respond with a Connection request from this Artemis instance
			if(!connectionData["response"])
				var /list/connectData = serverData()
				connectData["response"] = TRUE
				var /list/exportData = list(
					"connect" = connectData
				)
				export(exportData, remoteAddress, null)
				DIAG("Connection Success")
				return ARTEMIS_RESULT_SUCCESS
			//
			DIAG("Response Success")
			return ARTEMIS_RESULT_SUCCESS

	//-- Export/Import - Convert Topics to Messages --
	proc
		export(list/data, address, list/messages)
			set waitfor = FALSE
			// Compile topic text
			if(istype(messages, /artemis/msg))
				messages = list(messages)
			if(!data)
				data = list()
			if(messages)
				var /list/messagePackage = new()
				for(var/artemis/msg/exportMessage in messages)
					messagePackage[++messagePackage.len] = exportMessage.toJSON()
				data["messages"] = messagePackage
			var topicJSON = "artemis=[json_encode(data)]"
			world << {"<span style="color:#080;">Exporting:: [topicJSON]</span>"}
			var topic = url_encode(topicJSON)
			// Return immediately. Don't wait for network delays.
			sleep(-1)
			// Send the message to the remote Artemis Instance
			var result = world.Export("[address]?[topic]", null, 1)
			// If we DO NOT get back an Artemis reply, drop the remote server
			var drop = TRUE
			if(copytext(result, 1, 8) == "Artemis") drop = FALSE
			// Drop the remote server if it does not recognize this connection.
			if(!data["connect"])
				var colonPos = findtextEx(result, ":", 8)
				var /list/params = params2list(copytext(result, colonPos+1))
				var ownHandle = params["connection"]
				if(ownHandle != artemis.handle) drop = TRUE
			//
			if(drop)
				var remoteHandle = addressedHandles[address]
				var /artemis/server/remoteServer = getServer(remoteHandle)
				if(remoteServer)
					remoteServer.drop()

		import(string, remoteAddress)
			// Check if this is an Artemis message
			var decoded = url_decode(string)
			world << {"<span style="color:#080;">Importing:: [decoded]</span>"}
			var action = copytext(decoded,1,9)
			if(action != "artemis=") return ARTEMIS_RESULT_NOTARTEMIS
			// Respond with correct handshake information
			. = "Artemis [ARTEMIS_PROTOCOL_VERSION]:handle=[handle];"
			// If the remoteAddress is known, indicate so in response.
			var remoteHandle = addressedHandles[remoteAddress]
			if(remoteHandle)
				. += "connection=[remoteHandle];"
			// Get Artemis Package from JSON
			var /list/artemisPackage = json_decode(copytext(decoded, 9))
			var /list/messagePackage = artemisPackage["messages"]
			// Handle System Connections (send directly to SYSTEM without routing)
			var /list/connectRequest = artemisPackage["connect"]
			if(connectRequest)
				connectionRequest(remoteAddress, connectRequest)
			// Route All Messages (unless server isn't finished connecting)
			if(messagePackage)
				var /artemis/server/remoteServer = getServer(remoteHandle)
				if(!remoteServer) return
				for(var/list/msgData in messagePackage)
					var /artemis/msg/importedMessage = importMsg(msgData, remoteHandle)
					route(importedMessage)
			// Ping actions are handled via the default handshake message
			return

		importMsg(list/msgData, remoteHandle)
			// Add remote handle to msg sender
			msgData["sender"] += ".[remoteHandle]"
			// Remote own handle from msg target
			var targetText = msgData["target"]
			if(targetText)
				msgData["target"] = copytext(targetText, 1, findtextEx(targetText, "."))
			//
			var /artemis/msg/msg = new()
			msg.fromJSON(msgData)
			return msg

		serverData()
			var /list/serverData = list(
				"handle" = handle,
				"users" = null,
				"channels" = null
			)
			// Inform remote server of all local users
			var /list/userData = list()
			for(var/artemis/user/localUser in localUsers)
				if(localUser == SYSTEM) continue
				userData[localUser.nameSimple] = localUser.nickname
			serverData["users"] = userData
			// Inform remote server of all local channels
			var /list/channelData = list()
			for(var/channelName in namedChannels)
				var /artemis/channel/theChannel = namedChannels[channelName]
				var channelInfo = theChannel.toJSON()
				channelData[channelName] = channelInfo
			serverData["channels"] = channelData
			//
			return serverData
