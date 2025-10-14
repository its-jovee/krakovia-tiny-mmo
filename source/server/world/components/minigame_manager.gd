class_name MinigameManager
extends Node

const HorseRacingGame = preload("res://source/server/world/components/minigames/horse_racing_game.gd")

var world_server: WorldServer
var instance_manager: Node

var invitation_timer: Timer
var active_sessions: Dictionary = {}  # session_id -> game instance
var next_session_id: int = 1

# Game types to cycle through
var available_games: Array[String] = ["horse_racing"]
var current_game_index: int = 0

# Invitation settings
const INVITATION_INTERVAL: float = 900.0  # 15 minutes in seconds
const INVITATION_DURATION: float = 30.0  # Time players have to join


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
	
	print("[MinigameManager] Started with %d minute invitation interval" % (INVITATION_INTERVAL / 60.0))


func _on_invitation_timer_timeout() -> void:
	# Select next game type
	var game_type: String = available_games[current_game_index]
	current_game_index = (current_game_index + 1) % available_games.size()
	
	send_game_invitation(game_type)


func send_game_invitation(game_type: String) -> void:
	var session_id: int = next_session_id
	next_session_id += 1
	
	# Create game session
	var game_session = create_game_session(game_type, session_id)
	if not game_session:
		print("[MinigameManager] Failed to create game session for type: %s" % game_type)
		return
	
	active_sessions[session_id] = game_session
	
	# Broadcast invitation to all players across all instances
	var game_name: String = get_game_display_name(game_type)
	var invitation_message: String = "🎮 %s is starting! Type /join to participate!" % game_name
	
	broadcast_to_all_players(&"minigame.invitation", {
		"session_id": session_id,
		"game_type": game_type,
		"game_name": game_name,
		"message": invitation_message,
		"duration": INVITATION_DURATION
	})
	
	# Also send as chat message
	send_system_message(invitation_message)
	
	print("[MinigameManager] Sent invitation for %s (session %d)" % [game_name, session_id])


func create_game_session(game_type: String, session_id: int) -> Node:
	match game_type:
		"horse_racing":
			var game = HorseRacingGame.new()
			game.session_id = session_id
			game.minigame_manager = self
			add_child(game)
			return game
		_:
			print("[MinigameManager] Unknown game type: %s" % game_type)
			return null


func get_game_display_name(game_type: String) -> String:
	match game_type:
		"horse_racing":
			return "Horse Racing"
		_:
			return game_type.capitalize()


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

