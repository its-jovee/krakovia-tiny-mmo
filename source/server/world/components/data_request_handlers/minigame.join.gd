extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	print("[minigame.join] Request from peer %d with args: %s" % [peer_id, args])
	
	var player: Player = instance.players_by_peer_id.get(peer_id)
	if not player:
		print("[minigame.join] ERROR: Player not found for peer %d" % peer_id)
		return {"error": "Player not found"}
	
	var session_id: int = args.get("session_id", -1)
	if session_id == -1:
		print("[minigame.join] ERROR: Invalid session_id")
		return {"error": "Invalid session_id"}
	
	# Get minigame manager
	var minigame_manager = instance.world_server.get_node_or_null("InstanceManager/MinigameManager")
	if not minigame_manager:
		print("[minigame.join] ERROR: MinigameManager not found")
		return {"error": "Minigame system not available"}
	
	print("[minigame.join] Looking for session %d in: %s" % [session_id, minigame_manager.active_sessions.keys()])
	
	# Get the session
	var game_session = minigame_manager.get_active_session(session_id)
	if not game_session:
		print("[minigame.join] ERROR: Session %d not found" % session_id)
		return {"error": "Game session not found"}
	
	# Join the game
	var result = game_session.join_game(peer_id, instance, player.player_resource.display_name)
	
	print("[minigame.join] Join result: %s" % result)
	return result
