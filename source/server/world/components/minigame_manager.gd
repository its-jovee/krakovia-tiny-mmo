class_name MinigameManager
extends Node

var world_server: WorldServer
var instance_manager: Node

var invitation_timer: Timer
var active_sessions: Dictionary = {}  # session_id -> game instance
var next_session_id: int = 1
var minigame_zones: Array = []  # Array of MinigameZone references

# Game types to cycle through
var available_games: Array[String] = ["hot_potato", "horse_racing"]
var current_game_index: int = 0

# Invitation settings
const INVITATION_INTERVAL: float = 900.0  # 15 minutes in seconds
const INVITATION_DURATION: float = 30.0  # Time players have to join
const PRE_START_DELAY: float = 60.0  # 1 minute warning before game starts


func _ready() -> void:
	# Get references to world server and instance manager
	world_server = get_parent().get_parent() as WorldServer
	instance_manager = get_parent()
	
	# Setup invitation timer
	invitation_timer = Timer.new()
	invitation_timer.wait_time = INVITATION_INTERVAL
	invitation_timer.one_shot = false
	invitation_timer.timeout.connect(_on_invitation_timer_timeout)
	add_child(invitation_timer)
	invitation_timer.start()
	
	print("[MinigameManager] Started minigame system")
	print("[MinigameManager] - Invitation interval: %d minutes" % (INVITATION_INTERVAL / 60.0))
	print("[MinigameManager] - Registered zones: %d" % minigame_zones.size())


func _on_invitation_timer_timeout() -> void:
	# Select next game type using rotation system
	var game_type: String = get_next_game_in_rotation()
	
	send_game_invitation(game_type)


func send_game_invitation(game_type: String) -> void:
	var game_name: String = get_game_display_name(game_type)
	var session_id: int = next_session_id
	next_session_id += 1
	
	# Create game session IMMEDIATELY in "waiting" phase
	var game_session = create_game_session(game_type, session_id)
	if not game_session:
		print("[MinigameManager] Failed to create game session for type: %s" % game_type)
		return
	
	active_sessions[session_id] = game_session
	
	# Send announcement to EVERYONE
	send_system_message("🎮 %s starting in 1 minute at the Game Arena! Hurry over to join!" % game_name)
	
	# NEW: Send popup announcement to ALL players
	send_announcement_popup("🎮 %s Starting Soon!" % game_name, "Get to the Game Arena in 1 minute to join!", 10.0)
	
	# IMMEDIATELY send popup to players already in zone
	var players_in_zone: Array = []
	for zone in minigame_zones:
		players_in_zone.append_array(zone.get_players_in_zone())
	
	print("[MinigameManager] Found %d players in minigame zones" % players_in_zone.size())
	
	if players_in_zone.size() > 0:
		for peer_id in players_in_zone:
			send_invitation_popup(peer_id, session_id, game_type, game_name)
	
	print("[MinigameManager] Created session %d for %s, sent invites to %d players" % [session_id, game_name, players_in_zone.size()])
	
	# Wait 1 minute, then start the game phase
	await get_tree().create_timer(PRE_START_DELAY).timeout
	
	# Check if session still exists (might have been cancelled)
	if active_sessions.has(session_id):
		match game_type:
			"horse_racing":
				send_system_message("🎮 %s betting phase has begun!" % game_name)
				game_session.start_betting_phase()
			"hot_potato":
				send_system_message("🎮 %s has begun! Good luck!" % game_name)
				game_session.start_active_phase()
			_:
				push_warning("[MinigameManager] Unknown game type in phase start: %s" % game_type)
	else:
		print("[MinigameManager] Session %d was cancelled during waiting phase" % session_id)


func create_game_session(game_type: String, session_id: int) -> Node:
	match game_type:
		"horse_racing":
			var game = HorseRacingGame.new()
			game.session_id = session_id
			game.minigame_manager = self
			add_child(game)
			return game
		"hot_potato":
			var game = HotPotatoGame.new()
			game.session_id = session_id
			game.minigame_manager = self
			# Pass zone reference for locking
			if not minigame_zones.is_empty():
				game.zone_reference = minigame_zones[0]
			add_child(game)
			return game
		_:
			print("[MinigameManager] Unknown game type: %s" % game_type)
			return null


func get_game_display_name(game_type: String) -> String:
	match game_type:
		"horse_racing":
			return "Horse Racing"
		"hot_potato":
			return "Hot Potato"
		_:
			return game_type.capitalize()


func get_next_game_in_rotation() -> String:
	"""Get next game in rotation and advance the index"""
	if available_games.is_empty():
		return "horse_racing"  # Fallback
	
	var game_type = available_games[current_game_index]
	current_game_index = (current_game_index + 1) % available_games.size()
	
	return game_type


func get_active_session(session_id: int):
	return active_sessions.get(session_id, null)


func remove_session(session_id: int) -> void:
	if active_sessions.has(session_id):
		var session = active_sessions[session_id]
		active_sessions.erase(session_id)
		if session:
			session.queue_free()
		print("[MinigameManager] Removed session %d" % session_id)


func broadcast_to_all_players(event: StringName, data: Dictionary) -> void:
	# Broadcast to all players across all instances
	for child in instance_manager.get_children():
		if child is ServerInstance:
			child.propagate_rpc(child.data_push.bind(event, data))


func register_minigame_zone(zone: MinigameZone) -> void:
	if not minigame_zones.has(zone):
		minigame_zones.append(zone)
		print("[MinigameManager] Registered minigame zone: %s" % zone.zone_name)


func unregister_minigame_zone(zone: MinigameZone) -> void:
	minigame_zones.erase(zone)
	print("[MinigameManager] Unregistered minigame zone: %s" % zone.zone_name)


func send_invitation_popup(peer_id: int, session_id: int, game_type: String, game_name: String) -> void:
	"""Send invitation popup to a specific player"""
	for child in instance_manager.get_children():
		if child is ServerInstance:
			if child.connected_peers.has(peer_id):
				child.data_push.rpc_id(peer_id, &"minigame.invitation", {
					"session_id": session_id,
					"game_type": game_type,
					"game_name": game_name,
					"message": "🎮 %s is starting! Click to join!" % game_name,
					"duration": INVITATION_DURATION
				})
				print("[MinigameManager] Sent popup to peer %d" % peer_id)
				return


func notify_player_entered_zone(peer_id: int) -> void:
	"""Called by MinigameZone when a player enters during an active waiting phase"""
	# Find any active session in "waiting" phase
	for session_id in active_sessions:
		var game_session = active_sessions[session_id]
		if game_session.has_method("get_phase") and game_session.get_phase() == "waiting":
			var game_type = game_session.game_type
			var game_name = get_game_display_name(game_type)
			send_invitation_popup(peer_id, session_id, game_type, game_name)
			print("[MinigameManager] Sent invitation to player %d who entered zone during waiting phase" % peer_id)
			return


func notify_player_left_zone(peer_id: int) -> void:
	"""Called by MinigameZone when a player leaves the zone"""
	# Check all active sessions to see if player is participating
	for session_id in active_sessions:
		var game_session = active_sessions[session_id]
		
		# Only eliminate during active phase of Hot Potato
		if game_session.game_type == "hot_potato":
			if game_session.has_method("get_phase") and game_session.get_phase() == "active":
				# Check if player is in the game
				if game_session.active_players.has(peer_id):
					print("[MinigameManager] Player %d left zone during active Hot Potato - eliminating!" % peer_id)
					game_session.eliminate_player(peer_id)
					return


func send_system_message(message: String) -> void:
	# Send system message to all players
	for child in instance_manager.get_children():
		if child is ServerInstance:
			var chat_message = {
				"text": message,
				"name": "System",
				"id": 1
			}
			child.propagate_rpc(child.data_push.bind(&"chat.message", chat_message))


func send_announcement_popup(title: String, message: String, duration: float = 8.0) -> void:
	"""Send a popup announcement to ALL players in the game"""
	for child in instance_manager.get_children():
		if child is ServerInstance:
			for peer_id in child.connected_peers:
				child.data_push.rpc_id(peer_id, &"minigame.announcement", {
					"title": title,
					"message": message,
					"duration": duration
				})
