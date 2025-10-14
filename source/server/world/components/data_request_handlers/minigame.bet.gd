extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var player: Player = instance.players_by_peer_id.get(peer_id)
	if not player:
		return {"error": "Player not found"}
	
	var session_id: int = args.get("session_id", -1)
	var horse_id: int = args.get("horse_id", -1)
	var amount: int = args.get("amount", 0)
	
	if session_id == -1:
		return {"error": "Invalid session_id"}
	
	# Get minigame manager
	var minigame_manager = instance.world_server.get_node_or_null("InstanceManager/MinigameManager")
	if not minigame_manager:
		return {"error": "Minigame system not available"}
	
	# Get the session
	var game_session = minigame_manager.get_active_session(session_id)
	if not game_session:
		return {"error": "Game session not found"}
	
	# Place bet
	var result = game_session.place_bet(peer_id, horse_id, amount)
	
	return result

