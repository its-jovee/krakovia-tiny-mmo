extends ChatCommand


func execute(args: PackedStringArray, peer_id: int, server_instance: ServerInstance) -> String:
	# Get minigame manager
	var minigame_manager = server_instance.world_server.get_node_or_null("InstanceManager/MinigameManager")
	if not minigame_manager:
		return "Minigame system not available"
	
	print("[JoinCommand] Active sessions: ", minigame_manager.active_sessions.keys())
	
	# Find the most recent active session that's still in betting phase
	var active_session = null
	var latest_id = -1
	for session_id in minigame_manager.active_sessions:
		var session = minigame_manager.active_sessions[session_id]
		# Only join if in betting phase
		if session.phase == "betting" and session_id > latest_id:
			latest_id = session_id
			active_session = session
	
	if not active_session:
		return "No active minigame available to join (all games may have started)"
	
	print("[JoinCommand] Joining session %d for peer %d" % [latest_id, peer_id])
	
	# Get player
	var player: Player = server_instance.get_player(peer_id)
	if not player:
		return "Player not found"
	
	# Join the game
	var result = active_session.join_game(peer_id, server_instance, player.player_resource.display_name)
	
	if result.has("error"):
		return "Failed to join: " + result["error"]
	
	return "Joined the game!"

