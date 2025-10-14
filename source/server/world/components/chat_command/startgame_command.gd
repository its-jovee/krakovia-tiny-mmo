extends ChatCommand


func execute(args: PackedStringArray, peer_id: int, server_instance: ServerInstance) -> String:
	# Get minigame manager
	var minigame_manager = server_instance.world_server.get_node_or_null("InstanceManager/MinigameManager")
	if not minigame_manager:
		return "Minigame system not available"
	
	var game_type: String = "horse_racing"
	if args.size() > 1:
		game_type = args[1]
	
	# Trigger invitation immediately
	minigame_manager.send_game_invitation(game_type)
	
	return "Started %s game invitation" % game_type

