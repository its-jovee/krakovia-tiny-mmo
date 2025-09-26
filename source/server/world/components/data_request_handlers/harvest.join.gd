extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	_args: Dictionary
) -> Dictionary:
	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		return {"ok": false, "err": &"no_player"}

	# Find nearest node in range
	var best: HarvestNode = null
	var best_d2: float = INF
	for node in instance.get_tree().get_nodes_in_group(&"harvest_nodes"):
		if node is HarvestNode:
			var hn: HarvestNode = node
			if hn.player_in_range(player):
				var d2: float = player.global_position.distance_squared_to(hn.global_position)
				if d2 < best_d2:
					best = hn
					best_d2 = d2
	if best == null:
		return {"ok": false, "err": &"no_node"}

	# Ensure player is not already harvesting elsewhere
	for node2 in instance.get_tree().get_nodes_in_group(&"harvest_nodes"):
		if node2 is HarvestNode:
			var hn2: HarvestNode = node2
			if hn2.harvesters.has(peer_id) and hn2 != best:
				hn2.player_leave(peer_id)

	var ok: bool = best.player_join(peer_id, player)
	if not ok:
		return {"ok": false, "err": &"join_failed"}
	return {
		"ok": true,
		"node": String(best.get_path()),
		"count": best.get_count(),
		"multiplier": best.multiplier,
		"state": best.state,
		"remaining": best.remaining_amount,
		"pool": best.pool_amount,
	}
