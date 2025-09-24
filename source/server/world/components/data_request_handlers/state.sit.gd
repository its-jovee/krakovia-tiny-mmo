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
	asc.ensure_attr(&"is_sitting", 0.0, 1.0)
	asc.set_value_server(&"is_sitting", 1.0 if on else 0.0)
	return {"sitting": on}
