client
	proc/d(what)
		. = ..()
		var /list/words = relay.text2list(what, " ")
		if(words[1] == "c")
			relay.connect("127.0.0.1:1000")
		if(words[1] == "d")
			relay.namedServers["ceres"].drop()
			relay.namedServers.Remove("ceres")
		if(words[1] == "e")
			DIAG("All Users: ")
			for(var/userName in relay.namedUsers)
				DIAG("  [userName]")


world
	name = "Artemis"
	hub = "iainperegrine.artemis"
	visibility = FALSE

world/New()
	.=..()
	//
	var lePort = 999
	var success
	while(!success && lePort < 1100)
		success = OpenPort(++lePort)
		sleep(1)
	var relayHandle
	switch(lePort)
		if(1000) relayHandle = "artemis"
		if(1001) relayHandle = "ceres"
		if(1002) relayHandle = "pallas"
	//
	relay = new(relayHandle)
	world << {"Server "[relay.handle]" opened on port [port]."}
	world << {"Address:: [world.internet_address]:[world.port] \n\n"}
	//
	var/bot/logger/sally = new()
	sally.channel = "artemis"
	relay.registerUser("sally", null, sally)
	sally.user = relay.getUser("sally")
	relay.msg("sally", SYSTEM, ACTION_NICKNAME, "Sally")
	//relay.route(new /relay/msg("sally", SYSTEM, ACTION_PREFERENCES, "nickname=Sally;color_name=#fff;color_text=#f00;"))
	relay.msg("sally", "#[sally.channel]", ACTION_JOIN)

client
	Del()
		if(user)
			user.drop()
		. = ..()
	Center()
		if(key != "IainPeregrine") return
		world << "\n\n"
		world.Reboot()

relay
	parent_type = /obj
	icon = 'client/artemis.dmi'