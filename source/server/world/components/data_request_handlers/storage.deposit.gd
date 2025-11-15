extends DataRequestHandler
## Handler for depositing items from inventory to account storage

const MAX_STORAGE_SLOTS: int = 48

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
	
	# Check if player has the item in inventory
	var player_resource = player.player_resource
	if not player_resource.inventory.has(item_id):
		return {"error": "Item not in inventory"}
	
	var item_entry = player_resource.inventory[item_id]
	if item_entry.stack < quantity:
		return {"error": "Not enough items in inventory"}
	
	# Get world data
	var world_server: WorldServer = instance.world_server
	if not world_server or not world_server.database:
		return {"error": "Database not available"}
	
	var player_data: WorldPlayerData = world_server.database.player_data
	if not player_data:
		return {"error": "World data not available"}
	
	var account_name: String = player_resource.account_name
	
	# Ensure account storage exists
	if not player_data.account_storage.has(account_name):
		player_data.account_storage[account_name] = {}
	
	var storage: Dictionary = player_data.account_storage[account_name]
	
	# Check storage slot limit (unique items, not total stack count)
	if not storage.has(item_id) and storage.size() >= MAX_STORAGE_SLOTS:
		return {"error": "Storage is full (%d/%d slots)" % [storage.size(), MAX_STORAGE_SLOTS]}
	
	# Add to storage
	if storage.has(item_id):
		storage[item_id].stack += quantity
	else:
		storage[item_id] = {"stack": quantity}
	
	# Remove from inventory
	item_entry.stack -= quantity
	if item_entry.stack <= 0:
		player_resource.inventory.erase(item_id)
	
	# Notify client of changes
	instance.data_push.rpc_id(peer_id, &"inventory.update", player_resource.inventory)
	instance.data_push.rpc_id(peer_id, &"storage.update", storage)
	
	print("[storage.deposit] %s deposited %dx item %d to storage" % [player_resource.display_name, quantity, item_id])
	
	return {
		"success": true,
		"deposited_quantity": quantity,
		"item_id": item_id
	}

