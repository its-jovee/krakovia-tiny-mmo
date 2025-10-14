extends PanelContainer


@onready var game_name_label: Label = $MarginContainer/VBoxContainer/GameNameLabel
@onready var message_label: Label = $MarginContainer/VBoxContainer/MessageLabel
@onready var join_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/JoinButton
@onready var dismiss_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/DismissButton

var session_id: int = -1
var auto_dismiss_timer: Timer


func _ready() -> void:
	join_button.pressed.connect(_on_join_button_pressed)
	dismiss_button.pressed.connect(_on_dismiss_button_pressed)
	
	# Setup auto-dismiss timer
	auto_dismiss_timer = Timer.new()
	auto_dismiss_timer.one_shot = true
	auto_dismiss_timer.timeout.connect(_on_auto_dismiss)
	add_child(auto_dismiss_timer)
	
	hide()


func show_invitation(data: Dictionary) -> void:
	session_id = data.get("session_id", -1)
	var game_name: String = data.get("game_name", "Minigame")
	var message: String = data.get("message", "A minigame is starting!")
	var duration: float = data.get("duration", 30.0)
	
	game_name_label.text = game_name
	message_label.text = message
	
	# Start auto-dismiss timer
	auto_dismiss_timer.wait_time = duration
	auto_dismiss_timer.start()
	
	show()


func _on_join_button_pressed() -> void:
	if session_id != -1:
		print("[InvitationPopup] Joining session: ", session_id)
		# Request to join the game
		if InstanceClient.current:
			InstanceClient.current.request_data(&"minigame.join", _on_join_response, {
				"session_id": session_id
			})
		else:
			print("[InvitationPopup] ERROR: InstanceClient.current is null!")
	else:
		print("[InvitationPopup] ERROR: Invalid session_id")


func _on_join_response(response: Dictionary) -> void:
	print("[InvitationPopup] Received join response: ", response)
	
	if response.has("error"):
		print("[InvitationPopup] Failed to join: ", response["error"])
		# Show error to player
		var ui = get_viewport().get_node_or_null("UI")
		if ui:
			var chat = ui.get_node_or_null("ChatMenu")
			if chat:
				chat._on_chat_message({
					"text": "Failed to join game: " + response["error"],
					"name": "System",
					"id": 1
				})
	else:
		print("[InvitationPopup] Successfully joined game")
		# Show the horse racing UI
		var ui = get_viewport().get_node_or_null("UI")
		if ui and ui.has_node("HorseRacingUI"):
			var horse_ui = ui.get_node("HorseRacingUI")
			horse_ui.show_game(session_id)
	
	hide()


func _on_dismiss_button_pressed() -> void:
	hide()


func _on_auto_dismiss() -> void:
	hide()

