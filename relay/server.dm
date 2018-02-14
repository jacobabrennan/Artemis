

//-- Artemis Server - Represents a Remote Artemis instance ---------------------

artemis/server
	parent_type = /datum
	New(newHandle, remoteAddress)
		handle = newHandle
		. = ..()
		// Registration of remote SYSTEM users should happen here
		address = remoteAddress
		artemis.namedServers[handle] = src
		artemis.addressedHandles[address] = handle
		artemis.registerUser(ARTEMIS_SYSTEM_NAME, handle)
		SYSTEM = artemis.getUser("[ARTEMIS_SYSTEM_NAME].[handle]")
	var
		handle
		address
		list/users = new()
		artemis/user/SYSTEM


	//------------------------------------------------
	proc
		createUser(name)
			//var nameFull = "[simpleName].[handle]"
			var /artemis/user/newUser = new()
			newUser.setName(name, handle)
			users.Add(newUser)
			return newUser

		drop()
			// Call to manually drop a server.
			// NOT called by the artemis when a server drops.
			artemis.msg(SYSTEM, artemis.SYSTEM, ARTEMIS_ACTION_DISCONNECT)