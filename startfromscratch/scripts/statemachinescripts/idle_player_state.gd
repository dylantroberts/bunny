class_name IdlePlayerState

extends State

func update(delta):
	#if the player has velocity aka is moving then we will transition to our walking state
	if Global.player.velocity.length() > 0.0:
		transition.emit("WalkingPlayerState")
