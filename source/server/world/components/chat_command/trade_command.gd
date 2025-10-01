extends ChatCommand

func execute(args: PackedStringArray, peer_id: int, server_instance: ServerInstance) -> String:
	if args.is_empty():
		return "Usage: /trade @playerhandle"
	
	var target_handle: String = args[1]
	if not target_handle.begins_with("@"):
		return "Usage: /trade @playerhandle"
	
	target_handle = target_handle.substr(1)  # Remove @
	
	# Find target player by handle
	var target_peer: int = -1
	for peer in server_instance.players_by_peer_id.keys():
		var player: Player = server_instance.players_by_peer_id[peer]
		if player.player_resource.account_name == target_handle:
			target_peer = peer
			break
	
	if target_peer == -1:
		return "Player not found"
	
	if target_peer == peer_id:
		return "Cannot trade with yourself"
	
	# Get trade manager
	if not server_instance.has_node("TradeManager"):
		var trade_mgr = TradeManager.new()
		trade_mgr.name = "TradeManager"
		server_instance.add_child(trade_mgr)
	
	var trade_mgr: TradeManager = server_instance.get_node("TradeManager")
	
	# Check if target is already in a trade
	if trade_mgr.is_player_in_trade(target_peer):
		return "Player is already in a trade"
	
	# Check if requester is already in a trade
	if trade_mgr.is_player_in_trade(peer_id):
		return "You are already in a trade"
	
	# Store pending request
	trade_mgr.pending_requests[target_peer] = peer_id
	
	# Send trade request to target player
	var requester_name = server_instance.players_by_peer_id[peer_id].player_resource.display_name
	server_instance.data_push.rpc_id(target_peer, &"trade.request", {
		"requester_peer": peer_id,
		"requester_name": requester_name
	})
	
	# Send confirmation to requester
	server_instance.data_push.rpc_id(peer_id, &"trade.request_sent", {
		"target_peer": target_peer,
		"target_name": target_handle
	})
	
	return "Trade request sent to " + target_handle
