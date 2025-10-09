extends ChatCommand

const AdminUtils = preload("res://source/server/world/components/chat_command/admin_utils.gd")


func execute(args: PackedStringArray, peer_id: int, server_instance: ServerInstance) -> String:
	# Expected format: /give @handle item_slug quantity
	# Example: /give @john ore 10
	if args.size() < 4:
		return "Usage: /give @handle item_slug quantity (e.g. /give @john ore 10)"
	
	var target_handle: String = args[1]
	var item_slug: String = args[2]
	var quantity_str: String = args[3]
	
	# Find target player
	var target_peer: int = AdminUtils.find_player_by_handle(target_handle, server_instance)
	if target_peer == -1:
		return "Player not found: " + target_handle
	
	# Parse quantity
	var quantity: int = quantity_str.to_int()
	
	if quantity <= 0:
		return "Invalid quantity: " + quantity_str
	
	# Verify item exists by slug
	var item_slug_name: StringName = StringName(item_slug)
	var item: Item = ContentRegistryHub.load_by_slug(&"items", item_slug_name)
	if not item:
		return "Item not found: " + item_slug + " (use slugs like: ore, copper_ore, health_potion)"
	
	# Give item to player
	var target_player: Player = server_instance.get_player(target_peer)
	if not target_player:
		return "Target player not in instance"
	
	# Use the existing give_item function with the slug
	var success: bool = server_instance.give_item(target_peer, item_slug_name, quantity)
	
	if not success:
		return "Failed to give item (invalid slug or server error)"
	
	# Push inventory update to target player
	server_instance.data_push.rpc_id(
		target_peer,
		&"inventory.update",
		target_player.player_resource.inventory
	)
	
	# Notify target player
	server_instance.data_push.rpc_id(
		target_peer,
		&"chat.message",
		{"text": "You received %d x %s" % [quantity, item.item_name], "name": "Server", "id": 1}
	)
	
	var target_name: String = target_player.player_resource.account_name
	return "Gave %d x %s to @%s" % [quantity, item.item_name, target_name]
