extends ChatCommand

const AdminUtils = preload("res://source/server/world/components/chat_command/admin_utils.gd")


func execute(args: PackedStringArray, peer_id: int, server_instance: ServerInstance) -> String:
	# Expected format: 
	# /tp @target - teleport yourself to target
	# /tp @player1 @player2 - teleport player1 to player2
	
	if args.size() < 2:
		return "Usage: /tp @target  OR  /tp @player1 @player2"
	
	var source_peer: int
	var target_handle: String
	
	if args.size() == 2:
		# Teleport executor to target
		source_peer = peer_id
		target_handle = args[1]
	else:
		# Teleport player1 to player2
		var source_handle: String = args[1]
		target_handle = args[2]
		
		source_peer = AdminUtils.find_player_by_handle(source_handle, server_instance)
		if source_peer == -1:
			return "Source player not found: " + source_handle
	
	# Find target player
	var target_peer: int = AdminUtils.find_player_by_handle(target_handle, server_instance)
	if target_peer == -1:
		return "Target player not found: " + target_handle
	
	# Get players
	var source_player: Player = server_instance.get_player(source_peer)
	var target_player: Player = server_instance.get_player(target_peer)
	
	if not source_player:
		return "Source player not in instance"
	if not target_player:
		return "Target player not in instance"
	
	# Can't teleport to yourself
	if source_peer == target_peer:
		return "Cannot teleport to yourself"
	
	# Get target position
	var target_position: Vector2 = target_player.position
	
	# Teleport source player
	source_player.just_teleported = true
	source_player.syn.set_by_path(^":position", target_position)
	
	# Notify players
	server_instance.data_push.rpc_id(
		source_peer,
		&"chat.message",
		{"text": "Teleported to @" + target_player.player_resource.account_name, "name": "Server", "id": 1}
	)
	
	var source_name: String = source_player.player_resource.account_name
	var target_name: String = target_player.player_resource.account_name
	
	if source_peer == peer_id:
		return "Teleported to @%s" % target_name
	else:
		return "Teleported @%s to @%s" % [source_name, target_name]

