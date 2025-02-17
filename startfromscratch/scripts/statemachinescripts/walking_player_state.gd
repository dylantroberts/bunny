class_name WalkingPlayerState

extends State

func update(delta):
	#if the player velocity is 0 or stops moving then we are in idle state
	if Global.player.velocity.length() == 0.0:
		transition.emit("IdlePlayerState")
