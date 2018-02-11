world
	name = "Artemis"
	hub = "iainperegrine.artemis"

world/New()
	.=..()
	var/_handle = relay.configure("ceres")
	world << {"Server "[_handle]" opened on port [port]."}
	world << {"Address:: [world.internet_address]:[world.port] \n\n"}
	var/bot/logger/sally = new()
	sally.channel = "sessions"
	relay.registerUser("sally", sally)
	sally.user = relay.getUser("sally")
	//relay.route(new /relay/msg("sally", SYSTEM, ACTION_PREFERENCES, "nickname=Sally;color_name=#fff;color_text=#f00;"))
	relay.route(new /relay/msg("sally", "#[sally.channel]", ACTION_JOIN))

world
	Topic(T, Addr, Master, Key)
		. = ..()
		var/result = relay.import(T, Addr)
		return result

client
	Del()
		if(user)
			user.drop()
		. = ..()
	Center()
		if(key != "IainPeregrine") return
		world << "\n\n"
		world.Reboot()
