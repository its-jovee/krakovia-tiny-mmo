extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	_args: Dictionary
) -> Dictionary:
	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		return {"ok": false, "err": &"no_player"}
	
	var current_player_resource: PlayerResource = player.player_resource
	if not current_player_resource:
		return {"ok": false, "err": &"no_player_resource"}
	
	var account_name: String = current_player_resource.account_name
	
	# Get database reference
	var world_server: WorldServer = instance.world_server
	if not world_server or not world_server.database:
		return {"ok": false, "err": &"no_database"}
	
	var player_data: WorldPlayerData = world_server.database.player_data
	
	# Get all characters for this account
	var characters_data: Dictionary = player_data.get_account_characters(account_name)
	
	# Enhance with energy information
	var enhanced_data: Dictionary = {}
	for char_id in characters_data.keys():
		var char_info: Dictionary = characters_data[char_id].duplicate()
		var char_resource: PlayerResource = player_data.get_player_resource(int(char_id))
		
		if char_resource:
			# Calculate current energy (with offline regen if applicable)
			var energy_max: float = char_resource.get_energy_max()
			var saved_energy: float = char_resource.current_energy
			if saved_energy < 0.0:
				saved_energy = energy_max
			
			var last_logout: float = char_resource.last_logout_time
			var current_time: float = Time.get_unix_time_from_system()
			var time_offline: float = current_time - last_logout if last_logout > 0.0 else 0.0
			
			# Energy regenerates at 1 per 6 seconds
			var energy_regen: float = time_offline * (1.0 / 6.0)
			var current_energy: float = min(energy_max, saved_energy + energy_regen)
			
			char_info["energy"] = current_energy
			char_info["energy_max"] = energy_max
		else:
			char_info["energy"] = 0.0
			char_info["energy_max"] = 100.0
		
		enhanced_data[char_id] = char_info
	
	return {
		"ok": true,
		"characters": enhanced_data
	}

