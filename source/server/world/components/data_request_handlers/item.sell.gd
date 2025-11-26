extends DataRequestHandler
## Handler for selling items TO vendors (unified vendor system)

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
	
	if quantity <= 0:
		return {"error": "Quantity must be positive"}
	
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
	
	# Find the vendor the player is at
	var vendor: VendorArea = _get_player_vendor(player, instance)
	if not vendor:
		return {"error": "Must be at a vendor to sell items"}
	
	# Check if this vendor buys this item
	if not vendor.buys_item(item_id):
		return {"error": "This vendor doesn't buy that item"}
	
	# Get current event multiplier (if any)
	var event_mult = _get_event_multiplier(instance, item_id, vendor.vendor_type)
	
	# Calculate sell price using vendor's local pricing
	var sell_price = vendor.get_sell_price(item, item_id, event_mult)
	var total_price = sell_price * quantity
	
	# Execute sale
	# 1. Remove items from inventory
	item_entry.stack -= quantity
	if item_entry.stack <= 0:
		player_resource.inventory.erase(item_id)
	
	# 2. Add gold to player
	player_resource.golds += total_price
	
	# 3. Update vendor's local supply (selling increases supply, prices go down)
	var item_tier = _get_item_tier(item)
	vendor.adjust_supply(item_id, quantity, item_tier, false)
	
	# 4. Process material conversion → add stock for finished goods
	vendor.process_material_sale(item_id, quantity)
	
	# Notify client of inventory and gold changes
	instance.data_push.rpc_id(peer_id, &"inventory.update", player_resource.inventory)
	instance.data_push.rpc_id(peer_id, &"gold.update", {"gold": player_resource.golds})
	
	# Push updated catalog (with new stock levels) to all players at this vendor
	_push_catalog_update_to_vendor(instance, vendor, event_mult)
	
	return {
		"success": true,
		"sold_quantity": quantity,
		"total_price": total_price,
		"item_name": item.item_name
	}


func _get_player_vendor(player: Player, instance: ServerInstance) -> VendorArea:
	"""Find the vendor the player is currently at"""
	var vendors = instance.instance_map.find_children("*", "VendorArea", true, false)
	for vendor in vendors:
		if vendor is VendorArea and vendor.is_player_at_vendor(player):
			return vendor
	return null


func _get_event_multiplier(instance: ServerInstance, item_id: int, vendor_type: String) -> float:
	"""Get price multiplier from current market event (if any)"""
	var event_manager = _get_event_manager(instance)
	if event_manager and event_manager.current_event:
		return event_manager.get_price_multiplier(item_id, vendor_type)
	return 1.0


func _get_event_manager(instance: ServerInstance) -> Node:
	"""Get the MarketEventManager from the server"""
	if instance.world_server:
		return instance.world_server.get_node_or_null("MarketEventManager")
	return null


func _get_item_tier(item: Item) -> int:
	"""Estimate item tier based on tags for supply impact calculation"""
	if "legendary" in item.tags or "rare" in item.tags:
		return 5
	elif "epic" in item.tags:
		return 4
	elif "uncommon" in item.tags:
		return 3
	elif "common" in item.tags:
		return 2
	else:
		return 1


func _push_price_update_to_vendor(instance: ServerInstance, vendor: VendorArea, item_id: int, event_mult: float) -> void:
	"""Push price update to all players at this vendor"""
	var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
	if not item:
		return
	
	var update_data = {
		"vendor_id": vendor.vendor_id,
		"item_id": item_id,
		"buy_price": vendor.get_buy_price(item, item_id, event_mult),
		"sell_price": vendor.get_sell_price(item, item_id, event_mult),
		"supply_level": vendor.get_supply_level(item_id)
	}
	
	for player in vendor.players_at_vendor:
		var peer = _get_peer_id_for_player(instance, player)
		if peer != 0:
			instance.data_push.rpc_id(peer, &"vendor.price_update", update_data)


func _get_peer_id_for_player(instance: ServerInstance, player: Player) -> int:
	"""Get peer ID for a player"""
	for peer in instance.players_by_peer_id.keys():
		if instance.players_by_peer_id[peer] == player:
			return peer
	return 0


func _push_catalog_update_to_vendor(instance: ServerInstance, vendor: VendorArea, event_mult: float) -> void:
	"""Push updated catalog (with stock levels) to all players at this vendor"""
	var catalog = vendor.get_catalog_for_client(event_mult)
	
	var update_data = {
		"vendor_id": vendor.vendor_id,
		"catalog": catalog
	}
	
	for player in vendor.players_at_vendor:
		var peer = _get_peer_id_for_player(instance, player)
		if peer != 0:
			instance.data_push.rpc_id(peer, &"vendor.catalog_update", update_data)
