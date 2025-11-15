extends DataRequestHandler
## Handler for fetching account-wide storage contents

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
	
	# Get account storage from world data
	var world_server: WorldServer = instance.world_server
	if not world_server or not world_server.database:
		return {"error": "Database not available"}
	
	var player_data: WorldPlayerData = world_server.database.player_data
	if not player_data:
		return {"error": "World data not available"}
	
	var account_name: String = player.player_resource.account_name
	var storage: Dictionary = player_data.account_storage.get(account_name, {})
	
	print("[storage.get] Fetching storage for account '%s': %d items" % [account_name, storage.size()])
	
	return storage
