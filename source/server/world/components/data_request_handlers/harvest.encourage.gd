extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	# Encourage system placeholder - sends session/hit/end events to client
	# Currently not implemented; returns error to client
	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		return {"ok": false, "err": &"no_player"}

	# The encourage system is not yet implemented
	return {"ok": false, "err": &"not_implemented"}
