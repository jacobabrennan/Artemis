client
	North()
		. = ..()
		artemis.connect("127.0.0.1", 1000)
	Northeast()
		. = ..()
		artemis.connect("127.0.0.1", 1001)
	Northwest()
		. = ..()
		artemis.connect("127.0.0.1", 1002)
	South()
		. = ..()
		artemis.disconnect("artemis")
/*	East()
		. = ..()
		artemis.closed = TRUE
	West()
		. = ..()
		artemis.closed = FALSE

artemis
	var
		closed = FALSE
	import()
		if(closed) return
		. = ..()
*/

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
	var artemisHandle
	switch(lePort)
		if(1000) artemisHandle = "artemis"
		if(1001) artemisHandle = "ceres"
		if(1002) artemisHandle = "pallas"
	//
	artemis = new(artemisHandle)
	world << {"Server "[artemis.handle]" opened on port [port]."}
	world << {"Address:: [world.internet_address]:[world.port] \n\n"}
	//
	/*var/bot/logger/sally = new()
	sally.channel = "artemis"
	artemis.addUser("sally", sally)
	sally.user = artemis.getUser("sally")
	artemis.msg("sally", SYSTEM, ACTION_NICKNAME, "Sally")
	//artemis.route(new /artemis/msg("sally", SYSTEM, ACTION_PREFERENCES, "nickname=Sally;color_name=#fff;color_text=#f00;"))
	artemis.msg("sally", "#[sally.channel]", ACTION_JOIN)*/

client
	Del()
		if(user)
			user.drop()
		. = ..()
	Center()
		if(key != "IainPeregrine") return
		world << "\n\n"
		world.Reboot()

artemis
	parent_type = /obj
	icon = 'client/artemis.dmi'