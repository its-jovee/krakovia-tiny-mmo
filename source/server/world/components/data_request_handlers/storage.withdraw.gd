extends DataRequestHandler
## Handler for withdrawing items from account storage to inventory

func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var item_id: int = args.get("item_id", -1)
	var quantity: int = args.get("quantity", 1)
	
	if item_id == -1:
		return {"error": "Invalid item_id"}
	
	if quantity <= 0:
		return {"error": "Invalid quantity"}
	
	# Get player
	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		return {"error": "Player not found"}
	
	if not player.player_resource:
		return {"error": "Player resource not available"}
	
	# Check if player is in storage area
	var in_storage_area: bool = false
	for child in instance.instance_map.find_children("*", "StorageChestArea", true, false):
		if child is StorageChestArea:
			if child.is_player_in_storage(player):
				in_storage_area = true
				break
	
	if not in_storage_area:
		return {"error": "Must be near Family Crest to access storage"}
	
	# Get world data
	var world_server: WorldServer = instance.world_server
	if not world_server or not world_server.database:
		return {"error": "Database not available"}
	
	var player_data: WorldPlayerData = world_server.database.player_data
	if not player_data:
		return {"error": "World data not available"}
	
	var account_name: String = player.player_resource.account_name
	
	# Check if account has storage
	if not player_data.account_storage.has(account_name):
		return {"error": "Storage is empty"}
	
	var storage: Dictionary = player_data.account_storage[account_name]
	
	# Check if item exists in storage
	if not storage.has(item_id):
		return {"error": "Item not in storage"}
	
	var storage_entry = storage[item_id]
	if storage_entry.stack < quantity:
		return {"error": "Not enough items in storage"}
	
	# Get player inventory
	var player_resource = player.player_resource
	
	# Add to inventory
	if player_resource.inventory.has(item_id):
		player_resource.inventory[item_id].stack += quantity
	else:
		player_resource.inventory[item_id] = {"stack": quantity}
	
	# Remove from storage
	storage_entry.stack -= quantity
	if storage_entry.stack <= 0:
		storage.erase(item_id)
	
	# Notify client of changes
	instance.data_push.rpc_id(peer_id, &"inventory.update", player_resource.inventory)
	instance.data_push.rpc_id(peer_id, &"storage.update", storage)
	
	print("[storage.withdraw] %s withdrew %dx item %d from storage" % [player_resource.display_name, quantity, item_id])
	
	return {
		"success": true,
		"withdrawn_quantity": quantity,
		"item_id": item_id
	}

