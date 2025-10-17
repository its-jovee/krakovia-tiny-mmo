class_name HotPotatoGame
extends Node

var session_id: int
var minigame_manager: MinigameManager
var game_type: String = "hot_potato"

# Game state
var phase: String = "waiting"
var waiting_time_left: float = 60.0
var active_players: Dictionary = {}  # peer_id -> Player reference
var eliminated_players: Dictionary = {}  # peer_id -> player_name
var current_potato_holder_id: int = -1
var potato_timer: float = 5.0
var zone_reference: MinigameZone
var grace_timers: Dictionary = {}  # peer_id -> time_left (seconds remaining in grace period)

# Constants
const TOUCH_DISTANCE: float = 50.0
const SPEED_BOOST: float = 1.5
const POTATO_DURATION: float = 5.0
const GRACE_PERIOD: float = 1.0  # Can't receive potato back for 1 second after passing

# Timers
var state_broadcast_timer: Timer
var waiting_timer: Timer


func _ready() -> void:
	# Setup state broadcast timer
	state_broadcast_timer = Timer.new()
	state_broadcast_timer.wait_time = 1.0  # Broadcast once per second
	state_broadcast_timer.one_shot = false
	state_broadcast_timer.timeout.connect(broadcast_state)
	add_child(state_broadcast_timer)
	state_broadcast_timer.start()  # Start immediately for waiting phase
	
	print("[HotPotato:%d] Game created in waiting phase" % session_id)


func get_phase() -> String:
	return phase


func start_active_phase() -> void:
	"""Called by MinigameManager after 60-second waiting phase"""
	if active_players.size() < 2:
		print("[HotPotato:%d] Not enough players (%d), cancelling game" % [session_id, active_players.size()])
		minigame_manager.send_system_message("Hot Potato cancelled - not enough players!")
		minigame_manager.remove_session(session_id)
		return
	
	phase = "active"
	print("[HotPotato:%d] Starting active phase with %d players" % [session_id, active_players.size()])
	
	# Lock the zone
	if zone_reference:
		zone_reference.lock_zone()
		print("[HotPotato:%d] Zone locked" % session_id)
	
	# Clear grace timers (fresh start)
	grace_timers.clear()
	
	# Assign first potato randomly
	assign_random_potato()
	
	# Increase broadcast frequency during active phase (potato is moving fast!)
	state_broadcast_timer.wait_time = 0.1  # 10 times per second
	
	broadcast_state()


func join_game(peer_id: int, instance: ServerInstance, player_name: String) -> Dictionary:
	"""Handle player joining the game"""
	if phase != "waiting":
		return {"success": false, "error": "Game already started"}
	
	# Get player reference from the server instance
	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		print("[HotPotato:%d] ERROR: Player not found for peer %d in instance" % [session_id, peer_id])
		return {"success": false, "error": "Player not found"}
	
	active_players[peer_id] = player
	print("[HotPotato:%d] Player %s joined (total: %d)" % [session_id, player_name, active_players.size()])
	
	broadcast_state()
	
	return {"success": true, "session_id": session_id}


func leave_game(peer_id: int) -> Dictionary:
	"""Handle player leaving during waiting phase"""
	if phase != "waiting":
		return {"success": false, "error": "Cannot leave after game started"}
	
	if active_players.has(peer_id):
		active_players.erase(peer_id)
		print("[HotPotato:%d] Player left during waiting phase (remaining: %d)" % [session_id, active_players.size()])
		broadcast_state()
		return {"success": true}
	
	return {"success": false, "error": "Player not in game"}


func _process(delta: float) -> void:
	if phase == "waiting":
		waiting_time_left -= delta


func _physics_process(delta: float) -> void:
	if phase != "active" or current_potato_holder_id == -1:
		return
	
	# Decrement potato timer
	potato_timer -= delta
	
	# Decrement grace timers
	for peer_id in grace_timers.keys():
		grace_timers[peer_id] -= delta
		if grace_timers[peer_id] <= 0:
			grace_timers.erase(peer_id)
	
	if potato_timer <= 0:
		# Timer expired - eliminate current holder
		eliminate_player(current_potato_holder_id)
		return
	
	# Check for touches with other players
	if not active_players.has(current_potato_holder_id):
		assign_random_potato()
		return
	
	var holder = active_players[current_potato_holder_id]
	for peer_id in active_players:
		if peer_id == current_potato_holder_id:
			continue
		
		# Skip players on grace period (just passed potato)
		if grace_timers.has(peer_id):
			continue
		
		var other = active_players[peer_id]
		var distance = holder.global_position.distance_to(other.global_position)
		
		if distance < TOUCH_DISTANCE:
			transfer_potato(current_potato_holder_id, peer_id)
			break


func transfer_potato(from_peer: int, to_peer: int) -> void:
	"""Transfer potato from one player to another"""
	print("[HotPotato:%d] Potato passed from %d to %d (timer: %.1fs)" % [session_id, from_peer, to_peer, potato_timer])
	
	# Remove speed boost from previous holder
	if active_players.has(from_peer):
		remove_speed_boost(from_peer)
	
	# Give potato to new holder
	current_potato_holder_id = to_peer
	# DO NOT RESET THE TIMER - let it continue counting down
	
	# Apply grace period to the player who just passed (can't receive back for 1 second)
	grace_timers[from_peer] = GRACE_PERIOD
	print("[HotPotato:%d] Grace period applied to peer %d for %.1fs" % [session_id, from_peer, GRACE_PERIOD])
	
	# Apply speed boost to new holder
	if active_players.has(to_peer):
		apply_speed_boost(to_peer)
	
	# Notify clients
	_broadcast_potato_transfer(from_peer, to_peer)
	broadcast_state()


func assign_random_potato() -> void:
	"""Randomly assign potato to an active player"""
	if active_players.is_empty():
		end_game()
		return
	
	var player_ids = active_players.keys()
	var random_peer = player_ids[randi() % player_ids.size()]
	
	current_potato_holder_id = random_peer
	potato_timer = POTATO_DURATION
	
	apply_speed_boost(random_peer)
	
	print("[HotPotato:%d] Potato randomly assigned to peer %d" % [session_id, random_peer])
	broadcast_state()


func eliminate_player(peer_id: int) -> void:
	"""Eliminate a player from the game"""
	if not active_players.has(peer_id):
		return
	
	var player = active_players[peer_id]
	var player_name = player.player_resource.display_name
	print("[HotPotato:%d] Player %s eliminated!" % [session_id, player_name])
	
	# Remove speed boost if they had potato
	if peer_id == current_potato_holder_id:
		remove_speed_boost(peer_id)
		current_potato_holder_id = -1
	
	# Teleport player outside the zone
	if zone_reference and zone_reference.elimination_teleport_position != Vector2.ZERO:
		player.just_teleported = true
		player.syn.set_by_path(^":position", zone_reference.elimination_teleport_position)
		print("[HotPotato:%d] Teleported eliminated player to %v" % [session_id, zone_reference.elimination_teleport_position])
	
	# Move to eliminated list (store name for UI)
	eliminated_players[peer_id] = player_name
	active_players.erase(peer_id)
	
	# Clear grace period for eliminated player
	grace_timers.erase(peer_id)
	
	# Notify clients
	_broadcast_elimination(peer_id)
	
	# Check if game is over
	if active_players.size() <= 1:
		end_game()
	else:
		# Assign potato to random remaining player
		assign_random_potato()


func end_game() -> void:
	"""End the game and declare winner"""
	phase = "finished"
	state_broadcast_timer.stop()
	
	# Unlock zone
	if zone_reference:
		zone_reference.unlock_zone()
	
	# Determine winner
	if active_players.size() == 1:
		var winner_id = active_players.keys()[0]
		var winner = active_players[winner_id]
		print("[HotPotato:%d] Winner: %s (peer %d)" % [session_id, winner.player_resource.display_name, winner_id])
		
		# Award item
		award_winner(winner_id)
	else:
		print("[HotPotato:%d] No winner - all players eliminated" % session_id)
		minigame_manager.send_system_message("Hot Potato ended in a draw!")
	
	# Schedule cleanup
	await get_tree().create_timer(10.0).timeout
	minigame_manager.remove_session(session_id)


func award_winner(peer_id: int) -> void:
	"""Award random item to winner"""
	# Get all item IDs from ContentRegistry
	var items_registry = ContentRegistryHub.registry_of(&"items")
	if not items_registry:
		push_error("[HotPotato:%d] Items registry not found!" % session_id)
		return
	
	var all_item_ids = items_registry._id_to_path.keys()
	if all_item_ids.is_empty():
		push_error("[HotPotato:%d] No items in ContentRegistry!" % session_id)
		return
	
	# Pick random item ID
	var random_item_id = all_item_ids[randi() % all_item_ids.size()]
	
	# Load the item to get its name
	var random_item = ContentRegistryHub.load_by_id(&"items", random_item_id)
	if not random_item:
		push_error("[HotPotato:%d] Failed to load item %d" % [session_id, random_item_id])
		return
	
	# Get item name safely
	var item_name: String = "Unknown Item"
	if "display_name" in random_item:
		item_name = random_item.display_name
	elif "item_name" in random_item:
		item_name = random_item.item_name
	
	print("[HotPotato:%d] Awarding %s (ID: %d) to peer %d" % [session_id, item_name, random_item_id, peer_id])
	
	# Add item directly to player's inventory
	if active_players.has(peer_id):
		var player: Player = active_players[peer_id]
		var inv: Dictionary = player.player_resource.inventory
		var slot: Dictionary = inv.get(random_item_id, {"stack": 0})
		slot["stack"] = int(slot.get("stack", 0)) + 1
		inv[random_item_id] = slot
		
		print("[HotPotato:%d] Added item to inventory successfully" % session_id)
		
		# Notify winner and update inventory
		var instance_manager = minigame_manager.instance_manager
		for child in instance_manager.get_children():
			if child is ServerInstance:
				if child.connected_peers.has(peer_id):
					# Update inventory
					child.data_push.rpc_id(peer_id, &"inventory.update", inv)
					# Send results
					child.data_push.rpc_id(peer_id, &"minigame.results", {
						"session_id": session_id,
						"winner": true,
						"item_id": random_item_id,
						"item_name": item_name
					})
					# Send chat message
					child.data_push.rpc_id(peer_id, &"chat.message", {
						"text": "🎉 You won Hot Potato and received: %s!" % item_name,
						"name": "System",
						"id": 1
					})
					return


func apply_speed_boost(peer_id: int) -> void:
	"""Apply speed boost to potato holder"""
	if active_players.has(peer_id):
		var player = active_players[peer_id]
		# Directly modify the player's speed variable
		if "speed" in player:
			player.speed *= SPEED_BOOST
			print("[HotPotato:%d] Applied speed boost to peer %d (new speed: %.1f)" % [session_id, peer_id, player.speed])


func remove_speed_boost(peer_id: int) -> void:
	"""Remove speed boost from player"""
	if active_players.has(peer_id):
		var player = active_players[peer_id]
		# Directly modify the player's speed variable
		if "speed" in player:
			player.speed /= SPEED_BOOST
			print("[HotPotato:%d] Removed speed boost from peer %d (new speed: %.1f)" % [session_id, peer_id, player.speed])


func broadcast_state() -> void:
	"""Send current game state to all participants"""
	var participants = []
	
	# Build participant list
	for peer_id in active_players:
		var player = active_players[peer_id]
		participants.append({
			"peer_id": peer_id,
			"name": player.player_resource.display_name,
			"has_potato": peer_id == current_potato_holder_id,
			"eliminated": false
		})
	
	for peer_id in eliminated_players:
		participants.append({
			"peer_id": peer_id,
			"name": eliminated_players[peer_id],
			"has_potato": false,
			"eliminated": true
		})
	
	var time_left = waiting_time_left if phase == "waiting" else potato_timer
	
	var state = {
		"game_type": "hot_potato",
		"session_id": session_id,
		"phase": phase,
		"participants": participants,
		"time_left": time_left,
		"potato_holder_id": current_potato_holder_id
	}
	
	# Send to all participants
	var instance_manager = minigame_manager.instance_manager
	for child in instance_manager.get_children():
		if child is ServerInstance:
			for peer_id in active_players.keys() + eliminated_players.keys():
				if child.connected_peers.has(peer_id):
					child.data_push.rpc_id(peer_id, &"minigame.state", state)


func _broadcast_potato_transfer(from_peer: int, to_peer: int) -> void:
	"""Notify clients about potato transfer"""
	var instance_manager = minigame_manager.instance_manager
	for child in instance_manager.get_children():
		if child is ServerInstance:
			for peer_id in active_players.keys() + eliminated_players.keys():
				if child.connected_peers.has(peer_id):
					child.data_push.rpc_id(peer_id, &"minigame.potato_transfer", {
						"from_peer": from_peer,
						"to_peer": to_peer
					})


func _broadcast_elimination(eliminated_peer: int) -> void:
	"""Notify clients about player elimination"""
	var instance_manager = minigame_manager.instance_manager
	for child in instance_manager.get_children():
		if child is ServerInstance:
			for peer_id in active_players.keys() + eliminated_players.keys():
				if child.connected_peers.has(peer_id):
					child.data_push.rpc_id(peer_id, &"minigame.elimination", {
						"peer_id": eliminated_peer
					})


func _on_player_disconnected(peer_id: int) -> void:
	"""Handle player disconnect"""
	if active_players.has(peer_id):
		var player = active_players[peer_id]
		var player_name = player.player_resource.display_name
		print("[HotPotato:%d] Player %s disconnected" % [session_id, player_name])
		
		# If they had the potato, transfer it immediately
		if peer_id == current_potato_holder_id:
			eliminate_player(peer_id)
		else:
			eliminated_players[peer_id] = player_name
			active_players.erase(peer_id)
			
			if active_players.size() <= 1:
				end_game()
