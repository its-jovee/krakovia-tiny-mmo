extends DataRequestHandler
## Handler for getting storage information (slot usage, etc.)

const MAX_STORAGE_SLOTS: int = 48

func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	# Get player
	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		return {"error": "Player not found"}
	
	if not player.player_resource:
		return {"error": "Player resource not available"}
	
	# Get world data
	var world_server: WorldServer = instance.world_server
	if not world_server or not world_server.database:
		return {"error": "Database not available"}
	
	var player_data: WorldPlayerData = world_server.database.player_data
	if not player_data:
		return {"error": "World data not available"}
	
	var account_name: String = player.player_resource.account_name
	var storage: Dictionary = player_data.account_storage.get(account_name, {})
	
	return {
		"used_slots": storage.size(),
		"max_slots": MAX_STORAGE_SLOTS,
		"account_name": account_name
	}

