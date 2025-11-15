extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var title_slug: String = args.get("slug", "")
	
	# Get player
	var player: Player = instance.get_player(peer_id)
	if not player or not player.player_resource:
		return {"error": "Player not found"}
	
	var player_res: PlayerResource = player.player_resource
	var account_name: String = player_res.account_name
	var player_data: WorldPlayerData = instance.world_server.database.player_data
	
	# Empty string means unequip
	if title_slug.is_empty():
		player_res.selected_title_slug = ""
		
		# Update state synchronizer for live display update
		var syn: StateSynchronizer = player.get_node_or_null(^"StateSynchronizer")
		if syn:
			syn.set_by_path(^":title_text", "")
			syn.set_by_path(^":title_rarity", 0)
		
		# Save database
		instance.world_server.database.save_world_database()
		
		return {"success": true, "selected": ""}
	
	# Validate title is unlocked
	var account_data: Dictionary = player_data.account_titles.get(account_name, {"unlocked": [], "progress": {}})
	var unlocked_list: Array = account_data.get("unlocked", [])
	
	if not (title_slug in unlocked_list):
		return {"error": "Title not unlocked"}
	
	# Load title resource to get display text and rarity
	var title: TitleResource = ContentRegistryHub.load_by_slug(&"titles", StringName(title_slug))
	if not title:
		return {"error": "Title not found"}
	
	# Set selected title
	player_res.selected_title_slug = title_slug
	
	# Update state synchronizer for live display update
	var syn: StateSynchronizer = player.get_node_or_null(^"StateSynchronizer")
	if syn:
		syn.set_by_path(^":title_text", title.title_name)
		syn.set_by_path(^":title_rarity", title.rarity)
	
	# Save database
	instance.world_server.database.save_world_database()
	
	return {
		"success": true,
		"selected": title_slug,
		"title_name": title.title_name
	}


