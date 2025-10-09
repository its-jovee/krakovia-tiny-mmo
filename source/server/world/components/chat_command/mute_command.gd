extends ChatCommand

const AdminUtils = preload("res://source/server/world/components/chat_command/admin_utils.gd")


func execute(args: PackedStringArray, peer_id: int, server_instance: ServerInstance) -> String:
	# Expected format: /mute @handle [duration] [reason...]
	if args.size() < 2:
		return "Usage: /mute @handle [duration] [reason]"
	
	var target_handle: String = args[1]
	
	# Remove @ prefix if present
	if target_handle.begins_with("@"):
		target_handle = target_handle.substr(1)
	
	# Parse optional duration and reason
	var duration_str: String = "permanent"
	var reason: String = "No reason provided"
	
	if args.size() >= 3:
		duration_str = args[2]
	
	if args.size() >= 4:
		# Join remaining args as reason
		var reason_parts: PackedStringArray = []
		for i in range(3, args.size()):
			reason_parts.append(args[i])
		reason = " ".join(reason_parts)
	
	# Check if target account exists in database
	var player_data: WorldPlayerData = server_instance.world_server.database.player_data
	if not player_data.accounts.has(target_handle):
		return "Account not found: @" + target_handle
	
	# Parse duration
	var duration_seconds: int = AdminUtils.parse_duration(duration_str)
	var until_timestamp: int = 0
	
	if duration_seconds > 0:
		until_timestamp = int(Time.get_unix_time_from_system()) + duration_seconds
	
	# Get admin name
	var admin_player: Player = server_instance.get_player(peer_id)
	var admin_name: String = admin_player.player_resource.account_name if admin_player else "Server"
	
	# Add mute to database
	player_data.add_mute(target_handle, reason, until_timestamp, admin_name)
	
	# Save database immediately
	server_instance.world_server.database.save_world_database()
	
	# Notify player if online
	var target_peer: int = AdminUtils.find_player_by_handle(target_handle, server_instance)
	if target_peer != -1:
		var duration_text: String = AdminUtils.format_duration(duration_seconds)
		var mute_msg: String
		if duration_seconds > 0:
			mute_msg = "You have been muted for %s. Reason: %s" % [duration_text, reason]
		else:
			mute_msg = "You have been permanently muted. Reason: %s" % reason
		
		server_instance.data_push.rpc_id(
			target_peer,
			&"chat.message",
			{"text": mute_msg, "name": "Server", "id": 1}
		)
	
	# Format response
	var duration_text: String = AdminUtils.format_duration(duration_seconds)
	if duration_seconds > 0:
		var expiry_text: String = AdminUtils.format_timestamp(until_timestamp)
		return "Muted @%s for %s (until %s). Reason: %s" % [target_handle, duration_text, expiry_text, reason]
	else:
		return "Permanently muted @%s. Reason: %s" % [target_handle, reason]

