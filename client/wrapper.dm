
			/*filter(what){
				var/list/lines = text2list(what,"\n")
				var/_what = ""
				for(var/line in lines){
					_what += line
					}
				return _what
				}
			Also, flood guards*/


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
	var /artemis/bot/logger/sally = new("Salamander", "artemis")
	sally.userPermissions["iainperegrine"] = 5

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