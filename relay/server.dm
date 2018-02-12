

//-- Artemis Server - Represents a Remote Artemis instance ---------------------

artemis/server
	parent_type = /datum
	New(newHandle)
		handle = newHandle
		. = ..()
		// Registration of remote SYSTEM users should happen here
	var
		handle
		address
		list/users = new()


	//------------------------------------------------
	proc

		addUser(name)
			//var nameFull = "[simpleName].[handle]"
			var /artemis/user/newUser = new()
			newUser.setName(name, handle)
			newUser.isRemote = TRUE
			users.Add(newUser)
			return newUser

		drop()
			// Call to manually drop a server.
			// NOT called by the artemis when a server drops.
			artemis.msg("[SYSTEM].[handle]", SYSTEM, ACTION_DISCONNECT)