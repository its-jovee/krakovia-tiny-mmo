extends Control


# Floating Timer (stays visible during active phase)
@onready var floating_timer: PanelContainer = $FloatingTimer
@onready var floating_timer_label: Label = $FloatingTimer/MarginContainer/VBoxContainer/TimerLabel

# Game Panel
@onready var game_panel: PanelContainer = $GamePanel

# UI Nodes
@onready var waiting_phase: VBoxContainer = $GamePanel/MarginContainer/VBoxContainer/WaitingPhase
@onready var active_phase: VBoxContainer = $GamePanel/MarginContainer/VBoxContainer/ActivePhase
@onready var finished_phase: VBoxContainer = $GamePanel/MarginContainer/VBoxContainer/FinishedPhase

# Waiting Phase nodes
@onready var waiting_title: Label = $GamePanel/MarginContainer/VBoxContainer/WaitingPhase/Title
@onready var waiting_timer: Label = $GamePanel/MarginContainer/VBoxContainer/WaitingPhase/TimerLabel
@onready var waiting_players_container: VBoxContainer = $GamePanel/MarginContainer/VBoxContainer/WaitingPhase/ScrollContainer/PlayersContainer
@onready var leave_button_waiting: Button = $GamePanel/MarginContainer/VBoxContainer/WaitingPhase/LeaveButton

# Active Phase nodes
@onready var potato_holder_label: Label = $GamePanel/MarginContainer/VBoxContainer/ActivePhase/PotatoHolder
@onready var potato_timer_label: Label = $GamePanel/MarginContainer/VBoxContainer/ActivePhase/PotatoTimer
@onready var active_players_container: VBoxContainer = $GamePanel/MarginContainer/VBoxContainer/ActivePhase/PlayersScroll/PlayersContainer
@onready var eliminated_players_container: VBoxContainer = $GamePanel/MarginContainer/VBoxContainer/ActivePhase/EliminatedScroll/EliminatedContainer

# Finished Phase nodes
@onready var winner_label: Label = $GamePanel/MarginContainer/VBoxContainer/FinishedPhase/WinnerLabel
@onready var item_reward_label: Label = $GamePanel/MarginContainer/VBoxContainer/FinishedPhase/ItemRewardLabel
@onready var close_button: Button = $GamePanel/MarginContainer/VBoxContainer/FinishedPhase/CloseButton

# Game state
var session_id: int = -1
var current_phase: String = "waiting"
var my_peer_id: int = -1
var am_eliminated: bool = false


func _ready() -> void:
	# Connect signals
	leave_button_waiting.pressed.connect(_on_leave_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	
	# Subscribe to minigame events
	InstanceClient.subscribe(&"minigame.state", _on_minigame_state)
	InstanceClient.subscribe(&"minigame.potato_transfer", _on_potato_transfer)
	InstanceClient.subscribe(&"minigame.elimination", _on_elimination)
	InstanceClient.subscribe(&"minigame.results", _on_results)
	
	# Get my peer ID
	my_peer_id = multiplayer.get_unique_id()
	
	hide()


func show_game(session_id_param: int) -> void:
	session_id = session_id_param
	current_phase = "waiting"
	am_eliminated = false
	
	_show_phase("waiting")
	show()


func _show_phase(phase: String) -> void:
	waiting_phase.hide()
	active_phase.hide()
	finished_phase.hide()
	floating_timer.hide()
	
	match phase:
		"waiting":
			waiting_phase.show()
			game_panel.show()  # Show game panel during waiting
		"active":
			game_panel.hide()  # Hide game panel during active gameplay so players can see!
			floating_timer.show()  # But show the floating timer
		"finished":
			finished_phase.show()
			game_panel.show()  # Show game panel again for results
			floating_timer.hide()
			_update_potato_indicators(-1)  # Hide all potato indicators


func _on_minigame_state(data: Dictionary) -> void:
	var received_session_id: int = data.get("session_id", -1)
	var game_type: String = data.get("game_type", "")
	
	# Only process hot potato games
	if game_type != "hot_potato":
		return
	
	# If we don't have a session or this is a new session, show the UI
	if session_id == -1 or (received_session_id != session_id and not visible):
		print("[HotPotatoUI] Showing UI for session: ", received_session_id)
		show_game(received_session_id)
	
	# Only process if this is our current session
	if data.get("session_id") != session_id:
		return
	
	var phase: String = data.get("phase", "waiting")
	var participants: Array = data.get("participants", [])
	var time_left: float = data.get("time_left", 0.0)
	var potato_holder_id: int = data.get("potato_holder_id", -1)
	
	# Update phase if changed
	if phase != current_phase:
		current_phase = phase
		_show_phase(phase)
	
	# Update UI based on phase
	match phase:
		"waiting":
			_update_waiting_phase(time_left, participants)
		"active":
			_update_active_phase(time_left, potato_holder_id, participants)


func _update_waiting_phase(time_left: float, participants: Array) -> void:
	# Update timer
	var minutes: int = int(time_left) / 60
	var seconds: int = int(time_left) % 60
	waiting_timer.text = "Game starts in: %02d:%02d" % [minutes, seconds]
	
	# Update players list
	_clear_container(waiting_players_container)
	for participant in participants:
		var peer_id = participant.get("peer_id", -1)
		var player_name = participant.get("name", "Unknown")
		var is_me = peer_id == my_peer_id
		
		var label = Label.new()
		label.text = "• %s%s" % [player_name, " (You)" if is_me else ""]
		label.add_theme_font_size_override("font_size", 14)
		waiting_players_container.add_child(label)


func _update_active_phase(time_left: float, potato_holder_id: int, participants: Array) -> void:
	# Update potato timer (both in panel and floating)
	potato_timer_label.text = "Potato explodes in: %.1fs" % time_left
	
	# Only show/update floating timer if player is not eliminated
	if not am_eliminated:
		floating_timer_label.text = "🥔 %.1f" % time_left
		
		# Change color based on urgency
		if time_left < 2.0:
			floating_timer_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))  # Red - critical!
		elif time_left < 3.5:
			floating_timer_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0))  # Orange - warning
		else:
			floating_timer_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))  # White - normal
	
	# Find potato holder name
	var holder_name = "Nobody"
	var holder_is_me = false
	
	for participant in participants:
		if participant.get("peer_id") == potato_holder_id:
			holder_name = participant.get("name", "Unknown")
			holder_is_me = (potato_holder_id == my_peer_id)
			break
	
	# Update potato holder display
	if holder_is_me:
		potato_holder_label.text = "🥔 YOU have the hot potato! 🥔"
		potato_holder_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	else:
		potato_holder_label.text = "🥔 %s has the potato" % holder_name
		potato_holder_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	
	# Show/hide potato indicator on player in game world
	_update_potato_indicators(potato_holder_id)
	
	# Update players lists
	_clear_container(active_players_container)
	_clear_container(eliminated_players_container)
	
	for participant in participants:
		var peer_id = participant.get("peer_id", -1)
		var player_name = participant.get("name", "Unknown")
		var is_eliminated = participant.get("eliminated", false)
		var has_potato = participant.get("has_potato", false)
		var is_me = peer_id == my_peer_id
		
		var label = Label.new()
		var potato_icon = "🥔 " if has_potato else ""
		label.text = "%s%s%s" % [potato_icon, player_name, " (You)" if is_me else ""]
		label.add_theme_font_size_override("font_size", 14)
		
		if is_eliminated:
			label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			eliminated_players_container.add_child(label)
			
			if is_me and not am_eliminated:
				am_eliminated = true
		else:
			active_players_container.add_child(label)


func _on_potato_transfer(data: Dictionary) -> void:
	# Could add visual feedback or sound effect here
	var from_peer = data.get("from_peer", -1)
	var to_peer = data.get("to_peer", -1)
	
	print("[HotPotatoUI] Potato transferred from %d to %d" % [from_peer, to_peer])


func _on_elimination(data: Dictionary) -> void:
	var eliminated_peer = data.get("peer_id", -1)
	
	# Immediately hide potato on the eliminated player
	var instance_client = InstanceClient.current
	if instance_client and instance_client.players_by_peer_id.has(eliminated_peer):
		var eliminated_player = instance_client.players_by_peer_id[eliminated_peer]
		var potato_indicator = eliminated_player.get_node_or_null("PotatoIndicator")
		if potato_indicator:
			potato_indicator.hide_potato()
	
	if eliminated_peer == my_peer_id:
		am_eliminated = true
		
		# Hide the floating timer for eliminated players
		floating_timer.hide()
		
		# Send a chat message to show elimination
		var chat_hud = get_tree().root.get_node_or_null("ClientMain/CanvasLayer/HUD/ChatHUD")
		if chat_hud and chat_hud.has_method("add_message"):
			chat_hud.add_message({
				"text": "💀 You were eliminated from Hot Potato! Watch the remaining players battle it out!",
				"id": 1,  # System message
				"name": "Game"
			})


func _on_results(data: Dictionary) -> void:
	if data.get("session_id") != session_id:
		return
	
	current_phase = "finished"
	_show_phase("finished")
	
	var is_winner = data.get("winner", false)
	var item_name = data.get("item_name", "")
	
	if is_winner:
		winner_label.text = "🎉 YOU WON! 🎉"
		winner_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
		item_reward_label.text = "Reward: %s" % item_name
		item_reward_label.show()
	else:
		winner_label.text = "Game Over"
		winner_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		item_reward_label.hide()


func _on_leave_button_pressed() -> void:
	# Send leave request
	InstanceClient.current.request_data(
		&"minigame.leave",
		func(response: Dictionary):
			if response.get("success", false):
				print("[HotPotatoUI] Successfully left game")
				hide()
				session_id = -1
				am_eliminated = false
			else:
				print("[HotPotatoUI] Failed to leave: ", response.get("error", "Unknown")),
		{"session_id": session_id}
	)


func _on_close_button_pressed() -> void:
	hide()
	session_id = -1
	am_eliminated = false


func _update_potato_indicators(potato_holder_id: int) -> void:
	"""Show potato indicator on the player with potato_holder_id, hide on others"""
	var instance_client = InstanceClient.current
	if not instance_client:
		return
	
	# Use InstanceClient's players_by_peer_id dictionary - much simpler!
	for peer_id in instance_client.players_by_peer_id:
		var player: Player = instance_client.players_by_peer_id[peer_id]
		if not player:
			continue
		
		var potato_indicator = player.get_node_or_null("PotatoIndicator")
		if potato_indicator:
			# Only show potato on the current holder (not -1, not eliminated players)
			if peer_id == potato_holder_id and potato_holder_id != -1:
				potato_indicator.show_potato()
			else:
				potato_indicator.hide_potato()


func _clear_container(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()
