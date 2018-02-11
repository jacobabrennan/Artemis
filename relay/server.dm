

//-- Artemis Server - Represents a Remote Artemis instance ---------------------

relay/server
	parent_type = /datum
	New(newHandle)
		handle = newHandle
		. = ..()
	var
		handle
		password
		address
		list/dependents = new()
		list/users = new()
	proc

		//------------------------------------------------
		/*tree2string()
			var result
			for(var/relay/server/dependentServer in dependents)
				if(!result) result = "{"
				else result += ","
				result += dependentServer.tree2string()
			if(result)
				result += "}"
			return "[handle][result]"

		string2tree(string)
			string = lowertext(string)
			var stringLength = length(string)
			var firstOpen = findtextEx(string,"{")
			handle = copytext(string, 1, firstOpen)
			var /list/handles = list(handle)
			if(!firstOpen){ return handles}
			var start = firstOpen+1
			var numberOpen = 1
			for(var/pos = start to stringLength)
				var char = text2ascii(string, pos)
				var close = FALSE
				switch(char)
					if(123) // "{"
						numberOpen++
					if(125) // "}"
						numberOpen--
						if(numberOpen < 0) return
						else if(numberOpen >= 1) continue
						close = TRUE
					if(44) // ","
						if(numberOpen > 1) continue
						if(start == pos+1) continue
						close = TRUE
				if(close)
					var _string = copytext(string, start, pos)
					start = pos+1
					var /relay/server/S = new()
					dependents += S
					var /list/dependentHandles = S.string2tree(_string)
					if(!dependentHandles) return
					for(var/dependentHandle in dependentHandles)
						if(!length(dependentHandle)) return
						if(dependentHandle in handles) return
						handles.Add("[dependentHandle].[handle]")
			return handles
		*/

		//------------------------------------------------
		getServer(serverHandle, dependentOnly)
			serverHandle = lowertext(serverHandle)
			if(handle == serverHandle) return src
			for(var/relay/server/dependentServer in dependents)
				var result
				if(dependentOnly)
					result = (dependentServer.handle == serverHandle)? dependentServer : null
				else
					result = dependentServer.getServer(serverHandle)
				if(result) return result

		addServer(var/list/serverPath)
			if(istext(serverPath))
				serverPath = relay.text2list(serverPath, ".")
			var /relay/server/nextHandle = serverPath[serverPath.len]
			var /relay/server/nextServer = getServer(nextHandle, TRUE)
			if(serverPath.len == 1)
				if(nextServer) return
				var /relay/server/newServer = new()
				newServer.handle = nextHandle
				dependents.Add(newServer)
				return newServer
			else
				if(!nextServer) return
				serverPath.Cut(serverPath.len)
				return nextServer.addServer(serverPath)

		drop()
			for(var/relay/server/dependentServer in dependents)
				dependentServer.drop()
			for(var/relay/user/serverUser in users)
				serverUser.drop()
			del src

		addUser(var/list/userPath, var/fullName)
			if(!istype(userPath))
				userPath = relay.text2list(userPath, ".")
			if(!userPath.len)
				return FALSE
			if(userPath.len == 1)
				var /relay/user/newUser = new()
				newUser.setName(fullName)
				users.Add(newUser)
				return newUser
			var /relay/server/S = getServer(userPath[userPath.len])
			userPath.Cut(userPath.len)
			if(!S) return FALSE
			return S.addUser(userPath, fullName)
