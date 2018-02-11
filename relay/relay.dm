

//------------------------------------------------------------------------------

var /relay/relay = new()
relay
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
			return ACTION_SUCCESS

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
			var /list/senderPath = text2list(lowertext(msg.sender), ".")
			if(senderPath.len != 2 || senderPath[1] != SYSTEM) return
			var /list/arg_list = params2list(msg.body)
			var _handle
			var _password = arg_list["password"]
			var _address  = arg_list["address" ]
			var _response = arg_list["response"]
			var _servers  = lowertext(arg_list["servers"])
			if(!(_password && _address && _servers)) return ACTION_MALFORMED
			var /relay/server/S = new()
			var /new_handles = S.string2tree(_servers)
			if(!new_handles) return // malformed
			_handle = S.handle
			if(length(_handle) > MAX_HANDLE_LENGTH) return // malformed
			var/collisions = {""}
			for(var/handle_path in new_handles)
				var /list/path_im_running_out_of_var_names = text2list(handle_path, ".")
				var server_handle = path_im_running_out_of_var_names[1]
				if(rootServer.getServer(server_handle))
					if(length(collisions)) collisions += " "
					collisions += "[server_handle]"
			if(length(collisions))
				spawn()
					export(new /relay/msg(SYSTEM, "[SYSTEM].[_handle]", ACTION_COLLISION, collisions), _address)
				return ACTION_COLLISION
			var /old_servers_list = rootServer.tree2string()
			var /list/old_servers = rootServer.dependents.Copy()
			S.password = _password
			S.address = _address
			rootServer.dependents += S
			var/new_servers_text = list2text(new_handles, " ")
			for(var/relay/server/old_server in old_servers)
				route(new /relay/msg(SYSTEM, "[SYSTEM].[old_server.handle]", ACTION_SERVERUPDATE, new_servers_text))
			if(_response) return ACTION_SUCCESS
			var/outgoing_pass = md5("[rootServer.handle][rand(1,65535)]")
			passwords[S.handle] = outgoing_pass
			route(new /relay/msg(SYSTEM, "[SYSTEM].[S.handle]", ACTION_REGSERVER, "response=true;password=[outgoing_pass];servers=[old_servers_list];"))
			// Generate information about all users on this server
			var users_list = list2text(users, " ")
			var /list/prefs_list = new()
			for(var/userName in users)
				var /relay/user/_u = users[userName]
				var _body = {""}
				if(_u.nickname)   _body += "nickname=[  _u.nickname  ];"
				if(length(_body))
					prefs_list.Add(new /relay/msg(userName, "[SYSTEM].[S.handle]", ACTION_NICKNAME, _body))
			//
			spawn(1)
				route(new /relay/msg(SYSTEM, "[SYSTEM].[S.handle]", ACTION_REGUSER, users_list))
				spawn(1)
					for(var/chan_name in channels)
						var/relay/channel/C = channels[chan_name]
						route(new /relay/msg(SYSTEM, "[SYSTEM].[S.handle]", ACTION_CHANSYNC, C.chan2string()))
					spawn(1)
						for(var/relay/msg/M in prefs_list)
							sleep(0)
							route(M)
			return ACTION_SUCCESS

		actionRegisterUser(relay/msg/msg)
			var /list/sender_path = text2list(lowertext(msg.sender), ".")
			if(sender_path[1] != SYSTEM) return
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
					if(ACTION_SUCCESS ) successes += user_name
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
					return ACTION_SUCCESS
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
					if(result == ACTION_SUCCESS)
						var /list/senderPath = text2list(msg.sender, ".")
						var senderHandle = (senderPath.len > 1)? senderPath[senderPath.len] : rootServer.handle
						for(var/relay/server/S in rootServer.dependents)
							if(S.handle == senderHandle) continue
							export(new /relay/msg(msg.sender, "[msg.target].[S.handle]", msg.action, msg.body, msg.time), S.address)
							// ".[server]" section will be stripped off in import(), making this target valid.
						return ACTION_SUCCESS
					return ACTION_FAILURE
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


//------------------------------------------------------------------------------

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
			// Retrieve remote server handle
			DIAG("[_address]?artemis=ping;")
			var _ping = world.Export("[_address]?artemis=ping;")
				// "Artemis [VERSION]: [relay.handle]"
			if(copytext(_ping, 1, 8) != "Artemis")
				return ACTION_FAILURE
			var spacePos = findtextEx(_ping, " ")
			var colonPos = findtextEx(_ping, ":")
			if(copytext(_ping, spacePos+1, colonPos) != "[PROTOCOL_VERSION]")
				return ACTION_FAILURE
			// Register local server handle with remote server
			var password = md5("[rootServer.handle][rand(1,65535)]")
			var remoteHandle = copytext(_ping, colonPos+2)
			var /relay/msg/message = new(
				SYSTEM,
				"[SYSTEM].[remoteHandle]",
				ACTION_REGSERVER,
				"password=[password];servers=[rootServer.tree2string()];"
			)
			export(message, _address)
			passwords[remoteHandle] = password
			if(users.len)
				spawn(1)
					message = new(
						SYSTEM,
						"[SYSTEM].[remoteHandle]",
						ACTION_REGUSER,
						list2text(users, " ")
					)
					export(message, _address)
			return ACTION_SUCCESS

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

	//------------------------------------------------
	proc
		export(var/relay/msg/msg, address)
			// called by program to export a message
			msg.sender = "[msg.sender].[rootServer.handle]"
			var/topic = msg2topic(msg)
			spawn()
				var result = world.Export("[address]?[topic]", null, 1)
				if(copytext(result, 1, 8) != "Artemis")
					for(var/relay/server/S in rootServer.dependents)
						if(S.address == address)
							var /relay/msg/M = new(
								"[SYSTEM].[rootServer.handle]",
								"[SYSTEM].[S.handle]",
								ACTION_DISCONNECT
							)
							S.drop()
							world.Export("[address]?[msg2topic(M)]", null, 1)

		import(string, address)
			// called by world when exteral world sends a message to this one
			if(!rootServer) return
			if(!.)
				. = "Artemis [PROTOCOL_VERSION]: [relay.rootServer.handle]"
			var decoded = url_decode(string)
			var action = copytext(decoded,1,9)
			if(action != "artemis=") return
			var semicolon_pos = findtextEx(decoded, ";", 9)
			if(!semicolon_pos) return
			action = copytext(decoded, 9, semicolon_pos)
			if(!length(action)) return
			switch(lowertext(action))
				if("ping") return
				if("message")
					var/relay/msg/M = topic2msg(string)
					if(!istype(M)) return
					if(M.action == ACTION_REGSERVER)
						M.body += "address=[address];"
					else // Authentication : Is this the address of the server we have on file?
						var /list/senderPath = text2list(lowertext(M.sender), ".")
						if(senderPath.len < 2) return
						var remoteHandle = senderPath[senderPath.len]
						var /relay/server/S = rootServer.getServer(remoteHandle, TRUE)
						if(!S || S.address != address) return
						// End Authentication
					var /list/target_path = text2list(lowertext(M.target), ".")
					if(!target_path.len) return
					if(lowertext(target_path[target_path.len]) != rootServer.handle) return
					target_path.Cut(target_path.len)
					M.target = list2text(target_path, ".")
					spawn()
						relay.route(M)
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
