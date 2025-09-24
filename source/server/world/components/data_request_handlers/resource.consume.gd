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

	var cost_type: StringName = args.get("type", &"hp")
	var amount: float = float(args.get("amount", 5.0))

	# Try to pay via resource modules (e.g., HealthCostResource for "hp")
	var ok: bool = asc.try_pay_costs({cost_type: amount}, {"source": &"client_test"})
	return {"ok": ok}

