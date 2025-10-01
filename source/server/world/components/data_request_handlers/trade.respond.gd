extends DataRequestHandler

func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	print("=== TRADE.RESPOND DATA REQUEST HANDLER ===")
	print("Peer ID: ", peer_id)
	print("Args: ", args)
	
	var accepted: bool = args.get("accepted", false)
	var requester_peer: int = args.get("requester_peer", -1)
	
	print("Accepted: ", accepted, " Requester peer: ", requester_peer)
	
	if not instance.has_node("TradeManager"):
		print("ERROR: No TradeManager node!")
		return {"error": "No trade manager"}
	
	var trade_mgr: TradeManager = instance.get_node("TradeManager")
	var result = trade_mgr.handle_trade_request(requester_peer, peer_id, accepted, instance)
	print("Result: ", result)
	return result
