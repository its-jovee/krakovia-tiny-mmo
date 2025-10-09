extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	_args: Dictionary
) -> Dictionary:
	var player: Player = instance.get_player(peer_id)
	if not player or not player.player_resource:
		return {"error": "Player not found"}
	
	var pr: PlayerResource = player.player_resource
	return {
		"level": pr.level,
		"experience": pr.experience,
		"exp_required": pr.get_exp_required(),
		"exp_progress": pr.get_exp_progress()
	}

