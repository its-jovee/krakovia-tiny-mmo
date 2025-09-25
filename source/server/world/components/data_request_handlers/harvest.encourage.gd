extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	_args: Dictionary
) -> Dictionary:
	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		return {"ok": false, "err": &"no_player"}

	# Find the node this player is harvesting
	var target: HarvestNode = null
	for node in instance.get_tree().get_nodes_in_group(&"harvest_nodes"):
		if node is HarvestNode:
			var hn: HarvestNode = node
			if hn.harvesters.has(peer_id):
				target = hn
				break
	if target == null:
		return {"ok": false, "err": &"not_harvesting"}

	return target.request_encourage(peer_id)
