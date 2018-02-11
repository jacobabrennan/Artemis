client
	proc/d(what)
		. = ..()
		var /list/words = relay.text2list(what, " ")
		if(words[1] == "c")
			relay.connect("127.0.0.1:1000")
		if(words[1] == "d")
			relay.rootServer.dependents[1].drop()


world
	name = "Artemis"
	hub = "iainperegrine.artemis"

world/New()
	.=..()
	relay = new("artemis")
	world << {"Server "[relay.rootServer.handle]" opened on port [port]."}
	world << {"Address:: [world.internet_address]:[world.port] \n\n"}
	var/bot/logger/sally = new()
	sally.channel = "sessions"
	relay.registerUser("sally", sally)
	sally.user = relay.getUser("sally")
	relay.route(new /relay/msg("sally", SYSTEM, ACTION_NICKNAME, "Sally"))
	//relay.route(new /relay/msg("sally", SYSTEM, ACTION_PREFERENCES, "nickname=Sally;color_name=#fff;color_text=#f00;"))
	relay.route(new /relay/msg("sally", "#[sally.channel]", ACTION_JOIN))

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