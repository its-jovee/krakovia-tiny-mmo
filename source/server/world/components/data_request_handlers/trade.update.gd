extends DataRequestHandler

func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var session_id: int = args.get("session_id", -1)
	var items: Dictionary = args.get("items", {})
	var gold: int = args.get("gold", 0)
	
	if not instance.has_node("TradeManager"):
		return {"error": "no_active_trade"}
	
	var trade_mgr: TradeManager = instance.get_node("TradeManager")
	if trade_mgr.update_offer(session_id, peer_id, items, gold):
		return {"success": true}
	else:
		return {"error": "failed"}
