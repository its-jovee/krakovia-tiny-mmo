extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var player: Player = instance.players_by_peer_id.get(peer_id)
	if not player:
		return {"error": "Player not found"}
	
	var account_name: String = player.player_resource.account_name
	
	# Check if player is muted
	if instance.world_server.database.player_data.is_muted(account_name):
		var mute_info: Dictionary = instance.world_server.database.player_data.muted_players.get(account_name, {})
		var reason: String = mute_info.get("reason", "No reason provided")
		instance.data_push.rpc_id(
			peer_id,
			&"chat.message",
			{"text": "You are muted. Reason: " + reason, "name": "Server", "id": 1}
		)
		return {"error": "muted"}
	
	var message: Dictionary = {
		"text": args.get("text", ""),
		"channel": args.get("channel", 0),
		"name": player.player_resource.display_name,
		"id": peer_id
		#"time": Time.get_
	}
	instance.propagate_rpc(instance.data_push.bind(&"chat.message", message))
	return {} # ACK later #{"error": 0}
