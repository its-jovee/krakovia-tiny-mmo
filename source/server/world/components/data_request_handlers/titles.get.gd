extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	# Get player
	var player: Player = instance.get_player(peer_id)
	if not player or not player.player_resource:
		return {"error": "Player not found"}
	
	var player_res: PlayerResource = player.player_resource
	var account_name: String = player_res.account_name
	var player_data: WorldPlayerData = instance.world_server.database.player_data
	
	# Ensure account data exists
	if TitleProgressTracker.instance:
		TitleProgressTracker.instance.ensure_account_data(account_name, player_data)
	
	var account_data: Dictionary = player_data.account_titles.get(account_name, {"unlocked": [], "progress": {}})
	var unlocked_list: Array = account_data.get("unlocked", [])
	var progress_data: Dictionary = account_data.get("progress", {})
	
	# Get all titles from registry
	var registry: ContentRegistry = ContentRegistryHub.registry_of(&"titles")
	if not registry:
		return {"error": "Titles registry not found"}
	
	# Load the titles index directly
	var titles_index: ContentIndex = load("res://source/common/registry/indexes/titles_index.tres")
	if not titles_index:
		return {"error": "Titles index not found"}
	
	var titles_array: Array = []
	
	# Build title data for each title
	for entry in titles_index.entries:
		var title_slug: StringName = entry["slug"]
		var title: TitleResource = ContentRegistryHub.load_by_slug(&"titles", title_slug)
		
		if not title:
			continue
		
		var is_unlocked: bool = title_slug in unlocked_list
		var progress_key: String = title.get_progress_key()
		var current_progress: int = progress_data.get(progress_key, 0)
		
		titles_array.append({
			"slug": String(title_slug),
			"name": title.get_translated_name(),
			"description": title.get_translated_description(),
			"rarity": title.rarity,
			"unlocked": is_unlocked,
			"progress": current_progress,
			"target": title.target_value,
			"condition_type": title.condition_type
		})
	
	return {
		"unlocked": unlocked_list.map(func(s): return String(s)),
		"selected": player_res.selected_title_slug,
		"titles": titles_array
	}
