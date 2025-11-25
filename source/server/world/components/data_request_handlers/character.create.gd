extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if not player or not player.player_resource:
		return {"ok": false, "err": &"no_player"}
	
	var account_name: String = player.player_resource.account_name
	var character_name: String = args.get("name", "")
	var character_class: String = args.get("class", "")
	var head_id: String = args.get("head", "head_a")
	
	# Validate inputs
	if character_name.is_empty():
		return {"ok": false, "err": &"empty_name"}
	
	if character_name.length() < 4:
		return {"ok": false, "err": &"name_too_short"}
	
	if character_name.length() > 16:
		return {"ok": false, "err": &"name_too_long"}
	
	if character_class.is_empty() or not character_class in ["miner", "forager", "trapper"]:
		return {"ok": false, "err": &"invalid_class"}
	
	# Get database reference
	var world_server: WorldServer = instance.world_server
	if not world_server or not world_server.database:
		return {"ok": false, "err": &"no_database"}
	
	var player_data: WorldPlayerData = world_server.database.player_data
	
	# Create the character
	var new_character_id: int = player_data.create_player_character(account_name, {
		"name": character_name,
		"class": character_class,
		"head": head_id
	})
	
	# Handle error codes from create_player_character
	if new_character_id < 0:
		return {"ok": false, "err": &"max_characters_reached"}
	elif new_character_id == 1:
		return {"ok": false, "err": &"empty_name"}
	elif new_character_id == 2:
		return {"ok": false, "err": &"name_too_short"}
	elif new_character_id == 3:
		return {"ok": false, "err": &"name_too_long"}
	elif new_character_id == 10:
		return {"ok": false, "err": &"banned_word"}
	
	# Save database
	world_server.database.save_world_database()
	
	print("[CharacterCreate] Created character %d (%s - %s) for account %s" % [new_character_id, character_name, character_class, account_name])
	
	return {
		"ok": true,
		"character_id": new_character_id,
		"character_name": character_name,
		"character_class": character_class
	}


