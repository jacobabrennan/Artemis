

//-- Artemis artemis Messages ----------------------------------------------------

artemis/msg
	parent_type = /datum
	var
		artemis/user/sender
		artemis/user/target
		artemis/channel/channel
		action
		body
		time
	New(_sender, _target, _action, _channel, _body, _time)
		.=..()
		sender = _sender//lowertext(_sender)
		target = _target//lowertext(_target)
		channel = _channel
		action = _action
		body = _body
		time = _time? _time : world.timeofday

	proc
		toJSON()
			var /list/objectData = new()
			objectData["sender"] = sender?.nameFull
			objectData["target"] = target?.nameFull
			objectData["action"] = action
			objectData["channel"] = channel
			objectData["body"] = body
			objectData["time"] = time
			return objectData
		fromJSON(list/objectData)
			sender = artemis.getUser(objectData["sender"])
			target = artemis.getUser(objectData["target"])
			var channelName = objectData["channel"]
			action = objectData["action"]
			channel = artemis.getChannel(channelName)
			if(!channel) channel = channelName
			body = objectData["body"]
			time = objectData["time"]