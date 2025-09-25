extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	_args: Dictionary
) -> Dictionary:
	var found: bool = false
	for node in instance.get_tree().get_nodes_in_group(&"harvest_nodes"):
		if node is HarvestNode:
			var hn: HarvestNode = node
			if hn.harvesters.has(peer_id):
				found = true
				hn.player_leave(peer_id)
				break
	return {"ok": found, "err": null if found else &"not_harvesting"}

