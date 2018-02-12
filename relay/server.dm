

//-- Artemis Server - Represents a Remote Artemis instance ---------------------

relay/server
	parent_type = /datum
	New(newHandle)
		handle = newHandle
		. = ..()
		// Registration of remote SYSTEM users should happen here
	var
		handle
		address
		list/users = new()
	Del()
		CRASH()
		. = ..()
	proc

		//------------------------------------------------
		/*getServer(serverHandle, dependentOnly)
			serverHandle = lowertext(serverHandle)
			if(handle == serverHandle) return src
			for(var/relay/server/dependentServer in dependents)
				var result
				if(dependentOnly)
					result = (dependentServer.handle == serverHandle)? dependentServer : null
				else
					result = dependentServer.getServer(serverHandle)
				if(result) return result*/

		drop()
			CRASH("Dropping Server")
			for(var/relay/user/serverUser in users)
				serverUser.drop()
			del src

		addUser(name)
			//var nameFull = "[simpleName].[handle]"
			var /relay/user/newUser = new()
			newUser.setName(name, handle)
			newUser.isRemote = TRUE
			users.Add(newUser)
			return newUser
