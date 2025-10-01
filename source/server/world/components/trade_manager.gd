class_name TradeManager
extends Node

# Trade sessions: {session_id: TradeSession}
var active_trades: Dictionary = {}
var next_session_id: int = 0

# Pending requests: {target_peer: requester_peer}
var pending_requests: Dictionary = {}

class TradeSession:
	var session_id: int
	var peer_a: int
	var peer_b: int
	var items_a: Dictionary = {}  # {item_id: quantity}
	var items_b: Dictionary = {}
	var gold_a: int = 0
	var gold_b: int = 0
	var confirmed_a: bool = false
	var confirmed_b: bool = false
	var locked_a: bool = false
	var locked_b: bool = false
	var confirm_timer: float = 0.0
	var instance: ServerInstance

func is_player_in_trade(peer_id: int) -> bool:
	for session in active_trades.values():
		if session.peer_a == peer_id or session.peer_b == peer_id:
			return true
	return false

func handle_trade_request(requester_peer: int, target_peer: int, accepted: bool, instance: ServerInstance) -> Dictionary:
	print("=== TRADE REQUEST HANDLER ===")
	print("Requester: ", requester_peer, " Target (accepter): ", target_peer, " Accepted: ", accepted)
	print("Pending requests: ", pending_requests)
	
	if not pending_requests.has(target_peer) or pending_requests[target_peer] != requester_peer:
		print("ERROR: No pending request!")
		return {"error": "No pending request"}
	
	pending_requests.erase(target_peer)
	
	if not accepted:
		instance.data_push.rpc_id(requester_peer, &"trade.request_denied", {
			"target_name": instance.get_player(target_peer).player_resource.display_name
		})
		return {"success": "Trade request denied"}
	
	# Create trade session
	next_session_id += 1
	var session = TradeSession.new()
	session.session_id = next_session_id
	session.peer_a = requester_peer
	session.peer_b = target_peer
	session.instance = instance
	active_trades[next_session_id] = session
	
	# Notify both players
	var requester_name = instance.get_player(requester_peer).player_resource.display_name
	var target_name = instance.get_player(target_peer).player_resource.display_name
	
	instance.data_push.rpc_id(requester_peer, &"trade.open", {
		"session_id": next_session_id,
		"other_peer": target_peer,
		"other_name": target_name
	})
	instance.data_push.rpc_id(target_peer, &"trade.open", {
		"session_id": next_session_id,
		"other_peer": requester_peer,
		"other_name": requester_name
	})
	
	return {"success": "Trade started"}

func initiate_trade(peer_a: int, peer_b: int, instance: ServerInstance) -> int:
	# This method is now called internally by handle_trade_request
	# Keeping for backward compatibility
	return handle_trade_request(peer_a, peer_b, true, instance).get("session_id", -1)

func update_offer(session_id: int, peer_id: int, items: Dictionary, gold: int) -> bool:
	if not active_trades.has(session_id):
		return false
	
	var session: TradeSession = active_trades[session_id]
	
	# Reset confirmations on change
	session.confirmed_a = false
	session.confirmed_b = false
	
	if peer_id == session.peer_a:
		session.items_a = items
		session.gold_a = gold
	elif peer_id == session.peer_b:
		session.items_b = items
		session.gold_b = gold
	else:
		return false
	
	# Broadcast update
	_broadcast_update(session)
	return true

func confirm_trade(session_id: int, peer_id: int, ready: bool = true) -> Dictionary:
	if not active_trades.has(session_id):
		return {"error": "invalid_session"}
	
	var session: TradeSession = active_trades[session_id]
	
	if peer_id == session.peer_a:
		session.confirmed_a = ready
	elif peer_id == session.peer_b:
		session.confirmed_b = ready
	else:
		return {"error": "invalid_peer"}
	
	# If unconfirming, unlock the trade
	if not ready:
		session.locked_a = false
		session.locked_b = false
		session.confirm_timer = 0.0
	
	_broadcast_update(session)
	
	# Both confirmed? Start 3-second timer
	if session.confirmed_a and session.confirmed_b:
		session.locked_a = true
		session.locked_b = true
		session.confirm_timer = 1.0
		return {"status": "locked", "timer": 1.0}
	
	return {"status": "confirmed" if ready else "unconfirmed"}

func execute_trade(session_id: int) -> bool:
	if not active_trades.has(session_id):
		return false
	
	var session: TradeSession = active_trades[session_id]
	
	# Validate both players have the items/gold
	var player_a = session.instance.get_player(session.peer_a)
	var player_b = session.instance.get_player(session.peer_b)
	
	if not player_a or not player_b:
		return false
	
	var res_a = player_a.player_resource
	var res_b = player_b.player_resource
	
	# Validate player A has items/gold
	for item_id in session.items_a:
		if not res_a.inventory.has(item_id) or res_a.inventory[item_id].stack < session.items_a[item_id]:
			return false
	if res_a.golds < session.gold_a:
		return false
	
	# Validate player B has items/gold
	for item_id in session.items_b:
		if not res_b.inventory.has(item_id) or res_b.inventory[item_id].stack < session.items_b[item_id]:
			return false
	if res_b.golds < session.gold_b:
		return false
	
	# Execute exchange
	# Remove from A, add to B
	for item_id in session.items_a:
		res_a.inventory[item_id].stack -= session.items_a[item_id]
		if res_a.inventory[item_id].stack <= 0:
			res_a.inventory.erase(item_id)
		if not res_b.inventory.has(item_id):
			res_b.inventory[item_id] = {"stack": session.items_a[item_id]}
		else:
			res_b.inventory[item_id].stack += session.items_a[item_id]
	res_a.golds -= session.gold_a
	res_b.golds += session.gold_a
	
	# Remove from B, add to A
	for item_id in session.items_b:
		res_b.inventory[item_id].stack -= session.items_b[item_id]
		if res_b.inventory[item_id].stack <= 0:
			res_b.inventory.erase(item_id)
		if not res_a.inventory.has(item_id):
			res_a.inventory[item_id] = {"stack": session.items_b[item_id]}
		else:
			res_a.inventory[item_id].stack += session.items_b[item_id]
	res_b.golds -= session.gold_b
	res_a.golds += session.gold_b
	
	# Log trade (optional: save to database)
	_log_trade(session)
	
	# Notify completion
	session.instance.data_push.rpc_id(session.peer_a, &"trade.complete", {})
	session.instance.data_push.rpc_id(session.peer_b, &"trade.complete", {})
	
	active_trades.erase(session_id)
	return true

func cancel_trade(session_id: int, peer_id: int = -1) -> Dictionary:
	if not active_trades.has(session_id):
		return {"error": "invalid_session"}
	
	var session: TradeSession = active_trades[session_id]
	
	# Check if the cancelling peer is part of this trade
	if peer_id != -1 and peer_id != session.peer_a and peer_id != session.peer_b:
		return {"error": "not_participant"}
	
	# Get the name of who cancelled
	var cancelled_by_name = ""
	if peer_id == session.peer_a:
		cancelled_by_name = session.instance.get_player(session.peer_a).player_resource.display_name
	elif peer_id == session.peer_b:
		cancelled_by_name = session.instance.get_player(session.peer_b).player_resource.display_name
	else:
		cancelled_by_name = "System"
	
	# Notify both players about the cancellation
	session.instance.data_push.rpc_id(session.peer_a, &"trade.cancel", {
		"cancelled_by": cancelled_by_name
	})
	session.instance.data_push.rpc_id(session.peer_b, &"trade.cancel", {
		"cancelled_by": cancelled_by_name
	})
	
	# Remove the trade session
	active_trades.erase(session_id)
	
	return {"success": "Trade cancelled"}

func _broadcast_update(session: TradeSession):
	session.instance.data_push.rpc_id(session.peer_a, &"trade.update", {
		"session_id": session.session_id,
		"your_items": session.items_a,
		"your_gold": session.gold_a,
		"their_items": session.items_b,
		"their_gold": session.gold_b,
		"your_confirmed": session.confirmed_a,
		"their_confirmed": session.confirmed_b,
		"locked": session.locked_a
	})
	session.instance.data_push.rpc_id(session.peer_b, &"trade.update", {
		"session_id": session.session_id,
		"your_items": session.items_b,
		"your_gold": session.gold_b,
		"their_items": session.items_a,
		"their_gold": session.gold_a,
		"your_confirmed": session.confirmed_b,
		"their_confirmed": session.confirmed_a,
		"locked": session.locked_b
	})

func _log_trade(session: TradeSession):
	var log_entry = {
		"timestamp": Time.get_unix_time_from_system(),
		"peer_a": session.peer_a,
		"peer_b": session.peer_b,
		"items_a": session.items_a,
		"gold_a": session.gold_a,
		"items_b": session.items_b,
		"gold_b": session.gold_b
	}
	# Save to file or database
	print("Trade completed: ", log_entry)

func _process(delta: float):
	for session_id in active_trades.keys():
		var session: TradeSession = active_trades[session_id]
		if session.locked_a and session.locked_b and session.confirm_timer > 0:
			session.confirm_timer -= delta
			if session.confirm_timer <= 0:
				execute_trade(session_id)
