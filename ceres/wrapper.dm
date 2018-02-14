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
	world << {"Address:: [world.address]:[world.port] \n\n"}
	//
	var /artemis/bot/logger/sally = new("Salamander", "artemis")
	sally.userPermissions["iainperegrine"] = 5

artemis
	parent_type = /obj
	icon = 'client/artemis.dmi'