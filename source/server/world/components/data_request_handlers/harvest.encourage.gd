extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	_args: Dictionary
) -> Dictionary:
	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		return {"ok": false, "err": &"no_player"}

	# Use HarvestManager for instant lookup (eliminates tree scan)
	var target: HarvestNode = instance.harvest_manager.get_player_harvest_node(peer_id)
	if target == null:
		return {"ok": false, "err": &"not_harvesting"}

	return target.request_encourage(peer_id)
