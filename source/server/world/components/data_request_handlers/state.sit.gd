extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		return {}

	var asc: AbilitySystemComponent = player.ability_system_component
	if not asc:
		return {}

	var on: bool = bool(args.get("on", true))
	
	# If player is harvesting, remove them from harvest session first
	if on:  # Trying to sit down
		var harvest_mgr: HarvestManager = instance.get_node_or_null("HarvestManager")
		if harvest_mgr and harvest_mgr.active_harvesters.has(peer_id):
			harvest_mgr.leave_current_node(peer_id)
	
	asc.ensure_attr(&"is_sitting", 0.0, 1.0)
	asc.set_value_server(&"is_sitting", 1.0 if on else 0.0)
	return {"sitting": on}
