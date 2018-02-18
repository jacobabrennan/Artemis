client
	North()
		. = ..()
		artemis.connect("127.0.0.1", 7251)
	Northeast()
		. = ..()
		artemis.connect("127.0.0.1", 7252)
	Northwest()
		. = ..()
		artemis.connect("127.0.0.1", 7253)
	West()
		. = ..()
		var address = input(src, "Connection Address", "Connect", "127.0.0.1:1000") as text
		artemis.connect(address)
	South()
		. = ..()
		artemis.disconnect("artemis")
	Center()
		if(key != "IainPeregrine") return
		world << "\n\n"
		world.Reboot()
	East()
		var newChannel = input(src, "Set Default Channel", "Configuration", ARTEMIS_CHANNEL_DEFAULT) as text
		artemis.setDefaultChannel(newChannel)

world
	name = "Artemis"
	hub = "iainperegrine.artemis"
	visibility = FALSE

world/New()
	.=..()
	//
	var lePort = 7251
	var success
	while(!success && lePort < 7260)
		success = OpenPort(++lePort)
		sleep(1)
	var artemisHandle
	switch(lePort)
		if(7251) artemisHandle = "artemis"
		if(7252) artemisHandle = "ceres"
		if(7253) artemisHandle = "pallas"
	//
	artemis = new(artemisHandle)
	world << {"Server "[artemis.handle]" opened on port [port]."}
	world << {"Address:: [world.address]:[world.port] \n\n"}
	//
	var /artemis/bot/logger/sally = new("Salamander", "artemis")
	sally.userPermissions["iainperegrine"] = 5

artemis
	parent_type = /obj
	icon = 'ceres/artemis.dmi'
