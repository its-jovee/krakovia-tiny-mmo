extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	_args: Dictionary
) -> Dictionary:
	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		return {"ok": false, "err": &"no_player"}

	# Use HarvestManager to find nearest node (eliminates tree scan)
	var best: HarvestNode = instance.harvest_manager.find_nearest_in_range(player)
	if best == null:
		return {"ok": false, "err": &"no_node"}

	# Ensure player is not already harvesting elsewhere (eliminates second tree scan)
	instance.harvest_manager.ensure_single_harvest(peer_id, best)

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
