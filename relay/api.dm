

//-- Artemis Server Creation ---------------------------------------------------
artemis
	New(newHandle, channelDefault)/*
		Attempts to create and configure a new Artemis instance. Will fail if
		the length of the supplied handle is greater than MAX_HANDLE_LENGTH.

		Arguments
			newHandle (text): The name of the Artemis Instance. Cannot contain
				punctuation, & Must not be greater than MAX_HANDLE_LENGTH.
				Will be converted to lowercase.
			channelDefault (text, optional): The default channel for new users.

		Returns
			The new Artemis instance if successful.
			Otherwise null.
		*/


//-- Server Connecting, Disconnecting, and Retrieval ---------------------------
artemis/proc
	connect(address, port)/*
		Attempts to connect to an Artemis instance on a remote server.
		There is currently no way to programmatically determine if the
		connection is successful.

		Arguments
			address (text): The IP address of the remote server.
			port (text|number): The network port of the remote server.

		Returns null.
		*/
	disconnect(remoteHandle)/*
		Disconnects from a remote server. All remote users hosted by that
		server will also be disconnected.

		Arguments
			remoteHandle (text): The name of the remote server.

		Returns null.
		*/
	getServer(serverHandle)/*
		Retrieves a remote server with the specified handle.

		Arguments
			remoteHandle (text): The name of the remote server.

		Returns
			A remote server object if one was found.
			Null otherwise.
		*/


//-- User Creation, Deletion, and Retrieval ------------------------------------
artemis/proc
	addUser(userName, datum/intelligence)/*
		Attempts to create a user with the specified name.

		Arguments
			name (text): The name of this user.
				Must be unique to the server.
				Is capped at MAX_NAME_LENGTH characters.
			intelligence (datum): The object which will receive messages
				sent to the user. Must have a method named "receive".

		Returns
			RESULT_SUCCESS if a user was successfully created.
			RESULT_CONFLICT if that user already exists.
			RESULT_BADUSER if there's no server named "serverHandle".
		*/
	removeUser(artemis/user/oldUser)/*
		Removes a local user from the Artemis system.
		Remote users cannot be removed.

		Arguments
			theUser (user|text): A user object or name

		Returns
			TRUE if the user was removed.
			FALSE otherwise.
		*/
	getUser(userName)/*
		Retrieves a user with the specified name.

		Arguments
			userName (text): A user's full name.

		Returns
			A user object if one exists with that name.
			Otherwise null.
		*/


//-- Channel Retrieval ---------------------------------------------------------
artemis/proc
	getChannel(channelName)/*
		Retrieves a channel with the specified name.

		Arguments
			channelName (text): The name of the channel to retrieve

		Returns
			A channel object if one exists with that name.
			Otherwise null.
		*/
