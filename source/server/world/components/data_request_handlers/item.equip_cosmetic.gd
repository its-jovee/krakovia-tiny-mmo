extends DataRequestHandler
## Server handler for equipping cosmetic equipment items
## Validates requirements, updates PlayerResource, and syncs to all clients


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var item_id: int = args.get("item_id", -1)
	var slot_type: String = args.get("slot", "accessory")
	
	# Get player from peer_id
	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		print("[item.equip_cosmetic] ✗ Player not found for peer %d" % peer_id)
		return {"ok": false, "error": "Player not found"}
	
	print("[item.equip_cosmetic] Request from %s: item_id=%d, slot=%s" % [player.player_resource.display_name, item_id, slot_type])
	
	# Validate item exists in inventory
	if not player.player_resource.inventory.has(item_id):
		print("  ✗ Item not in inventory")
		return {"ok": false, "error": "Item not in inventory"}
	
	# Load item and validate it's an EquipmentItem
	var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
	if not item:
		print("  ✗ Item failed to load from registry")
		return {"ok": false, "error": "Item not found"}
	
	if not item is EquipmentItem:
		print("  ✗ Item is not an EquipmentItem (is %s)" % item.get_class())
		return {"ok": false, "error": "Not an equipment item"}
	
	var equipment_item := item as EquipmentItem
	
	print("  → Item loaded: %s" % equipment_item.item_name)
	print("  → Required level: %d, Player level: %d" % [equipment_item.required_level, player.player_resource.level])
	print("  → Required classes: %s, Player class: %s" % [equipment_item.required_classes, player.player_resource.character_class])
	
	# Validate requirements
	if not equipment_item.can_equip(player):
		print("  ✗ Requirements not met")
		return {"ok": false, "error": "Requirements not met"}
	
	print("  ✅ Requirements met!")
	
	# Equip item (update server-side PlayerResource)
	match slot_type:
		"accessory":
			player.player_resource.equipped_accessory_id = item_id
			# Sync to all clients via StateSynchronizer
			if player.state_synchronizer:
				player.state_synchronizer.set_by_path(^":equipped_accessory_id", item_id)
			print("  → Equipped to accessory slot")
	
	# Save to database (if you have persistence)
	if player.has_method("save_player_data"):
		player.save_player_data()
	
	print("  ✅ Successfully equipped %s!" % equipment_item.item_name)
	
	return {
		"ok": true,
		"equipped_id": item_id,
		"slot": slot_type,
		"item_name": equipment_item.item_name
	}

