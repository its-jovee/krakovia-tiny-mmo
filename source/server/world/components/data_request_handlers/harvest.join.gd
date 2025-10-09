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

	var result: Dictionary = best.player_join(peer_id, player)
	if not result.get("ok", false):
		# Pass through error information from node validation
		return result
	
	# Success - add node info to response
	result["node"] = String(best.get_path())
	result["count"] = best.get_count()
	result["multiplier"] = best.multiplier
	result["state"] = best.state
	result["remaining"] = best.remaining_amount
	result["pool"] = best.pool_amount
	result["tier"] = best.tier
	result["required_class"] = best.required_class
	result["required_level"] = best.required_level
	return result
