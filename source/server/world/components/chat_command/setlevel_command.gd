extends ChatCommand

const AdminUtils = preload("res://source/server/world/components/chat_command/admin_utils.gd")


func execute(args: PackedStringArray, peer_id: int, server_instance: ServerInstance) -> String:
	# Expected format: /setlevel @handle level
	if args.size() < 3:
		return "Usage: /setlevel @handle level"
	
	var target_handle: String = args[1]
	var level_str: String = args[2]
	
	# Find target player
	var target_peer: int = AdminUtils.find_player_by_handle(target_handle, server_instance)
	if target_peer == -1:
		return "Player not found: " + target_handle
	
	# Parse level
	var new_level: int = level_str.to_int()
	
	if new_level < 0:
		return "Invalid level: " + level_str
	
	# Get target player
	var target_player: Player = server_instance.get_player(target_peer)
	if not target_player:
		return "Target player not in instance"
	
	# Calculate attribute points difference
	var old_level: int = target_player.player_resource.level
	var level_diff: int = new_level - old_level
	
	# Set level
	target_player.player_resource.level = new_level
	
	# Award attribute points for level difference
	if level_diff > 0:
		var points_to_add: int = level_diff * PlayerResource.ATTRIBUTE_POINTS_PER_LEVEL
		target_player.player_resource.available_attributes_points += points_to_add
	
	# Notify target player
	server_instance.data_push.rpc_id(
		target_peer,
		&"chat.message",
		{"text": "Your level has been set to %d" % new_level, "name": "Server", "id": 1}
	)
	
	var target_name: String = target_player.player_resource.account_name
	return "Set @%s's level to %d" % [target_name, new_level]

