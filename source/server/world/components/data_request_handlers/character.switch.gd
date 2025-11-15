extends DataRequestHandler


const SWITCH_COOLDOWN_SECONDS: float = 5.0


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		return {"ok": false, "err": &"no_player"}
	
	var current_player_resource: PlayerResource = player.player_resource
	if not current_player_resource:
		return {"ok": false, "err": &"no_player_resource"}
	
	var account_name: String = current_player_resource.account_name
	var target_character_id: int = int(args.get("character_id", -1))
	
	if target_character_id <= 0:
		return {"ok": false, "err": &"invalid_character_id"}
	
	# Don't allow switching to the same character
	if target_character_id == current_player_resource.player_id:
		return {"ok": false, "err": &"already_this_character"}
	
	# Get database reference
	var world_server: WorldServer = instance.world_server
	if not world_server or not world_server.database:
		return {"ok": false, "err": &"no_database"}
	
	var player_data: WorldPlayerData = world_server.database.player_data
	
	# Validate target character exists and belongs to this account
	var target_player_resource: PlayerResource = player_data.get_player_resource(target_character_id)
	if not target_player_resource:
		return {"ok": false, "err": &"character_not_found"}
	
	if target_player_resource.account_name != account_name:
		return {"ok": false, "err": &"not_your_character"}
	
	# Check if player is currently harvesting
	if instance.harvest_manager and instance.harvest_manager.is_peer_harvesting(peer_id):
		return {"ok": false, "err": &"cannot_switch_while_harvesting"}
	
	# Check cooldown
	var current_time: float = Time.get_unix_time_from_system()
	var last_switch_time: float = float(player_data.account_switch_cooldowns.get(account_name, 0.0))
	var time_since_last_switch: float = current_time - last_switch_time
	
	if time_since_last_switch < SWITCH_COOLDOWN_SECONDS:
		var remaining: float = SWITCH_COOLDOWN_SECONDS - time_since_last_switch
		return {"ok": false, "err": &"cooldown", "cooldown_remaining": remaining}
	
	# Check if player is in an active trade
	if instance.has_node("TradeManager"):
		var trade_mgr: TradeManager = instance.get_node("TradeManager")
		for session_id in trade_mgr.active_trades.keys():
			var session = trade_mgr.active_trades[session_id]
			if session.peer_a == peer_id or session.peer_b == peer_id:
				return {"ok": false, "err": &"cannot_switch_during_trade"}
	
	# Check if player has an active shop
	if instance.has_node("ShopManager"):
		var shop_mgr: ShopManager = instance.get_node("ShopManager")
		if shop_mgr.has_shop(peer_id):
			return {"ok": false, "err": &"cannot_switch_with_active_shop"}
	
	# Save current character state and capture their position for the new character
	var switch_position: Vector2 = player.global_position  # Use current position for in-place switch
	
	var asc: AbilitySystemComponent = player.ability_system_component
	if asc:
		var energy_cur: float = asc.get_value(&"energy")
		var energy_max: float = asc.get_max(&"energy")
		current_player_resource.current_energy = clamp(energy_cur, 0.0, energy_max)
	
	current_player_resource.last_position = player.global_position
	current_player_resource.last_logout_time = current_time
	
	# Calculate target character's energy (offline regeneration)
	var target_energy_max: float = target_player_resource.get_energy_max()
	var target_saved_energy: float = target_player_resource.current_energy
	if target_saved_energy < 0.0:
		target_saved_energy = target_energy_max  # First time, start full
	
	var target_last_logout: float = target_player_resource.last_logout_time
	var time_offline: float = current_time - target_last_logout if target_last_logout > 0.0 else 0.0
	
	# Energy regenerates at 1 per 6 seconds (1/6 per second)
	var energy_regen: float = time_offline * (1.0 / 6.0)
	var new_energy: float = min(target_energy_max, target_saved_energy + energy_regen)
	target_player_resource.current_energy = new_energy
	
	# Update the connected player resource BEFORE despawning
	# This ensures instantiate_player will use the correct character when called
	world_server.connected_players[peer_id] = target_player_resource
	target_player_resource.current_peer_id = peer_id
	
	print("[CharacterSwitch] Switching peer %d to character %s (class: %s)" % [peer_id, target_player_resource.display_name, target_player_resource.character_class])
	
	# Despawn current character (with deletion)
	instance.despawn_player(peer_id, true)
	
	# Create and set up the new player with the switched position
	var new_player: Player = instance.instantiate_player(peer_id)
	
	print("[CharacterSwitch] Instantiated new player: %s" % new_player.name)
	
	instance.awaiting_peers[peer_id] = {
		"player": new_player,
		"target_id": 0,
		"saved_position": switch_position  # Always use the position where they switched
	}
	
	# Spawn the new character at the switch location
	instance.spawn_player(peer_id)
	
	print("[CharacterSwitch] Spawned player at position: %s" % switch_position)
	
	# Update cooldown timestamp
	player_data.account_switch_cooldowns[account_name] = current_time
	
	# Save database
	world_server.database.save_world_database()
	
	# Push updated character data to client for HUD refresh
	instance.data_push.rpc_id(peer_id, &"gold.update", {"gold": target_player_resource.golds})
	instance.data_push.rpc_id(peer_id, &"exp.update", {
		"level": target_player_resource.level,
		"exp": target_player_resource.experience,
		"exp_required": target_player_resource.get_exp_required(),
		"leveled_up": false
	})
	
	# Notify client that switch is complete so it can refresh UI
	instance.data_push.rpc_id(peer_id, &"character.switch.complete", {
		"character_id": target_character_id,
		"character_name": target_player_resource.display_name,
		"character_class": target_player_resource.character_class
	})
	
	return {
		"ok": true,
		"character_id": target_character_id,
		"character_name": target_player_resource.display_name,
		"character_class": target_player_resource.character_class,
		"level": target_player_resource.level,
		"energy": new_energy,
		"energy_max": target_energy_max
	}

