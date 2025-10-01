extends DataRequestHandler

func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var session_id: int = args.get("session_id", -1)
	var ready: bool = args.get("ready", true)  # Get ready state
	
	if not instance.has_node("TradeManager"):
		return {"error": "no_active_trade"}
	
	var trade_mgr: TradeManager = instance.get_node("TradeManager")
	return trade_mgr.confirm_trade(session_id, peer_id, ready)  # Pass ready state
