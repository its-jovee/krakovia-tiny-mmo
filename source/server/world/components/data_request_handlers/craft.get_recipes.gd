extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var player: Player = instance.get_player(peer_id)
	if not player or not player.player_resource:
		return {"recipes": []}
	
	var player_class = player.player_resource.character_class
	var player_level = player.player_resource.level
	
	# This will be optimized later - for now, return all recipe IDs
	# Client will filter/validate locally
	var registry = ContentRegistryHub.registry_of(&"recipes")
	var all_recipe_ids: Array = []
	
	# TODO: More efficient filtering server-side
	# For now, just return all recipe IDs and let client load/filter
	
	return {
		"player_class": player_class,
		"player_level": player_level,
		"recipe_version": ContentRegistryHub.version_of(&"recipes")
	}
