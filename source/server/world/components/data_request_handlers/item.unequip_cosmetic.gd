extends DataRequestHandler
## Server handler for unequipping cosmetic equipment items


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var slot_type: String = args.get("slot", "accessory")
	
	# Get player from peer_id
	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		print("[item.unequip_cosmetic] ✗ Player not found for peer %d" % peer_id)
		return {"ok": false, "error": "Player not found"}
	
	print("[item.unequip_cosmetic] Request from %s: slot=%s" % [player.player_resource.display_name, slot_type])
	
	# Unequip item
	match slot_type:
		"accessory":
			var old_id = player.player_resource.equipped_accessory_id
			player.player_resource.equipped_accessory_id = -1
			# Sync to all clients
			if player.state_synchronizer:
				player.state_synchronizer.set_by_path(^":equipped_accessory_id", -1)
			print("  → Unequipped item %d from accessory slot" % old_id)
	
	# Save to database
	if player.has_method("save_player_data"):
		player.save_player_data()
	
	print("  ✅ Successfully unequipped!")
	
	return {
		"ok": true,
		"unequipped_slot": slot_type
	}

