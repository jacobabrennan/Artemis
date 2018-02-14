

//-- Logger - Bot Managers Permissions, Logs Chat, Compiles Stats --------------

artemis/bot/logger
	var
		name
		homeChannel
		artemis/user/user
		list/userPermissions = new()
		offset = 0 // Has to do with time zone. Need to revisit this.
		stat_delay = 2*60*60*10

	New(newName, newChannel)
		name = newName
		homeChannel = newChannel
		user = artemis.addUser(newName, src)
		user.msg(artemis.SYSTEM, ARTEMIS_ACTION_NICKNAME, null, newName)
		user.msg(null, ARTEMIS_ACTION_JOIN, homeChannel)

	var
		pathLog = ARTEMIS_PATH_DATA+"/logs"
		pathStats = ARTEMIS_PATH_DATA+"/stats"


//-- Message Handling ----------------------------------------------------------

artemis/bot/logger

	//-- Receive & Handle all Artemis Messages -------
	receive(artemis/msg/msg)
		// Return instantly. File access takes time.
		set waitfor = FALSE
		. = ..()
		sleep(1)
		// Handle messages sent directly from a user (not through a channel)
		if(!msg.channel)
			var success = parsePrivateMessage(msg)
			if(!success)
				user.msg(msg.sender, ARTEMIS_ACTION_MESSAGE, null, "No thanks ^-^")
			return
		// Cancel out if not home channel.
		if(msg.channel != homeChannel) return
		// Handle Traffic: Set user permissions
		if(msg.action == ARTEMIS_ACTION_TRAFFIC)
			var /list/actions = params2list(msg.body)
			// Only pay attention to joining traffic
			if(!("join" in actions)) return
			var userName = actions["join"]
			if(userName in userPermissions)
				var permissionLevel = userPermissions[userName]
				user.msg(null, ARTEMIS_ACTION_OPERATE, homeChannel, "user=[userName]:[permissionLevel]")
		// Log messages sent to the channel
		else if(msg.action == ARTEMIS_ACTION_MESSAGE)
			if(!msg.body) return
			var /list/objectData = list()
			var nudged_stamp = msg.time + offset
			if(nudged_stamp < 0) nudged_stamp += 864000 // one day
			objectData["sender"] = msg.sender
			objectData["time"]   = nudged_stamp
			objectData["body"]   = msg.body
			var date = time2text(world.realtime, "YY-MM-DD")
			var F = file({"[pathLog]/[homeChannel] [date].txt"})
			F << "[json_encode(objectData)],"

	//-- Commands from Owners and Operators ----------
	proc/parsePrivateMessage(artemis/msg/msg)
		// Ensure user can opperate channel
		var /artemis/channel/logChannel = artemis.getChannel(homeChannel)
		if(!logChannel.canOperate(msg.sender) && FALSE) return TRUE
		// Parse message body for command
		var /list/argList = artemis.text2list(msg.body, " ")
		if(!argList.len){ return}
		var/command = lowertext(argList[1])
		switch(command)
		// Retrieve log file
			if("retrieve")
				// Ensure second word is "log"
				if(argList.len < 2 || lowertext(argList[2]) != "log") return
				// Send file to user
				var/artemis/user/U = artemis.getUser(msg.sender)
				if(!U || !istype(U.intelligence, /client)) return
				var date = time2text(world.realtime, "YY-MM-DD")
				U.intelligence << ftp(file({"[pathLog]/[homeChannel] [date].txt"}))
		// Update and Display Stats
			if("update")
				DIAG("ASDFASDF")
				// Ensure second word is "stats"
				if(argList.len < 2 || lowertext(argList[2]) != "stats") return
				DIAG("ASDF")
				spawn() updateStats()
		// Speak as directed
			if("echo")
				var /list/words = argList.Copy(2)
				user.msg(null, ARTEMIS_ACTION_MESSAGE, homeChannel, "[artemis.list2text(words, " ")]")
		// Emote as directed
			if("emote")
				var /list/rest = argList.Copy(2)
				user.msg(null, ARTEMIS_ACTION_EMOTE, homeChannel, "[artemis.list2text(rest, " ")]")
		// Reboot the server
			if("reboot")
				user.msg(null, ARTEMIS_ACTION_MESSAGE, homeChannel, "Rebooting.")
				sleep(10)
				world.Reboot()
		// Inform caller of success
		return TRUE


//-- Channel Statistics --------------------------------------------------------

artemis/bot/logger
	var
		statsPeriod = 7 // Number of days to track
	New()
		. = ..()
		spawn()
			while(src)
				sleep(stat_delay)
				spawn()
					updateStats()
	var
		barNight = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAgCAYAAAAbifjMAAAAkElEQVR42u3VIQ7BAQBG8XcGVWWTRERFothkIymC0WyKpJho+09TjAM4gKg5giI4g30O8ZoJv/rqo0IzBg36MeixiMGIXQzmXGKw4R6DglcMziTGP/AbgROfGBx4x2DPMwZbHjFYc4vBkmsMphxjMKGIwZBtDAasYtBlFoM24xj+THU6MajSikGZWgxKlGN8Abo2MV0C5VkOAAAAAElFTkSuQmCC"
		barMorning = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAgCAYAAAAbifjMAAAAfklEQVR42u3VIRGEAAAF0d+DAjSAAgQgAg2YQROBwWNPEoAASBwRMAgyMHsh1t2ceHbtJlWFkrZFyTCgZJ5Rsq4oOQ6U3DdKAOUf+I3A+6LkeVByXSg5T5TsO0q2DSWfD0qWBSXThJJxREnfo6TrUPyZmgYldY2SskRJUWB8AfLJof1YGnK6AAAAAElFTkSuQmCC"
		barAfternoon = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAgCAYAAAAbifjMAAAAlElEQVR42u3VoQ5BAQCF4f8FJJEk3Spds4kkhU2S7iaItrtp5glMV0UP4AFEzSMogmew477D30z4TjzxHEq6MZhRxKBmGIMjkxhcWMTgzioGL+oYhH2Mf8FvFHyaMHizjcGTTQwerGNwo4rBlWUMzsxjcGIag0OzawY7RjHYUMagoh/DP9OYXgwGzUEaFLRj0KEV4wtLd/gOODZLXgAAAABJRU5ErkJggg=="
		barEvening = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAgCAYAAAAbifjMAAAAiklEQVR42u3VPwrBAQBH8e8g9UtKKOknofzJBbiAAziCGyizI8huNTqAAxhtjmAxOIOeQ7xNhs/61pcUC5TU1yhp7VDSOaKkd0HJ8I6SyQslc1D+gR8JfFAyfaNk/ETJ6IGSwQ0l/StKyjNKuieUdA4oae9R0tyipLFB8WeqrVBSLFFSnaGkUmJ8Af7Ih175kwI5AAAAAElFTkSuQmCC"

	stats
		parent_type = /datum
		channel
			var
				total_lines
		relationship
			var
				name
				strength

			proc/compare(artemis/bot/logger/stats/relationship/competitor)
				return strength - competitor.strength
		user
			var
				name
				list/night = new()
				list/morning = new()
				list/afternoon = new()
				list/evening = new()
				sortMode = "total"
			proc/compare(artemis/bot/logger/stats/user/competitor)
				switch(sortMode)
					if("total"    )
						var competitorStrength = (competitor.night.len+competitor.morning.len+competitor.afternoon.len+competitor.evening.len)
						var selfStrength = (night.len+morning.len+afternoon.len+evening.len)
						return selfStrength - competitorStrength
					if("night"    ) return night.len - competitor.night.len
					if("morning"  ) return morning.len - competitor.morning.len
					if("afternoon") return afternoon.len - competitor.afternoon.len
					if("evening"  ) return evening.len - competitor.evening.len

artemis/bot/logger/proc

	listAdd(list/insertList, list/newElement)
		insertList[++insertList.len] = newElement

	updateStats()
		set background = 1
		user.msg(null, ARTEMIS_ACTION_EMOTE, homeChannel, "is updating the channel statistics")
		// Get all messages from the compilation period
		var/list/period = new()
		for(var/day = statsPeriod+1 to 1 step -1)
			period.Add(statsDay(day)) // Merge Lists
		// Compile Stats
		sleep(1)
		var /list/users = new()
		var /list/relationships = new()
		var /list/fractions = new()
		// Cycle through each message and compile
		var /list/openConversations = new()
		var sleepCounter = 0
		for(var/list/msgData in period)
			statsCompileMsg(msgData, users, relationships, fractions, openConversations)
			// Don't lock up the CPU
			sleepCounter++
			if(sleepCounter == 50)
				sleep(1)
				sleepCounter = 0
			else
				sleep(-1)
		//
		var mostLines = 0
		for(var/fractionPeriod in fractions)
			var /list/fp = fractions[fractionPeriod]
			if(fp.len > mostLines)
				mostLines = fp.len
		// Hourly Activity graph
		var hourlyActivity = statsHourlyActivity(fractions, mostLines)
		// Most Active Users
		var activeUsers = statsActiveUsers(users)
		// Associates (relationships)
		var associates = statsAssociates(relationships)
		// Save all stats to file
		var header = compileHeader()
		var footer = compileFooter()
		var filePath = {"[pathStats]/[homeChannel].html"}
		if(fexists(filePath)){ fdel(filePath)}
		var F = file(filePath)
		F << {"[header] [hourlyActivity] [activeUsers] [associates] [footer]"}
		user.msg(null, ARTEMIS_ACTION_MESSAGE, homeChannel, {"Stats updated: byond://?action=stats;channel=[homeChannel];src=\ref[src];"})


	statsDay(day)
		var /list/period = list()
		// Get chat logs by date
		var dateStamp = world.realtime+offset - (864000 * (day-1))
		dateStamp = time2text(dateStamp, "YY-MM-DD")
		var datePath = {"[pathLog]/[dateStamp] [homeChannel].txt"}
		if(!fexists(datePath)) return period
		var logText = file2text(datePath)
		// Format raw text as valid JSON array, and convert to list
		// There's an extra object literal to account for the extra comma in logfile.
		logText = "\[[logText]{}]"
		var /list/logMessages = json_decode(logText)
		logMessages.Cut(logMessages.len)
		// Include messages sent in the compilation period
		if(day != statsPeriod+1)
			period.Add(logMessages) // Merge List
		else
			 // Not sure what's happening here.
			for(var/I = logMessages.len; I > 0; I--)
				sleep(0)
				var /list/msg = logMessages[I]
				if(world.timeofday+offset >= text2num(msg["time"]))
					logMessages.Cut(1, I)
					break
				logMessages[I] = msg
			//
			for(var/list/msg in logMessages)
				period[++period.len] = msg
		// Return all valid messages from within that period
		return period

	statsCompileMsg(msgData, list/users, list/relationships, list/fractions, openConversations)
		var/user_name = msgData["sender"]
		var /artemis/bot/logger/stats/user/U
		if(!(user_name in users))
			U = new()
			U.name = user_name
			users[user_name] = U
		else
			U = users[user_name]
		var time_stamp = text2num(msgData["time"])
		var fractionPeriod = round(time_stamp / 9000) // ticks per 15min
		var quarter
		switch(fractionPeriod)
			if( 0 to 23)
				listAdd(U.night, msgData)
				quarter = "n"
			if(24 to 47)
				listAdd(U.morning, msgData)
				quarter = "m"
			if(48 to 71)
				listAdd(U.afternoon, msgData)
				quarter = "a"
			if(72 to 96)
				listAdd(U.evening, msgData)
				quarter = "e"
		for(var/list/openLineData in openConversations)
			if(time_stamp - text2num(openLineData["time"]) > 50)
				openConversations -= openLineData
				continue
			var/open_name = openConversations[openLineData]
			if(open_name == user_name)
				openConversations -= openLineData
				continue
			var /relationship = (user_name > open_name)? "[quarter] [user_name] / [open_name]" : "[quarter] [open_name] / [user_name]"
			if(!(relationship in relationships)){ relationships[relationship] = 0}
			relationships[relationship]++
		openConversations[msgData] = user_name
		var/list/fp = fractions["[fractionPeriod]"]
		if(!fp)
			fp = new()
			fractions["[fractionPeriod]"] = fp
		fp += msgData

	statsHourlyActivity(list/fractions, mostLines)
		// A graph (table) of colored bars showing activity over 24 hours
		var hourlyActivity = {"
		<div class="section">
			<h3>Hourly Activity</h3>
			<table class="hourly_activity" cellspacing="0" cellpadding="1">
				<tr>"}
		for(var/I = 0 to 95)
			var /list/half = fractions["[I]"]
			var /line_height
			if(!half)
				line_height = 0
			else
				line_height = max(round((half.len/mostLines)*100),2)
			var time_bar
			switch(I)
				if( 0 to 23) time_bar = barNight
				if(24 to 47) time_bar = barMorning
				if(48 to 71) time_bar = barAfternoon
				if(72 to 96) time_bar = barEvening
			hourlyActivity += {"\n<td class="hourly_activity"><img class="tall_bar" src="[time_bar]" style="height:[line_height]px;"></td>"}
		var table_bottom = {"\n</tr>\n<tr>"}
		for(var/I = 0 to 23)
			table_bottom += {"<td colspan="4">[I]</td>"}
		hourlyActivity = {"[hourlyActivity]
					[table_bottom]
				</tr>
			</table>
		</div>
		<hr class="short">"}
		return hourlyActivity

	statsActiveUsers(list/users)
		var activeUsers = {"
		<div class="section">
			<h3>Most Active Users</h3>
			<table class="user_sheet">
				<tr class="margin">
					<td></td>
					<td>User Name</td>
					<td style="width:150px">Total Lines</td>
					<td>Random Quote</td>
				</tr>"}
		var /list/_users = new()
		for(var/user_name in users)
			_users += users[user_name]
		quickSort(_users)
		var longestBar
		for(var/I = 1 to min(_users.len, 25))
			var /artemis/bot/logger/stats/user/U = _users[I]
			if(I == 1)
				longestBar = U.night.len + U.morning.len + U.afternoon.len + U.evening.len
			var night_bar     = U.night.len    ? {"<img class="long_bar" src="[barNight    ]" style="width:[round((U.night.len    /longestBar)*100)]px">"} : ""
			var morning_bar   = U.morning.len  ? {"<img class="long_bar" src="[barMorning  ]" style="width:[round((U.morning.len  /longestBar)*100)]px">"} : ""
			var afternoon_bar = U.afternoon.len? {"<img class="long_bar" src="[barAfternoon]" style="width:[round((U.afternoon.len/longestBar)*100)]px">"} : ""
			var evening_bar   = U.evening.len  ? {"<img class="long_bar" src="[barEvening  ]" style="width:[round((U.evening.len  /longestBar)*100)]px">"} : ""
			var /list/sampleData = pick(U.night + U.morning + U.afternoon + U.evening)
			sampleData = sampleData["body"]
			activeUsers += {"
				<tr>
					<td class="margin">[I]</td>
					<td>[U.name]</td>
					<td>[night_bar][morning_bar][afternoon_bar][evening_bar][U.night.len + U.morning.len + U.afternoon.len + U.evening.len]</td>
					<td>[sampleData]</td>
				</tr>"}
		activeUsers += {"
			</table>
		</div>
		<hr class="short">"}
		//
		activeUsers += {"
		<div class="section">
			<h3>Users by Time</h3>
			<table class="user_sheet">
				<tr class="margin">
					<td></td>
					<td>Night</td>
					<td>Morning</td>
					<td>Afternoon</td>
					<td>Evening</td>
				</tr>"}
		for(var/artemis/bot/logger/stats/user/U in _users)
			U.sortMode = "night"
		var/list/most_active_night = quickSort(_users.Copy())
		for(var/artemis/bot/logger/stats/user/U in _users)
			U.sortMode = "morning"
		var/list/most_active_morning = quickSort(_users.Copy())
		for(var/artemis/bot/logger/stats/user/U in _users)
			U.sortMode = "afternoon"
		var/list/most_active_afternoon = quickSort(_users.Copy())
		for(var/artemis/bot/logger/stats/user/U in _users)
			U.sortMode = "evening"
		var/list/most_active_evening = quickSort(_users.Copy())
		for(var/I = 1; I <= min(10, _users.len); I++)
			var /artemis/bot/logger/stats/user/nU = most_active_night[I]
			var /artemis/bot/logger/stats/user/mU = most_active_morning[I]
			var /artemis/bot/logger/stats/user/aU = most_active_afternoon[I]
			var /artemis/bot/logger/stats/user/eU = most_active_evening[I]
			if(I == 1)
				longestBar = max(nU.night.len, mU.morning.len, aU.afternoon.len, eU.evening.len)
			var ntd = nU.night.len    ? {"[nU.name]: [nU.night.len    ]<br><img class="long_bar" src="[barNight    ]" style="width:[round((nU.night.len    /longestBar)*100)]px">"} : ""
			var mtd = mU.morning.len  ? {"[mU.name]: [mU.morning.len  ]<br><img class="long_bar" src="[barMorning  ]" style="width:[round((mU.morning.len  /longestBar)*100)]px">"} : ""
			var atd = aU.afternoon.len? {"[aU.name]: [aU.afternoon.len]<br><img class="long_bar" src="[barAfternoon]" style="width:[round((aU.afternoon.len/longestBar)*100)]px">"} : ""
			var etd = eU.evening.len  ? {"[eU.name]: [eU.evening.len  ]<br><img class="long_bar" src="[barEvening  ]" style="width:[round((eU.evening.len  /longestBar)*100)]px">"} : ""
			activeUsers += {"
				<tr>
					<td class="margin">[I]</td>
					<td>[ntd]</td>
					<td>[mtd]</td>
					<td>[atd]</td>
					<td>[etd]</td>
				</tr>"}
		activeUsers += {"
			</table>
		</div>
		<hr class="short">"}
		return activeUsers

	statsAssociates(list/relationships)
		var associates = {"
		<div class="section">
			<h3>Associates</h3>
			<table class="user_sheet">
				<tr class="margin">
					<td></td>
					<td>Night</td>
					<td>Morning</td>
					<td>Afternoon</td>
					<td>Evening</td>
				</tr>"}
		var /list/nrel = new()
		var /list/mrel = new()
		var /list/arel = new()
		var /list/erel = new()
		for(var/rel_name in relationships)
			var quarter = copytext(rel_name,1,2)
			var _name = copytext(rel_name,3)
			var /artemis/bot/logger/stats/relationship/R = new()
			R.name = _name
			R.strength = relationships[rel_name]
			switch(quarter)
				if("n") nrel.Add(R)
				if("m") mrel.Add(R)
				if("a") arel.Add(R)
				if("e") erel.Add(R)
		nrel = quickSort(nrel.Copy())
		mrel = quickSort(mrel.Copy())
		arel = quickSort(arel.Copy())
		erel = quickSort(erel.Copy())
		var longestBar
		for(var/I = 1 to min(max(nrel.len, mrel.len, arel.len, erel.len), 10))
			var/artemis/bot/logger/stats/relationship/nU = (nrel.len >= I)? nrel[I] : null
			var/artemis/bot/logger/stats/relationship/mU = (mrel.len >= I)? mrel[I] : null
			var/artemis/bot/logger/stats/relationship/aU = (arel.len >= I)? arel[I] : null
			var/artemis/bot/logger/stats/relationship/eU = (erel.len >= I)? erel[I] : null
			if(I == 1)
				longestBar = max((nU? nU.strength : 1), (mU? mU.strength : 1), (aU? aU.strength : 1), (eU? eU.strength : 1))
			var/ntd = nU? {"[nU.name]<br><img class="long_bar" src="[barNight    ]" style="width:[round((nU.strength/longestBar)*150)]px">"} : ""
			var/mtd = mU? {"[mU.name]<br><img class="long_bar" src="[barMorning  ]" style="width:[round((mU.strength/longestBar)*150)]px">"} : ""
			var/atd = aU? {"[aU.name]<br><img class="long_bar" src="[barAfternoon]" style="width:[round((aU.strength/longestBar)*150)]px">"} : ""
			var/etd = eU? {"[eU.name]<br><img class="long_bar" src="[barEvening  ]" style="width:[round((eU.strength/longestBar)*150)]px">"} : ""
			associates += {"
				<tr>
					<td class="margin">[I]</td>
					<td>[ntd]</td>
					<td>[mtd]</td>
					<td>[atd]</td>
					<td>[etd]</td>
				</tr>"}
		associates += {"
			</table>
		</div>"}
		return associates

//-- Utilities -----------------------------------
artemis/bot/logger
	proc
		text2list_faster(string, splitter)
			set background = TRUE
			var/textlength      = length(string)
			var/list/textList   = new()
			var/searchPosition  = 1
			var/findPosition    = 1
			var/buggyText
			var/sleeper = 0
			while(1)
				sleep(-1)
				sleeper++
				if(sleeper == 25)
					sleep(1)
					sleeper = 0
				findPosition = findtextEx(string, splitter, searchPosition, 0)
				buggyText = copytext(string, searchPosition, findPosition) // Everything from searchPosition to findPosition goes into a list element.
				if(length(buggyText)) // no null list items
					textList += buggyText // Working around weird problem where "text" != "text" after this copytext().
				searchPosition = findPosition + 1 // Skip over separator.
				if(findPosition == 0) // Didn't find anything at end of string so stop here.
					return textList
				else if(searchPosition > textlength) // Found separator at very end of string.
					return textList

		//-- QuickSort - Attributed to AbyssDragon -------
		quickSort(list/unsortedList, low = 1, high = -1)
			if(high == -1)
				high = unsortedList.len
			if(low >= high)
				return unsortedList
			// Find Pivot (folded helper function into main function)
			var X = unsortedList[high]
			var I = low -1
			for(var/J = low to high -1)
				if(!hascall(J, "compare")) continue
				if(call(J, "compare")(X) > 0)
					I++
					unsortedList.Swap(I, J)
			unsortedList.Swap(I+1, high)
			var pivot = I + 1
			//
			quickSort(unsortedList, low, pivot-1)
			quickSort(unsortedList, pivot+1, high)
			//
			return unsortedList


//-- HTML Formatting -----------------------------
artemis/bot/logger
	proc
		compileFooter()
			return {"
</div>
<hr>
<br>
<br>
<br>
<br>
</body>
</html>"}
		compileHeader()
			return {"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<meta http-equiv="Content-Script-Type" content="text:javascript">
<style type="text/css">
	body{
		margin: 1em;
		background-color: #000;
		color: #fc0;
		font-family: fixedsys, monospace;
		}
	hr{
		border: solid 0px #000;
		height: 1px;
		background-color: #fc0;
		color: #fc0;
		}
	hr.short{
		background-color: #111;
		color: #520;
		}
	h1{
		text-align: center;
		font-family: Georgia;
		color: #fff;
		}
	h2{
		text-align: left;
		font-family: Georgia;
		margin-top: 0em;
		color: #fff;
		}
	h3{
		text-align: left;
		font-family: Georgia;
		margin-top: 0em;
		/*color: #fff;*/
		}
	#contents_title{
		display: inline;
		position: relative;
		left: -2em;
		}
	li a{
		color: #fc0;
		text-decoration: none;
		}
	li a:hover{
		color: #fc0;
		text-decoration: underline;
		}
	li a:visited{
		color: #fc0;
		}
	.tall_bar{
		margin: 0px;
		width: 5px;
		}
	.long_bar{
		margin: 0px;
		height: 16px;
		}
	.main_section{
		margin-top: 3em;
		}
	.section{
		padding: 1em;
		margin: 1em;
		margin-top: 2em;
		}
	table.hourly_activity{
		background-color: #111;
		padding-top: 8px;
		}
	table.hourly_activity td{
		font-size: 8px;
		vertical-align: bottom;
		text-align: center;
		}
	td.hourly_activity{
		border-bottom: dotted 1px #fc0;
		}
	table.user_sheet{
		background-color: #111;
		}
	table.user_sheet td{
		border: solid 1px #000;
		padding-left: 1em;
		padding-right: 1em;
		vertical-align: middle;
		text-align: left;
		}
	table.user_sheet .margin{
		background-color: #001;
		}

	</style>
<title>Statistics for channel [homeChannel]</title>
</head>
<body>
	<br><br><br><hr>
	<div class="main_section">
		<h1>[homeChannel] Channel Statistics</h1>
		<div class="section">
			<ul><h3 id="contents_title">Contents</h3>
				<li><a href="#hourly">Hourly Activity and Users</a></li>
				<li><a href="#users">Top User Details</a> (in progress)</li>
				<li><a href="#misc">Misc</a> (in progress)</li>
				</ul>
			</div>
		</div>
	<hr>
	<div class="main_section"><a name="hourly"><h2>Hourly Activity and Users</h2></a>
"}
