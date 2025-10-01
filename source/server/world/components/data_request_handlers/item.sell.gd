extends DataRequestHandler

func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		return {"error": "Player not found"}
	
	var item_id: int = args.get("item_id", -1)
	var quantity: int = args.get("quantity", 1)
	
	if item_id == -1:
		return {"error": "Invalid item_id"}
	
	var player_resource = player.player_resource
	
	# Check if player has the item
	if not player_resource.inventory.has(item_id):
		return {"error": "Item not in inventory"}
	
	var item_entry = player_resource.inventory[item_id]
	if item_entry.stack < quantity:
		return {"error": "Not enough items to sell"}
	
	# Load the item to check if it can be sold
	var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
	if not item:
		return {"error": "Item not found"}
	
	if not item.can_sell:
		return {"error": "Item cannot be sold"}
	
	# Check if player is in a market area
	if not _is_player_in_market(player, instance):
		return {"error": "Must be in a market to sell items"}
	
	# Calculate sell price
	var sell_price = _calculate_sell_price(item, instance, player)
	var total_price = sell_price * quantity
	
	# Remove items from inventory
	item_entry.stack -= quantity
	if item_entry.stack <= 0:
		player_resource.inventory.erase(item_id)
	
	# Add gold to player
	player_resource.golds += total_price
	
	# Notify client of inventory and gold changes
	instance.data_push.rpc_id(peer_id, &"inventory.update", player_resource.inventory)
	instance.data_push.rpc_id(peer_id, &"gold.update", {"gold": player_resource.golds})
	
	return {
		"success": true,
		"sold_quantity": quantity,
		"total_price": total_price,
		"item_name": item.item_name
	}

func _is_player_in_market(player: Player, instance: ServerInstance) -> bool:
	# Check if player is in any market area
	for child in instance.instance_map.get_children():
		if child is MarketArea:
			var market = child as MarketArea
			if market.is_player_in_market(player):
				return true
	return false

func _calculate_sell_price(item: Item, instance: ServerInstance, player: Player) -> int:
	# Find the market area the player is in
	for child in instance.instance_map.get_children():
		if child is MarketArea:
			var market = child as MarketArea
			if market.is_player_in_market(player):
				return market.get_sell_price(item)
	
	# Fallback to base price if no market found (shouldn't happen due to check above)
	if item.minimum_price > 0:
		return item.minimum_price
	else:
		return 1  # Default minimal price
