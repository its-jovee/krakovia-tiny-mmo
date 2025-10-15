extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var session_id: int = args.get("session_id", -1)
	
	if session_id == -1:
		return {"success": false, "error": "Invalid session ID"}
	
	# Get minigame manager
	var minigame_manager = instance.world_server.get_node_or_null("InstanceManager/MinigameManager")
	if not minigame_manager:
		return {"success": false, "error": "Minigame system not available"}
	
	# Get the active session
	var game_session = minigame_manager.get_active_session(session_id)
	if not game_session:
		return {"success": false, "error": "Game session not found"}
	
	# Try to leave the game
	if game_session.has_method("leave_game"):
		return game_session.leave_game(peer_id)
	else:
		return {"success": false, "error": "Game does not support leaving"}
