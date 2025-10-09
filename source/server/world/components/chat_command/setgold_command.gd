extends ChatCommand

const AdminUtils = preload("res://source/server/world/components/chat_command/admin_utils.gd")


func execute(args: PackedStringArray, peer_id: int, server_instance: ServerInstance) -> String:
	# Expected format: /setgold @handle amount
	if args.size() < 3:
		return "Usage: /setgold @handle amount"
	
	var target_handle: String = args[1]
	var amount_str: String = args[2]
	
	# Find target player
	var target_peer: int = AdminUtils.find_player_by_handle(target_handle, server_instance)
	if target_peer == -1:
		return "Player not found: " + target_handle
	
	# Parse amount
	var amount: int = amount_str.to_int()
	
	if amount < 0:
		return "Invalid amount: " + amount_str
	
	# Get target player
	var target_player: Player = server_instance.get_player(target_peer)
	if not target_player:
		return "Target player not in instance"
	
	# Set gold
	target_player.player_resource.golds = amount
	
	# Push gold update to target player
	server_instance.data_push.rpc_id(
		target_peer,
		&"gold.update",
		{"gold": amount}
	)
	
	# Notify target player
	server_instance.data_push.rpc_id(
		target_peer,
		&"chat.message",
		{"text": "Your gold has been set to %d" % amount, "name": "Server", "id": 1}
	)
	
	var target_name: String = target_player.player_resource.account_name
	return "Set @%s's gold to %d" % [target_name, amount]

