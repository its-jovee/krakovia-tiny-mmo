extends DataRequestHandler
## Handler for getting the vendor catalog (items this vendor trades and their prices)

func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		return {"error": "Player not found"}
	
	# Find the vendor the player is at
	var vendor: VendorArea = _get_player_vendor(player, instance)
	if not vendor:
		return {"error": "Must be at a vendor to view catalog"}
	
	# Get event manager for per-item multipliers
	var event_manager = _get_event_manager(instance)
	
	# Build catalog with per-item event multipliers
	var catalog = _build_catalog_with_event_prices(vendor, event_manager)
	
	return {
		"success": true,
		"vendor": vendor.get_vendor_info(),
		"catalog": catalog,
		"event": _get_current_event_info(instance)
	}


func _build_catalog_with_event_prices(vendor: VendorArea, event_manager: Node) -> Dictionary:
	"""Build catalog with per-item event price modifiers applied and production info"""
	var vendor_type = vendor.vendor_type
	
	# Get full catalog from vendor (includes production info)
	var base_catalog = vendor.get_catalog_for_client(1.0)
	var sell_catalog_result: Array[Dictionary] = []
	var buy_catalog_result: Array[Dictionary] = []
	
	# Apply event multipliers to sell items (player buys)
	for entry in base_catalog.get("sells", []):
		var item_id = entry.get("id", 0)
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if item:
			var event_mult = _get_item_event_multiplier(event_manager, item_id, vendor_type)
			entry["price"] = vendor.get_buy_price(item, item_id, event_mult)
		sell_catalog_result.append(entry)
	
	# Apply event multipliers to buy items (vendor buys from player)
	for entry in base_catalog.get("buys", []):
		var item_id = entry.get("id", 0)
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if item:
			var event_mult = _get_item_event_multiplier(event_manager, item_id, vendor_type)
			entry["price"] = vendor.get_sell_price(item, item_id, event_mult)
		buy_catalog_result.append(entry)
	
	return {
		"sells": sell_catalog_result,
		"buys": buy_catalog_result
	}


func _get_player_vendor(player: Player, instance: ServerInstance) -> VendorArea:
	"""Find the vendor the player is currently at"""
	var vendors = instance.instance_map.find_children("*", "VendorArea", true, false)
	for vendor in vendors:
		if vendor is VendorArea and vendor.is_player_at_vendor(player):
			return vendor
	return null


func _get_item_event_multiplier(event_manager: Node, item_id: int, vendor_type: String) -> float:
	"""Get the combined event multiplier for a specific item at a vendor type"""
	if event_manager and event_manager.current_event:
		return event_manager.get_price_multiplier(item_id, vendor_type)
	return 1.0


func _get_event_manager(instance: ServerInstance) -> Node:
	"""Get the MarketEventManager from the server"""
	if instance.world_server:
		return instance.world_server.get_node_or_null("MarketEventManager")
	return null


func _get_current_event_info(instance: ServerInstance) -> Variant:
	"""Get current event info for client display"""
	var event_manager = _get_event_manager(instance)
	if event_manager and event_manager.current_event:
		return event_manager.get_event_info_for_client()
	return null
