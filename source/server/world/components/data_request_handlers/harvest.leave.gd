extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	_args: Dictionary
) -> Dictionary:
	# Use HarvestManager for instant lookup (eliminates tree scan)
	var node: HarvestNode = instance.harvest_manager.get_player_harvest_node(peer_id)
	if node:
		node.player_leave(peer_id)
		return {"ok": true}
	return {"ok": false, "err": &"not_harvesting"}

