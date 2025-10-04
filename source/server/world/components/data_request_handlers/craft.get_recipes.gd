extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	print("=== SERVER CRAFT.GET_RECIPES DEBUG ===")
	print("Peer ID: ", peer_id)
	
	var player: Player = instance.get_player(peer_id)
	if not player:
		print("❌ Player not found for peer: ", peer_id)
		return {"recipes": []}
	
	if not player.player_resource:
		print("❌ Player resource not found")
		return {"recipes": []}
	
	var player_class = player.player_resource.character_class
	var player_level = player.player_resource.level
	
	print("Player class: '", player_class, "'")
	print("Player level: ", player_level)
	
	# This will be optimized later - for now, return all recipe IDs
	# Client will filter/validate locally
	var registry = ContentRegistryHub.registry_of(&"recipes")
	var all_recipe_ids: Array = []
	
	# TODO: More efficient filtering server-side
	# For now, just return all recipe IDs and let client load/filter
	
	var response = {
		"player_class": player_class,
		"player_level": player_level,
		"recipe_version": ContentRegistryHub.version_of(&"recipes")
	}
	
	print("Sending response: ", response)
	print("===============================")
	
	return response
