extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	# Check if player exists
	if not instance.players_by_peer_id.has(peer_id):
		return {"error": "Player not found"}
	
	var player = instance.players_by_peer_id[peer_id]
	if not player or not player.player_resource:
		return {"error": "Player resource not available"}
	
	return player.player_resource.inventory
