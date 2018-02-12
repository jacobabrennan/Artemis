

//-- Artemis artemis Messages ----------------------------------------------------

artemis/msg
	parent_type = /datum
	var
		sender
		body
		time
		target
		action
	New(_sender, _target, _action, _body, _time)
		.=..()
		sender = lowertext(_sender)
		target = lowertext(_target)
		action = _action
		body = _body
		time = _time? _time : world.timeofday
